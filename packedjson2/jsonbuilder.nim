## Provides procedures for deserializing JSON data into Nim data types.

import jsonnode, jsontree, jsonpointer, std/[macros, tables, options, strutils]
from std/parsejson import JsonKindError
export JsonKindError

proc raiseJsonKindError*(kind: JsonNodeKind, kinds: set[JsonNodeKind]) {.noinline.} =
  let msg = format("Incorrect JSON kind. Wanted '$1' but got '$2'.", kinds, kind)
  raise newException(JsonKindError, msg)

template verifyJsonKind*(tree: JsonTree; n: NodePos, kinds: set[JsonNodeKind]) =
  let kind = JsonNodeKind(n.kind)
  if kind notin kinds:
    raiseJsonKindError(kind, kinds)

proc initFromJson*(dst: var string; tree: JsonTree; n: NodePos) =
  verifyJsonKind(tree, n, {JString, JNull})
  if n.kind == opcodeNull:
    dst = ""
  else:
    dst = n.str

proc initFromJson*(dst: var bool; tree: JsonTree; n: NodePos) =
  verifyJsonKind(tree, n, {JBool})
  dst = n.bval

# proc initFromJson*(dst: var JsonTree; tree: JsonTree; n: NodePos) =
#   rawExtract(dst, tree, n)

proc initFromJson*[T: SomeInteger](dst: var T; tree: JsonTree; n: NodePos) =
  verifyJsonKind(tree, n, {JInt})
  when T is BiggestUInt:
    dst = parseBiggestUInt n.str
  elif T is BiggestInt:
    dst = parseBiggestInt n.str
  elif T is SomeSignedInt:
    dst = T(parseInt n.str)
  else:
    dst = T(parseUInt n.str)

proc initFromJson*[T: SomeFloat](dst: var T; tree: JsonTree; n: NodePos) =
  verifyJsonKind(tree, n, {JInt, JFloat})
  if n.kind == opcodeFloat:
    dst = T(parseFloat n.str)
  else:
    dst = T(parseBiggestInt n.str)

proc initFromJson*[T: enum](dst: var T; tree: JsonTree; n: NodePos) =
  verifyJsonKind(tree, n, {JString})
  dst = parseEnum[T](n.str)

proc initFromJson*[T](dst: var seq[T]; tree: JsonTree; n: NodePos) =
  verifyJsonKind(tree, n, {JArray})
  dst.setLen len(tree, n)
  var i = 0
  for x in sonsReadonly(tree, n):
    initFromJson(dst[i], tree, x)
    inc i

proc initFromJson*[S, T](dst: var array[S, T]; tree: JsonTree; n: NodePos) =
  verifyJsonKind(tree, n, {JArray})
  var i = int(low(dst))
  for x in sonsReadonly(tree, n):
    initFromJson(dst[S(i)], tree, x)
    inc i

proc initFromJson*[T](dst: var (Table[string, T]|OrderedTable[string, T]); tree: JsonTree; n: NodePos) =
  verifyJsonKind(tree, n, {JObject})
  for x in sonsReadonlySkip1(tree, n):
    initFromJson(mgetOrPut(dst, x.str, default(T)), tree, x.firstSon)

proc initFromJson*[T](dst: var ref T; tree: JsonTree; n: NodePos) =
  verifyJsonKind(tree, n, {JObject, JNull})
  if n.kind == opcodeNull:
    dst = nil
  else:
    dst = new(T)
    initFromJson(dst[], tree, n)

proc initFromJson*[T](dst: var Option[T]; tree: JsonTree; n: NodePos) =
  if not n.isNil and n.kind != opcodeNull:
    when T is ref:
      dst = some(new(T))
    else:
      dst = some(default(T))
    initFromJson(dst.get, tree, n)

proc initFromJson*[T: object|tuple](dst: var T; tree: JsonTree; n: NodePos) =
  verifyJsonKind(tree, n, {JObject})
  for x in sonsReadonlySkip1(tree, n):
    block outer:
      for k, v in dst.fieldPairs:
        if x.str == k:
          initFromJson(v, tree, x.firstSon)
          break outer

proc fromJson*[T](tree: JsonTree; path: JsonPtr; t: typedesc[T]): T =
  let n = findNode(tree, path.string)
  if n.isNil:
    raisePathError(path.string)
  initFromJson(result, tree, n)

iterator items*[T](tree: JsonTree; path: JsonPtr; t: typedesc[T]): T =
  ## Iterator for the items of `x`. `x` has to be a JArray.
  let n = findNode(tree, path.string)
  if n.isNil:
    raisePathError(path.string)
  assert n.kind == opcodeArray
  var item: T
  for x in sonsReadonly(tree, n):
    initFromJson(item, tree, x)
    yield item

iterator pairs*[T](tree: JsonTree; path: JsonPtr; t: typedesc[T]): (lent string, T) =
  ## Iterator for the pairs of `x`. `x` has to be a JObject.
  let n = findNode(tree, path.string)
  if n.isNil:
    raisePathError(path.string)
  assert n.kind == opcodeObject
  var item: T
  for x in sonsReadonlySkip1(tree, n):
    initFromJson(item, tree, x.firstSon)
    yield (x.str, item)

when isMainModule:
  import std/assertions, jsonparser, jsonmapper

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
      let jsonStr = """{"name": "John", "age": 30, "height": 1.75, "isStudent": false}"""
      let tree = jsonStr.parseJson
      var p: Person
      initFromJson(p, tree, rootNodeId)
      assert p.name == "John"
      assert p.age == 30
      assert p.height == 1.75
      assert p.isStudent == false

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
