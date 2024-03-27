import jsonpak, jsonpak/[mapper, extra, jsonptr]

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

