## Provides procedures for deserializing JSON data into Nim data types.

import private/[jsonnode, jsontree, rawops], jsonptr, std/[macros, tables, options, strutils]
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

proc initFromJson*(dst: var JsonTree; tree: JsonTree; n: NodePos) =
  rawExtract(dst, tree, n)

proc initFromJson*[T: SomeInteger](dst: var T; tree: JsonTree; n: NodePos) =
  when T is uint|uint64 or int.sizeof == 4:
    verifyJsonKind(tree, n, {JInt, JRawNumber})
    case n.kind
    of opcodeRawNumber:
      let x = parseBiggestUInt(n.str)
      dst = cast[T](x)
    else:
      dst = T(n.num)
  else:
    verifyJsonKind(tree, n, {JInt})
    dst = cast[T](n.num)

proc initFromJson*[T: SomeFloat](dst: var T; tree: JsonTree; n: NodePos) =
  verifyJsonKind(tree, n, {JInt, JFloat, JRawNumber})
  if n.kind == opcodeRawNumber:
    case n.str
    of "nan":
      let b = NaN
      dst = T(b)
    of "inf":
      let b = Inf
      dst = T(b)
    of "-inf":
      let b = -Inf
      dst = T(b)
    else: raise newException(JsonKindError, "expected 'nan|inf|-inf', got " & n.str)
  else:
    if n.kind == opcodeFloat:
      dst = cast[T](n.num)
    else:
      dst = T(n.num)

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
  for x in keys(tree, n):
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
  for x in keys(tree, n):
    for k, v in dst.fieldPairs:
      if x.str == k:
        initFromJson(v, tree, x.firstSon)
        break # emulate elif

proc fromJson*[T](tree: JsonTree; path: JsonPtr; t: typedesc[T]): T =
  let n = findNode(tree, path.string)
  if n.isNil:
    raisePathError(path.string)
  result = default(T)
  initFromJson(result, tree, n)

iterator items*[T](tree: JsonTree; path: JsonPtr; t: typedesc[T]): T =
  ## Iterator for the items of `x`. `x` has to be a JArray.
  let n = findNode(tree, path.string)
  if n.isNil:
    raisePathError(path.string)
  assert n.kind == opcodeArray
  var item = default(T)
  for x in sonsReadonly(tree, n):
    initFromJson(item, tree, x)
    yield item

iterator pairs*[T](tree: JsonTree; path: JsonPtr; t: typedesc[T]): (lent string, T) =
  ## Iterator for the pairs of `x`. `x` has to be a JObject.
  let n = findNode(tree, path.string)
  if n.isNil:
    raisePathError(path.string)
  assert n.kind == opcodeObject
  var item = default(T)
  for x in keys(tree, n):
    initFromJson(item, tree, x.firstSon)
    yield (x.str, item)
