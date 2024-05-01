import std/strutils, private/[jsontree, jsonnode, rawops]

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
  result = 0
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

template copySubStr(buf, src, first, last) =
  buf.setLen(last-first)
  for i in 0..high(buf):
    buf[i] = src[i+first]

proc findNode*(tree: JsonTree, path: string): NodePos =
  var
    cur = ""
    last = 1
    n = rootNodeId

  while last <= len(path):
    var first = last
    while last < len(path) and path[last] != '/':
      inc(last)
    copySubStr(cur, path, first, last)

    case n.kind
    of opcodeObject:
      unescapeJsonPtr(cur)
      n = rawGet(tree, n, cur)
      if n.isNil:
        return nilNodeId
    of opcodeArray:
      if cur == "-" and last < len(path):
        raiseSyntaxError("Invalid usage of '-'")
      let i = getArrayIndex(cur)
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
    copySubStr(cur, path, first, last)

    case n.kind
    of opcodeObject:
      parents.add(n.PatchPos)
      unescapeJsonPtr(cur)
      n = rawGet(tree, n, cur)
      if n.isNil:
        if last < len(path):
          raisePathError(path)
        return PathResult(node: nilNodeId, parents: parents, key: cur)
    of opcodeArray:
      parents.add(n.PatchPos)
      if cur == "-":
        if last < len(path):
          raiseSyntaxError("Invalid usage of '-'")
        return PathResult(node: nilNodeId, parents: parents)
      let i = getArrayIndex(cur)
      if i >= len(tree, n):
        raisePathError(path)
      var pos = n.int + 1
      for j in 0..<i:
        nextChild(tree, pos)
      n = NodePos(pos)
    else:
      raisePathError(path)
    inc(last)

  return PathResult(node: n, parents: parents)
