import
  packedjson2 / bitabs,
  std / [parsejson, streams, strutils]
export JsonParsingError, JsonKindError

type
  JsonNode* = distinct int32

  Node = distinct int32
  NodePos = distinct int
  JsonNodeKind* = enum ## possible JSON node types
    JNull,
    JBool,
    JInt,
    JFloat,
    JString,
    JObject,
    JArray

const
  rootJsonNode* = JsonNode(0)  ## Each `JsonTree` starts from this index.
  nullJsonNode* = JsonNode(-1) ## Null `JsonNode`

proc `==`*(a, b: NodePos): bool {.borrow.}
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

iterator sonsReadonly(tree: JsonTree; n: NodePos): NodePos =
  var pos = n.int
  assert tree.nodes[pos].kind > opcodeString
  let last = pos + tree.nodes[pos].operand
  inc pos
  while pos < last:
    yield NodePos(pos)
    nextChild tree, pos

proc parentImpl(tree: JsonTree; n: NodePos): NodePos =
  # finding the parent of a node is rather easy:
  var pos = n.int - 1
  while pos >= 0 and (isAtom(tree, pos) or (pos + tree.nodes[pos].operand - 1 < n.int)):
    dec pos
  #assert pos >= 0, "node has no parent"
  result = NodePos(pos)

template parent(n: NodePos): NodePos = parentImpl(tree, n)

proc firstSon(n: NodePos): NodePos {.inline.} = NodePos(n.int+1)

template kind(n: NodePos): int32 = tree.nodes[n.int].kind
template litId(n: NodePos): LitId = LitId tree.nodes[n.int].operand

template operand(n: NodePos): int32 = tree.nodes[n.int].operand

proc hasKey*(tree: JsonTree; n: JsonNode; key: string): bool =
  let litId = tree.atoms.getKeyId(key)
  if litId == LitId(0):
    return false
  assert kind(NodePos n) == opcodeObject
  for ch0 in sonsReadonly(tree, NodePos n):
    assert ch0.kind == opcodeKeyValuePair
    if ch0.firstSon.litId == litId:
      return true

proc getStr*(tree: JsonTree, n: JsonNode, default: string = ""): string =
  ## Retrieves the string value of a `JString`.
  ##
  ## Returns `default` if `x` is not a `JString`.
  if kind(tree, n) == JString: result = tree.atoms[NodePos(n).litId]
  else: result = default

proc getInt*(tree: JsonTree, n: JsonNode, default: int = 0): int =
  ## Retrieves the int value of a `JInt`.
  ##
  ## Returns `default` if `x` is not a `JInt`, or if `x` is nil.
  if kind(tree, n) == JInt: result = parseInt tree.atoms[NodePos(n).litId]
  else: result = default

proc getBiggestInt*(tree: JsonTree, n: JsonNode, default: BiggestInt = 0): BiggestInt =
  ## Retrieves the BiggestInt value of a `JInt`.
  ##
  ## Returns `default` if `x` is not a `JInt`, or if `x` is nil.
  if kind(tree, n) == JInt: result = parseBiggestInt tree.atoms[NodePos(n).litId]
  else: result = default

proc getFloat*(tree: JsonTree, n: JsonNode, default: float = 0.0): float =
  ## Retrieves the float value of a `JFloat`.
  ##
  ## Returns `default` if `x` is not a `JFloat` or `JInt`, or if `x` is nil.
  case kind(tree, n)
  of JFloat:
    result = parseFloat tree.atoms[NodePos(n).litId]
  of JInt:
    result = float(parseBiggestInt tree.atoms[NodePos(n).litId])
  else:
    result = default

proc getBool*(tree: JsonTree, n: JsonNode, default: bool = false): bool =
  ## Retrieves the bool value of a `JBool`.
  ##
  ## Returns `default` if `n` is not a `JBool`, or if `n` is nil.
  if kind(tree, n) == JBool: result = NodePos(n).operand == 1
  else: result = default

