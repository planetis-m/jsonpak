import
  packedjson2 / bitabs,
  std / [parsejson, streams, strutils, macros]
export JsonParsingError, JsonKindError

type
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
  rootNodeId = NodePos(0) ## Each `JsonTree` starts from this index.
  nilNodeId = NodePos(-1) ## Empty `NodePos`

proc `<`(a, b: NodePos): bool {.borrow.}
proc `<=`(a, b: NodePos): bool {.borrow.}
proc `==`(a, b: NodePos): bool {.borrow.}

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
template operand(n: Node): int32 = int32(n.uint32 shr opcodeBits.int32)
template toNode(kind, operand: int32): Node = Node(operand shl opcodeBits.int32 or kind)

type
  JsonTree* = object
    nodes: seq[Node]
    atoms: BiTable[string]

proc isEmpty*(tree: JsonTree): bool {.inline.} = tree.nodes.len == 0

proc isAtom(tree: JsonTree; pos: int): bool {.inline.} =
  tree.nodes[pos].kind <= opcodeString

proc span(tree: JsonTree; pos: int): int {.inline.} =
  if isAtom(tree, pos): 1 else: tree.nodes[pos].operand

proc nextChild(tree: JsonTree; pos: var int) {.inline.} =
  if tree.nodes[pos].kind > opcodeString:
    assert tree.nodes[pos].operand > 0
    inc pos, tree.nodes[pos].operand
  else:
    inc pos

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

proc isNil(n: NodePos): bool {.inline.} = n == nilNodeId
proc firstSon(n: NodePos): NodePos {.inline.} = NodePos(n.int+1)

template kind(n: NodePos): int32 = tree.nodes[n.int].kind
template litId(n: NodePos): LitId = LitId tree.nodes[n.int].operand
template operand(n: NodePos): int32 = tree.nodes[n.int].operand

proc rawGet(tree: JsonTree, n: NodePos, name: string): NodePos =
  let litId = tree.atoms.getKeyId(name)
  if litId == LitId(0):
    return nilNodeId
  for ch0 in sonsReadonly(tree, n):
    assert ch0.kind == opcodeKeyValuePair
    if ch0.firstSon.litId == litId:
      return NodePos(ch0.int+2) # guaranteed that firstSon isAtom
  return nilNodeId

func addEscapedJsonPtr*(result: var string, s: string) =
  ## The same as `result.add(escapeJsonPtr(s)) <#escape,string>`_, but more efficient.
  for c in items(s):
    case c
    of '~': result.add("~0")
    of '/': result.add("~1")
    else: result.add(c)

func escapeJsonPtr*(s: string): string =
  ## Escaped `s` for inclusion into a JSON Pointer.
  ##
  ## '~' => `~0`
  ## '/' => `~1`
  ##
  ## You can also use `addEscapedJsonPtr proc <#addEscaped,string,string>`_.
  result = newStringOfCap(s.len)
  addEscapedJsonPtr(result, s)

type
  JsonPtrError* = object of CatchableError
  UsageError* = object of JsonPtrError
  SyntaxError* = object of JsonPtrError

proc raiseSyntaxError*(token: string) {.noinline.} =
  raise newException(SyntaxError, "invalid JSON pointer: " & token)

proc raiseUsageError*(token: string) {.noinline.} =
  raise newException(UsageError, "invalid use of unescapeJsonPtr on string with '/': " & token)

func unescapeJsonPtr*(token: var string) =
  ## Unescapes a string `s`.
  ##
  ## This complements `escapeJsonPtr func<#escape,string>`_
  ## as it performs the opposite operations.
  var p = -1
  block outer:
    for q in 0 ..< len(token):
      case token[q]
      of '~':
        p = q
        break outer
      of '/':
        raiseUsageError(token)
      else: discard
  # Nothing to replace
  if p == -1:
    return
  if token[^1] == '~':
    raiseSyntaxError(token)
  var q = p
  while q < len(token):
    case token[q]
    of '~':
      inc(q)
      case token[q]
      of '0':
        token[p] = '~'
      of '1':
        token[p] = '/'
      else:
        raiseSyntaxError(token)
    of '/':
      raiseUsageError(token)
    else:
      token[p] = token[q] # Move byte
    inc(p)
    inc(q)
  token.setLen(p)

type
  JsonPtr* = distinct string

