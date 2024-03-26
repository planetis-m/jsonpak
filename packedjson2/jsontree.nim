import private/bitabs, jsonnode, std/assertions

type
  JsonTree* = object
    nodes: seq[Node]
    atoms: BiTable[string]

proc isEmpty*(tree: JsonTree): bool {.inline.} =
  tree.nodes.len == 0 or tree.nodes.len == 1 and tree.nodes[0].kind == opcodeNull

proc isAtom*(tree: JsonTree; pos: int): bool {.inline.} =
  tree.nodes[pos].kind <= opcodeString

proc span*(tree: JsonTree; pos: int): int {.inline.} =
  if isAtom(tree, pos): 1 else: tree.nodes[pos].operand

proc nextChild*(tree: JsonTree; pos: var int) {.inline.} =
  if tree.nodes[pos].kind > opcodeString:
    assert tree.nodes[pos].operand > 0
    inc pos, tree.nodes[pos].operand
  else:
    inc pos

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
  let last = pos + tree.nodes[pos].operand
  inc pos
  while pos < last:
    yield NodePos(pos)
    nextChild tree, pos

iterator sonsReadonlySkip1*(tree: JsonTree; n: NodePos): NodePos =
  var pos = n.int
  assert tree.nodes[pos].kind == opcodeObject
  let last = pos + tree.nodes[pos].operand
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
  while pos >= 0 and (isAtom(tree, pos) or (pos + tree.nodes[pos].operand - 1 < n.int)):
    dec pos
  #assert pos >= 0, "node has no parent"
  result = NodePos(pos)

template parent*(n: NodePos): NodePos = parentImpl(tree, n)

template kind*(n: NodePos): int32 = tree.nodes[n.int].kind
template litId*(n: NodePos): LitId = LitId operand(tree.nodes[n.int])
template operand*(n: NodePos): int32 = tree.nodes[n.int].operand

template str*(n: NodePos): string = tree.atoms[litId(n)]
template bval*(n: NodePos): bool = n.operand == 1

type
  PatchPos* = distinct int32

proc `<`*(a, b: PatchPos): bool {.borrow.}
proc `<=`*(a, b: PatchPos): bool {.borrow.}
proc `==`*(a, b: PatchPos): bool {.borrow.}

proc prepare*(tree: var JsonTree; kind: int32): PatchPos =
  result = PatchPos tree.nodes.len
  tree.nodes.add Node kind

proc patch*(tree: var JsonTree; pos: PatchPos) =
  let pos = pos.int
  assert tree.nodes[pos].kind > opcodeString
  let distance = int32(tree.nodes.len - pos)
  tree.nodes[pos] = toNode(tree.nodes[pos].int32, distance)

proc storeAtom*(tree: var JsonTree; kind: int32) {.inline.} =
  tree.nodes.add Node(kind)

proc storeAtom*(tree: var JsonTree; kind: int32; data: string) {.inline.} =
  tree.nodes.add toNode(kind, int32 getOrIncl(tree.atoms, data))

proc storeEmpty*(tree: var JsonTree; kind: int32) {.inline.} =
  tree.nodes.add toNode(kind, 1)

when isMainModule:
  proc main =
    block:
      var tree = JsonTree(nodes: @[], atoms: BiTable[string]())
      assert tree.isEmpty
      tree.nodes.add Node(opcodeNull)
      assert tree.isEmpty
      tree.nodes = @[
        toNode(opcodeArray, 2),
        toNode(opcodeString, int32 getOrIncl(tree.atoms, "hello"))
      ]
      assert not tree.isEmpty
      assert tree.len(NodePos 0) == 1
      assert parent(NodePos 1) == NodePos 0
      assert NodePos(1).str == "hello"

    block:
      var tree = JsonTree(atoms: BiTable[string]())
      tree.nodes = @[
        toNode(opcodeArray, 4),
        toNode(opcodeString, int32 getOrIncl(tree.atoms, "hello")),
        toNode(opcodeInt, int32 getOrIncl(tree.atoms, "42")),
        toNode(opcodeNull, 0)
      ]
      assert tree.span(0) == 4
      assert tree.span(1) == 1
      assert tree.span(2) == 1
      assert tree.span(3) == 1

    block:
      var tree = JsonTree(atoms: BiTable[string]())
      tree.nodes = @[
        toNode(opcodeObject, 6),
        toNode(opcodeString, int32 getOrIncl(tree.atoms, "key1")),
        toNode(opcodeInt, int32 getOrIncl(tree.atoms, "10")),
        toNode(opcodeString, int32 getOrIncl(tree.atoms, "key2")),
        toNode(opcodeArray, 3),
        toNode(opcodeString, int32 getOrIncl(tree.atoms, "value1")),
        toNode(opcodeString, int32 getOrIncl(tree.atoms, "value2"))
      ]
      var sons: seq[NodePos] = @[]
      for son in sonsReadonly(tree, NodePos 0):
        sons.add son
      assert sons == @[NodePos 1, NodePos 2, NodePos 3, NodePos 4]
      sons = @[]
      for son in sonsReadonly(tree, NodePos 4):
        sons.add son
      assert sons == @[NodePos 5, NodePos 6]
      sons = @[]
      for son in sonsReadonlySkip1(tree, NodePos 0):
        sons.add son
      assert sons == @[NodePos 1, NodePos 3]

    block:
      var tree = JsonTree(atoms: BiTable[string]())
      tree.nodes = @[
        toNode(opcodeArray, 6),
        toNode(opcodeObject, 5),
        toNode(opcodeString, int32 getOrIncl(tree.atoms, "key1")),
        toNode(opcodeInt, int32 getOrIncl(tree.atoms, "10")),
        toNode(opcodeString, int32 getOrIncl(tree.atoms, "key2")),
        toNode(opcodeString, int32 getOrIncl(tree.atoms, "value"))
      ]
      assert parentImpl(tree, NodePos 0) == nilNodeId
      assert parentImpl(tree, NodePos 1) == NodePos 0
      assert parentImpl(tree, NodePos 2) == NodePos 1
      assert parentImpl(tree, NodePos 3) == NodePos 1
      assert parentImpl(tree, NodePos 4) == NodePos 1
      assert parentImpl(tree, NodePos 5) == NodePos 1
      assert tree.len(NodePos 0) == 1
      assert tree.len(NodePos 1) == 2

    block:
      var tree = JsonTree(nodes: @[], atoms: BiTable[string]())
      tree.storeAtom(opcodeNull)
      assert tree.nodes[0] == toNode(opcodeNull, 0)
      tree.storeAtom(opcodeBool, "true")
      assert tree.nodes[1] == toNode(opcodeBool, 1)
      tree.storeAtom(opcodeInt, "42")
      assert tree.nodes[2] == toNode(opcodeInt, int32 getOrIncl(tree.atoms, "42"))
      tree.storeAtom(opcodeString, "hello")
      assert tree.nodes[3] == toNode(opcodeString, int32 getOrIncl(tree.atoms, "hello"))

    block:
      var tree = JsonTree(nodes: @[], atoms: BiTable[string]())
      var patchPos = tree.prepare(opcodeObject)
      tree.storeAtom(opcodeString, "key1")
      tree.storeAtom(opcodeInt, "42")
      tree.storeAtom(opcodeString, "key2")
      tree.storeAtom(opcodeString, "value")
      tree.patch(patchPos)
      assert tree.len(NodePos 0) == 2
      assert tree.nodes[0] == toNode(opcodeObject, 5)

  static: main()
  main()
