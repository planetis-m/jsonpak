import bitabs, jsonnode, jsontree, std/[importutils, algorithm, sequtils]

proc rawGet*(tree: JsonTree, n: NodePos, name: string): NodePos =
  privateAccess(JsonTree)
  let litId = tree.atoms.getKeyId(name)
  if litId == LitId(0):
    return nilNodeId
  for x in keys(tree, n):
    if x.litId == litId:
      return x.firstSon
  return nilNodeId

proc rawUpdateParents*(tree: var JsonTree, parents: seq[PatchPos], diff: int) =
  privateAccess(JsonTree)
  for parent in parents:
    let distance = tree.nodes[parent.int].rawSpan + diff
    tree.nodes[parent.int] = toNode(tree.nodes[parent.int].kind, distance.uint32)

proc rawExtract*(result: var JsonTree, tree: JsonTree, n: NodePos) =
  privateAccess(JsonTree)
  let L = span(tree, n.int)
  newSeq(result.nodes, L)
  for i in 0..<L:
    let n = NodePos(i+n.int) # careful
    case n.kind
    of opcodeInt, opcodeFloat, opcodeString:
      result.nodes[i] = toAtomNode(result, n.kind, n.str)
    else:
      result.nodes[i] = tree.nodes[n.int]

proc rawAdd*(result: var JsonTree, src, dest: NodePos) =
  privateAccess(JsonTree)
  let L = span(result, src.int)
  let oldfull = result.nodes.len
  setLen(result.nodes, oldfull+L)
  for i in countdown(oldfull-1, dest.int):
    result.nodes[i+L] = result.nodes[i]
  let src =
    if src >= dest: NodePos(src.int+L) else: src
  for i in 0..<L:
    result.nodes[dest.int+i] = result.nodes[src.int+i]

proc rawAdd*(result: var JsonTree, tree: JsonTree, n: NodePos) =
  privateAccess(JsonTree)
  let L = span(tree, 0)
  let oldfull = result.nodes.len
  setLen(result.nodes, oldfull+L)
  for i in countdown(oldfull-1, n.int):
    result.nodes[i+L] = result.nodes[i]
  for i in 0..<L:
    let m = NodePos(i)
    case m.kind
    of opcodeInt, opcodeFloat, opcodeString:
      result.nodes[i+n.int] = toAtomNode(result, m.kind, m.str)
    else:
      result.nodes[i+n.int] = tree.nodes[i]

proc rawAddKeyValuePair*(result: var JsonTree, src, dest: NodePos, key: string) =
  privateAccess(JsonTree)
  let L = span(result, src.int) + 1
  let oldfull = result.nodes.len
  setLen(result.nodes, oldfull+L)
  for i in countdown(oldfull-1, dest.int):
    result.nodes[i+L] = result.nodes[i]
  result.nodes[dest.int] = toAtomNode(result, opcodeString, key)
  let src =
    if src >= dest: NodePos(src.int+L) else: src
  for i in 0..<L-1:
    result.nodes[dest.int+i+1] = result.nodes[src.int+i]

proc rawAddKeyValuePair*(result: var JsonTree, tree: JsonTree, n: NodePos, key: string) =
  privateAccess(JsonTree)
  let L = span(tree, 0) + 1
  let oldfull = result.nodes.len
  setLen(result.nodes, oldfull+L)
  for i in countdown(oldfull-1, n.int):
    result.nodes[i+L] = result.nodes[i]
  result.nodes[n.int] = toAtomNode(result, opcodeString, key)
  for i in 0..<L-1:
    let m = NodePos(i)
    case m.kind
    of opcodeInt, opcodeFloat, opcodeString:
      result.nodes[i+n.int+1] = toAtomNode(result, m.kind, m.str)
    else:
      result.nodes[i+n.int+1] = tree.nodes[i]

proc rawReplace*(result: var JsonTree, src, dest: NodePos) =
  privateAccess(JsonTree)
  let L = span(result, src.int)
  let diff = L - span(result, dest.int)
  let oldfull = result.nodes.len
  let endpos = dest.int + span(result, dest.int)
  if diff > 0:
    # Expand the nodes sequence if the new value is larger
    setLen(result.nodes, oldfull+diff)
    for i in countdown(oldfull-1, endpos):
      result.nodes[i+diff] = result.nodes[i]
    let src =
      if src >= dest: NodePos(src.int+diff) else: src
    for i in 0..<L:
      result.nodes[dest.int+i] = result.nodes[src.int+i]
  elif diff < 0:
    # Shrink the nodes sequence if the new value is smaller
    # Handles the case where src is a child of dest
    for i in 0..<L:
      result.nodes[dest.int+i] = result.nodes[src.int+i]
    for i in countup(endpos, oldfull-1):
      result.nodes[i+diff] = result.nodes[i]
    setLen(result.nodes, oldfull+diff)
  else:
    for i in 0..<L:
      result.nodes[dest.int+i] = result.nodes[src.int+i]

