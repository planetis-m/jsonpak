import packedjson2, strutils, times

proc main =
  let start = cpuTime()
  let jobj = parseFile("1.json")

  let coordinates = get(jobj, jRoot, "coordinates")
  let len = 1000000.float #float(coordinates.len)
  #doAssert coordinates.len == 1000000
  var x = 0.0
  var y = 0.0
  var z = 0.0

  for coord in items(jobj, coordinates):
    x += getFloat(jobj, get(jobj, coord, "x"))
    y += getFloat(jobj, get(jobj, coord, "y"))
    z += getFloat(jobj, get(jobj, coord, "z"))

  echo x / len
  echo y / len
  echo z / len
  echo "used Mem: ", formatSize getOccupiedMem(), " time: ", cpuTime() - start, "s"

main()

#[
Results on my machine:

packedjson2:  used Mem: 386.075MiB time: 3.522s
packed json:  used Mem: 94.02MiB time: 2.734s
stdlib json:  used Mem: 1.32GiB time: 4.337s

]#
