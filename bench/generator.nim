import std/[random, strutils, times], jsonpak, jsonpak/[mapper, patch, jsonptr, dollar]

const
  NumRecords = 1_000
  OutputFile = "test.json"

proc main =
  let start = cpuTime()
  var data = %*{"records":[]}
  for i in 1..NumRecords:
    let record = %*{
      "id": i,
      "name": "User" & $i,
      "email": "user" & $i & "@example.com",
      "age": rand(18..65),
      "city": sample(["New York", "London", "Paris", "Tokyo", "Sydney"]),
      "balance": rand(1000..100_000),
      "active": rand(bool)
    }
    data.add(JsonPtr"/records/-", record)

  writeFile(OutputFile, $data)
  echo " used Mem: ", formatSize getOccupiedMem(), " time: ", cpuTime() - start, "s"

main()