proc rawReplace*(result: var JsonTree, tree: JsonTree, n: NodePos) =
  privateAccess(JsonTree)
  let L = span(tree, 0)
  let diff = L - span(result, n.int)
  let oldfull = result.nodes.len
  let endpos = n.int + span(result, n.int)
  if diff > 0:
    # Expand the nodes sequence if the new value is larger
    setLen(result.nodes, oldfull+diff)
    for i in countdown(oldfull-1, endpos):
      result.nodes[i+diff] = result.nodes[i]
  elif diff < 0:
    # Shrink the nodes sequence if the new value is smaller
    for i in countup(endpos, oldfull-1):
      result.nodes[i+diff] = result.nodes[i]
    setLen(result.nodes, oldfull+diff)
  # Copy the new nodes into the nodes sequence
  for i in 0..<L:
    let m = NodePos(i)
    case m.kind
    of opcodeInt, opcodeFloat, opcodeString:
      result.nodes[i+n.int] = toAtomNode(result, m.kind, m.str)
    else:
      result.nodes[i+n.int] = tree.nodes[i]

proc rawTest*(a, b: JsonTree, na, nb: NodePos): bool =
  privateAccess(JsonTree)
  if a.nodes[na.int].kind != b.nodes[nb.int].kind:
    return false
  case a.nodes[na.int].kind
  of opcodeNull:
    return true
  of opcodeBool:
    return a.nodes[na.int].operand == b.nodes[nb.int].operand
  of opcodeInt, opcodeFloat, opcodeString:
    return a.atoms[LitId a.nodes[na.int].operand] == b.atoms[LitId b.nodes[nb.int].operand]
  of opcodeArray:
    let lenA = len(a, na)
    let lenB = len(b, nb)
    if lenA != lenB:
      return false
    var posA = na.int+1
    var posB = nb.int+1
    for i in 0..<lenA:
      if not rawTest(a, b, NodePos(posA), NodePos(posB)):
        return false
      a.nextChild(posA)
      b.nextChild(posB)
    return true
  of opcodeObject:
    let lenA = len(a, na)
    let lenB = len(b, nb)
    if lenA != lenB:
      return false
    for keyA in keys(a, na):
      let valA = keyA.firstSon
      let keyStrA = a.atoms[LitId a.nodes[keyA.int].operand]
      let valB = b.rawGet(nb, keyStrA)
      if valB.isNil or not rawTest(a, b, valA, valB):
        return false
    return true
  else: return false # Cannot happen.

proc rawSorted*(result: var JsonTree; tree: JsonTree, n: NodePos) =
  privateAccess(JsonTree)
  var stack = @[n.PatchPos]
  while stack.len > 0:
    let curr = stack.pop().NodePos
    case curr.kind
    of opcodeObject:
      result.nodes.add tree.nodes[curr.int]
      var pairs: seq[(string, PatchPos)] = @[]
      for n in keys(tree, curr):
        pairs.add (n.str, n.PatchPos)
      sort(pairs, proc (a, b: (string, PatchPos)): int = cmp(a[0], b[0]))
      for i in countdown(pairs.high, 0):
        let n = pairs[i][1].NodePos
        stack.add PatchPos(n.firstSon)
        stack.add n.PatchPos
    of opcodeArray:
      result.nodes.add tree.nodes[curr.int]
      var items: seq[PatchPos] = @[]
      for n in sonsReadonly(tree, curr):
        items.add n.PatchPos
      for i in countdown(items.high, 0):
        stack.add items[i]
    of opcodeInt, opcodeFloat, opcodeString:
      result.nodes.add toAtomNode(result, curr.kind, curr.str)
    else:
      result.nodes.add tree.nodes[curr.int]

proc rawTestSorted*(tree, value: JsonTree, n: NodePos): bool =
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

proc rawDeduplicateSorted*(tree: var JsonTree, n: NodePos, parents: var seq[PatchPos]) =
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
          rawDeduplicateSorted(tree, NodePos(pos+1), parents)
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
        rawDeduplicateSorted(tree, NodePos(pos), parents)
      inc curr
      nextChild tree, pos
    parents.setLen(parents.high)
  else:
    discard
