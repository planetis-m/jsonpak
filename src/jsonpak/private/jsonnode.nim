type
  Node* = distinct uint64
  JsonNodeKind* = enum ## possible JSON node types
    JNull,
    JBool,
    JInt,
    JFloat,
    JString,
    JObject,
    JArray

const
  opcodeBits* = 4
  payloadBits* = sizeof(uint64)*8 - opcodeBits
  shortBit = 0b0000_1000

  shortLenMask = (1 shl opcodeBits) - 1

  shortIntLow* = -(1 shl payloadBits)
  shortIntHigh* = (1 shl payloadBits) - 1

  opcodeNull* = uint64 JNull
  opcodeBool* = uint64 JBool
  opcodeFalse* = opcodeBool
  opcodeTrue* = opcodeBool or shortBit
  opcodeInt* = uint64 JInt
  opcodeFloat* = uint64 JFloat
  opcodeString* = uint64 JString
  opcodeObject* = uint64 JObject
  opcodeArray* = uint64 JArray

  opcodeMask = (1 shl (opcodeBits - 1)) - 1

template kind*(n: Node): uint64 = n.uint64 and opcodeMask
template operand*(n: Node): uint64 = n.uint64 shr opcodeBits.uint64
template isShort*(n: Node): bool = (n.uint64 and shortBit) != 0
template shortLen*(n: Node): int = int(n.uint64 shr opcodeBits.uint64 and shortLenMask)

template toShortNode*(kind, operand: uint64): Node =
  Node(operand shl opcodeBits.uint64 or kind or shortBit.uint64)

template toNode*(kind, operand: uint64): Node =
  Node(operand shl opcodeBits.uint64 or kind)

proc `==`*(a, b: Node): bool {.borrow.}
