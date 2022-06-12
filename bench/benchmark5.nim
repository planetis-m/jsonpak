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
      "opts": {"1": [1, true]},
    }
    x.add JsonPtr"/-", h
  echo " used Mem: ", formatSize getOccupiedMem(), " time: ", cpuTime() - start, "s"

main()
