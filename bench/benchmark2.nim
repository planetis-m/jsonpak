import random, times, strutils, deques, sets, hashes
import ".." / packedjson2

proc hash(x: JsonNode): Hash =
  result = hash(x.int32)

proc breadthFirstSearch(tree: JsonTree; source: JsonNode; name: string): JsonNode =
  template `[]`(n: JsonNode, name: string): untyped = get(tree, n, name)
  template items(n: JsonNode): untyped = items(tree, n)
  template getStr(n: JsonNode): untyped = getStr(tree, n)

  var queue: Deque[JsonNode]
  queue.addLast(source)

  var visited: HashSet[JsonNode]
  visited.incl(source)

  while queue.len > 0:
    let node = queue.popFirst()
    if kind(tree, node) == JObject:
      if node["really_long_variable_name"].getStr == name:
        return node
      for kid in items(node["really_long_variable_kids"]):
        if kid notin visited:
          queue.addLast(kid)
          visited.incl(kid)
  result = jNull

proc main =
  template `$`(n: JsonNode): untyped =
    (var result = ""; toUgly(result, jobj, n); result)

  let start = cpuTime()
  let jobj = parseFile("2.json")
  echo $breadthFirstSearch(jobj, jRoot, "node1611092")
  echo "used Mem: ", formatSize getOccupiedMem(), " time: ", cpuTime() - start, "s"

main()
