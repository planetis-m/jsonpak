import
  jsonpak/[mapper, dollar], jsonpak/private/[jsonnode, jsontree],
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
  block:
    const tree = %*{
      "a": [1, 2, 3],
      "b": 4,
      "c": [5, 6],
      "d": {"e": [7, 8], "f": 9},
      "": {"": [10, 11], "g": [12]}
    }
    assert not tree.isEmpty
    assert $tree == """{"a":[1,2,3],"b":4,"c":[5,6],"d":{"e":[7,8],"f":9},"":{"":[10,11],"g":[12]}}"""

  block:
    let x = {"message":"Hello, \"World\"!"}.toTable
    let tree = x.toJson
    assert not tree.isEmpty

  block:
    let p = Person(name: "John", age: 30, height: 1.75, isStudent: false)
    let tree = p.toJson
    assert NodePos(0).kind == opcodeObject
    assert len(tree, NodePos(0)) == 4
    assert NodePos(2).kind == opcodeString
    assert NodePos(2).str == "John"
    assert NodePos(4).kind == opcodeInt
    assert NodePos(4).str == "30"
    assert NodePos(6).kind == opcodeFloat
    assert NodePos(6).str == "1.75"
    assert NodePos(8).kind == opcodeFalse

  block:
    let color = Color.Green
    let tree = color.toJson
    assert NodePos(0).kind == opcodeString
    assert NodePos(0).str == "Green"

  block:
    let opt1 = some(42)
    var tree = opt1.toJson
    assert NodePos(0).kind == opcodeInt
    assert NodePos(0).str == "42"
    let opt2 = none(int)
    tree = opt2.toJson
    assert NodePos(0).kind == opcodeNull

  block:
    let arr = [1, 2, 3, 4, 5]
    let tree = arr.toJson
    assert NodePos(0).kind == opcodeArray
    assert len(tree, NodePos(0)) == 5
    for i, num in arr:
      assert NodePos(i+1).kind == opcodeInt
      assert NodePos(i+1).str == $num

  block:
    let nilRef: ref int = nil
    let tree = nilRef.toJson
    assert NodePos(0).kind == opcodeNull

  block:
    let data = %*{"message":"Hello"}
    var tree = toJson(data)
    assert not tree.isEmpty
    assert NodePos(0).kind == opcodeObject
    assert NodePos(1).kind == opcodeString
    assert NodePos(2).kind == opcodeString
    assert len(tree, NodePos(0)) == 3

static: main()
main()
