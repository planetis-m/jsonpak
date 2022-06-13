import packedjson2, random, strutils, times, sequtils

proc main =
  let start = cpuTime()
  var x = %*[]

  for _ in 0 ..< 500_000:
    var alpha = toSeq('a'..'z')
    shuffle(alpha)
    let h = %*{
      "x": rand(1.0),
      "y": rand(1.0),
      "z": rand(1.0),
      "name": alpha[0..4].join & ' ' & $rand(10000),
      "opts": {"1": [1, true]}
    }
    x.add JsonPtr"/-", h
  echo " used Mem: ", formatSize getOccupiedMem(), " time: ", cpuTime() - start, "s"

main()

#[
Results on my machine:

packedjson2:  used Mem: 178.028MiB time: 1.67s
packed json:  used Mem: 62.02MiB   time: 2.56s
stdlib json:  used Mem: 631.353MiB time: 0.823s

]#
