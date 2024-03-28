import std/[times, strutils, strformat, stats]
import std/json except `%*`
import jsonpak, jsonpak/[patch, parser, jsonptr, mapper]

const
  SmallJson = """{"records":[{"id":1,"name":"User1","email":"user1@example.com","age":65,"city":"Sydney","balance":37341,"active":true}]}"""

  MediumJson = """
{"records":[
{"id":1,"name":"User1","email":"user1@example.com","age":65,"city":"Sydney","balance":37341,"active":true},
{"id":2,"name":"User2","email":"user2@example.com","age":50,"city":"London","balance":6093,"active":true},
{"id":3,"name":"User3","email":"user3@example.com","age":36,"city":"Paris","balance":54558,"active":false},
{"id":4,"name":"User4","email":"user4@example.com","age":28,"city":"New York","balance":40909,"active":true},
{"id":5,"name":"User5","email":"user5@example.com","age":58,"city":"New York","balance":1661,"active":true},
{"id":6,"name":"User6","email":"user6@example.com","age":53,"city":"Sydney","balance":55950,"active":false},
{"id":7,"name":"User7","email":"user7@example.com","age":53,"city":"London","balance":23837,"active":true},
{"id":8,"name":"User8","email":"user8@example.com","age":56,"city":"London","balance":63526,"active":false},
{"id":9,"name":"User9","email":"user9@example.com","age":28,"city":"Sydney","balance":16882,"active":false},
{"id":10,"name":"User10","email":"user10@example.com","age":62,"city":"Paris","balance":43109,"active":false},
{"id":11,"name":"User11","email":"user11@example.com","age":37,"city":"Sydney","balance":73798,"active":false},
{"id":12,"name":"User12","email":"user12@example.com","age":52,"city":"Tokyo","balance":96326,"active":true},
{"id":13,"name":"User13","email":"user13@example.com","age":50,"city":"New York","balance":56423,"active":true},
{"id":14,"name":"User14","email":"user14@example.com","age":54,"city":"Sydney","balance":63254,"active":false},
{"id":15,"name":"User15","email":"user15@example.com","age":48,"city":"Tokyo","balance":85866,"active":false}]}
"""

  LargeJson = readFile("large.json")

const
  N = 10_000

proc printStats(name: string, stats: RunningStat, dur: float) =
  echo &"""{name}:
  Collected {stats.n} samples in {dur:>4.4f} s
  Average time: {stats.mean * 1000:>4.4f} ms
  Stddev  time: {stats.standardDeviationS * 1000:>4.4f} ms
  Min     time: {stats.min * 1000:>4.4f} ms
  Max     time: {stats.max * 1000:>4.4f} ms"""

template bench(name, tree, code: untyped) =
  var stats: RunningStat
  let globalStart = cpuTime()
  for i in 1..N:
    var t {.inject.} = copy(tree)
    let start = cpuTime()
    code
    let duration = cpuTime() - start
    stats.push duration
  let globalDuration = cpuTime() - globalStart
  printStats(name, stats, globalDuration)

type
  JsonSize = enum
    small, medium, large

proc main(s: JsonSize) =
  var
    stdTree: JsonNode
    tree: JsonTree

  case s
  of small:
    tree = parser.parseJson(SmallJson)
    stdTree = json.parseJson(SmallJson)
  of medium:
    tree = parser.parseJson(MediumJson)
    stdTree = json.parseJson(MediumJson)
  of large:
    tree = parser.parseJson(LargeJson)
    stdTree = json.parseJson(LargeJson)

  bench "test", tree:
    discard test(t, JsonPtr"/records/0/age", %*30)

  bench "replace", tree:
    replace(t, JsonPtr"/records/0/age", %*31)

  bench "remove", tree:
    remove(t, JsonPtr"/records/0/city")

  bench "add", tree:
    add(t, JsonPtr"/records/0/email", %*"john@example.com")

  bench "copy", tree:
    copy(t, JsonPtr"/records/0/age", JsonPtr"/records/0/newAge")

  bench "move", tree:
    move(t, JsonPtr"/records/0/city", JsonPtr"/records/0/location")

  # Repeat the benchs for medium and large JSON trees

  # Benchmarks for std/json module
  bench "stdlib - contains", stdTree:
    discard stdTree.contains("age")

  bench "replace", stdTree.copy():
    t["records"][0]["age"] = %31

  bench "delete", stdTree.copy():
    t["records"][0].delete("city")

  bench "add", stdTree.copy():
    t["records"][0]["email"] = %"john@example.com"

main(large)