func getArrayIndex(token: string): int {.inline.} =
  if len(token) == 0:
    raiseSyntaxError(token)
  if len(token) == 1:
    if token[0] == '0':
      return 0
    if token[0] == '-':
      return -1
  if token[0] < '1':
    raiseSyntaxError(token)
  result = parseInt(token)

proc nodePosFromPath*(tree: JsonTree; n: NodePos; path: JsonPtr): NodePos =
  result = n
  if result.isNil: return
  let path = string(path)
  var cur = ""
  var last = 1
  while last <= len(path):
    var first = last
    while last < len(path) and path[last] != '/':
      inc(last)
    cur.setLen(last-first)
    when nimvm:
      for i in 0..high(cur):
        cur[i] = path[i+first]
    else: copyMem(cur.cstring, addr path[first], cur.len)
    case result.kind
    of opcodeObject:
      unescapeJsonPtr(cur)
      result = rawGet(tree, result, cur)
      if result.isNil: return
    of opcodeArray:
      block searchLoop:
        var i = getArrayIndex(cur)
        var last = nilNodeId
        for ch0 in sonsReadonly(tree, result):
          last = ch0
          if i == 0:
            result = ch0
            break searchLoop
          dec i
        if i < 0: result = last
        else: return nilNodeId
    else: return nilNodeId
    inc(last)

proc raiseKeyError(path: string) {.noinline, noreturn.} =
  raise newException(KeyError, "path not in object: " & path)

proc raiseIndexDefect() {.noinline, noreturn.} =
  raise newException(IndexDefect, "index out of bounds")

proc contains*(tree: JsonTree, path: JsonPtr): bool =
  ## Checks if `key` exists in `n`.
  let n = nodePosFromPath(tree, rootNodeId, path)
  result = n >= rootNodeId

proc kind*(tree: JsonTree; path: JsonPtr): JsonNodeKind {.inline.} =
  let n = nodePosFromPath(tree, rootNodeId, path)
  if n.isNil: raiseKeyError(path.string)
  JsonNodeKind tree.nodes[n.int].kind

proc len*(tree: JsonTree; path: JsonPtr): int =
  result = 0
  let n = nodePosFromPath(tree, rootNodeId, path)
  if n.isNil: raiseKeyError(path.string)
  if tree.nodes[n.int].kind > opcodeString:
    for child in sonsReadonly(tree, n): inc result

proc rawRemove(tree: var JsonTree, n: NodePos) =
  let diff = n.operand
  var pos = n.parent.int
  while pos >= 0:
    let distance = tree.nodes[pos].operand - diff
    tree.nodes[pos] = toNode(tree.nodes[pos].kind, distance)
    pos = NodePos(pos).parent.int
  let oldfull = tree.nodes.len
  for i in countup(n.int, oldfull-diff-1): tree.nodes[i] = tree.nodes[i+diff]
  setLen(tree.nodes, oldfull-diff)

proc remove*(tree: var JsonTree, path: JsonPtr) =
  ## Removes `path`.
  let n = nodePosFromPath(tree, rootNodeId, path)
  if n.isNil: raiseKeyError(path.string)
  rawRemove(tree, NodePos(n.int-2))

template str(n: NodePos): string = tree.atoms[n.litId]
template bval(n: NodePos): bool = n.operand == 1

proc getStr*(tree: JsonTree, path: JsonPtr, default: string = ""): string =
  ## Retrieves the string value of a `JString`.
  ##
  ## Returns `default` if `x` is not a `JString`.
  let n = nodePosFromPath(tree, rootNodeId, path)
  if n.isNil or n.kind != opcodeString: result = default
  else: result = n.str

proc getInt*(tree: JsonTree, path: JsonPtr, default: int = 0): int =
  ## Retrieves the int value of a `JInt`.
  ##
  ## Returns `default` if `x` is not a `JInt`, or if `x` is nil.
  let n = nodePosFromPath(tree, rootNodeId, path)
  if n.isNil or n.kind != opcodeInt: result = default
  else: result = parseInt n.str

proc getBiggestInt*(tree: JsonTree, path: JsonPtr, default: BiggestInt = 0): BiggestInt =
  ## Retrieves the BiggestInt value of a `JInt`.
  ##
  ## Returns `default` if `x` is not a `JInt`, or if `x` is nil.
  let n = nodePosFromPath(tree, rootNodeId, path)
  if n.isNil or n.kind != opcodeInt: result = default
  else: result = parseBiggestInt n.str

