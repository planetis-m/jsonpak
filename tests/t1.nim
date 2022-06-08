import ".."/packedjson2

proc main =
  block:
    let data = """{"a":0,"key":[4,[1,2,3]],"b":{"a":false}}"""
    var x = parseJson(data)
    assert $x == data
    assert not x.isEmpty
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
    remove(x, JsonPtr"/key/0")
    assert $x == """{"key":[[1,2,3]]}"""
    remove(x, JsonPtr"/key/0/1")
    assert $x == """{"key":[[1,3]]}"""
    #assert kind(x, JsonPtr"/a") == JInt
    assert kind(x, JsonPtr"/key") == JArray

  block:
    const x = %*{
      "a": [1, 2, 3],
      "b": 4,
      "c": [5, 6],
      "d": {"e": [7, 8], "f": 9},
      "": {"": [10, 11], "g": [12]}
    }
    assert not x.isEmpty
    assert $extract(x, JsonPtr"/a") == "[1,2,3]"
    assert $extract(x, JsonPtr"/b") == "4"
    assert $extract(x, JsonPtr"/d") == """{"e":[7,8],"f":9}"""
    assert $extract(x, JsonPtr"/d/e") == "[7,8]"
    assert test(x, JsonPtr"/d", %*{"e": [7, 8], "f": 9})
    assert test(x, JsonPtr"/d/e", %*[7, 8])
    assert not test(x, JsonPtr"/d/e", %*[7, 8, 9])
    assert test(extract(x, JsonPtr"/d/e"), JsonPtr"", %*[7, 8])
    assert fromJson(x, JsonPtr"/d/e", array[2, int]) == [7, 8]
    assert fromJson(x, JsonPtr"///1", int) == 11
    for k, v in pairs(x, JsonPtr"/", seq[int]):
      assert k in ["", "g"]
    assert $x == """{"a":[1,2,3],"b":4,"c":[5,6],"d":{"e":[7,8],"f":9},"":{"":[10,11],"g":[12]}}"""

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
    let y = Foo(a: [Vec3(x: 1, y: 2, z: 3)], b: true, c: "hi", d: foo)
    let x = %*y
    assert not x.isEmpty
    assert fromJson(x, JsonPtr"", Foo)[] == y[]
    assert fromJson(x, JsonPtr"/a/0", Vec3) == Vec3(x: 1, y: 2, z: 3)
    assert fromJson(x, JsonPtr"/b", bool) == true
    assert fromJson(x, JsonPtr"/c", string) == "hi"
    assert fromJson(x, JsonPtr"/d", Bar) == foo
    assert $x == """{"a":[{"x":1,"y":2,"z":3}],"b":true,"c":"hi","d":"foo"}"""
    for v in items(x, JsonPtr"/a", Vec3):
      assert v == Vec3(x: 1, y: 2, z: 3)
    assert not test(x, JsonPtr"", %*nil)

static: main()
main()
