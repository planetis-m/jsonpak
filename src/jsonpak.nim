import jsonpak/private/[jsonnode, jsontree, rawops], std/importutils

export
  JsonTree, isEmpty, JsonNodeKind

proc `==`*(a, b: JsonTree): bool {.inline.} =
  privateAccess(JsonTree)
  if a.nodes.len != b.nodes.len:
    return false
  rawTest(a, b, rootNodeId, rootNodeId)

proc copy*(tree: JsonTree): JsonTree =
  ## Returns a fresh copy of `tree`.
  rawExtract(result, tree, rootNodeId)
