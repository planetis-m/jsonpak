import packedjson2, random, strutils, times

var
  genId: int

proc genTree(r: var Rand; depth: int): JsonTree =
  let id = genId
  inc genId
  result = %*{
    "id": id,
    "active": r.rand(1.0) > 0.98,
    "name": "node" & $id,
    "kind": "NODE",
    if r.rand(1.0) > 0.98:
      "kids": [genTree(r, depth-1), genTree(r, depth-1), nil, nil]
    else:
      "kids": [genTree(r, depth-1), nil, nil, nil]
  }

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
