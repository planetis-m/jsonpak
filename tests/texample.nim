import jsonpak, jsonpak/[patch, parser, jsonptr, extra, builder, mapper, sorted, dollar]

var x = %*{
  "a": [1, 2, 3],
  "b": 4,
  "c": [5, 6],
  "d": {"e": [7, 8], "f": 9}
}

# Basic usage
assert len(x, JsonPtr"") == 4
assert contains(x, JsonPtr"/a")
assert kind(x, JsonPtr"/a") == JArray

add x, JsonPtr"/a/-", %*[5, 6]
assert x == %*{"a":[1,2,3,[5,6]],"b":4,"c":[5,6],"d":{"e":[7,8],"f":9}}

remove x, JsonPtr"/d/e/1"
assert x == %*{"a":[1,2,3,[5,6]],"b":4,"c":[5,6],"d":{"e":[7],"f":9}}

replace x, JsonPtr"/b", %*"foo"
assert x == %*{"a":[1,2,3,[5,6]],"b":"foo","c":[5,6],"d":{"e":[7],"f":9}}

copy x, JsonPtr"/b", JsonPtr"/d/f"
assert x == %*{"a":[1,2,3,[5,6]],"b":"foo","c":[5,6],"d":{"e":[7],"f":"foo"}}

move x, JsonPtr"/c", JsonPtr"/b"
assert x == %*{"a":[1,2,3,[5,6]],"b":[5,6],"d":{"e":[7],"f":"foo"}}

# Comparing, copying, deserializing
assert test(x, JsonPtr"/d", %*{"e": [7], "f": "foo"})
assert $extract(x, JsonPtr"/d") == """{"e":[7],"f":"foo"}"""
assert fromJson(x, JsonPtr"/a/3", seq[int]) == @[5, 6]
assert toJson(@[5, 6]) == extract(x, JsonPtr"/b")
# Iterating
for i in items(x, JsonPtr"/b", int): echo i, " "
# 5 6
for k, v in pairs(x, JsonPtr"/d", JsonTree): echo (k, v), " "
# ("e", [7]) ("f", "foo")

# Sorting, deduplicating
var y = parseJson("""{"a": 1, "b": 2, "a": 3}""").sorted
deduplicate(y)
assert y == SortedJsonTree(%*{"a": 3, "b": 2})
