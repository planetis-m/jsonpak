import jsonpak/private/[jsonnode, jsontree, rawops], std/importutils

export
  JsonTree, isEmpty, JsonNodeKind

proc newEmptyTree*(): JsonTree {.inline.} =
  privateAccess(JsonTree)
  JsonTree(nodes: @[Node(opcodeNull)])

proc `==`*(a, b: JsonTree): bool {.inline.} =
  privateAccess(JsonTree)
  if a.nodes.len != b.nodes.len:
    return false
  rawTest(a, b, rootNodeId, rootNodeId)

proc copy*(tree: JsonTree): JsonTree =
  ## Returns a fresh copy of `tree`.
  result = JsonTree()
  rawExtract(result, tree, rootNodeId)
