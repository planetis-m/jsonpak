import packedjson2, strutils, times

proc main =
  let start = cpuTime()
  var jobj = parseFile("1.json")

  let L = len(jobj, JsonPtr"/coordinates")
  doAssert L == 1000000

  for i in 0..<1000:
    remove(jobj, JsonPtr("/coordinates/" & $i & "/x"))

  echo "used Mem: ", formatSize getOccupiedMem(), " time: ", cpuTime() - start, "s"

main()

#[
Results on my machine:

packedjson2:  used Mem: 386.075MiB time: 14s
packed json:  used Mem: 94.02MiB time: 66s
stdlib json:  used Mem: 1.32GiB time: 2.9s

]#
