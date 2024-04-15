import private/[jsontree, jsonnode, rawops], std/importutils

type
  SortedJsonTree* = distinct JsonTree

proc sorted*(tree: JsonTree): SortedJsonTree {.inline.} =
  ## Sorts all the keys of `tree` recursively, ensuring that
  ## the resulting tree has its keys in lexicographic order.
  privateAccess(JsonTree)
  result = JsonTree(nodes: newSeqOfCap[Node](tree.nodes.len)).SortedJsonTree
  rawSorted(JsonTree(result), tree, rootNodeId)

proc `==`*(a, b: SortedJsonTree): bool {.inline.} =
  ## The equality comparison for `SortedJsonTree` is faster than the one for `JsonTree`.
  privateAccess(JsonTree)
  if JsonTree(a).nodes.len != JsonTree(b).nodes.len:
    return false
  rawTestSorted(JsonTree(a), JsonTree(b), rootNodeId)

proc deduplicate*(tree: var SortedJsonTree) =
  ## Deduplicates keys in `tree` recursively. If duplicate keys are found,
  ## only the last occurrence of the key is kept.
  ##
  ## The deduplication is performed in-place.
  var parents: seq[PatchPos] = @[]
  rawDeduplicateSorted(JsonTree(tree), rootNodeId, parents)
