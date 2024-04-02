import private/[bitabs, jsontree, jsonnode], std/[algorithm, importutils]

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
      for n in keys(tree, curr):
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
      nodes.add toNode(curr.kind, uint32 getOrIncl(atoms, curr.str))
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
