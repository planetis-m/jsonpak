# To be included by main!
block:
  let data = """{"a":[1,false,{"key":[4,5]},4]}"""
  let x = parseJson(data)
  assert not x.isEmpty
  assert x.atoms.len == 5
  assert kind(x, jRoot) == JObject
  assert get(x, jRoot, "a") == JsonNode 3
  assert hasKey(x, jRoot, "a")
  assert x.nodes[1].kind == opcodeKeyValuePair
  assert x.nodes[1].operand == 12
  assert get(x, JsonNode 6, "key") == JsonNode 9
  assert hasKey(x, JsonNode 6, "key")
  assert not hasKey(x, JsonNode 6, "a")
  assert x.nodes[7].kind == opcodeKeyValuePair
  assert x.nodes[7].operand == 5
  assert kind(x, JsonNode 9) == JArray
  assert get(x, JsonNode 9, 1) == JsonNode 11
  assert kind(x, JsonNode 5) == JBool
  assert getBool(x, JsonNode 5) == false
  assert kind(x, JsonNode 4) == JInt
  assert getInt(x, JsonNode 4) == 1
  assert kind(x, JsonNode 11) == JInt
  assert getInt(x, JsonNode 11) == 5
  assert get(x, jRoot, "a", "key") == jNull
  assert get(x, JsonNode 3, 2) == JsonNode 6
  assert get(x, jRoot, "b", "key") == jNull
  assert get(x, JsonNode 3, 2, 1) == jNull
  assert $x == data

block:
  let data = """{"a":{"key":[4,[1,2,3]]}}"""
  let x = parseJson(data)
  assert not x.isEmpty
  assert x.atoms.len == 6
  assert kind(x, jRoot) == JObject
  assert get(x, jRoot, "a", "key") == JsonNode 6
  assert get(x, JsonNode 6, 1, 2) == JsonNode 11
  for k, v in pairs(x, jRoot):
    assert k == "a"
    assert kind(x, v) == JObject
  assert $x == data

block:
  let data = """{"a":0,"key":[4,[1,2,3]],"b":{"a":false}}"""
  var x = parseJson(data)
  assert $x == data
  assert not x.isEmpty
  assert x.atoms.len == 8
  assert hasKey(x, jRoot, "a")
  assert hasKey(x, jRoot, "key")
  delete(x, jRoot, "a")
  assert not hasKey(x, jRoot, "a")
  assert hasKey(x, jRoot, "key")
  assert kind(x, jRoot) == JObject
  assert kind(x, JsonNode 3) == JArray
