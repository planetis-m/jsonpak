import private/bitabs, jsontree, jsonnode, std/[algorithm, importutils]

type
  SortedJsonTree* = distinct JsonTree

proc sorted*(tree: JsonTree, n: NodePos): SortedJsonTree =
  privateAccess(JsonTree)
  var stack = @[n]
  var nodes: seq[Node] = @[]
  var atoms = BiTable[string]()
  while stack.len > 0:
    let curr = stack.pop()
    case curr.kind
    of opcodeObject:
      nodes.add tree.nodes[curr.int]
      var pairs: seq[(string, PatchPos)] = @[]
      for n in sonsReadonlySkip1(tree, curr):
        pairs.add (n.str, n.PatchPos)
      sort(pairs, proc (a, b: (string, PatchPos)): int = cmp(a[0], b[0]))
      for i in countdown(pairs.high, 0):
        let n = pairs[i][1].NodePos
        stack.add n.firstSon
        stack.add n
    of opcodeArray:
      nodes.add tree.nodes[curr.int]
      var items: seq[PatchPos] = @[]
      for n in sonsReadonly(tree, curr):
        items.add n.PatchPos
      for i in countdown(items.high, 0):
        stack.add items[i].NodePos
    of opcodeInt, opcodeFloat, opcodeString:
      nodes.add toNode(curr.kind, int32 getOrIncl(atoms, curr.str))
    else:
      nodes.add tree.nodes[curr.int]
  result = JsonTree(nodes: nodes, atoms: atoms).SortedJsonTree

proc sorted*(tree: JsonTree): SortedJsonTree {.inline.} =
  result = sorted(tree, rootNodeId)

proc rawTest*(tree, value: JsonTree, n: NodePos): bool =
  privateAccess(JsonTree)
  if n.kind != value.nodes[0].kind: return false
  if n.kind == opcodeNull: return true
  let L = span(tree, n.int)
  if L != value.nodes.len: return false
  for i in 0..<L:
    let n = NodePos(i+n.int) # careful
    case n.kind
    of opcodeInt, opcodeFloat, opcodeString:
      if value.atoms[LitId value.nodes[i].operand] != n.str: return false
    else:
      if value.nodes[i] != tree.nodes[n.int]: return false
  return true

proc `==`*(a, b: SortedJsonTree): bool {.inline.} =
  rawTest(JsonTree(a), JsonTree(b), rootNodeId)

when isMainModule:
  import jsonmapper

  proc main =
    block: # empty object
      let data = %*{}
      let tree = sorted(data)
      assert tree == SortedJsonTree(%*{})

    block: # object with one key
      let data = %*{"a": 1}
      let tree = sorted(data)
      assert tree == SortedJsonTree(%*{"a": 1})

    block: # object with multiple keys
      let data = %*{"c": 3, "a": 1, "b": 2}
      let tree = sorted(data)
      assert tree == SortedJsonTree(%*{"a": 1, "b": 2, "c": 3})

    block: # nested objects
      let data = %*{"b": {"d": 4, "c": 3}, "a": {"y": 25, "x": 24}}
      let tree = sorted(data)
      assert tree == SortedJsonTree(%*{"a": {"x": 24, "y": 25}, "b": {"c": 3, "d": 4}})

    block: # array
      let data = %*[3, 1, 2]
      let tree = sorted(data)
      assert tree == SortedJsonTree(%*[3, 1, 2])

    block: # nested arrays
      let data = %*[[3, 1, 2], [6, 4, 5]]
      let tree = sorted(data)
      echo tree.JsonTree
      assert tree == SortedJsonTree(%*[[3, 1, 2], [6, 4, 5]])

    block: # object with array
      let data = %*{"b": [3, 1, 2], "a": 0}
      let tree = sorted(data)
      assert tree == SortedJsonTree(%*{"a": 0, "b": [3, 1, 2]})

    block: # object with null
      let data = %*{"b": nil, "a": 0}
      let tree = sorted(data)
      assert tree == SortedJsonTree(%*{"a": 0, "b": nil})

    block: # object with bool
      let data = %*{"b": false, "a": true}
      let tree = sorted(data)
      assert tree == SortedJsonTree(%*{"a": true, "b": false})

    block: # comparing equal trees
      let data1 = %*{"b": {"d": 4, "c": 3}, "a": {"y": 25, "x": 24}}
      let tree1 = sorted(data1)
      let data2 = %*{"a": {"x": 24, "y": 25}, "b": {"c": 3, "d": 4}}
      let tree2 = sorted(data2)
      assert tree1 == tree2

    block: # comparing unequal trees
      let data1 = %*{"a": 1, "b": 2}
      let tree1 = sorted(data1)
      let data2 = %*{"a": 1, "b": 3}
      let tree2 = sorted(data2)
      assert tree1 != tree2

  static: main()
  main()
