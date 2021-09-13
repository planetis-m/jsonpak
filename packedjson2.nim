import
  packedjson2 / bitabs,
  std / [parsejson, streams]

type
  NodePos* = distinct int

  Node = distinct int32
  JsonNodeKind* = enum ## possible JSON node types
    JNull,
    JBool,
    JInt,
    JFloat,
    JString,
    JObject,
    JArray

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

template kind*(n: Node): int32 = n.int32 and opcodeMask
template operand*(n: Node): int32 = n.int32 shr opcodeBits
template toNode*(kind, operand: int32): Node = Node(operand shl opcodeBits or kind)

type
  JsonTree = object
    nodes: seq[Node]
    atoms: BiTable[string]

proc isAtom*(tree: JsonTree; pos: int): bool {.inline.} =
  tree.nodes[pos].kind <= opcodeString

proc nextChild(tree: JsonTree; pos: var int) {.inline.} =
  if tree.nodes[pos].kind > opcodeString:
    assert tree.nodes[pos].operand > 0
    inc pos, tree.nodes[pos].operand
  else:
    inc pos
#[
iterator sonsReadonly*(tree: JsonTree; n: NodePos): NodePos =
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

template parent*(n: NodePos): NodePos = parentImpl(tree, n)

proc identIdImpl(tree: JsonTree; n: NodePos): LitId =
  if n.kind == opcodeIdent:
    result = n.litId
  elif n.kind == opcodeSym:
    result = tree.sh.syms[int n.symId].name
  else:
    result = LitId(0)

template identId*(n: NodePos): LitId = identIdImpl(tree, n)

template kind*(n: NodePos): TNodeKind = tree.nodes[n.int].kind
template litId*(n: NodePos): LitId = LitId tree.nodes[n.int].operand

template symId*(n: NodePos): SymId = SymId tree.nodes[n.int].operand

proc firstSon*(n: NodePos): NodePos {.inline.} = NodePos(n.int+1)

proc hasPragma*(tree: JsonTree; n: NodePos; pragma: string): bool =
  let litId = tree.sh.strings.getKeyId(pragma)
  if litId == LitId(0):
    return false
  assert n.kind == opcodePragma
  for ch0 in sonsReadonly(tree, n):
    if ch0.kind == opcodeExprColonExpr:
      if ch0.firstSon.identId == litId:
        return true
    elif ch0.identId == litId:
      return true]#

type
  PatchPos = distinct int

proc prepare*(tree: var JsonTree; kind: int32): PatchPos =
  result = PatchPos tree.nodes.len
  tree.nodes.add Node kind

proc patch*(tree: var JsonTree; pos: PatchPos) =
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

when isMainModule:
  let data = """{"a": [1, 2, {"key": [4, 5]}, 4]}"""
  var p: JsonParser
  var x: JsonTree
  open(p, newStringStream(data), "input")
  try:
    discard getTok(p)
    parseJson x, p
    eat(p, tkEof)
  finally:
    close(p)
