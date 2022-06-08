# To be included by main!
proc main =
  block:
    let data = """{"a":[1,false,{"key":[4,5]},4]}"""
    let x = parseJson(data)
    assert not x.isEmpty
    assert x.atoms.len == 5
    assert kind(x, JsonPtr"") == JObject
    var parent = rootNodeId
    assert posFromPtr(x, JsonPtr"", parent) == rootNodeId
    assert parent == nilNodeId
    parent = rootNodeId
    assert posFromPtr(x, JsonPtr"/a", parent) == NodePos 3
    assert parent == rootNodeId
    parent = rootNodeId
    assert posFromPtr(x, JsonPtr"/a/4", parent) == nilNodeId
    assert parent == NodePos 3
    parent = rootNodeId
    assert posFromPtr(x, JsonPtr"/a/4/key", parent) == nilNodeId
    assert parent == nilNodeId
    assert contains(x, JsonPtr"/a")
    assert x.nodes[1].kind == opcodeKeyValuePair
    assert x.nodes[1].operand == 12
    assert contains(x, JsonPtr"/a/2/key")
    assert not contains(x, JsonPtr"/a/2/a")
    assert x.nodes[7].kind == opcodeKeyValuePair
    assert x.nodes[7].operand == 5
    parent = rootNodeId
    assert posFromPtr(x, JsonPtr"/a/2/key", parent) == NodePos 9
    assert parent == NodePos 6
    assert kind(x, JsonPtr"/a/2/key") == JArray
    parent = rootNodeId
    assert posFromPtr(x, JsonPtr"/a/1", parent) == NodePos 5
    assert parent == NodePos 3
    assert kind(x, JsonPtr"/a/1") == JBool
    assert getBool(x, JsonPtr"/a/1") == false
    parent = rootNodeId
    assert posFromPtr(x, JsonPtr"/a/0", parent) == NodePos 4
    assert parent == NodePos 3
    assert kind(x, JsonPtr"/a/0") == JInt
    assert getInt(x, JsonPtr"/a/0") == 1
    parent = rootNodeId
    assert posFromPtr(x, JsonPtr"/a/2/key/1", parent) == NodePos 11
    assert parent == NodePos 9
    assert kind(x, JsonPtr"/a/2/key/1") == JInt
    assert getInt(x, JsonPtr"/a/2/key/1") == 5
    parent = NodePos 3
    assert posFromPtr(x, JsonPtr"", parent) == NodePos 3
    assert parent == nilNodeId
    parent = NodePos 3
    assert posFromPtr(x, JsonPtr"/2", parent) == NodePos 6
    assert parent == NodePos 3
    parent = NodePos 3
    assert posFromPtr(x, JsonPtr"/-", parent, noDash = false) == NodePos 13
    assert parent == NodePos 3
    assert $x == data

  block:
    let data = """{"a":{"key":[4,[1,2,3]]}}"""
    let x = parseJson(data)
    assert not x.isEmpty
    assert x.atoms.len == 6
    assert kind(x, JsonPtr"") == JObject
    var parent = rootNodeId
    assert posFromPtr(x, JsonPtr"/a/key", parent) == NodePos 6
    assert parent == NodePos 3
    parent = NodePos 6
    assert posFromPtr(x, JsonPtr"/1/2", parent) == NodePos 11
    assert parent == NodePos 8
    assert $x == data

static: main()
main()