proc getFloat*(tree: JsonTree, path: JsonPtr, default: float = 0.0): float =
  ## Retrieves the float value of a `JFloat`.
  ##
  ## Returns `default` if `x` is not a `JFloat` or `JInt`, or if `x` is nil.
  let n = nodePosFromPath(tree, rootNodeId, path)
  if n.isNil: return default
  case n.kind
  of opcodeFloat:
    result = parseFloat n.str
  of opcodeInt:
    result = float(parseBiggestInt n.str)
  else:
    result = default

proc getBool*(tree: JsonTree, path: JsonPtr, default: bool = false): bool =
  ## Retrieves the bool value of a `JBool`.
  ##
  ## Returns `default` if `n` is not a `JBool`, or if `n` is nil.
  let n = nodePosFromPath(tree, rootNodeId, path)
  if n.isNil or n.kind != opcodeBool: result = default
  else: result = n.bval

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

proc storeAtom(tree: var JsonTree; kind: int32; data: string) {.inline.} =
  tree.nodes.add toNode(kind, int32 getOrIncl(tree.atoms, data))

proc parseJson(tree: var JsonTree; p: var JsonParser) =
  case p.tok
  of tkString:
    storeAtom(tree, opcodeString, p.a)
    discard getTok(p)
  of tkInt:
    storeAtom(tree, opcodeInt, p.a)
    discard getTok(p)
  of tkFloat:
    storeAtom(tree, opcodeFloat, p.a)
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
          storeAtom(tree, opcodeString, p.a)
          insertPos.add patchPos
          discard getTok(p)
          eat(p, tkColon)

      template putVal() =
        if insertPos.len > 0 and kind(NodePos insertPos[^1]) == opcodeKeyValuePair:
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

proc escapeJsonUnquoted*(s: string; result: var string) =
  ## Converts a string `s` to its JSON representation without quotes.
  ## Appends to `result`.
  for c in s:
    case c
    of '\L': result.add("\\n")
    of '\b': result.add("\\b")
    of '\f': result.add("\\f")
    of '\t': result.add("\\t")
    of '\v': result.add("\\u000b")
    of '\r': result.add("\\r")
    of '"': result.add("\\\"")
    of '\0'..'\7': result.add("\\u000" & $ord(c))
    of '\14'..'\31': result.add("\\u00" & toHex(ord(c), 2))
    of '\\': result.add("\\\\") #"
    else: result.add(c)

proc escapeJsonUnquoted*(s: string): string =
  ## Converts a string `s` to its JSON representation without quotes.
  result = newStringOfCap(s.len + s.len shr 3)
  escapeJsonUnquoted(s, result)

proc escapeJson*(s: string; result: var string) =
  ## Converts a string `s` to its JSON representation with quotes.
  ## Appends to `result`.
  result.add("\"")
  escapeJsonUnquoted(s, result)
  result.add("\"")

type
  JsonIter = object
    stack: seq[(int32, int32)]
    tos: NodePos
    tosEnd: int
    pos: int

template tosEnd(n: NodePos): int = n.int + tree.nodes[n.int].operand

proc initJsonIter(tree: JsonTree, n: NodePos): JsonIter =
  result = JsonIter(stack: @[], tos: n, tosEnd: n.tosEnd, pos: n.int+1)

proc pushImpl(it: var JsonIter, tree: JsonTree, n: NodePos) =
  it.stack.add (int32 it.tos, int32 it.pos)
  it.tos = n
  it.tosEnd = n.tosEnd
  it.pos = n.int+1

template push(it: JsonIter, n: NodePos) = pushImpl(it, tree, n)

type
  Action = enum
    actionElem, actionKeyVal, actionPop, actionEnd

proc currentAndNext(it: var JsonIter, tree: JsonTree): (NodePos, LitId, Action) =
  if it.pos < it.tosEnd:
    if it.tos.kind == opcodeArray:
      result = (NodePos it.pos, LitId(0), actionElem)
    else:
      let litId = firstSon(NodePos it.pos).litId
      result = (NodePos(it.pos+2), litId, actionKeyVal)
    nextChild tree, it.pos
  elif it.stack.len > 0:
    result = (it.tos, LitId(0), actionPop)
    let tmp = it.stack.pop()
    it.tos = tmp[0].NodePos
    it.pos = tmp[1]
    it.tosEnd = it.tos.tosEnd
  else:
    result = (nilNodeId, LitId(0), actionEnd)

