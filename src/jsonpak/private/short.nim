type
  Node* = distinct int64
  JsonNodeKind* = enum ## possible JSON node types
    JNull,
    JBool,
    JInt,
    JFloat,
    JString,
    JObject,
    JArray

const
  opcodeBits = 3
  payloadBits = 60
  shortBit = 0b0000_1000

  opcodeNull* = ord JNull
  opcodeBool* = ord JBool
  opcodeFalse* = opcodeBool
  opcodeTrue* = opcodeBool or shortBit
  opcodeInt* = ord JInt
  opcodeFloat* = ord JFloat
  opcodeString* = ord JString
  opcodeObject* = ord JObject
  opcodeArray* = ord JArray

  opcodeMask = 0b111

  shortIntBits = payloadBits - 1
  shortIntMin = -(1'i64 shl shortIntBits)
  shortIntMax = (1'i64 shl shortIntBits) - 1

template kind*(n: Node): int64 = n.int64 and opcodeMask
template operand*(n: Node): int64 = int64(n.uint64 shr opcodeBits.int64)
template isShort*(n: Node): bool = (n.int64 and shortBit) != 0

template toNode*(kind, operand: int64; isShort: bool = false): Node =
  if isShort:
    Node(operand shl opcodeBits.int64 or kind.int64 or shortBit.int64)
  else:
    Node(operand shl opcodeBits.int64 or kind.int64)

proc `==`*(a, b: Node): bool {.borrow.}

template str*(n: NodePos): string =
  if n.kind == opcodeString and isShort(tree.nodes[n.int]):
    var data = newString(payloadBits div 8)
    for i in 0 ..< data.len:
      data[i] = chr(n.operand shr (i * 8) and 0xFF)
    data
  else:
    tree.atoms[litId(n)]

template ival*(n: NodePos): int64 =
  if n.kind == opcodeInt and isShort(tree.nodes[n.int]):
    n.operand
  else:
    parseInt(tree.atoms[litId(n)])

proc storeAtom*(tree: var JsonTree; kind: int32; data: int64) {.inline.} =
  if data >= low(int32) and data <= high(int32):
    tree.nodes.add toNode(kind, data, isShort = true)
  else:
    tree.nodes.add toNode(kind, int64 getOrIncl(tree.atoms, $data))

proc storeAtom*(tree: var JsonTree; kind: int32; data: string) {.inline.} =
  if data.len <= payloadBits div 8:
    var payload = 0'u64
    for i in 0 ..< data.len:
      payload = payload or (data[i].uint64 shl (i * 8))
    tree.nodes.add toNode(kind, payload, isShort = true)
  else:
    tree.nodes.add toNode(kind, int64 getOrIncl(tree.atoms, data))
