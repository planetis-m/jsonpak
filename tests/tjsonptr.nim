import std/assertions, jsonpak/[mapper, jsonptr], jsonpak/private/jsontree

proc main =
  block:
    var s = "hello~world/foo"
    s = escapeJsonPtr(s)
    assert s == "hello~0world~1foo"

  block:
    var s = "hello~0world~1foo"
    unescapeJsonPtr(s)
    assert s == "hello~world/foo"

  # block:
  #   assert getArrayIndex("0") == 0
  #   assert getArrayIndex("123") == 123
  #   assert getArrayIndex("-") == -1
  #   assert:
  #     try: (discard getArrayIndex(""); false)
  #     except SyntaxError: true
  #   assert:
  #     try: (discard getArrayIndex("01"); false)
  #     except SyntaxError: true
  #   assert:
  #     try: (discard getArrayIndex("-1"); false)
  #     except SyntaxError: true

  block:
    let tree = %*{"foo": {"bar": nil}, "arr": [1, 2]}
    assert findNode(tree, "/foo/bar") == NodePos(4)
    assert findNode(tree, "/foo/baz") == nilNodeId
    assert findNode(tree, "/arr/0") == NodePos(7)
    assert findNode(tree, "/arr/1") == NodePos(8)
    assert findNode(tree, "/arr/-") == nilNodeId
    assert findNode(tree, "/arr/100") == nilNodeId

  block:
    let tree = %*{"foo": {"bar": nil}, "arr": [1, 2]}
    var res = findNodeMut(tree, "/foo/bar")
    assert res.node == NodePos(4)
    assert res.parents == @[PatchPos(0), PatchPos(2)]
    res = findNodeMut(tree, "/arr/-")
    assert res.node == nilNodeId
    assert res.parents == @[PatchPos(0), PatchPos(6)]
    assert res.key == ""
    res = findNodeMut(tree, "/foo/baz")
    assert res.key == "baz"

static: main()
main()
