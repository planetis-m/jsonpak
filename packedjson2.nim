import
  packedjson2 / bitabs,
  std / [parsejson, streams, strutils]
export JsonParsingError, JsonKindError

type
  JsonNode* = distinct int

  Node = distinct int32
  JsonNodeKind* = enum ## possible JSON node types
    JNull,
    JBool,
    JInt,
    JFloat,
    JString,
    JObject,
    JArray

proc `==`*(a, b: JsonNode): bool {.borrow.}

const
  opcodeBits = 3

  opcodeNull = ord JNull
  opcodeBool = ord JBool
  opcodeFalse = opcodeBool
  opcodeTrue = opcodeBool or 0b0000_1000
  opcodeInt = ord JInt
  opcodeFloat = ord JFloat
  opcodeString = ord JString
  opcodeObject = ord JObject
  opcodeArray = ord JArray
  opcodeKeyValuePair = 7

  opcodeMask = 0b111

template kind(n: Node): int32 = n.int32 and opcodeMask
template operand(n: Node): int32 = n.int32 shr opcodeBits.int32
template toNode(kind, operand: int32): Node = Node(operand shl opcodeBits.int32 or kind)

type
  JsonTree* = object
    nodes: seq[Node]
    atoms: BiTable[string]

proc isAtom(tree: JsonTree; pos: int): bool {.inline.} =
  tree.nodes[pos].kind <= opcodeString

proc nextChild(tree: JsonTree; pos: var int) {.inline.} =
  if tree.nodes[pos].kind > opcodeString:
    assert tree.nodes[pos].operand > 0
    inc pos, tree.nodes[pos].operand
  else:
    inc pos

proc kind*(tree: JsonTree; n: JsonNode): JsonNodeKind {.inline.} =
  JsonNodeKind tree.nodes[n.int].kind

iterator sonsReadonly(tree: JsonTree; n: JsonNode): JsonNode =
  var pos = n.int
  assert tree.nodes[pos].kind > opcodeString
  let last = pos + tree.nodes[pos].operand
  inc pos
  while pos < last:
    yield JsonNode(pos)
    nextChild tree, pos

proc parentImpl(tree: JsonTree; n: JsonNode): JsonNode =
  # finding the parent of a node is rather easy:
  var pos = n.int - 1
  while pos >= 0 and (isAtom(tree, pos) or (pos + tree.nodes[pos].operand - 1 < n.int)):
    dec pos
  #assert pos >= 0, "node has no parent"
  result = JsonNode(pos)

template parent(n: JsonNode): JsonNode = parentImpl(tree, n)

proc firstSon(n: JsonNode): JsonNode {.inline.} = JsonNode(n.int+1)

template kind(n: JsonNode): int32 = tree.nodes[n.int].kind
template litId(n: JsonNode): LitId = LitId tree.nodes[n.int].operand

template operand(n: JsonNode): int32 = tree.nodes[n.int].operand

proc hasKey*(tree: JsonTree; n: JsonNode; key: string): bool =
  let litId = tree.atoms.getKeyId(key)
  if litId == LitId(0):
    return false
  assert n.kind == opcodeObject
  for ch0 in sonsReadonly(tree, n):
    assert ch0.kind == opcodeKeyValuePair
    if ch0.firstSon.litId == litId:
      return true

proc getStr*(tree: JsonTree, n: JsonNode, default: string = ""): string =
  ## Retrieves the string value of a `JString`.
  ##
  ## Returns `default` if `x` is not a `JString`.
  if n.kind == opcodeString: result = tree.atoms[n.litId]
  else: result = default

proc getInt*(tree: JsonTree, n: JsonNode, default: int = 0): int =
  ## Retrieves the int value of a `JInt`.
  ##
  ## Returns `default` if `x` is not a `JInt`, or if `x` is nil.
  if n.kind == opcodeInt: result = parseInt tree.atoms[n.litId]
  else: result = default

proc getBiggestInt*(tree: JsonTree, n: JsonNode, default: BiggestInt = 0): BiggestInt =
  ## Retrieves the BiggestInt value of a `JInt`.
  ##
  ## Returns `default` if `x` is not a `JInt`, or if `x` is nil.
  if n.kind == opcodeInt: result = parseBiggestInt tree.atoms[n.litId]
  else: result = default