type
  PatchPos = distinct int32

proc prepare(tree: var JsonTree; kind: int32): PatchPos =
  result = PatchPos tree.nodes.len
  tree.nodes.add Node kind

proc patch(tree: var JsonTree; pos: PatchPos) =
  let pos = pos.int
  assert tree.nodes[pos].kind > opcodeString
  let distance = int32(tree.nodes.len - pos)
  tree.nodes[pos] = toNode(tree.nodes[pos].int32, distance)

proc parseJson(tree: var JsonTree; p: var JsonParser) =
  case p.tok
  of tkString:
    tree.nodes.add toNode(opcodeString, int32 getOrIncl(tree.atoms, p.a))
    discard getTok(p)
  of tkInt:
    tree.nodes.add toNode(opcodeInt, int32 getOrIncl(tree.atoms, p.a))
    discard getTok(p)
  of tkFloat:
    tree.nodes.add toNode(opcodeFloat, int32 getOrIncl(tree.atoms, p.a))
    discard getTok(p)
  of tkTrue:
    tree.nodes.add Node opcodeTrue
    discard getTok(p)
  of tkFalse:
    tree.nodes.add Node opcodeFalse
    discard getTok(p)
  of tkNull:
    tree.nodes.add Node opcodeNull
    discard getTok(p)
  of tkCurlyLe, tkBracketLe:
    var insertPos: seq[PatchPos] = @[]
    while true:
      if insertPos.len > 0 and
          kind(NodePos insertPos[^1]) == opcodeObject and p.tok != tkCurlyRi:
        if p.tok != tkString:
          raiseParseErr(p, "string literal as key")
        else:
          let patchPos = tree.prepare(opcodeKeyValuePair)
          tree.nodes.add toNode(opcodeString, int32 getOrIncl(tree.atoms, p.a))
          insertPos.add patchPos
          discard getTok(p)
          eat(p, tkColon)

      template putVal() =
        if insertPos.len > 0:
          if kind(NodePos insertPos[^1]) == opcodeKeyValuePair:
            tree.patch insertPos.pop()

      case p.tok
      of tkString, tkInt, tkFloat, tkTrue, tkFalse, tkNull:
        # this recursion for atoms is fine and could easily be avoided
        # since it deals with atoms only.
        parseJson(tree, p)
        putVal()
        if p.tok == tkComma:
          discard getTok(p)
      of tkCurlyLe:
        insertPos.add tree.prepare(opcodeObject)
        discard getTok(p)
      of tkBracketLe:
        insertPos.add tree.prepare(opcodeArray)
        discard getTok(p)
      of tkCurlyRi:
        if insertPos.len > 0 and kind(NodePos insertPos[^1]) == opcodeObject:
          tree.patch insertPos.pop()
          putVal()
          discard getTok(p)
          if insertPos.len == 0: break
        else:
          raiseParseErr(p, "{")
        if p.tok == tkComma:
          discard getTok(p)
      of tkBracketRi:
        if insertPos.len > 0 and kind(NodePos insertPos[^1]) == opcodeArray:
          tree.patch insertPos.pop()
          putVal()
          discard getTok(p)
          if insertPos.len == 0: break
        else:
          raiseParseErr(p, "{")
        if p.tok == tkComma:
          discard getTok(p)
      else:
        raiseParseErr(p, "{")
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
  let x = parseJson(data)
  assert x.atoms.len == 5
  assert hasKey(x, rootJsonNode, "a")
  assert x.nodes[1].kind == opcodeKeyValuePair
  assert x.nodes[1].operand == 12
  assert kind(x, rootJsonNode) == JObject
  assert hasKey(x, JsonNode 6, "key")
  assert kind(x, JsonNode 5) == JBool
  assert getBool(x, JsonNode 5) == false
  assert kind(x, JsonNode 4) == JInt
  assert getInt(x, JsonNode 4) == 1
  assert kind(x, JsonNode 11) == JInt
  assert getInt(x, JsonNode 11) == 5
