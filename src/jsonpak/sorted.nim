import private/[bitabs, jsontree, jsonnode, rawops], std/[algorithm, importutils]

type
  SortedJsonTree* = distinct JsonTree

proc sorted*(tree: JsonTree, n: NodePos): SortedJsonTree =
  privateAccess(JsonTree)
  var stack = @[n.PatchPos]
  var nodes: seq[Node] = @[]
  var atoms = BiTable[string]()
  while stack.len > 0:
    let curr = stack.pop().NodePos
    case curr.kind
    of opcodeObject:
      nodes.add tree.nodes[curr.int]
      var pairs: seq[(string, PatchPos)] = @[]
      for n in keys(tree, curr):
        pairs.add (n.str, n.PatchPos)
      sort(pairs, proc (a, b: (string, PatchPos)): int = cmp(a[0], b[0]))
      for i in countdown(pairs.high, 0):
        let n = pairs[i][1].NodePos
        stack.add PatchPos(n.firstSon)
        stack.add n.PatchPos
    of opcodeArray:
      nodes.add tree.nodes[curr.int]
      var items: seq[PatchPos] = @[]
      for n in sonsReadonly(tree, curr):
        items.add n.PatchPos
      for i in countdown(items.high, 0):
        stack.add items[i]
    of opcodeInt, opcodeFloat, opcodeString:
      nodes.add toNode(curr.kind, uint32 getOrIncl(atoms, curr.str))
    else:
      nodes.add tree.nodes[curr.int]
  result = JsonTree(nodes: nodes, atoms: atoms).SortedJsonTree

proc sorted*(tree: JsonTree): SortedJsonTree {.inline.} =
  result = sorted(tree, rootNodeId)

proc rawTest(tree, value: JsonTree, n: NodePos): bool =
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
  privateAccess(JsonTree)
  if JsonTree(a).nodes.len != JsonTree(b).nodes.len:
    return false
  rawTest(JsonTree(a), JsonTree(b), rootNodeId)

proc rawDeduplicate(tree: var JsonTree, n: NodePos, parents: var seq[PatchPos]) =
  privateAccess(JsonTree)
  case n.kind
  of opcodeObject:
    parents.add n.PatchPos
    var totaldiff = 0
    var prevKeyId = LitId(0)
    var pos = n.int+1
    var len = len(tree, n)
    var count = 0
    while count < len:
      if prevKeyId == LitId(0) or NodePos(pos).str != tree.atoms[prevKeyId]:
        prevKeyId = NodePos(pos).litId
        rawDeduplicate(tree, NodePos(pos+1), parents)
        inc count
        inc pos
        nextChild tree, pos
      else:
        let oldfull = tree.nodes.len
        let diff = span(tree, pos+1) + 1
        let endpos = pos + diff
        for i in countup(endpos, oldfull-1):
          tree.nodes[i+diff] = tree.nodes[i]
        setLen(tree.nodes, oldfull+diff)
        dec totaldiff, diff
        dec len
      # if i == sorted.high or sorted[i] != sorted[i+1]:
      #   result.add(sorted[i])
    if totaldiff < 0:
      rawUpdateParents(tree, parents, totaldiff)
    discard parents.pop()
  of opcodeArray:
    parents.add n.PatchPos
    var pos = n.int+1
    let len = len(tree, n)
    var count = 0
    while count < len:
      rawDeduplicate(tree, NodePos(pos), parents)
      inc count
      nextChild tree, pos
    discard parents.pop()
  else:
    discard

proc deduplicate*(tree: var SortedJsonTree) =
  var parents: seq[PatchPos] = @[]
  rawDeduplicate(JsonTree(tree), rootNodeId, parents)
