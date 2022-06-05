# To be included by main!
block:
  let data = """{"a":[1,false,{"key":[4,5]},4]}"""
  let x = parseJson(data)
  assert not x.isEmpty
  assert x.atoms.len == 5
  assert kind(x, JsonPtr"") == JObject
  assert toNodePos(x, jRoot, JsonPtr"") == jRoot
  assert toNodePos(x, jRoot, JsonPtr"/a") == NodePos 3
  assert contains(x, JsonPtr"/a")
  assert x.nodes[1].kind == opcodeKeyValuePair
  assert x.nodes[1].operand == 12
  assert contains(x, JsonPtr"/a/2/key")
  assert not contains(x, JsonPtr"/a/2/a")
  assert x.nodes[7].kind == opcodeKeyValuePair
  assert x.nodes[7].operand == 5
  assert toNodePos(x, jRoot, JsonPtr"/a/2/key") == NodePos 9
  assert kind(x, JsonPtr"/a/2/key") == JArray
  assert toNodePos(x, jRoot, JsonPtr"/a/1") == NodePos 5
  assert kind(x, JsonPtr"/a/1") == JBool
  assert getBool(x, JsonPtr"/a/1") == false
  assert toNodePos(x, jRoot, JsonPtr"/a/0") == NodePos 4
  assert kind(x, JsonPtr"/a/0") == JInt
  assert getInt(x, JsonPtr"/a/0") == 1
  assert toNodePos(x, jRoot, JsonPtr"/a/2/key/1") == NodePos 11
  assert kind(x, JsonPtr"/a/2/key/1") == JInt
  assert getInt(x, JsonPtr"/a/2/key/1") == 5
  assert toNodePos(x, NodePos 3, JsonPtr"") == NodePos 3
  assert toNodePos(x, NodePos 3, JsonPtr"/2") == NodePos 6
  assert toNodePos(x, NodePos 3, JsonPtr"/-") == NodePos 12
  assert $x == data

block:
  let data = """{"a":{"key":[4,[1,2,3]]}}"""
  let x = parseJson(data)
  assert not x.isEmpty
  assert x.atoms.len == 6
  assert kind(x, JsonPtr"") == JObject
  assert toNodePos(x, jRoot, JsonPtr"/a/key") == NodePos 6
  assert toNodePos(x, NodePos 6, JsonPtr"/-/-") == NodePos 11
  assert toNodePos(x, NodePos 6, JsonPtr"/1/2") == NodePos 11
  for k, v in pairs(x, jRoot):
    assert k == "a"
    assert v == NodePos 3
  assert $x == data

block:
  let data = """{"a":0,"key":[4,[1,2,3]],"b":{"a":false}}"""
  var x = parseJson(data)
  assert $x == data
  assert not x.isEmpty
  assert x.atoms.len == 8
  assert contains(x, JsonPtr"/a")
  assert contains(x, JsonPtr"/key")
  delete(x, jRoot, "a")
  assert not contains(x, JsonPtr"/a")
  assert contains(x, JsonPtr"/key")
  assert kind(x, JsonPtr"") == JObject
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
