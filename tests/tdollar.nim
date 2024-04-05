import std/assertions, jsonpak, jsonpak/[parser, dollar]

proc main =
  let tests = [
    """{"a":{"key":[4,[1,2,3]]}}""",
    """{"a":[1,false,{"key":[4,5]},4]}""",
    """{"employees":[{"name":"John","age":30},{"name":"Jane","age":25}]}""",
    """{"string":"hello","number":42,"boolean":true,"null":null}""",
    """{"message":"Hello, \"World\"!"}""",
    "{}", "[]", "123", "\"hello\"",
    """{"menu":{"id":"file","value":"File","popup":{"menuitem":[{"value":"New","onclick":"CreateNewDoc()"},{"value":"Open","onclick":"OpenDoc()"},{"value":"Close","onclick":"CloseDoc()"}]}}}"""
  ]
  for data in items(tests):
    let tree = parseJson(data)
    assert not tree.isEmpty
    assert $tree == data

main()
