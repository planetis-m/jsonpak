import jsonpak, jsonpak/[mapper, sorted, parser]

proc main =
  block: # empty object
    let data = %*{}
    let tree = sorted(data)
    assert tree == SortedJsonTree(%*{})

  block: # object with one key
    let data = %*{"a": 1}
    let tree = sorted(data)
    assert tree == SortedJsonTree(%*{"a": 1})

  block: # object with multiple keys
    let data = %*{"c": 3, "a": 1, "b": 2}
    let tree = sorted(data)
    assert tree == SortedJsonTree(%*{"a": 1, "b": 2, "c": 3})

  block: # nested objects
    let data = %*{"b": {"d": 4, "c": 3}, "a": {"y": 25, "x": 24}}
    let tree = sorted(data)
    assert tree == SortedJsonTree(%*{"a": {"x": 24, "y": 25}, "b": {"c": 3, "d": 4}})

  block: # array
    let data = %*[3, 1, 2]
    let tree = sorted(data)
    assert tree == SortedJsonTree(%*[3, 1, 2])

  block: # nested arrays
    let data = %*[[3, 1, 2], [6, 4, 5]]
    let tree = sorted(data)
    assert tree == SortedJsonTree(%*[[3, 1, 2], [6, 4, 5]])

  block: # object with array
    let data = %*{"b": [3, 1, 2], "a": 0}
    let tree = sorted(data)
    assert tree == SortedJsonTree(%*{"a": 0, "b": [3, 1, 2]})

  block: # object with null
    let data = %*{"b": nil, "a": 0}
    let tree = sorted(data)
    assert tree == SortedJsonTree(%*{"a": 0, "b": nil})

  block: # object with bool
    let data = %*{"b": false, "a": true}
    let tree = sorted(data)
    assert tree == SortedJsonTree(%*{"a": true, "b": false})

  block: # comparing equal trees
    let data1 = %*{"b": {"d": 4, "c": 3}, "a": {"y": 25, "x": 24}}
    let tree1 = sorted(data1)
    let data2 = %*{"a": {"x": 24, "y": 25}, "b": {"c": 3, "d": 4}}
    let tree2 = sorted(data2)
    assert tree1 == tree2

  block: # comparing unequal trees
    let data1 = %*{"a": 1, "b": 2}
    let tree1 = sorted(data1)
    let data2 = %*{"a": 1, "b": 3}
    let tree2 = sorted(data2)
    assert tree1 != tree2

  block:
    var tree = sorted(%*{"b": {"d": 4, "d": 3}, "a": {"y": 25, "x": 24}})
    deduplicate(tree)
    assert tree == SortedJsonTree(%*{"a": {"x": 24, "y": 25}, "b": {"d": 3}})

  block:
    var tree = sorted(%*{"a": 1, "b": 2, "a": 3})
    deduplicate(tree)
    assert tree == SortedJsonTree(%*{"a": 3, "b": 2})

  block:
    var tree = sorted(%*{"a": {"x": 1, "y": 2}, "b": {"x": 3, "y": 4}, "a": {"x": 5, "y": 6}})
    deduplicate(tree)
    assert tree == SortedJsonTree(%*{"a": {"x": 5, "y": 6}, "b": {"x": 3, "y": 4}})

  block:
    var tree = sorted(%*{"a": [1, 2, 3], "b": [4, 5, 6], "a": [7, 8, 9]})
    deduplicate(tree)
    assert tree == SortedJsonTree(%*{"a": [7, 8, 9], "b": [4, 5, 6]})

  block:
    var tree = sorted(%*[{"a": 1, "b": 2, "a": 3}, 1, {"a": 4, "b": 5, "a": 6}])
    deduplicate(tree)
    assert tree == SortedJsonTree(%*[{"a": 3, "b": 2}, 1, {"a": 6, "b": 5}])

  block:
    var tree = sorted(%*{
      "a": {
        "b": {
          "c": 1,
          "d": 2
        },
        "e": 3,
        "b": {
          "c": 1,
          "d": 2,
          "c": 3,
        }
      },
      "a": {
        "b": {
          "c": 4,
          "d": 5
        },
        "e": 6
      }
    })
    deduplicate(tree)
    assert tree == SortedJsonTree(%*{
      "a": {
        "b": {
          "c": 4,
          "d": 5
        },
        "e": 6
      }
    })

  block:
    var tree = sorted(%*{
      "a": {
        "b": {
          "c": {
            "d": 1,
            "e": 2,
            "d": 3
          }
        }
      }
    })
    deduplicate(tree)
    assert tree == SortedJsonTree(%*{
      "a": {
        "b": {
          "c": {
            "d": 3,
            "e": 2
          }
        }
      }
    })

  block:
    var tree = sorted(%*{
      "a": {
        "b": 1,
        "c": 2,
        "b": 3,
        "d": 4,
        "c": 5
      }
    })
    deduplicate(tree)
    assert tree == SortedJsonTree(%*{
      "a": {
        "b": 3,
        "c": 5,
        "d": 4
      }
    })

  block:
    var tree = sorted(%*{
      "a": {
        "b": 1,
        "c": 2,
        "b": 3,
        "d": 4,
        "c": 5
      },
      "a": {
        "b": 1,
        "c": 2,
        "b": 3,
        "b": 4,
        "d": 5,
        "c": 6
      }
    })
    deduplicate(tree)
    assert tree == SortedJsonTree(%*{
      "a": {
        "b": 4,
        "c": 6,
        "d": 5
      }
    })

  block:
    let tree1 = sorted(%*{"a": 1, "b": 2, "c": 3})
    let tree2 = sorted(%*{"c": 3, "a": 1, "b": 2})
    assert hash(tree1) == hash(tree2)

  block: # object with duplicate keys
    var tree1 = sorted(%*{"a": 1, "b": 2, "a": 3})
    deduplicate(tree1)
    let tree2 = SortedJsonTree(%*{"a": 3, "b": 2})
    assert hash(tree1) == hash(tree2)

  block:
    let tree1 = SortedJsonTree(%*{"a": 1, "b": "2", "c": 3})
    let tree2 = SortedJsonTree(%*{"a": "1", "b": 2, "c": "3"})
    assert hash(tree1) != hash(tree2)

  block: # object with arrays in different order
    let tree1 = SortedJsonTree(%*{"a": [1, 2, 3], "b": [4, 5, 6]})
    let tree2 = SortedJsonTree(%*{"a": [4, 5, 6], "b": [1, 2, 3]})
    assert hash(tree1) != hash(tree2)

  block: # deeply nested objects
    let tree1 = SortedJsonTree(%*{"a": {"b": {"c": {"d": 2}}}})
    let tree2 = SortedJsonTree(%*{"a": {"b": {"c": {"d": 1}}}})
    assert hash(tree1) != hash(tree2)

  block: # object with empty arrays and objects
    let tree1 = SortedJsonTree(%*{"a": {}, "b": {}})
    let tree2 = SortedJsonTree(%*{"a": [], "b": []})
    assert hash(tree1) != hash(tree2)

  block: # object with different float representations (scientific notation)
    let tree1 = parseJson("""{"a": 1.0, "b": 2.0, "c": 3.0}""").SortedJsonTree
    let tree2 = parseJson("""{"a": 1e0, "b": 2e0, "c": 3e0}""").SortedJsonTree
    assert hash(tree1) == hash(tree2)

  block: # object with different float representations (trailing zeros)
    let tree1 = parseJson("""{"a": 1.0, "b": 2.0, "c": 3.0}""").SortedJsonTree
    let tree2 = parseJson("""{"a": 1.00000, "b": 2.00000, "c": 3.00000}""").SortedJsonTree
    assert hash(tree1) == hash(tree2)

  block: # object with different float representations (leading zeros)
    let tree1 = parseJson("""{"a": 1.0, "b": 2.0, "c": 3.0}""").SortedJsonTree
    let tree2 = parseJson("""{"a": 01.0, "b": 02.0, "c": 03.0}""").SortedJsonTree
    assert hash(tree1) == hash(tree2)

static: main()
main()
