import std/strutils, jsontree, jsonnode, jsonops

type
  JsonPtr* = distinct string

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

  PathError* = object of JsonPtrError
  UsageError* = object of JsonPtrError
  SyntaxError* = object of JsonPtrError

proc raisePathError*(path: string) {.noinline.} =
  raise newException(PathError, "path not found: " & path)

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

proc getArrayIndex(token: string): int =
  if len(token) == 0:
    raiseSyntaxError(token)
  if token == "-":
    return -1
  if token[0] == '0' and len(token) > 1:
    raiseSyntaxError(token)
  try:
    result = parseInt(token)
    if result < 0:
      raiseSyntaxError(token)
  except ValueError:
    raiseSyntaxError(token)

template copyTokenToBuffer(buf, src, first, last) =
  buf.setLen(last-first)
  when nimvm:
    for i in 0..high(buf):
      buf[i] = src[i+first]
  else:
    if first < last: copyMem(cstring(buf), addr src[first], buf.len)

proc findNode*(tree: JsonTree, path: string): NodePos =
  var
    cur = ""
    last = 1
    n = rootNodeId

  while last <= len(path):
    var first = last
    while last < len(path) and path[last] != '/':
      inc(last)
    copyTokenToBuffer(cur, path, first, last)

    case n.kind
    of opcodeObject:
      unescapeJsonPtr(cur)
      n = rawGet(tree, n, cur)
      if n.isNil:
        return nilNodeId
    of opcodeArray:
      if cur == "-" and last < len(path):
        raiseSyntaxError("Invalid usage of '-'")
      var i = getArrayIndex(cur)
      if i < 0 or i >= len(tree, n):
        return nilNodeId
      var pos = n.int + 1
      for j in 0..<i:
        nextChild(tree, pos)
      n = NodePos(pos)
    else:
      return nilNodeId
    inc(last)

  return n

type
  PathResult* = object
    node*: NodePos
    parents*: seq[PatchPos]
    key*: string

proc findNodeMut*(tree: JsonTree, path: string): PathResult =
  var
    cur = ""
    last = 1
    n = rootNodeId
    parents: seq[PatchPos] = @[]

  while last <= len(path):
    var first = last
    while last < len(path) and path[last] != '/':
      inc(last)
    copyTokenToBuffer(cur, path, first, last)

    case n.kind
    of opcodeObject:
      parents.add(n.PatchPos)
      unescapeJsonPtr(cur)
      n = rawGet(tree, n, cur)
      if n.isNil:
        return PathResult(node: nilNodeId, parents: parents, key: cur)
    of opcodeArray:
      parents.add(n.PatchPos)
      if cur == "-":
        if last < len(path):
          raiseSyntaxError("Invalid usage of '-'")
        return PathResult(node: nilNodeId, parents: parents)
      var i = getArrayIndex(cur)
      if i >= len(tree, n):
        return PathResult(node: nilNodeId, parents: parents)
      var pos = n.int + 1
      for j in 0..<i:
        nextChild(tree, pos)
      n = NodePos(pos)
    else:
      raisePathError(path)
    inc(last)

  return PathResult(node: n, parents: parents)

when isMainModule:
  import std/assertions, jsonmapper

  proc main =
    block:
      var s = "hello~world/foo"
      s = escapeJsonPtr(s)
      assert s == "hello~0world~1foo"

    block:
      var s = "hello~0world~1foo"
      unescapeJsonPtr(s)
      assert s == "hello~world/foo"

    block:
      assert getArrayIndex("0") == 0
      assert getArrayIndex("123") == 123
      assert getArrayIndex("-") == -1
      assert:
        try: (discard getArrayIndex(""); false)
        except SyntaxError: true
      assert:
        try: (discard getArrayIndex("01"); false)
        except SyntaxError: true
      assert:
        try: (discard getArrayIndex("-1"); false)
        except SyntaxError: true

    block:
      let tree = %*{"foo": {"bar": nil}, "arr": [1, 2]}
      assert findNode(tree, "/foo/bar") == NodePos(4)
      assert findNode(tree, "/foo/baz") == nilNodeId
      assert findNode(tree, "/arr/0") == NodePos(7)
      assert findNode(tree, "/arr/1") == NodePos(8)
      assert findNode(tree, "/arr/-") == nilNodeId
      assert findNode(tree, "/arr/100") == nilNodeId

    block:
      let tree = %*{"foo": {"bar": nil}, "arr": [1, 2]}
      var res = findNodeMut(tree, "/foo/bar")
      assert res.node == NodePos(4)
      assert res.parents == @[PatchPos(0), PatchPos(2)]
      res = findNodeMut(tree, "/arr/-")
      assert res.node == nilNodeId
      assert res.parents == @[PatchPos(0), PatchPos(6)]
      assert res.key == ""
      res = findNodeMut(tree, "/foo/baz")
      assert res.key == "baz"

  static: main()
  main()
