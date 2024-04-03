import
  jsonpak/[builder, parser, mapper, jsonptr], jsonpak/private/[jsontree, rawops],
  std/[assertions, tables, options]

type
  Person = object
    name: string
    age: int
    height: float
    isStudent: bool

  Color = enum
    Red, Green, Blue

proc main =
  let tree = %*{
    "a": {"x": 24, "y": 25},
    "b": {"c": 3, "d": 4},
    "arr": [1, 2, 3, 4],
    "str": "hello"
  }

  block:
    let tree = tree
    var tmp: JsonTree
    initFromJson(tmp, tree, NodePos 2)
    assert rawTest(tmp, tree, rootNodeId, NodePos 2)
    tmp.reset()
    initFromJson(tmp, tree, NodePos 14)
    assert rawTest(tmp, tree, rootNodeId, NodePos 14)
    tmp.reset()
    initFromJson(tmp, tree, NodePos 20)
    assert rawTest(tmp, tree, rootNodeId, NodePos 20)

  block:
    let jsonStr = """{"age": 30, "isStudent": true, "name": "John", "height": 1.75}"""
    let tree = jsonStr.parseJson
    var p: Person
    initFromJson(p, tree, rootNodeId)
    assert p.name == "John"
    assert p.age == 30
    assert p.height == 1.75
    assert p.isStudent == true

  block:
    let jsonStr = """{"color": "Green"}"""
    let tree = jsonStr.parseJson
    var color: Color
    initFromJson(color, tree, NodePos 2)
    assert color == Color.Green

  block:
    let jsonStr = """[1, 2, 3, 4, 5]"""
    let tree = jsonStr.parseJson
    var arr: seq[int]
    initFromJson(arr, tree, rootNodeId)
    assert arr == @[1, 2, 3, 4, 5]

  block:
    let jsonStr = """{"values": [1, 2, 3, 4, 5]}"""
    let tree = jsonStr.parseJson
    var arr: array[5, int]
    initFromJson(arr, tree, NodePos 2)
    assert arr == [1, 2, 3, 4, 5]

  block:
    let jsonStr = """{"key1": "value1", "key2": "value2"}"""
    let tree = jsonStr.parseJson
    var table: Table[string, string]
    initFromJson(table, tree, rootNodeId)
    assert table["key1"] == "value1"
    assert table["key2"] == "value2"

  block:
    let jsonStr = """{"value": 42}"""
    let tree = jsonStr.parseJson
    var opt: Option[int]
    initFromJson(opt, tree, NodePos 2)
    assert opt.isSome
    assert opt.get == 42

  block:
    let jsonStr = """{"value": null}"""
    let tree = jsonStr.parseJson
    var opt: Option[int]
    initFromJson(opt, tree, NodePos 2)
    assert opt.isNone

  block:
    let jsonStr = """null"""
    let tree = jsonStr.parseJson
    var str: string
    initFromJson(str, tree, rootNodeId)
    assert str == ""

  block:
    let jsonStr = """{"value": 3.14}"""
    let tree = jsonStr.parseJson
    var num: float
    initFromJson(num, tree, NodePos 2)
    assert num == 3.14

  block:
    let jsonStr = """{"value": 42}"""
    let tree = jsonStr.parseJson
    var num: int
    initFromJson(num, tree, NodePos 2)
    assert num == 42

  block:
    type
      Point = object
        x, y: int
    let point = tree.fromJson(JsonPtr"/a", Point)
    assert point == Point(x: 24, y: 25)

  block:
    var values: seq[int]
    for item in tree.items(JsonPtr"/arr", int):
      values.add(item)
    assert values == @[1, 2, 3, 4]

  block:
    var pairs: seq[(string, int)]
    for key, value in tree.pairs(JsonPtr"/b", int):
      pairs.add((key, value))
    assert pairs == @[("c", 3), ("d", 4)]

static: main()
main()

