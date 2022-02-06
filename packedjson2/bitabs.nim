## A BiTable is a table that can be seen as an optimized pair
## of (Table[LitId, Val], Table[Val, LitId]).

import std/hashes

const
  defaultInitialSize = 64
  growthFactor = 2

type
  LitId* = distinct uint32

  Key = tuple[hcode: int32, key: LitId] # kept together to improve cache locality
  BiTable*[T] = object
    vals: seq[T] # indexed by LitId
    keys: seq[Key] # indexed by hash(val)

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
  idStart = 1

template idToIdx(x: LitId): int = x.int - idStart

proc hasLitId*[T](t: BiTable[T]; x: LitId): bool =
  let idx = idToIdx(x)
  result = idx >= 0 and idx < t.vals.len

proc enlarge[T](t: var BiTable[T]) =
  var n: seq[Key]
  newSeq(n, len(t.keys) * growthFactor)
  swap(t.keys, n)
  for i in 0..high(n):
    let eh = n[i]
    if isFilled(eh.key):
      var j = eh.hcode and maxHash(t)
      while isFilled(t.keys[j].key):
        j = nextTry(j, maxHash(t))
      t.keys[j] = move n[i]

proc getKeyId*[T](t: BiTable[T]; v: T): LitId =
  let origH = hash(v)
  var h = origH and maxHash(t)
  if t.keys.len != 0:
    while true:
      let litId = t.keys[h].key
      if not isFilled(litId): break
      if t.keys[h].hcode == cast[int32](origH) and
          t.vals[idToIdx litId] == v: return litId
      h = nextTry(h, maxHash(t))
  return LitId(0)

proc getOrIncl*[T](t: var BiTable[T]; v: T): LitId =
  let origH = hash(v)
  var h = origH and maxHash(t)
  if t.keys.len != 0:
    while true:
      let litId = t.keys[h].key
      if not isFilled(litId): break
      if t.keys[h].hcode == cast[int32](origH) and
          t.vals[idToIdx litId] == v: return litId
      h = nextTry(h, maxHash(t))
    # not found, we need to insert it:
    if mustRehash(t.keys.len, t.vals.len):
      enlarge(t)
      # recompute where to insert:
      h = origH and maxHash(t)
      while true:
        let litId = t.keys[h].key
        if not isFilled(litId): break
        h = nextTry(h, maxHash(t))
  else:
    setLen(t.keys, defaultInitialSize)
    h = origH and maxHash(t)

  result = LitId(t.vals.len + idStart)
  t.keys[h].key = result
  t.keys[h].hcode = cast[int32](origH) # downcast Hash in order to save space
  t.vals.add v

proc `[]`*[T](t: var BiTable[T]; LitId: LitId): var T {.inline.} =
  let idx = idToIdx LitId
  assert idx >= 0 and idx < t.vals.len
  result = t.vals[idx]

proc `[]`*[T](t: BiTable[T]; LitId: LitId): lent T {.inline.} =
  let idx = idToIdx LitId
  assert idx >= 0 and idx < t.vals.len
  result = t.vals[idx]

when isMainModule:

  var t: BiTable[string]

  echo getOrIncl(t, "hello")

  echo getOrIncl(t, "hello")
  echo getOrIncl(t, "hello3")
  echo getOrIncl(t, "hello4")
  echo getOrIncl(t, "helloasfasdfdsa")
  echo getOrIncl(t, "hello")
  echo getKeyId(t, "hello")
  echo getKeyId(t, "none")

  for i in 0 ..< 100_000:
    discard t.getOrIncl($i & "___" & $i)

  for i in 0 ..< 100_000:
    assert t.getOrIncl($i & "___" & $i).idToIdx == i + 4
  echo "begin"
  echo t.vals.len

  echo t.vals[0]
  echo t.vals[1004]

  echo "middle"

  var tf: BiTable[float]

  discard tf.getOrIncl(0.4)
  discard tf.getOrIncl(16.4)
  discard tf.getOrIncl(32.4)
  echo getKeyId(tf, 32.4)
