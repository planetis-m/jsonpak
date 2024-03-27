import jsonpak, jsonpak/[mapper, sorted]

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
    echo tree.JsonTree
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

static: main()
main()
