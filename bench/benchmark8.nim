import packedjson2, strutils, times

type
  Coordinate = tuple[x, y, z: float]

proc walk(tree: JsonTree; L: var int; path: var string; coord: var Coordinate) =
  inc L
  if kind(tree, JsonPtr(path)) == JObject:
    let c = fromJson(tree, JsonPtr(path), Coordinate)
    coord.x += c.x
    coord.y += c.y
    coord.z += c.z
    path.add "/kid"
    walk(tree, L, path, coord)

proc main =
  let jobj = parseFile("3.json")
  let start = cpuTime()
  var L = 0
  var coord: Coordinate
  var path = newStringOfCap(40004)
  walk(jobj, L, path, coord)
  echo "used Mem: ", formatSize getOccupiedMem(), " time: ", cpuTime() - start, "s"
  echo coord.x / L.float
  echo coord.y / L.float
  echo coord.z / L.float
  echo L

main()
