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

proc add(x: var JsonTree; path: JsonPtr; value: JsonTree)

```

Adds a value to an object or inserts it into an array. In the case of an array, the value
is inserted before the given index. The `-` character can be used instead of an index to
insert at the end of an array.

#### Remove

```nim

proc remove(x: var JsonTree; path: JsonPtr)

```

Removes a value from an object or array.

#### Replace

```nim

proc replace(x: var JsonTree; path: JsonPtr, value: JsonTree)

```

Replaces a value. Equivalent to a `remove` followed by an `add`.

#### Copy

```nim

proc copy(x: var JsonTree; `from`, path: JsonPtr)

```

Copies a value from one location to another within the JSON document. Both `from` and
`path` are JSON Pointers.

#### Move

```nim

proc move(x: var JsonTree; `from`, path: JsonPtr)

```

Moves a value from one location to the other. Both `from` and `path` are JSON Pointers.

#### Test

```nim

proc test(x: JsonTree; path: JsonPtr, value: JsonTree): bool

```

Tests that the specified value is set in the document.

### Misc

```nim

# JsonTree type
proc `==`*(a, b: JsonTree): bool
proc newEmptyTree*(): JsonTree
proc copy*(tree: JsonTree): JsonTree
# basic usage
proc len(x: JsonTree; path: JsonPtr): int
proc kind(x: JsonTree; path: JsonPtr): JsonNodeKind
proc contains(x: JsonTree; path: JsonPtr): bool
proc extract(x: JsonTree; path: JsonPtr): JsonTree
# (de)serialize
proc fromJson[T](x: JsonTree; path: JsonPtr; t: typedesc[T]): T
proc toJson[T](x: T): JsonTree
macro %*(x: untyped): JsonTree
# iterators
iterator items(x: JsonTree; path: JsonPtr; t: typedesc[T]): T
iterator pairs(x: JsonTree; path: JsonPtr; t: typedesc[T]): (lent string, T)

```

### Examples

```nim

import jsonpak, jsonpak/[patch, jsonptr, extra, builder, mapper, dollar]

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
# """{"a":[1,2,3,[5,6]],"b":4,"c":[5,6],"d":{"e":[7,8],"f":9}}"""

remove x, JsonPtr"/d/e/1"
# """{"a":[1,2,3,[5,6]],"b":4,"c":[5,6],"d":{"e":[7],"f":9}}"""

replace x, JsonPtr"/b", %*"foo"
# """{"a":[1,2,3,[5,6]],"b":"foo","c":[5,6],"d":{"e":[7],"f":9}}"""

copy x, JsonPtr"/b", JsonPtr"/d/f"
# """{"a":[1,2,3,[5,6]],"b":"foo","c":[5,6],"d":{"e":[7],"f":"foo"}}"""

move x, JsonPtr"/c", JsonPtr"/b"
# """{"a":[1,2,3,[5,6]],"b":[5,6],"d":{"e":[7],"f":"foo"}}"""

# Comparing, copying, deserializing
assert test(x, JsonPtr"/d", %*{"e": [7], "f": "foo"})
assert $extract(x, JsonPtr"/d") == """{"e":[7,8],"f":9}"""
assert fromJson(x, JsonPtr"/d/e", seq[int]) == @[7, 8]
assert toJson(@[1, 2, 3]) == extract(x, JsonPtr"/a")
# Iterating
for x in items(x, JsonPtr"/a", int): echo x, " "
# 1 2 3
for k, v in pairs(x, JsonPtr"/d", JsonTree): echo (k, v), " "
# ("e", [7, 8]) ("f", 9)

```

## Benchmarks

This section details the average time (in milliseconds) it takes to perform
various operations on a JSON document containing 1,000 entries.

| Library  | Extract | Parse   | Test   | Replace | Remove | Add    | Copy   | Move   |
|----------|---------|---------|--------|---------|--------|--------|--------|--------|
| jsonpak  | 0.2900  | 1.5065  | 0.0035 | 0.0036  | 0.0124 | 0.0035 | 0.0120 | 0.0212 |
| std/json | 0.7394  | 1.7205  | 0.0005 | 0.0006  | 0.0009 | 0.0006 | 0.0007 | 0.0011 |

However, the standard library's representation occupies approximately 13.4MiB,
whereas ours only takes up 2.8MiB. Therefore, this library aims to optimize
for space, and further improvements are planned.
