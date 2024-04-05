import bitabs, jsonnode, std/assertions, ssostrings

type
  JsonTree* = object
    nodes: seq[Node]
    atoms: BiTable[String]

proc isEmpty*(tree: JsonTree): bool {.inline.} =
  tree.nodes.len == 0 or tree.nodes.len == 1 and tree.nodes[0].kind == opcodeNull

proc isAtom*(tree: JsonTree; pos: int): bool {.inline.} =
  tree.nodes[pos].kind <= opcodeString

template rawSpan*(n: Node): int = int(operand(n))

proc span*(tree: JsonTree; pos: int): int {.inline.} =
  if isAtom(tree, pos): 1 else: tree.nodes[pos].rawSpan

proc nextChild*(tree: JsonTree; pos: var int) {.inline.} =
  if tree.nodes[pos].kind > opcodeString:
    assert tree.nodes[pos].rawSpan > 0
    inc pos, tree.nodes[pos].rawSpan
  else:
    inc pos

proc toAtomNode*(tree: var JsonTree; kind: uint32, str: String): Node {.inline.} =
  toNode(kind, uint32 getOrIncl(tree.atoms, str))

type
  NodePos* = distinct int

const
  rootNodeId* = NodePos(0) ## Each `JsonTree` starts from this index.
  nilNodeId* = NodePos(-1) ## Empty `NodePos`

proc `<`*(a, b: NodePos): bool {.borrow.}
proc `<=`*(a, b: NodePos): bool {.borrow.}
proc `==`*(a, b: NodePos): bool {.borrow.}

proc isNil*(n: NodePos): bool {.inline.} = n == nilNodeId
proc firstSon*(n: NodePos): NodePos {.inline.} = NodePos(n.int+1)

iterator sonsReadonly*(tree: JsonTree; n: NodePos): NodePos =
  var pos = n.int
  assert tree.nodes[pos].kind > opcodeString
  let last = pos + tree.nodes[pos].rawSpan
  inc pos
  while pos < last:
    yield NodePos(pos)
    nextChild tree, pos

iterator keys*(tree: JsonTree; n: NodePos): NodePos =
  var pos = n.int
  assert tree.nodes[pos].kind == opcodeObject
  let last = pos + tree.nodes[pos].rawSpan
  inc pos
  while pos < last:
    yield NodePos(pos)
    inc pos
    nextChild tree, pos

proc len*(tree: JsonTree; n: NodePos): int =
  result = 0
  if tree.nodes[n.int].kind > opcodeNull:
    for child in sonsReadonly(tree, n): inc result
    if tree.nodes[n.int].kind == opcodeObject:
      result = result div 2

proc parentImpl*(tree: JsonTree; n: NodePos): NodePos =
  # finding the parent of a node is rather easy:
  var pos = n.int - 1
  while pos >= 0 and (isAtom(tree, pos) or (pos + tree.nodes[pos].rawSpan - 1 < n.int)):
    dec pos
  #assert pos >= 0, "node has no parent"
  result = NodePos(pos)

template parent*(n: NodePos): NodePos = parentImpl(tree, n)

template kind*(n: NodePos): uint32 = tree.nodes[n.int].kind
template litId*(n: NodePos): LitId = LitId operand(tree.nodes[n.int])
template operand*(n: NodePos): uint32 = tree.nodes[n.int].operand

template str*(n: NodePos): String = tree.atoms[litId(n)]
template bval*(n: NodePos): bool = n.operand == 1

type
  PatchPos* = distinct int32

proc `<`*(a, b: PatchPos): bool {.borrow.}
proc `<=`*(a, b: PatchPos): bool {.borrow.}
proc `==`*(a, b: PatchPos): bool {.borrow.}

proc prepare*(tree: var JsonTree; kind: uint32): PatchPos =
  result = PatchPos tree.nodes.len
  tree.nodes.add Node kind

proc patch*(tree: var JsonTree; pos: PatchPos) =
  let pos = pos.int
  assert tree.nodes[pos].kind > opcodeString
  let distance = uint32(tree.nodes.len - pos)
  tree.nodes[pos] = toNode(tree.nodes[pos].uint32, distance)

proc storeAtom*(tree: var JsonTree; kind: uint32) {.inline.} =
  tree.nodes.add Node(kind)

proc storeAtom*(tree: var JsonTree; kind: uint32; data: string) {.inline.} =
  tree.nodes.add toAtomNode(tree, kind, data.toStr)

proc storeEmpty*(tree: var JsonTree; kind: uint32) {.inline.} =
  tree.nodes.add toNode(kind, 1)
