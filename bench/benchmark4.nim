import packedjson2, random, strutils, times

var
  genId: int

proc genTree(r: var Rand; depth: int): JsonTree =
  result = %*{
    "id": genId,
    "active": r.rand(0..1) == 0,
    "name": "node" & $genId,
    "kind": "NODE",
    "kids": []
  }
  inc genId
  if depth > 0:
    for i in 0 .. r.rand(0..3):
      result.add JsonPtr"/kids/-", genTree(r, depth-1)
    for i in 0 .. r.rand(0..3):
      result.add JsonPtr"/kids/-", %*nil

proc main =
  let start = cpuTime()
  var r = initRand(2020)
  let jobj = genTree(r, 15)
  echo genId, " node tree\n used Mem: ", formatSize getOccupiedMem(), " time: ", cpuTime() - start, "s"

main()
