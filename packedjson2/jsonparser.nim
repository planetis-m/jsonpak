import std/[parsejson, streams], jsontree, jsonnode
export JsonParsingError

proc parseJsonAtom(tree: var JsonTree; p: var JsonParser) =
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
    storeAtom(tree, opcodeTrue)
    discard getTok(p)
  of tkFalse:
    storeAtom(tree, opcodeFalse)
    discard getTok(p)
  of tkNull:
    storeAtom(tree, opcodeNull)
    discard getTok(p)
  else: discard

proc parseJsonCompound(tree: var JsonTree; p: var JsonParser) =
  var insertPos: seq[PatchPos] = @[]
  var commaExpected, foundComma = false
  while true:
    if insertPos.len > 0 and
        kind(NodePos insertPos[^1]) == opcodeObject and p.tok != tkCurlyRi:
      if p.tok != tkString:
        raiseParseErr(p, "string literal as key")
      else:
        storeAtom(tree, opcodeString, p.a)
        discard getTok(p)
        eat(p, tkColon)

    case p.tok
    of tkString, tkInt, tkFloat, tkTrue, tkFalse, tkNull:
      if commaExpected: raiseParseErr(p, ",")
      foundComma = false
      parseJsonAtom(tree, p)
      if p.tok == tkComma:
        discard getTok(p)
        foundComma = true
      else: commaExpected = true
    of tkCurlyLe:
      if commaExpected: raiseParseErr(p, ",")
      foundComma = false
      insertPos.add tree.prepare(opcodeObject)
      discard getTok(p)
    of tkBracketLe:
      if commaExpected: raiseParseErr(p, ",")
      foundComma = false
      insertPos.add tree.prepare(opcodeArray)
      discard getTok(p)
    of tkCurlyRi:
      if insertPos.len > 0 and kind(NodePos insertPos[^1]) == opcodeObject:
        if foundComma: raiseParseErr(p, "}")
        commaExpected = false
        tree.patch insertPos.pop()
        discard getTok(p)
        if insertPos.len == 0: break
      else:
        raiseParseErr(p, "{")
      if p.tok == tkComma:
        discard getTok(p)
        foundComma = true
      else: commaExpected = true
    of tkBracketRi:
      if insertPos.len > 0 and kind(NodePos insertPos[^1]) == opcodeArray:
        if foundComma: raiseParseErr(p, "]")
        commaExpected = false
        tree.patch insertPos.pop()
        discard getTok(p)
        if insertPos.len == 0: break
      else:
        raiseParseErr(p, "{")
      if p.tok == tkComma:
        discard getTok(p)
        foundComma = true
      else: commaExpected = true
    else:
      raiseParseErr(p, "{")

proc parseJson(tree: var JsonTree; p: var JsonParser) =
  case p.tok
  of tkString, tkInt, tkFloat, tkTrue, tkFalse, tkNull:
    parseJsonAtom(tree, p)
  of tkCurlyLe, tkBracketLe:
    parseJsonCompound(tree, p)
  of tkError, tkCurlyRi, tkBracketRi, tkColon, tkComma, tkEof:
    raiseParseErr(p, "{")

proc parseJson*(s: Stream, filename: string = ""): JsonTree =
  ## Parses from a stream `s` into a `JsonNode`. `filename` is only needed
  ## for nice error messages.
  ## If `s` contains extra data, it will raise `JsonParsingError`.
  result = JsonTree()
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
  result = parseJson(newStringStream(buffer), "input")

proc parseFile*(filename: string): JsonTree =
  ## Parses `file` into a `JsonNode`.
  ## If `file` contains extra data, it will raise `JsonParsingError`.
  var stream = newFileStream(filename, fmRead)
  if stream == nil:
    raise newException(IOError, "cannot read from file: " & filename)
  result = parseJson(stream, filename)

when isMainModule:
  import std/assertions

  proc main =
    block:
      let invalid = [
        "{\"a\"}", "{\"a\":[}", "{", "[false", "{[]}", "[,]", "{:}", "  ", "",
        "{a: \"value\"}", "{\"a\": value}",
        """{"a": "value" "b": "value"}""",
        """[1, 2 3]""",
        """[{} 2]""",
        """{"a": [] "b": 2}""",
        """{"a": "value",}""",
        """[1, 2, 3,]""",
        """[1, {},]""",
        """{"a": 1, "b": [],}""",
        """{"a": "value", "b", "c": "value"}""",
        """{"a": 0123, "b": 1.2.3, "c": 1e+}""",
        """{"a": "value1"} {"b": "value2"}""",
        """{"a": undefined, "b": NaN, "c": Infinity}"""
      ]
      for data in items(invalid):
        assert:
          try: (discard parseJson(data); false)
          except JsonParsingError: true

      let valid = [
        "\"a\"", "[]", "{}", "[[{}]]", "false",
        """{"a": null, "b": [null, null]}""",
        """{"a": 123456789012345678901234567890, "b": -987654321098765432109876543210}""",
        """[true, false, null, {"a": true, "b": false, "c": null}]""",
        """{"a": "This is a \"quoted\" string with \\ backslashes and \/ slashes and \b backspaces and \f form feeds and \n new lines and \r carriage returns and \t tabs and \u1234 unicode."}""",
        """{"a":{"b":{"c":{"d":{"e":{"f":{"g":{"h":{"i":{"j":{"k":{"l":{"m":{"n":{"o":{"p":{"q":{"r":{"s":{"t":{"u":{"v":{"w":{"x":{"y":{"z":1}}}}}}}}}}}}}}}}}}}}}}}}}}""",
        """{"a": 1.23e+100, "b": 4.56e-100}""",
        """{"a":[1,2,3],"b":{"c":4,"d":5}}""",
        """{"a"  :  [1 ,2  ,3] ,  "b":  {"c" :4,  "d":5  }  }""",
        """{"a": {}, "b": {"c": []}, "d": [{}]}""",
      ]
      for data in items(valid):
        let tree = parseJson(data)
        assert not tree.isEmpty

      let data = """null"""
      let tree = parseJson(data)
      assert tree.isEmpty

  static: main()
  main()
