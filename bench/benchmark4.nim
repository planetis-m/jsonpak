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
    #var arr = %*[]
    for i in 0 .. r.rand(0..3):
      #arr.add JsonPtr"/-", genTree(r, depth-1)
      result.add JsonPtr"/kids/-", genTree(r, depth-1)
    for i in 0 .. r.rand(0..3):
      #arr.add JsonPtr"/-", %*nil
      result.add JsonPtr"/kids/-", %*nil
    #result.replace JsonPtr"/kids", arr

proc main =
  let start = cpuTime()
  var r = initRand(2020)
  let jobj = genTree(r, 15)
  echo genId, " node tree\n used Mem: ", formatSize getOccupiedMem(), " time: ", cpuTime() - start, "s"

main()

#[
Results on my machine:

packedjson2:  used Mem: 315.735MiB time: 9.21s
packed json:  used Mem: 84.02MiB   time: 7.4s
stdlib json:  used Mem: 1.265GiB   time: 1.18s

]#
