import jsonpak/private/[bitabs, jsonnode, jsontree], std/importutils

proc main =
  privateAccess(JsonTree)

  block:
    var tree = JsonTree(nodes: @[], atoms: BiTable[string]())
    assert tree.isEmpty
    tree.nodes.add Node(opcodeNull)
    assert tree.isEmpty
    tree.nodes = @[
      toNode(opcodeArray, 2),
      toNode(opcodeString, uint32 getOrIncl(tree.atoms, "hello"))
    ]
    assert not tree.isEmpty
    assert tree.len(NodePos 0) == 1
    assert parent(NodePos 1) == NodePos 0
    assert NodePos(1).str == "hello"

  block:
    var tree = JsonTree(atoms: BiTable[string]())
    tree.nodes = @[
      toNode(opcodeArray, 4),
      toNode(opcodeString, uint32 getOrIncl(tree.atoms, "hello")),
      toNode(opcodeInt, uint32 getOrIncl(tree.atoms, "42")),
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
      toNode(opcodeString, uint32 getOrIncl(tree.atoms, "key1")),
      toNode(opcodeInt, uint32 getOrIncl(tree.atoms, "10")),
      toNode(opcodeString, uint32 getOrIncl(tree.atoms, "key2")),
      toNode(opcodeArray, 3),
      toNode(opcodeString, uint32 getOrIncl(tree.atoms, "value1")),
      toNode(opcodeString, uint32 getOrIncl(tree.atoms, "value2"))
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
    for son in keys(tree, NodePos 0):
      sons.add son
    assert sons == @[NodePos 1, NodePos 3]

  block:
    var tree = JsonTree(atoms: BiTable[string]())
    tree.nodes = @[
      toNode(opcodeArray, 6),
      toNode(opcodeObject, 5),
      toNode(opcodeString, uint32 getOrIncl(tree.atoms, "key1")),
      toNode(opcodeInt, uint32 getOrIncl(tree.atoms, "10")),
      toNode(opcodeString, uint32 getOrIncl(tree.atoms, "key2")),
      toNode(opcodeString, uint32 getOrIncl(tree.atoms, "value"))
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
    assert tree.nodes[2] == toNode(opcodeInt, uint32 getOrIncl(tree.atoms, "42"))
    tree.storeAtom(opcodeString, "hello")
    assert tree.nodes[3] == toNode(opcodeString, uint32 getOrIncl(tree.atoms, "hello"))

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
