## A BiTable is a table that can be seen as an optimized pair
## of (Table[LitId, Val], Table[Val, LitId]).

import std/[hashes, assertions]

type
  LitId* = distinct uint32

  BiTable*[T] = object
    vals: seq[T] # indexed by LitId
    keys: seq[LitId]  # indexed by hash(val)

proc initBiTable*[T](): BiTable[T] = BiTable[T](vals: @[], keys: @[])

proc nextTry(h, maxHash: Hash): Hash {.inline.} =
  result = (h + 1) and maxHash

template maxHash(t): untyped = high(t.keys)
template isFilled(x: LitId): bool = x.uint32 > 0'u32

proc `$`*(x: LitId): string {.borrow.}
proc `<`*(x, y: LitId): bool {.borrow.}
proc `<=`*(x, y: LitId): bool {.borrow.}
proc `==`*(x, y: LitId): bool {.borrow.}
proc hash*(x: LitId): Hash {.borrow.}


proc len*[T](t: BiTable[T]): int = t.vals.len

proc mustRehash(length, counter: int): bool {.inline.} =
  assert(length > counter)
  result = (length * 2 < counter * 3) or (length - counter < 4)

const
  idStart = 2

template idToIdx(x: LitId): int = x.int - idStart

proc hasLitId*[T](t: BiTable[T]; x: LitId): bool =
  let idx = idToIdx(x)
  result = idx >= 0 and idx < t.vals.len

proc enlarge[T](t: var BiTable[T]) =
  var n: seq[LitId]
  newSeq(n, len(t.keys) * 2)
  swap(t.keys, n)
  for i in 0..high(n):
    let eh = n[i]
    if isFilled(eh):
      var j = hash(t.vals[idToIdx eh]) and maxHash(t)
      while isFilled(t.keys[j]):
        j = nextTry(j, maxHash(t))
      t.keys[j] = move n[i]

proc getKeyId*[T](t: BiTable[T]; v: T): LitId =
  let origH = hash(v)
  var h = origH and maxHash(t)
  if t.keys.len != 0:
    while true:
      let litId = t.keys[h]
      if not isFilled(litId): break
      if t.vals[idToIdx t.keys[h]] == v: return litId
      h = nextTry(h, maxHash(t))
  return LitId(0)

proc getOrIncl*[T](t: var BiTable[T]; v: T): LitId =
  let origH = hash(v)
  var h = origH and maxHash(t)
  if t.keys.len != 0:
    while true:
      let litId = t.keys[h]
      if not isFilled(litId): break
      if t.vals[idToIdx t.keys[h]] == v: return litId
      h = nextTry(h, maxHash(t))
    # not found, we need to insert it:
    if mustRehash(t.keys.len, t.vals.len):
      enlarge(t)
      # recompute where to insert:
      h = origH and maxHash(t)
      while true:
        let litId = t.keys[h]
        if not isFilled(litId): break
        h = nextTry(h, maxHash(t))
  else:
    setLen(t.keys, 16)
    h = origH and maxHash(t)

  result = LitId(t.vals.len + idStart)
  t.keys[h] = result
  t.vals.add v


proc `[]`*[T](t: var BiTable[T]; litId: LitId): var T {.inline.} =
  let idx = idToIdx litId
  assert idx < t.vals.len
  result = t.vals[idx]

proc `[]`*[T](t: BiTable[T]; litId: LitId): lent T {.inline.} =
  let idx = idToIdx litId
  assert idx < t.vals.len
  result = t.vals[idx]

proc hash*[T](t: BiTable[T]): Hash =
  ## as the keys are hashes of the values, we simply use them instead
  var h: Hash = 0
  for i, n in pairs t.keys:
    h = h !& hash((i, n))
  result = !$h

when isMainModule:
  proc main =
    block:
      var t: BiTable[string]
      assert t.getOrIncl("hello") == LitId(1)
      assert t.getOrIncl("hello") == LitId(1)
      assert t.getOrIncl("world") == LitId(2)
      assert t.getOrIncl("hello") == LitId(1)
      assert t.getOrIncl("world") == LitId(2)
      assert t.len == 2

    block:
      var t: BiTable[string]
      discard t.getOrIncl("hello")
      discard t.getOrIncl("world")
      assert t.getKeyId("hello") == LitId(1)
      assert t.getKeyId("world") == LitId(2)
      assert t.getKeyId("none") == LitId(0)

    block:
      var t: BiTable[string]
      discard t.getOrIncl("hello")
      discard t.getOrIncl("world")
      assert t.hasLitId(LitId(1)) == true
      assert t.hasLitId(LitId(2)) == true
      assert t.hasLitId(LitId(3)) == false

    block:
      var t: BiTable[string]
      let id1 = t.getOrIncl("hello")
      let id2 = t.getOrIncl("world")
      assert t[id1] == "hello"
      assert t[id2] == "world"

    block:
      var t: BiTable[string]
      for i in 0 ..< 1000:
        discard t.getOrIncl($i)
      assert t.len == 1000

    block:
      var t: BiTable[float]
      let id1 = t.getOrIncl(0.4)
      let id2 = t.getOrIncl(16.4)
      let id3 = t.getOrIncl(32.4)
      assert t.getKeyId(0.4) == id1
      assert t.getKeyId(16.4) == id2
      assert t.getKeyId(32.4) == id3
      assert t.len == 3

  static: main()
  main()
