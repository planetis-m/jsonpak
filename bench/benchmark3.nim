include ".." / packedjson2
import strutils
import std/[times, stats, strformat]

const MaxIter = 1_000_000

proc printStats(name: string, stats: RunningStat, dur: float) =
  echo &"""{name}:
  Collected {stats.n} samples in {dur:>4.4f} s
  Average time: {stats.mean * 1000:>4.4f} ms
  Stddev  time: {stats.standardDeviationS * 1000:>4.4f} ms
  Min     time: {stats.min * 1000:>4.4f} ms
  Max     time: {stats.max * 1000:>4.4f} ms"""

template bench(name, samples, code: untyped) =
  var stats: RunningStat
  let globalStart = cpuTime()
  for i in 0 ..< samples:
    let start = cpuTime()
    code
    let duration = cpuTime() - start
    stats.push duration
  let globalDuration = cpuTime() - globalStart
  printStats(name, stats, globalDuration)

proc getRoot(tree: JsonTree; n: NodePos): NodePos =
  var pos = n.parent
  while pos > rootNodeId:
    pos = pos.parent
  return pos

proc tGet(tree: JsonTree, n: NodePos, key: string): NodePos =
  if n.isNil or n.kind != opcodeObject: return nilNodeId
  result = rawGet(tree, n, key)

proc tGet(tree: JsonTree, n: NodePos, index: int): NodePos =
  if n.isNil or n.kind != opcodeArray: return nilNodeId
  var i = index
  for x in sonsReadonly(tree, n):
    if i == 0: return x
    dec i
  result = nilNodeId

macro traverse(tree: JsonTree, n: NodePos, keys: varargs[typed]): NodePos =
  ## Traverses the tree and gets the given value.
  result = newNimNode(nnkStmtListExpr)
  let res = genSym(nskVar, "tResult")
  result.add newVarStmt(res, n)
  for kk in keys:
    result.add newAssignment(res, newCall(bindSym"tGet", tree, res, kk))
  result.add(res)

proc test =
  let jobj = parseFile("3.json")
  var result: NodePos
  bench("posFromPtr", MaxIter):
    var tmp = rootNodeId
    result = posFromPtr(jobj, JsonPtr"/kids/kids/kids/kids/kids/kids/kids/kids/kids/kids/kids/kids/kids/kids/kids/kids/kids/kids", tmp)
  echo result.int
  bench("traverse", MaxIter):
    result = traverse(jobj, rootNodeId, "kids", "kids", "kids", "kids", "kids", "kids", "kids", "kids", "kids", "kids", "kids", "kids", "kids", "kids", "kids", "kids", "kids", "kids")
  echo result.int
  let tmp = result
  bench("parent", MaxIter):
    result = tmp
    result = getRoot(jobj, result)
  echo result.int

test()
