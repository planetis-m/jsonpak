# jsonpak - Yet another JSON library

jsonpak is JSON library that implements the JSON Patch RFC which is specified in
[RFC 6902](https://datatracker.ietf.org/doc/html/rfc5789/) from the IETF.

It uses Packed ASTs for compact and efficient JSON representation. Based on Araq's
[idea](https://github.com/planetis-m/jsonecs/issues/8).

## Documentation

API [documentation](https://planetis-m.github.io/jsonpak/)

For more information visit: <https://jsonpatch.com/> or the linked RFC documents.

### JSON Pointer

```nim

type
  JsonPtr* = distinct string

```

JSON Pointer [(IETF RFC 6901)](https://datatracker.ietf.org/doc/html/rfc6901/) defines a
string format for identifying a specific value within a JSON document. It is used by all
operations in JSON Patch to specify the part of the document to operate on.

A JSON Pointer is a string of tokens separated by `/` characters, these tokens either
specify keys in objects or indexes into arrays. For example, given the JSON

```json

{
  "a": [1, 2, 3],
  "b": 4,
  "c": [5, 6],
  "d": {"e": [7, 8], "f": 9}
}

```

`/d/e` would point to the array of ints `[7, 8]` and `/d/e/0` would point to `7`.

To point to the root of the document use an empty string for the pointer. The pointer
`/` doesn’t point to the root, it points to a key of `""` on the root (which is
totally valid in JSON).

If you need to refer to a key with `~` or `/` in its name, you must escape the
characters with `~0` and `~1` respectively. For example, to get `"baz"` from
`{"foo/bar~": "baz" }` you’d use the pointer `/foo~1bar~0`.

Finally, if you need to refer to the end of an array you can use `-` instead of an
index. For example, to refer to the end of the array above you would use
`/a/-`. This is useful when you need to insert a value at the end of an array.

### Operations

#### Add

```nim

proc add(tree: var JsonTree; path: JsonPtr; value: JsonTree)

```

Adds a value to an object or inserts it into an array. In the case of an array, the value
is inserted before the given index. The `-` character can be used instead of an index to
insert at the end of an array.

#### Remove

```nim

proc remove(tree: var JsonTree; path: JsonPtr)

```

Removes a value from an object or array.

#### Replace

```nim

proc replace(tree: var JsonTree; path: JsonPtr, value: JsonTree)

```

Replaces a value. Equivalent to a `remove` followed by an `add`.

#### Copy

```nim

proc copy(tree: var JsonTree; `from`, path: JsonPtr)

```

Copies a value from one location to another within the JSON document. Both `from` and
`path` are JSON Pointers.

#### Move

```nim

proc move(tree: var JsonTree; `from`, path: JsonPtr)

```

Moves a value from one location to the other. Both `from` and `path` are JSON Pointers.

#### Test

```nim

proc test(tree: JsonTree; path: JsonPtr, value: JsonTree): bool

```

Tests that the specified value is set in the document.

### Misc

```nim

# JsonTree type (import jsonpak, jsonpak/dollar)
proc `==`(a, b: JsonTree): bool
proc isEmpty(tree: JsonTree): bool
proc newEmptyTree(): JsonTree
proc copy(tree: JsonTree): JsonTree
proc `$`(tree: JsonTree): string
# basic usage (import jsonpak/extra)
proc len(tree: JsonTree; path: JsonPtr): int
proc kind(tree: JsonTree; path: JsonPtr): JsonNodeKind
proc contains(tree: JsonTree; path: JsonPtr): bool
proc extract(tree: JsonTree; path: JsonPtr): JsonTree
proc dump(tree: JsonTree; path: JsonPtr): string
# (de)serialize (import jsonpak/[builder, mapper])
proc fromJson[T](tree: JsonTree; path: JsonPtr; t: typedesc[T]): T
proc toJson[T](x: T): JsonTree
macro `%*`(x: untyped): JsonTree
# iterators (import jsonpak/builder)
iterator items[T](tree: JsonTree; path: JsonPtr; t: typedesc[T]): T
iterator pairs[T](tree: JsonTree; path: JsonPtr; t: typedesc[T]): (lent string, T)
# SortedJsonTree type (import jsonpak/sorted)
proc sorted(tree: JsonTree): SortedJsonTree
proc `==`(a, b: SortedJsonTree): bool
proc deduplicate(tree: var SortedJsonTree)

```

### Examples

```nim

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
# {"a":[1,2,3,[5,6]],"b":4,"c":[5,6],"d":{"e":[7,8],"f":9}}

remove x, JsonPtr"/d/e/1"
# {"a":[1,2,3,[5,6]],"b":4,"c":[5,6],"d":{"e":[7],"f":9}}

replace x, JsonPtr"/b", %*"foo"
# {"a":[1,2,3,[5,6]],"b":"foo","c":[5,6],"d":{"e":[7],"f":9}}

copy x, JsonPtr"/b", JsonPtr"/d/f"
# {"a":[1,2,3,[5,6]],"b":"foo","c":[5,6],"d":{"e":[7],"f":"foo"}}

move x, JsonPtr"/c", JsonPtr"/b"
# {"a":[1,2,3,[5,6]],"b":[5,6],"d":{"e":[7],"f":"foo"}}

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
var y = parseJson("""{"b":5,"a":1,"b":{"d":4,"c":2,"d":3}}""").sorted
deduplicate(y)
# {"a": 1, "b": {"c": 2, "d": 3}}

```

## Benchmarks

This section details the average time (in milliseconds) it takes to perform
various operations on a JSON document containing 1,000 entries.

| Op\Lib   | jsonpak  | std/json |
|----------|----------|----------|
| Extract  | 0.2805   | 0.7552   |
| toString | 0.8243   | 0.6683   |
| fromJson | 0.0033   | 0.0009   |
| toJson   | 0.0007   | 0.0005   |
| Parse    | 1.5065   | 1.7205   |
| Test     | 0.0035   | 0.0005   |
| Replace  | 0.0036   | 0.0006   |
| Remove   | 0.0124   | 0.0009   |
| Add      | 0.0035   | 0.0006   |
| Copy     | 0.0120   | 0.0007   |
| Move     | 0.0212   | 0.0011   |

However, the standard library's representation occupies approximately 13.4MiB,
whereas ours only takes up 2.8MiB. Therefore, this library aims to optimize
for space, and further improvements are planned.
