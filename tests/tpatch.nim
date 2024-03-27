import std/assertions, jsonpak, jsonpak/[mapper, patch, jsonptr]

proc main =
  var tree = %*{
    "name": "John",
    "age": 30,
    "numbers": [1, 2, 3]
  }

  block: # replace a string value
    var tree = tree
    var newValue = %*"Jane"
    tree.replace(JsonPtr"/name", newValue)
    assert tree == %*{
      "name": "Jane",
      "age": 30,
      "numbers": [1, 2, 3]
    }

  block: # replace an array
    var tree = tree
    var newValue = %*[4, 5]
    tree.replace(JsonPtr"/numbers", newValue)
    assert tree == %*{
      "name": "John",
      "age": 30,
      "numbers": [4, 5]
    }

  block: # replace a non-existing path
    var tree = tree
    var newValue = %*"New York"
    assert:
      try: (tree.replace(JsonPtr"/address", newValue); false)
      except PathError: true

  block: # replace an object
    var tree = tree
    var newValue = %*{"city": "New York"}
    tree.replace(JsonPtr"", newValue)
    assert tree == %*{"city": "New York"}

  tree = %*{
    "a": 1,
    "b": {"c": 2, "d": 3},
    "e": [4, 5, 6],
    "f": nil,
    "g": true
  }

  block:
    var tree = tree
    var newValue = %*7
    tree.replace(JsonPtr"/e/2", newValue)
    assert tree == %*{
      "a": 1,
      "b": {"c": 2, "d": 3},
      "e": [4, 5, 7],
      "f": nil,
      "g": true
    }

  block:
    var tree = tree
    var newValue = %*5
    tree.replace(JsonPtr"/b/c", newValue)
    assert tree == %*{
      "a": 1,
      "b": {"c": 5, "d": 3},
      "e": [4, 5, 6],
      "f": nil,
      "g": true
    }

  block:
    var tree = tree
    var newValue = %*5
    assert:
      try: (tree.replace(JsonPtr"/e/-", newValue); false)
      except PathError: true

  block:
    var tree = tree
    var newValue = %*{"": [10, 11], "g": [12]}
    tree.replace(JsonPtr"/f", newValue)
    assert tree == %*{
      "a": 1,
      "b": {"c": 2, "d": 3},
      "e": [4, 5, 6],
      "f": {"": [10, 11], "g": [12]},
      "g": true
    }

  block:
    var tree = %*{
      "a": 1,
      "b": {"c": 2, "d": 3},
      "e": [4, 5, 6]
    }

    tree.remove(JsonPtr"/b/c")
    assert tree == %*{
      "a": 1,
      "b": {"d": 3},
      "e": [4, 5, 6]
    }

    tree.remove(JsonPtr"/e/1")
    assert tree == %*{
      "a": 1,
      "b": {"d": 3},
      "e": [4, 6]
    }

    tree.remove(JsonPtr"/a")
    assert tree == %*{
      "b": {"d": 3},
      "e": [4, 6]
    }

    assert:
      try: (tree.remove(JsonPtr"/x"); false)
      except PathError: true

    tree.remove(JsonPtr"/e")
    assert tree == %*{
      "b": {"d": 3}
    }

    tree.remove(JsonPtr"")
    assert tree.isEmpty

  block: # add
    var tree = %*{
      "a": 1,
      "b": {"c": 2},
      "d": [3, 4]
    }

    var value1 = %*{"f": 5}
    tree.add(JsonPtr"/b/e", value1)
    assert tree == %*{
      "a": 1,
      "b": {"c": 2, "e": {"f": 5}},
      "d": [3, 4]
    }

    tree = %*{
      "a": {"x": 24, "y": 25},
      "b": {"c": 3, "d": 4},
      "arr": [1, 2, 3, 4],
      "str": "hello"
    }

    block: # test
      assert tree.test(JsonPtr"/a", %*{"x": 24, "y": 25}) == true
      assert tree.test(JsonPtr"/b", %*{"c": 3, "d": 5}) == false
      assert tree.test(JsonPtr"/arr", %*[1, 2, 3, 4]) == true
      assert tree.test(JsonPtr"/str", %*"hello") == true

    block: # replace existing node
      let newValue = %*{"x": 100, "y": 200}
      tree.add(JsonPtr"/a", newValue)
      assert tree.test(JsonPtr"/a", newValue) == true

    block: # add new key-value pair to object
      let newValue = %*{"e": 5}
      tree.add(JsonPtr"/b", newValue)
      assert tree.test(JsonPtr"/b", %*{"e": 5}) == true

    block: # add new element to array
      let newValue = %*5
      tree.add(JsonPtr"/arr/2", newValue)
      assert tree.test(JsonPtr"/arr", %*[1, 2, 5, 3, 4]) == true

    block: # add new element to the end of array
      let newValue = %*5
      tree.add(JsonPtr"/arr/-", newValue)
      assert tree.test(JsonPtr"/arr", %*[1, 2, 5, 3, 4, 5]) == true

    block: # add new node to root
      let newValue = %*{"new": "value"}
      tree.add(JsonPtr"", newValue)
      assert tree.test(JsonPtr"/new", %*"value") == true

    tree = %*{
      "a": {"x": 24, "y": 25},
      "b": {"c": 3, "d": 4, "e": 5},
      "arr": [1, 2, 3, 4],
      "str": "hello"
    }

    block: # copy existing node to a new location
      var tree = tree
      tree.copy(JsonPtr"/a", JsonPtr"/copied")
      assert tree.test(JsonPtr"/copied", %*{"x": 24, "y": 25}) == true

    block: # copy existing node to replace another node
      var tree = tree
      tree.copy(JsonPtr"/a", JsonPtr"/b")
      assert tree.test(JsonPtr"/b", %*{"x": 24, "y": 25}) == true

    block: # copy existing node to a new element in an array
      var tree = tree
      tree.copy(JsonPtr"/a", JsonPtr"/arr/2")
      assert tree.test(JsonPtr"/arr", %*[1, 2, {"x": 24, "y": 25}, 3, 4]) == true

    block: # copy existing node to the end of an array
      var tree = tree
      tree.copy(JsonPtr"/a", JsonPtr"/arr/-")
      assert tree.test(JsonPtr"/arr", %*[1, 2, 3, 4, {"x": 24, "y": 25}]) == true

    block: # copy existing node to the root
      var tree = tree
      tree.copy(JsonPtr"/a", JsonPtr"")
      assert tree.test(JsonPtr"", %*{"x": 24, "y": 25}) == true

    block: # copy a child node to its parent
      var tree = tree
      tree.copy(JsonPtr"/a/x", JsonPtr"/a")
      assert tree.test(JsonPtr"/a", %*24) == true

    block: # copy a node to itself
      var tree = tree
      tree.copy(JsonPtr"/a", JsonPtr"/a")
      assert tree.test(JsonPtr"/a", %*{"x": 24, "y": 25}) == true

    block: # copy array element to a new location
      var tree = tree
      tree.copy(JsonPtr"/arr/0", JsonPtr"/copied_element")
      assert tree.test(JsonPtr"/copied_element", %*1) == true

    block: # copy array element to replace another element
      var tree = tree
      tree.copy(JsonPtr"/arr/0", JsonPtr"/arr/1")
      assert tree.test(JsonPtr"/arr", %*[1, 1, 2, 3, 4]) == true

    block: # copy non-existing node (should raise PathError)
      try:
        tree.copy(JsonPtr"/non_existing", JsonPtr"/copied")
        assert false, "Expected PathError"
      except PathError:
        assert true

    block: # copy parent to child (should raise PathError)
      try:
        tree.copy(JsonPtr"/a", JsonPtr"/a/x")
        assert false, "Expected PathError"
      except PathError:
        assert true

    block: # move existing node to the root
      var tree = tree
      tree.move(JsonPtr"/a", JsonPtr"")
      assert tree.test(JsonPtr"", %*{"x": 24, "y": 25}) == true

    block: # move a child node to its parent
      var tree = tree
      tree.move(JsonPtr"/a/x", JsonPtr"/a")
      assert tree.test(JsonPtr"", %*{"a":24,"b":{"c":3,"d":4,"e":5},"arr":[1,2,3,4],"str":"hello"})

    block: # move array element to a new location
      var tree = tree
      tree.move(JsonPtr"/arr/0", JsonPtr"/copied_element")
      assert tree.test(JsonPtr"",
        %*{"a":{"x":24,"y":25},"b":{"c":3,"d":4,"e":5},"arr":[2,3,4],"str":"hello","copied_element":1})

    block: # move existing node to the end of an array
      var tree = tree
      tree.move(JsonPtr"/a", JsonPtr"/arr/-")
      assert tree.test(JsonPtr"",
        %*{"b":{"c":3,"d":4,"e":5},"arr":[1,2,3,4,{"x":24,"y":25}],"str":"hello"})

    block: # move existing node to replace another node
      var tree = tree
      tree.move(JsonPtr"/b", JsonPtr"/a/x")
      assert tree.test(JsonPtr"",
        %*{"a":{"x":{"c":3,"d":4,"e":5},"y":25},"arr":[1,2,3,4],"str":"hello"})

    block: # move existing node to replace another node
      var tree = tree
      tree.move(JsonPtr"/b/e", JsonPtr"/a/y")
      assert tree.test(JsonPtr"",
        %*{"a":{"x":24,"y":5},"b":{"c":3,"d":4},"arr":[1,2,3,4],"str":"hello"})

static: main()
main()
