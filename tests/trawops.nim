import jsonpak/mapper, jsonpak/private/[bitabs, rawops, jsonnode, jsontree]
from jsonpak import `==`

proc main =
  block: # nested objects
    let data = %*{"a": {"x": 24, "y": 25}, "b": {"c": 3, "d": 4}}
    var tree: JsonTree
    rawExtract(tree, data, NodePos 0)
    assert tree == %*{"a": {"x": 24, "y": 25}, "b": {"c": 3, "d": 4}}
    rawExtract(tree, data, NodePos 2)
    assert tree == %*{"x": 24, "y": 25}
    rawExtract(tree, data, NodePos 8)
    assert tree == %*{"c": 3, "d": 4}

  # Hard to test effectively on it's own
  # block: # rawAdd
  #   var tree1 = %*{"a": 1, "b": 2}
  #   var tree2 = %*{"c": 3, "d": 4}
  #   rawAdd(tree1, tree2, NodePos 0)
  #   assert tree1 == tree2
  #   var tree3 = %*5
  #   rawAdd(tree1, tree3, NodePos 4)
  #   assert tree1 == %*{"c": 3, "d": 5}
  #   reset(tree1)
  #   rawAdd(tree1, tree2, NodePos 0)
  #   assert tree1 == tree2

  block:
    let tree = %*{
      "a": 1,
      "b": {"c": 2, "d": 3},
      "e": [4, 5, 6],
      "f": nil,
      "g": true
    }
    # get existing key
    var n = tree.rawGet(rootNodeId, "a")
    assert n.kind == opcodeInt
    assert n.str == "1"
    # get non-existing key
    n = tree.rawGet(rootNodeId, "x")
    assert n == nilNodeId
    # get key in nested object
    var parent = tree.rawGet(rootNodeId, "b")
    n = tree.rawGet(parent, "c")
    assert n.kind == opcodeInt
    assert n.str == "2"
    # get key in array
    parent = tree.rawGet(rootNodeId, "e")
    n = tree.rawGet(parent, "0")
    assert n == nilNodeId
    # get null value
    n = tree.rawGet(rootNodeId, "f")
    assert n.kind == opcodeNull
    # get bool value"
    n = tree.rawGet(rootNodeId, "g")
    assert n.kind == opcodeBool
    assert n.bval == true

  block: # comparing equal trees
    let tree1 = %*{"b": {"d": 4, "c": 3}, "a": {"y": 25, "x": 24}}
    let tree2 = %*{"a": {"x": 24, "y": 25}, "b": {"c": 3, "d": 4}}
    assert tree1 == tree2

  block: # comparing unequal trees
    let tree1 = %*{"a": 1, "b": 2}
    let tree2 = %*{"a": 1, "b": 3}
    assert tree1 != tree2

static: main()
main()
