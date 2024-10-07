import jsonpak, jsonpak/parser, std/assertions

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
      try:
        discard parseJson(data)
        assert false, "Expected JsonParsingError"
      except JsonParsingError:
        assert true

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