proc toUgly(result: var string, tree: JsonTree, n: NodePos) =
  template key: string = tree.atoms[keyId]

  case n.kind
  of opcodeArray, opcodeObject:
    if n.kind == opcodeArray:
      result.add "["
    else:
      result.add "{"
    var it = initJsonIter(tree, n)
    var pendingComma = false
    while true:
      let (child, keyId, action) = currentAndNext(it, tree)
      case action
      of actionPop:
        if child.kind == opcodeArray:
          result.add "]"
        else:
          result.add "}"
        pendingComma = true
      of actionEnd: break
      of actionElem, actionKeyVal:
        if pendingComma:
          result.add ","
          pendingComma = false
        if action == actionKeyVal:
          key.escapeJson(result)
          result.add ":"
        case child.kind
        of opcodeArray:
          result.add "["
          it.push child
          pendingComma = false
        of opcodeObject:
          result.add "{"
          it.push child
          pendingComma = false
        of opcodeInt, opcodeFloat:
          result.add child.str
          pendingComma = true
        of opcodeString:
          escapeJson(child.str, result)
          pendingComma = true
        of opcodeBool:
          result.add(if child.bval: "true" else: "false")
          pendingComma = true
        of opcodeNull:
          result.add "null"
          pendingComma = true
        else: discard
    if n.kind == opcodeArray:
      result.add "]"
    else:
      result.add "}"
  of opcodeString:
    escapeJson(n.str, result)
  of opcodeInt, opcodeFloat:
    result.add n.str
  of opcodeBool:
    result.add(if n.bval: "true" else: "false")
  of opcodeNull:
    result.add "null"
  else: discard

proc dump*(tree: JsonTree, path: JsonPtr): string =
  result = ""
  let n = nodePosFromPath(tree, rootNodeId, path)
  toUgly(result, tree, n)

proc `$`*(tree: JsonTree): string =
  ## Converts `tree` to its JSON Representation on one line.
  result = newStringOfCap(tree.nodes.len shl 1)
  toUgly(result, tree, rootNodeId)

proc toJson*(s: string; tree: var JsonTree) =
  ## Generic constructor for JSON data. Creates a new `JString JsonNode`.
  storeAtom(tree, opcodeString, s)

proc toJson*(n: BiggestInt; tree: var JsonTree) =
  ## Generic constructor for JSON data. Creates a new `JInt JsonNode`.
  storeAtom(tree, opcodeInt, $n)

proc toJson*(n: float; tree: var JsonTree) =
  ## Generic constructor for JSON data. Creates a new `JFloat JsonNode`.
  storeAtom(tree, opcodeFloat, $n)

proc toJson*(b: bool; tree: var JsonTree) =
  ## Generic constructor for JSON data. Creates a new `JBool JsonNode`.
  tree.nodes.add if b: Node opcodeTrue else: Node opcodeFalse

proc toJson*[T](elements: openArray[T]; tree: var JsonTree) =
  ## Generic constructor for JSON data. Creates a new `JArray JsonNode`
  let patchPos = tree.prepare(opcodeArray)
  for elem in elements:
    toJson(elem, tree)
  tree.patch patchPos

proc toJson*(o: object; tree: var JsonTree) =
  ## Generic constructor for JSON data. Creates a new `JObject JsonNode`
  let patchPos1 = tree.prepare(opcodeObject)
  for k, v in o.fieldPairs:
    let patchPos2 = tree.prepare(opcodeKeyValuePair)
    storeAtom(tree, opcodeString, k)
    toJson(v, tree)
    tree.patch patchPos2
  tree.patch patchPos1

proc toJson*(o: ref object; tree: var JsonTree) =
  ## Generic constructor for JSON data. Creates a new `JObject JsonNode`
  if o.isNil:
    tree.nodes.add Node opcodeNull
  else:
    toJson(o[], tree)

proc toJson*(o: enum; tree: var JsonTree) =
  ## Construct a JsonNode that represents the specified enum value as a
  ## string. Creates a new ``JString JsonNode``.
  toJson($o, tree)

