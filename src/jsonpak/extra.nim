import
  private/[jsontree, jsonnode, rawops], jsonptr, dollar,
  std/[importutils, assertions]

proc dump*(tree: JsonTree, path: JsonPtr): string =
  ## Dumps the JSON `tree` to a string.
  result = ""
  let n = findNode(tree, path.string)
  if n.isNil:
    raisePathError(path.string)
  toUgly(result, tree, n)

proc extract*(tree: JsonTree; path: JsonPtr): JsonTree =
  ## Extracts the JSON tree at `path` from `tree`.
  let n = findNode(tree, path.string)
  if n.isNil:
    raisePathError(path.string)
  rawExtract(result, tree, n)

proc contains*(tree: JsonTree, path: JsonPtr): bool {.inline.} =
  ## Checks if `key` exists in `n`.
  let n = findNode(tree, path.string)
  result = n >= rootNodeId

proc kind*(tree: JsonTree; path: JsonPtr): JsonNodeKind {.inline.} =
  privateAccess(JsonTree)
  let n = findNode(tree, path.string)
  if n.isNil:
    raisePathError(path.string)
  result = JsonNodeKind tree.nodes[n.int].kind

proc len*(tree: JsonTree; path: JsonPtr): int =
  let n = findNode(tree, path.string)
  if n.isNil:
    raisePathError(path.string)
  result = len(tree, n)
