import packedjson2, strutils, times

proc main =
  template `[]`(n, name): untyped = get(jobj, n, name)
  template items(n): untyped = items(jobj, n)
  template getFloat(n): untyped = getFloat(jobj, n)
  template len(n): untyped = len(jobj, n)

  let start = cpuTime()
  let jobj = parseFile("1.json")

  let coordinates = jRoot["coordinates"]
  let L = float(coordinates.len)
  doAssert L == 1000000
  var x = 0.0
  var y = 0.0
  var z = 0.0

  for coord in items(coordinates):
    x += coord["x"].getFloat
    y += coord["y"].getFloat
    z += coord["z"].getFloat

  echo x / L
  echo y / L
  echo z / L
  echo "used Mem: ", formatSize getOccupiedMem(), " time: ", cpuTime() - start, "s"

main()

#[
Results on my machine:

packedjson2:  used Mem: 386.075MiB time: 3.522s
packed json:  used Mem: 94.02MiB time: 2.734s
stdlib json:  used Mem: 1.32GiB time: 4.337s

]#
