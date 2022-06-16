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
    assert kind(x, JsonPtr"/a") == JInt
    assert $x == """{"a":0,"key":[4,[1,2,3]]}"""
    remove(x, JsonPtr"/a")
    assert not contains(x, JsonPtr"/a")
    assert contains(x, JsonPtr"/key")
    assert $x == """{"key":[4,[1,2,3]]}"""
    remove(x, JsonPtr"/key/0")
    assert $x == """{"key":[[1,2,3]]}"""
    remove(x, JsonPtr"/key/0/1")
    assert $x == """{"key":[[1,3]]}"""
    assert kind(x, JsonPtr"/key") == JArray
    remove(x, JsonPtr"")
    assert x.isEmpty

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
    let z = Vec3(x: 1, y: 2, z: 3)
    let y = Foo(a: [Vec3(x: 1, y: 2, z: 3)], b: true, c: "hi", d: foo)
    let x = %*y
    assert not x.isEmpty
    assert toJson(y) == x
    assert toJson(z) == %*z
    assert fromJson(x, JsonPtr"", Foo)[] == y[]
    assert fromJson(x, JsonPtr"/a/0", Vec3) == z
    assert test(fromJson(x, JsonPtr"/a/0", JsonTree), JsonPtr"", %*z)
    assert fromJson(x, JsonPtr"/b", bool) == true
    assert fromJson(x, JsonPtr"/c", string) == "hi"
    assert fromJson(x, JsonPtr"/d", Bar) == foo
    assert $x == """{"a":[{"x":1,"y":2,"z":3}],"b":true,"c":"hi","d":"foo"}"""
    for v in items(x, JsonPtr"/a", Vec3):
      assert v == z
    assert x != %*nil

  block:
    var x = %*[]
    var y = parseJson("[]")
    assert x == y
    x = %*{}
    y = parseJson("{}")
    assert x == y
    x = %*[x]
    y = parseJson("[{}]")
    assert x == y
    y = parseJson("[1, 2, 3]")
    x = %*{"x": y}
    assert x == parseJson("""{"x": [1, 2, 3]}""")
    x = %*{"x": 1, "y": y}
    assert x == parseJson("""{"x": 1, "y": [1, 2, 3]}""")
    x = %*{"x": y, "y": 1}
    assert x == parseJson("""{"x": [1, 2, 3], "y": 1}""")
    x = %*{"x": x, "y": 1}
    assert x == parseJson("""{"x": {"x": [1, 2, 3], "y": 1}, "y": 1}""")

  block:
    var x = %*[]
    let z = %*[1, 2, 3, 4, 5]
    add(x, JsonPtr"/-", z)
    assert test(x, JsonPtr"/0", z)
    add(x, JsonPtr"/-", %*"a")
    assert x == %*[z, "a"]
    var y = %*{}
    add(y, JsonPtr"/x", z)
    assert y == %*{"x": z}

static: main()
main()
