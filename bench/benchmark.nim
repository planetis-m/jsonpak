import std/[times, strutils, strformat, stats]
import std/json except `%*`
import jsonpak, jsonpak/[extra, patch, parser, jsonptr, mapper, builder, sorted]
import packedjson except `%`

const
  JsonData = readFile("test.json")
  NumIters = 10_000

proc printStats(name: string, stats: RunningStat, dur: float) =
  echo &"""{name}:
  Collected {stats.n} samples in {dur:>4.4f} s
  Average time: {stats.mean * 1000:>4.4f} ms
  Stddev  time: {stats.standardDeviationS * 1000:>4.4f} ms
  Min     time: {stats.min * 1000:>4.4f} ms
  Max     time: {stats.max * 1000:>4.4f} ms"""

template bench(name, tree, code: untyped) =
  var stats = RunningStat()
  let globalStart = cpuTime()
  for i in 1..NumIters:
    var t {.inject.} = copy(tree)
    let start = cpuTime()
    code
    let duration = cpuTime() - start
    stats.push duration
  let globalDuration = cpuTime() - globalStart
  printStats(name, stats, globalDuration)

import std/tables

proc sort(n: json.JsonNode) =
  ## Sort a JSON node
  case n.kind
  of JArray:
    for e in mitems(n.elems):
      sort(e)
  of JObject:
    sort(n.fields, proc (x, y: (string, json.JsonNode)): int = cmp[string](x[0], y[0]))
    for k, v in mpairs(n.fields):
      sort(v)
  else: discard

type
  UserRecord = object
    id: int
    name, email: string
    age: int
    city: string
    balance: int
    active: bool

proc main() =
  var
    stdTree = json.parseJson(JsonData)
    tree = parser.parseJson(JsonData)
    packedTree = packedjson.parseJson(JsonData)

  bench "extract", newEmptyTree():
    t = extract(tree, JsonPtr"")

  bench "parse", newEmptyTree():
    t = parser.parseJson(JsonData)

  bench "toString", tree:
    discard $t

  bench "fromJson", tree:
    discard fromJson(t, JsonPtr"/records/500", UserRecord)

  bench "toJson", newEmptyTree():
    t = toJson(UserRecord(id:1,name:"User1",email:"user1@example.com",age:65,city:"Sydney",balance:37341,active:false))

  bench "test", tree:
    discard test(t, JsonPtr"/records/500/age", mapper.`%*`30)

  bench "replace", tree:
    replace(t, JsonPtr"/records/500/age", mapper.`%*`31)

  bench "remove", tree:
    remove(t, JsonPtr"/records/500/city")

  bench "add", tree:
    add(t, JsonPtr"/records/500/email", mapper.`%*`"john@example.com")

  bench "copy", tree:
    copy(t, JsonPtr"/records/500/age", JsonPtr"/records/0/newAge")

  bench "move", tree:
    move(t, JsonPtr"/records/500/city", JsonPtr"/records/0/location")

  bench "sort", newEmptyTree().SortedJsonTree:
    t = sorted(tree)

  tree = jsonpak.JsonTree(sorted(tree))
  bench "hash", tree:
    discard hash(t.SortedJsonTree)

  # Benchmarks for std/json module
  bench "stdlib - extract", json.JsonNode():
    t = stdTree.copy()

  bench "stdlib - parse", json.JsonNode():
    t = json.parseJson(JsonData)

  bench "stdlib - toString", stdTree:
    discard $t

  bench "stdlib - hash", stdTree:
    discard hash(t)

  bench "stdlib - fromJson", stdTree:
    discard t["records"][500].to(UserRecord)

  bench "stdlib - toJson", json.JsonNode():
    t = json.`%`UserRecord(id:1,name:"User1",email:"user1@example.com",age:65,city:"Sydney",balance:37341,active:false)

  bench "stdlib - test", stdTree:
    discard t["records"][500]["age"] == json.`%`30

  bench "stdlib - replace", stdTree:
    t["records"][500]["age"] = json.`%`31

  bench "stdlib - remove", stdTree:
    t["records"][500].delete("city")

  bench "stdlib - add", stdTree:
    t["records"][500]["email"] = json.`%`"john@example.com"

  bench "stdlib - copy", stdTree:
    t["records"][500]["newAge"] = t["records"][0]["age"]

  bench "stdlib - move", stdTree:
    t["records"][500]["location"] = t["records"][0]["city"]
    t["records"][0].delete("city")

  bench "stdlib - sort", stdTree:
    t.sort

  # Benchmarks for packedjson module
  bench "packedjson - parse", packedjson.newJNull():
    t = packedjson.parseJson(JsonData)

  bench "packedjson - extract", packedjson.newJNull():
    t = packedTree.copy()

  bench "packedjson - toString", packedTree:
    discard $t

  bench "packedjson - hash", packedTree:
    discard hash(t)

  bench "packedjson - test", packedTree:
    discard t["records"][500]["age"] == packedjson.newJInt(30)

  bench "packedjson - replace", packedjson.JsonTree(packedTree):
    let rec = t["records"]
    var user = packedjson.JsonTree(rec[500])
    user["age"] = packedjson.newJInt(31)

  bench "packedjson - remove", packedjson.JsonTree(packedTree):
    let rec = t["records"]
    var user = packedjson.JsonTree(rec[500])
    user.delete("city")

  bench "packedjson - add", packedjson.JsonTree(packedTree):
    let rec = t["records"]
    var user = packedjson.JsonTree(rec[500])
    user["email"] = packedjson.newJString("john@example.com")

  bench "packedjson - copy", packedjson.JsonTree(packedTree):
    let rec = t["records"]
    var user = packedjson.JsonTree(rec[500])
    user["newAge"] = t["records"][0]["age"]

  bench "packedjson - move", packedjson.JsonTree(packedTree):
    let rec = t["records"]
    var rec0 = packedjson.JsonTree(rec[0])
    var rec500 = packedjson.JsonTree(rec[500])
    rec500["location"] = rec0["city"]
    rec0.delete("city")

  echo "used Mem: ", formatSize getOccupiedMem()

main()
