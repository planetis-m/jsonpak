import bitabs, jsonnode, jsontree, std/importutils

proc rawGet*(tree: JsonTree, n: NodePos, name: string): NodePos =
  privateAccess(JsonTree)
  let litId = tree.atoms.getKeyId(name)
  if litId == LitId(0):
    return nilNodeId
  for x in sonsReadonlySkip1(tree, n):
    if x.litId == litId:
      return x.firstSon
  return nilNodeId

proc rawUpdateParents*(tree: var JsonTree, parents: seq[PatchPos], diff: int) =
  privateAccess(JsonTree)
  for parent in parents:
    let distance = tree.nodes[parent.int].operand + diff
    tree.nodes[parent.int] = toNode(tree.nodes[parent.int].kind, distance.int32)

proc rawExtract*(result: var JsonTree, tree: JsonTree, n: NodePos) =
  privateAccess(JsonTree)
  let L = span(tree, n.int)
  newSeq(result.nodes, L)
  for i in 0..<L:
    let n = NodePos(i+n.int) # careful
    case n.kind
    of opcodeInt, opcodeFloat, opcodeString:
      result.nodes[i] = toNode(n.kind, int32 getOrIncl(result.atoms, n.str))
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
      result.nodes[i+n.int] = toNode(m.kind, int32 getOrIncl(result.atoms, m.str))
    else:
      result.nodes[i+n.int] = tree.nodes[i]

proc rawAddKeyValuePair*(result: var JsonTree, src, dest: NodePos, key: string) =
  privateAccess(JsonTree)
  let L = span(result, src.int) + 1
  let oldfull = result.nodes.len
  setLen(result.nodes, oldfull+L)
  for i in countdown(oldfull-1, dest.int):
    result.nodes[i+L] = result.nodes[i]
  result.nodes[dest.int] = toNode(opcodeString, int32 getOrIncl(result.atoms, key))
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
  result.nodes[n.int] = toNode(opcodeString, int32 getOrIncl(result.atoms, key))
  for i in 0..<L-1:
    let m = NodePos(i)
    case m.kind
    of opcodeInt, opcodeFloat, opcodeString:
      result.nodes[i+n.int+1] = toNode(m.kind, int32 getOrIncl(result.atoms, m.str))
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
      result.nodes[i+n.int] = toNode(m.kind, int32 getOrIncl(result.atoms, m.str))
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
    for keyA in sonsReadonlySkip1(a, na):
      let valA = keyA.firstSon
      let keyStrA = a.atoms[LitId a.nodes[keyA.int].operand]
      let valB = b.rawGet(nb, keyStrA)
      if valB.isNil or not rawTest(a, b, valA, valB):
        return false
    return true
  else: return false # Cannot happen.
