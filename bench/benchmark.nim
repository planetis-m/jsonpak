import packedjson2, strutils, times

type
  Coordinate = tuple[x, y, z: float]

proc main =
  let start = cpuTime()
  let jobj = parseFile("1.json")

  let L = len(jobj, JsonPtr"/coordinates").float
  doAssert L == 1000000
  var x = 0.0
  var y = 0.0
  var z = 0.0

  for coord in items(jobj, JsonPtr"/coordinates", Coordinate):
    x += coord.x
    y += coord.y
    z += coord.z

  echo x / L
  echo y / L
  echo z / L
  echo "used Mem: ", formatSize getOccupiedMem(), " time: ", cpuTime() - start, "s"

main()

#[
Results on my machine:

packedjson2:  used Mem: 386.075MiB time: 2.82s
packed json:  used Mem: 94.02MiB time: 2.0s
stdlib json:  used Mem: 1.32GiB time: 3.07s

]#
