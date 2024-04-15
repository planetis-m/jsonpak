import bitabs, jsonnode, jsontree, rawops, std/[importutils, algorithm, sequtils]

proc rawSorted*(tree: JsonTree, n: NodePos): JsonTree =
  privateAccess(JsonTree)
  var nodes = newSeqOfCap[Node](tree.nodes.len)
  var atoms = BiTable[string]()
  var stack = @[n.PatchPos]
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
  result = JsonTree(nodes: nodes, atoms: atoms)

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

proc rawDeduplicate*(tree: var JsonTree, n: NodePos, parents: var seq[PatchPos]) =
  privateAccess(JsonTree)
  case n.kind
  of opcodeObject:
    parents.add n.PatchPos
    var totaldiff = 0
    var curr = 0
    var last = len(tree, n)-1
    var pos = n.firstSon.int
    while curr <= last:
      var i = curr
      var tmp = pos
      var diff = 0
      while i < last and
          (var next = tmp+1; nextChild tree, next; NodePos(tmp).str == NodePos(next).str):
        dec last
        inc i
        inc diff, 1 + span(tree, tmp+1)
        tmp = next
      if i > curr:
        let endpos = pos + diff
        tree.nodes.delete(pos, endpos - 1)
        dec totaldiff, diff
      else:
        inc curr
        if not isAtom(tree, pos+1):
          rawDeduplicate(tree, NodePos(pos+1), parents)
        inc pos
        nextChild tree, pos
    if totaldiff < 0:
      rawUpdateParents(tree, parents, totaldiff)
    parents.setLen(parents.high)
  of opcodeArray:
    parents.add n.PatchPos
    var pos = n.int+1
    let last = len(tree, n)-1
    var curr = 0
    while curr <= last:
      if not isAtom(tree, pos):
        rawDeduplicate(tree, NodePos(pos), parents)
      inc curr
      nextChild tree, pos
    parents.setLen(parents.high)
  else:
    discard
