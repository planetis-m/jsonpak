import std/parseutils, ssostrings

proc parseInt*(s: String, number: var int, start = 0): int {.noSideEffect, raises: [ValueError].} =
  parseInt(s.toOpenArray(start, s.high), number)

func parseInt*(s: String): int =
  result = 0
  let L = parseInt(s, result, 0)
  if L != s.len or L == 0:
    raise newException(ValueError, "invalid integer")

proc parseBiggestInt*(s: String, number: var BiggestInt, start = 0): int {.noSideEffect, raises: [ValueError].} =
  parseBiggestInt(s.toOpenArray(start, s.high), number)

func parseBiggestInt*(s: String): BiggestInt =
  result = BiggestInt(0)
  let L = parseBiggestInt(s, result, 0)
  if L != s.len or L == 0:
    raise newException(ValueError, "invalid integer")

proc parseUInt*(s: String, number: var uint, start = 0): int {.noSideEffect, raises: [ValueError].} =
  parseUInt(s.toOpenArray(start, s.high), number)

func parseUInt*(s: String): uint =
  result = uint(0)
  let L = parseUInt(s, result, 0)
  if L != s.len or L == 0:
    raise newException(ValueError, "invalid unsigned integer")

proc parseBiggestUInt*(s: String, number: var BiggestUInt, start = 0): int {.noSideEffect, raises: [ValueError].} =
  parseBiggestUInt(s.toOpenArray(start, s.high), number)

func parseBiggestUInt*(s: String): BiggestUInt =
  result = BiggestUInt(0)
  let L = parseBiggestUInt(s, result, 0)
  if L != s.len or L == 0:
    raise newException(ValueError, "invalid unsigned integer")

proc parseFloat*(s: String, number: var float, start = 0): int {.noSideEffect.} =
  parseFloat(s.toOpenArray(start, s.high), number)

func parseFloat*(s: String): float =
  result = 0.0
  let L = parseFloat(s, result, 0)
  if L != s.len or L == 0:
    raise newException(ValueError, "invalid float")
