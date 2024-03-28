import std/[json, random, strutils, os]

const
  NumRecords = 1_000
  OutputFile = "test.json"

var data = newJArray()
for i in 1..NumRecords:
  let record = %*{
    "id": i,
    "name": "User" & $i,
    "email": "user" & $i & "@example.com",
    "age": rand(18..65),
    "city": sample(["New York", "London", "Paris", "Tokyo", "Sydney"]),
    "balance": rand(1000..100_000),
    "active": rand(0..1) == 1
  }
  data.add(record)

let jsonData = newJObject()
jsonData["records"] = data

writeFile(OutputFile, $(jsonData))
echo "JSON file generated: ", OutputFile
