import
  jsontree, jsonnode, jsonpointer, jsonops, jsondollar,
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

when isMainModule:
  import jsonmapper

  proc main =
    let tree = %*{
      "a": {"x": 24, "y": 25},
      "b": {"c": 3, "d": 4},
      "arr": [1, 2, 3, 4],
      "str": "hello"
    }

    block:
      assert tree.dump(JsonPtr"/a") == """{"x":24,"y":25}"""
      assert tree.dump(JsonPtr"/b") == """{"c":3,"d":4}"""
      assert tree.dump(JsonPtr"/arr") == "[1,2,3,4]"
      assert tree.dump(JsonPtr"/str") == "\"hello\""

    block:
      let extracted = tree.extract(JsonPtr"/a")
      assert extracted == %*{"x": 24, "y": 25}

    block:
      assert tree.contains(JsonPtr"/a") == true
      assert tree.contains(JsonPtr"/b") == true
      assert tree.contains(JsonPtr"/c") == false

    block:
      assert tree.kind(JsonPtr"/a") == JObject
      assert tree.kind(JsonPtr"/arr") == JArray
      assert tree.kind(JsonPtr"/str") == JString

    block:
      assert tree.len(JsonPtr"/a") == 2
      assert tree.len(JsonPtr"/arr") == 4

  static: main()
  main()
