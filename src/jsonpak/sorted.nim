import private/[jsontree, rawops_sorted], std/importutils

type
  SortedJsonTree* = distinct JsonTree

proc sorted*(tree: JsonTree): SortedJsonTree {.inline.} =
  ## Sorts all the keys of `tree` recursively, ensuring that
  ## the resulting tree has its keys in lexicographic order.
  result = rawSorted(tree, rootNodeId).SortedJsonTree

proc `==`*(a, b: SortedJsonTree): bool {.inline.} =
  ## The equality comparison for `SortedJsonTree` is faster than the one for `JsonTree`.
  privateAccess(JsonTree)
  if JsonTree(a).nodes.len != JsonTree(b).nodes.len:
    return false
  rawTest(JsonTree(a), JsonTree(b), rootNodeId)

proc deduplicate*(tree: var SortedJsonTree) =
  ## Deduplicates keys in `tree` recursively. If duplicate keys are found,
  ## only the last occurrence of the key is kept.
  ##
  ## The deduplication is performed in-place.
  var parents: seq[PatchPos] = @[]
  rawDeduplicate(JsonTree(tree), rootNodeId, parents)

proc hash*(tree: SortedJsonTree): Hash =
  ## Stable and fast hashes
  result = rawHash(tree, rootNodeId)
