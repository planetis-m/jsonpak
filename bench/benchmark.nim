import std/[times, strutils, strformat, stats]
import std/json except `%*`
import jsonpak, jsonpak/[patch, parser, jsonptr, mapper]

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
  var stats: RunningStat
  let globalStart = cpuTime()
  for i in 1..NumIters:
    var t {.inject.} = copy(tree)
    let start = cpuTime()
    code
    let duration = cpuTime() - start
    stats.push duration
  let globalDuration = cpuTime() - globalStart
  printStats(name, stats, globalDuration)

proc main() =
  var
    stdTree = json.parseJson(JsonData)
    tree = parser.parseJson(JsonData)

  bench "test", tree:
    discard test(t, JsonPtr"/records/500/age", %*30)

  bench "replace", tree:
    replace(t, JsonPtr"/records/500/age", %*31)

  bench "remove", tree:
    remove(t, JsonPtr"/records/500/city")

  bench "add", tree:
    add(t, JsonPtr"/records/500/email", %*"john@example.com")

  bench "copy", tree:
    copy(t, JsonPtr"/records/500/age", JsonPtr"/records/0/newAge")

  bench "move", tree:
    move(t, JsonPtr"/records/500/city", JsonPtr"/records/0/location")

  # Benchmarks for std/json module
  bench "stdlib - test", stdTree:
    discard t["records"][500]["age"] == %30

  bench "stdlib - replace", stdTree:
    t["records"][500]["age"] = %31

  bench "stdlib - delete", stdTree:
    t["records"][500].delete("city")

  bench "stdlib - add", stdTree:
    t["records"][500]["email"] = %"john@example.com"

  bench "stdlib - copy", stdTree:
    t["records"][500]["newAge"] = t["records"][0]["age"]

  bench "stdlib - move", stdTree:
    t["records"][500]["location"] = t["records"][0]["city"]
    t["records"][0].delete("city")

main()
echo "used Mem: ", formatSize getOccupiedMem()
