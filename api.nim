
type
  JsonPtr* = distinct string

proc add*(x: var JsonTree; path: JsonPtr; value: sink JsonTree)
proc remove*(x: var JsonTree; path: JsonPtr)
proc replace*(x: var JsonTree; path: JsonPtr, value: sink JsonTree)
proc copy*(x: var JsonTree; `from`, path: JsonPtr)
proc move*(x: var JsonTree; `from`, path: JsonPtr)
proc test*(x: JsonTree; path: JsonPtr, value: JsonTree): bool

var x = %*{
  "a": [1, 2, 3],
  "b": 4,
  "c": [5, 6],
  "d": {"e": [7, 8], "f": 9}
}

add x, JsonPtr"/a/-", %*[5, 6]
# """{"a":[1,2,3,[5,6]],"b":4,"c":[5,6],"d":{"e":[7,8],"f":9}}"""

remove x, JsonPtr"/d/e/1"
# """{"a":[1,2,3,[5,6]],"b":4,"c":[5,6],"d":{"e":[7],"f":9}}"""

replace x, JsonPtr"/b", %*"foo"
# """{"a":[1,2,3,[5,6]],"b":"foo","c":[5,6],"d":{"e":[7],"f":9}}"""

copy x, JsonPtr"/b", JsonPtr"/d/f"
# """{"a":[1,2,3,[5,6]],"b":"foo","c":[5,6],"d":{"e":[7],"f":"foo"}}"""

move x, JsonPtr"/c", JsonPtr"/b"
# """{"a":[1,2,3,[5,6]],"b":[5,6],"d":{"e":[7],"f":"foo"}}"""

assert test(x, JsonPtr"/d", %*{"e": [7], "f": "foo"})

proc fromJson*[T](x: JsonTree; path: JsonPtr; t: typedesc[T]): T
proc toJson*[T](x: T): JsonTree

# iterators
iterator items*(x: JsonTree; path: JsonPtr; t: typedesc[T]): T
iterator pairs*(x: JsonTree; path: JsonPtr; t: typedesc[T]): (lent string, T)

# Extra
proc len*(x: JsonTree; path: JsonPtr): int
proc kind*(x: JsonTree; path: JsonPtr): JsonNodeKind
proc hasKey*(tree: JsonTree; path: JsonPtr; key: string): bool
proc extract*(x: JsonTree; path: JsonPtr): JsonTree
#proc hash*(x: JsonTree): Hash

assert len(x, JsonPtr"/b") == 2
assert kind(x, JsonPtr"/d/e") == JArray
assert hasKey(x, JsonPtr"", "d")
assert $extract(x, JsonPtr"/d") == """{"e":[7],"f":"foo"}"""

# recursive iterators
iterator itemsRec*(x: JsonTree; path: JsonPtr; t: typedesc[T]): T
iterator pairsRec*(x: JsonTree; path: JsonPtr; t: typedesc[T]): (lent string, T)

# Examples
type
  Coordinate = tuple[x: float, y: float, z: float]

let jobj = parseFile("1.json")

let L = len(jobj, JsonPtr"/coordinates").float
var x = 0.0
var y = 0.0
var z = 0.0

for coord in items(jobj, JsonPtr"/coordinates", Coordinate):
  x += coord.x
  y += coord.y
  z += coord.z

const left = %*{
  "coordinates":[{"x":2.0,"y":0.5,"z":0.25}]
}
assert test(left, JsonPtr"", %*{"coordinates":[{"y":0.5,"x":2.0,"z":0.25}]})