proc toJsonImpl(x, res: NimNode): NimNode =
  template addEmpty(kind, tree): untyped =
    newCall(bindSym"add", newDotExpr(tree, ident"nodes"), newCall(bindSym"Node", kind))

  template prepareCompl(tmp, kind, tree): untyped =
    newLetStmt(tmp, newCall(bindSym"prepare", tree, kind))

  template storeKey(tmp, key, tree): untyped =
    newCall(bindSym"storeAtom", tree, bindSym"opcodeString", key)

  case x.kind
  of nnkBracket: # array
    if x.len == 0: return addEmpty(bindSym"opcodeArray", res)
    let tmp = genSym(nskLet, "tmp")
    result = newStmtList(
        prepareCompl(tmp, bindSym"opcodeArray", res))
    for i in 0 ..< x.len:
      result.add toJsonImpl(x[i], res)
    result.add newCall(bindSym"patch", res, tmp)
  of nnkTableConstr: # object
    if x.len == 0: return addEmpty(bindSym"opcodeObject", res)
    let tmp1 = genSym(nskLet, "tmp")
    result = newStmtList(
        prepareCompl(tmp1, bindSym"opcodeObject", res))
    for i in 0 ..< x.len:
      x[i].expectKind nnkExprColonExpr
      let tmp2 = genSym(nskLet, "tmp")
      result.add prepareCompl(tmp2, bindSym"opcodeKeyValuePair", res)
      result.add storeKey(tmp2, x[i][0], res)
      result.add toJsonImpl(x[i][1], res)
      result.add newCall(bindSym"patch", res, tmp2)
    result.add newCall(bindSym"patch", res, tmp1)
  of nnkCurly: # nil object
    x.expectLen(0)
    result = addEmpty(bindSym"opcodeObject", res)
  of nnkNilLit:
    result = addEmpty(bindSym"opcodeNull", res)
  of nnkPar:
    if x.len == 1: result = toJsonImpl(x[0], res)
    else: result = newCall(bindSym("toJson", brOpen), x, res)
  else:
    result = newCall(bindSym("toJson", brOpen), x, res)

macro `%*`*(x: untyped): untyped =
  ## Convert an expression to a JsonTree directly, without having to specify
  ## `%` for every element.
  let res = genSym(nskVar, "toJsonResult")
  let v = newTree(nnkVarSection,
    newTree(nnkIdentDefs, res, bindSym"JsonTree", newEmptyNode()))
  result = newTree(nnkStmtListExpr, v, toJsonImpl(x, res), res)

proc rawExtract(result: var JsonTree, tree: JsonTree, n: NodePos) =
  let L = span(tree, n.int)
  newSeq(result.nodes, L)
  for i in 0..<L:
    let n = NodePos(i+n.int) # careful
    case n.kind
    of opcodeInt, opcodeFloat, opcodeString:
      result.nodes[i] = toNode(n.kind, int32 getOrIncl(result.atoms, n.str))
    else:
      result.nodes[i] = tree.nodes[n.int]

proc extract*(tree: JsonTree; path: JsonPtr): JsonTree =
  let n = nodePosFromPath(tree, rootNodeId, path)
  if n.isNil: raiseKeyError(path.string)
  rawExtract(result, tree, n)

template ast(n: NodePos): string =
  var dump = ""
  toUgly(dump, tree, n)
  dump

template verifyJsonKind(tree: JsonTree; n: NodePos, kind: JsonNodeKind, kinds: set[JsonNodeKind]) =
  if n == nilNodeId:
    raiseKeyError("key not found: " & n.ast)
  elif kind notin kinds:
    let msg = format("Incorrect JSON kind. Wanted '$1' in '$2' but got '$3'.", kinds, n.ast, kind)
    raise newException(JsonKindError, msg)

proc initFromJson(dst: var string; tree: JsonTree; n: NodePos) =
  verifyJsonKind(tree, n, JsonNodeKind(n.kind), {JString, JNull})
  if n.kind == opcodeNull:
    dst = ""
  else:
    dst = n.str

proc initFromJson(dst: var bool; tree: JsonTree; n: NodePos) =
  verifyJsonKind(tree, n, JsonNodeKind(n.kind), {JBool})
  dst = n.bval

proc initFromJson[T: SomeInteger](dst: var T; tree: JsonTree; n: NodePos) =
  verifyJsonKind(tree, n, JsonNodeKind(n.kind), {JInt})
  when T is BiggestUInt:
    dst = parseBiggestUInt n.str
  elif T is BiggestInt:
    dst = parseBiggestInt n.str
  elif T is SomeSignedInt:
    dst = T(parseInt n.str)
  else:
    dst = T(parseUInt n.str)

when isMainModule:
  include tests/internals
