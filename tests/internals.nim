# To be included by main!
block:
  let data = """{"a":[1,false,{"key":[4,5]},4]}"""
  let x = parseJson(data)
  assert not x.isEmpty
  assert x.atoms.len == 5
  assert kind(x, JsonPtr"") == JObject
  var parent = rootNodeId
  assert posFromPtr(x, parent, JsonPtr"") == rootNodeId
  assert parent == nilNodeId
  parent = rootNodeId
  assert posFromPtr(x, parent, JsonPtr"/a") == NodePos 3
  assert parent == rootNodeId
  parent = rootNodeId
  assert posFromPtr(x, parent, JsonPtr"/a/4") == nilNodeId
  assert parent == NodePos 3
  parent = rootNodeId
  assert posFromPtr(x, parent, JsonPtr"/a/4/key") == nilNodeId
  assert parent == nilNodeId
  assert contains(x, JsonPtr"/a")
  assert x.nodes[1].kind == opcodeKeyValuePair
  assert x.nodes[1].operand == 12
  assert contains(x, JsonPtr"/a/2/key")
  assert not contains(x, JsonPtr"/a/2/a")
  assert x.nodes[7].kind == opcodeKeyValuePair
  assert x.nodes[7].operand == 5
  parent = rootNodeId
  assert posFromPtr(x, parent, JsonPtr"/a/2/key") == NodePos 9
  assert parent == NodePos 6
  assert kind(x, JsonPtr"/a/2/key") == JArray
  parent = rootNodeId
  assert posFromPtr(x, parent, JsonPtr"/a/1") == NodePos 5
  assert parent == NodePos 3
  assert kind(x, JsonPtr"/a/1") == JBool
  assert getBool(x, JsonPtr"/a/1") == false
  parent = rootNodeId
  assert posFromPtr(x, parent, JsonPtr"/a/0") == NodePos 4
  assert parent == NodePos 3
  assert kind(x, JsonPtr"/a/0") == JInt
  assert getInt(x, JsonPtr"/a/0") == 1
  parent = rootNodeId
  assert posFromPtr(x, parent, JsonPtr"/a/2/key/1") == NodePos 11
  assert parent == NodePos 9
  assert kind(x, JsonPtr"/a/2/key/1") == JInt
  assert getInt(x, JsonPtr"/a/2/key/1") == 5
  parent = NodePos 3
  assert posFromPtr(x, parent, JsonPtr"") == NodePos 3
  assert parent == nilNodeId
  parent = NodePos 3
  assert posFromPtr(x, parent, JsonPtr"/2") == NodePos 6
  assert parent == NodePos 3
  parent = NodePos 3
  assert posFromPtr(x, parent, JsonPtr"/-", noDash = false) == NodePos 13
  assert parent == NodePos 3
  assert $x == data

block:
  let data = """{"a":{"key":[4,[1,2,3]]}}"""
  let x = parseJson(data)
  assert not x.isEmpty
  assert x.atoms.len == 6
  assert kind(x, JsonPtr"") == JObject
  var parent = rootNodeId
  assert posFromPtr(x, parent, JsonPtr"/a/key") == NodePos 6
  assert parent == NodePos 3
  parent = NodePos 6
  assert posFromPtr(x, parent, JsonPtr"/1/2") == NodePos 11
  assert parent == NodePos 8
  assert $x == data

block:
  let data = """{"a":0,"key":[4,[1,2,3]],"b":{"a":false}}"""
  var x = parseJson(data)
  assert $x == data
  assert not x.isEmpty
  assert x.atoms.len == 8
  assert contains(x, JsonPtr"/a")
  assert contains(x, JsonPtr"/key")
  remove(x, JsonPtr"/b/a")
  assert contains(x, JsonPtr"/b")
  assert not contains(x, JsonPtr"/b/a")
  assert kind(x, JsonPtr"/b") == JObject
  assert $x == """{"a":0,"key":[4,[1,2,3]],"b":{}}"""
  remove(x, JsonPtr"/b")
  assert not contains(x, JsonPtr"/b")
  assert contains(x, JsonPtr"/key")
  assert contains(x, JsonPtr"/a")
  assert kind(x, JsonPtr"") == JObject
  assert $x == """{"a":0,"key":[4,[1,2,3]]}"""
  remove(x, JsonPtr"/a")
  assert not contains(x, JsonPtr"/a")
  assert contains(x, JsonPtr"/key")
  assert $x == """{"key":[4,[1,2,3]]}"""
  #assert kind(x, JsonPtr"/a") == JInt
  assert kind(x, JsonPtr"/key") == JArray

block:
  const x = %*{
    "a": [1, 2, 3],
    "b": 4,
    "c": [5, 6],
    "d": {"e": [7, 8], "f": 9}
  }
  assert not x.isEmpty
  assert x.atoms.len == 15
  assert $extract(x, JsonPtr"/a") == "[1,2,3]"
  assert $extract(x, JsonPtr"/b") == "4"
  assert $extract(x, JsonPtr"/d") == """{"e":[7,8],"f":9}"""
  assert $extract(x, JsonPtr"/d/e") == "[7,8]"
  assert $x == """{"a":[1,2,3],"b":4,"c":[5,6],"d":{"e":[7,8],"f":9}}"""

block:
  type
    Foo = ref object
      a: array[1, Vec3]
      b: bool
      c: string
      d: Bar
    Bar = enum
      foo, bar, baz
    Vec3 = object
      x, y, z: int
  let x = %*Foo(a: [Vec3(x: 1, y: 2, z: 3)], b: true, c: "hi", d: foo)
  assert not x.isEmpty
  assert x.atoms.len == 12
  assert $x == """{"a":[{"x":1,"y":2,"z":3}],"b":true,"c":"hi","d":"foo"}"""