proc getFloat*(tree: JsonTree, n: JsonNode, default: float = 0.0): float =
  ## Retrieves the float value of a `JFloat`.
  ##
  ## Returns `default` if `x` is not a `JFloat` or `JInt`, or if `x` is nil.
  case n.kind
  of opcodeFloat:
    result = parseFloat tree.atoms[n.litId]
  of opcodeInt:
    result = float(parseBiggestInt tree.atoms[n.litId])
  else:
    result = default

proc getBool*(tree: JsonTree, n: JsonNode, default: bool = false): bool =
  ## Retrieves the bool value of a `JBool`.
  ##
  ## Returns `default` if `n` is not a `JBool`, or if `n` is nil.
  if n.kind == opcodeBool: result = n.operand == 1
  else: result = default

type
  PatchPos = distinct int

proc prepare(tree: var JsonTree; kind: int32): PatchPos =
  result = PatchPos tree.nodes.len
  tree.nodes.add Node kind

proc patch(tree: var JsonTree; pos: PatchPos) =
  let pos = pos.int
  assert tree.nodes[pos].kind > opcodeString
  let distance = int32(tree.nodes.len - pos)
  tree.nodes[pos] = toNode(tree.nodes[pos].int32, distance)

proc parseJson(x: var JsonTree; p: var JsonParser) =
  case p.tok
  of tkString:
    x.nodes.add toNode(opcodeString, int32 getOrIncl(x.atoms, p.a))
    discard getTok(p)
  of tkInt:
    x.nodes.add toNode(opcodeInt, int32 getOrIncl(x.atoms, p.a))
    discard getTok(p)
  of tkFloat:
    x.nodes.add toNode(opcodeFloat, int32 getOrIncl(x.atoms, p.a))
    discard getTok(p)
  of tkTrue:
    x.nodes.add Node opcodeTrue
    discard getTok(p)
  of tkFalse:
    x.nodes.add Node opcodeFalse
    discard getTok(p)
  of tkNull:
    x.nodes.add Node opcodeNull
    discard getTok(p)
  of tkCurlyLe:
    let patchPos = x.prepare(opcodeObject)
    discard getTok(p)
    while p.tok != tkCurlyRi:
      if p.tok != tkString:
        raiseParseErr(p, "string literal as key")
      let patchPos = x.prepare(opcodeKeyValuePair)
      x.nodes.add toNode(opcodeString, int32 getOrIncl(x.atoms, p.a))
      discard getTok(p)
      eat(p, tkColon)
      parseJson(x, p)
      x.patch patchPos
      if p.tok != tkComma: break
      discard getTok(p)
    eat(p, tkCurlyRi)
    x.patch patchPos
  of tkBracketLe:
    let patchPos = x.prepare(opcodeArray)
    discard getTok(p)
    while p.tok != tkBracketRi:
      parseJson(x, p)
      if p.tok != tkComma: break
      discard getTok(p)
    eat(p, tkBracketRi)
    x.patch patchPos
  of tkError, tkCurlyRi, tkBracketRi, tkColon, tkComma, tkEof:
    raiseParseErr(p, "{")

proc parseJson*(s: Stream, filename: string = ""): JsonTree =
  ## Parses from a stream `s` into a `JsonNode`. `filename` is only needed
  ## for nice error messages.
  ## If `s` contains extra data, it will raise `JsonParsingError`.
  var p: JsonParser
  open(p, s, filename)
  try:
    discard getTok(p)
    parseJson(result, p)
    eat(p, tkEof)
  finally:
    close(p)

proc parseJson*(buffer: string): JsonTree =
  ## Parses JSON from `buffer`.
  ## If `buffer` contains extra data, it will raise `JsonParsingError`.
  parseJson(newStringStream(buffer), "input")

proc parseFile*(filename: string): JsonTree =
  ## Parses `file` into a `JsonNode`.
  ## If `file` contains extra data, it will raise `JsonParsingError`.
  var stream = newFileStream(filename, fmRead)
  if stream == nil:
    raise newException(IOError, "cannot read from file: " & filename)
  result = parseJson(stream, filename)

when isMainModule:
  let data = """{"a": [1, false, {"key": [4, 5]}, 4]}"""
  var x = parseJson(data)
  assert hasKey(x, JsonNode 0, "a")
  assert kind(x, JsonNode 0) == JObject
  assert hasKey(x, JsonNode 6, "key")
  assert kind(x, JsonNode 5) == JBool
  assert getBool(x, JsonNode 5) == false
  assert kind(x, JsonNode 4) == JInt
  assert getInt(x, JsonNode 4) == 1
