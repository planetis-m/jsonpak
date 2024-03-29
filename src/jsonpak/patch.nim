import private/[jsontree, jsonnode, rawops], jsonptr, std/[algorithm, sequtils, importutils]

proc test*(tree: JsonTree; path: JsonPtr, value: JsonTree): bool =
  ## Tests that a value at the target location is
  ## equal to a specified value.
  ##
  ## `value` conveys the value to be compared to the `path`'s value.
  ##
  ## The `path`'s value must be equal to `value` for the
  ## operation to be considered successful.
  privateAccess(JsonTree)
  let n = findNode(tree, path.string)
  if n.isNil:
    raisePathError(path.string)
  if span(tree, n.int) != value.nodes.len:
    return false
  rawTest(tree, value, n, rootNodeId)

proc replace*(tree: var JsonTree, path: JsonPtr, value: JsonTree) =
  ## Replaces the value at the target location with a new value.
  ## `value` specifies the replacement value.
  ##
  ## `path` must exist for the operation to be successful.
  ##
  ## This operation is functionally identical to a `remove`,
  ## followed immediately by an `add` at the same
  ## location with the replacement value.
  privateAccess(JsonTree)
  # Find the target node
  let res = findNodeMut(tree, path.string)
  if res.node.isNil:
    raisePathError(path.string)
  # Replace the value at the target node
  let diff = span(value, 0) - span(tree, res.node.int)
  rawReplace(tree, value, res.node)
  # Update the operands of the parent nodes
  rawUpdateParents(tree, res.parents, diff)

proc remove*(tree: var JsonTree, path: JsonPtr) =
  ## Removes the value at the target location.
  ##
  ## `path` must exist for the operation to be successful.
  ##
  ## If removing an element from an array, any elements above the
  ## specified index are shifted one position to the left.
  privateAccess(JsonTree)
  # Find the target node
  let res = findNodeMut(tree, path.string)
  if res.node.isNil:
    raisePathError(path.string)
  # Remove the target node
  var startPos, diff = 0
  if res.parents.len > 0 and res.parents[^1].NodePos.kind == opcodeObject:
    startPos = res.node.int - 1
    diff = -1 - span(tree, res.node.int)
  else:
    startPos = res.node.int
    diff = -span(tree, res.node.int)
  let endPos = startPos - diff
  tree.nodes.delete(startPos, endPos - 1)
  # Update the operands of the parent nodes
  rawUpdateParents(tree, res.parents, diff)

proc add*(tree: var JsonTree, path: JsonPtr, value: JsonTree) =
  ## Performs one of the following functions,
  ## depending upon what the target location references:
  ##
  ## - If `path` specifies an array index, a new value is
  ##   inserted into the array at the specified index.
  ##
  ## - If `path` specifies an object member that does not
  ##   already exist, a new member is added to the object.
  ##
  ## - If `path` specifies an object member that does exist,
  ##   that member's value is replaced.
  ##
  ## `value` specifies the value to be added.
  privateAccess(JsonTree)
  # Find the target node
  let res = findNodeMut(tree, path.string)
  var diff = 0
  if res.node.isNil:
    # Add a new node
    let parent = res.parents[^1].NodePos
    let startPos = parent.int + int(parent.operand)
    if parent.kind == opcodeObject:
      # Add a new key-value pair to an object
      diff = 1 + span(value, 0)
      rawAddKeyValuePair(tree, value, NodePos(startPos), res.key)
    else:
      # Add a new element to an array
      diff = span(value, 0)
      rawAdd(tree, value, NodePos(startPos))
  else:
    if res.parents.len > 0 and res.parents[^1].NodePos.kind == opcodeArray:
      # Insert a value before the given index
      diff = span(value, 0)
      rawAdd(tree, value, res.node)
    else:
      # Replace an existing node
      diff = span(value, 0) - span(tree, res.node.int)
      rawReplace(tree, value, res.node)
  rawUpdateParents(tree, res.parents, diff)

proc copy*(tree: var JsonTree, `from`, path: JsonPtr) =
  ## Copies the value at a specified location to the
  ## target location.
  ##
  ## ``from`` references the location in `tree` to copy the value from.
  ##
  ## The ``from`` location must exist for the operation to be successful.
  ##
  ## This operation is functionally identical to an `add` at the
  ## `path` using the value specified in ``from``.
  privateAccess(JsonTree)
  # Find the source node
  let srcNode = findNode(tree, `from`.string)
  if srcNode.isNil:
    raisePathError(`from`.string)
  # Find the target node
  let res = findNodeMut(tree, path.string)
  if res.node == srcNode:
    # Source and destination are the same, no need to copy
    return
  if binarySearch(res.parents, srcNode.PatchPos) >= 0:
    raise newException(PathError, "Invalid operation: `from` is an ancestor of `path`")
  var diff = 0
  if res.node.isNil:
    # Copy to a new node
    let parent = res.parents[^1].NodePos
    let startPos = parent.int + int(parent.operand)
    if parent.kind == opcodeObject:
      # Copy to a new key-value pair in an object
      diff = 1 + span(tree, srcNode.int)
      rawAddKeyValuePair(tree, srcNode, NodePos(startPos), res.key)
    else:
      # Copy to a new element in an array
      diff = span(tree, srcNode.int)
      rawAdd(tree, srcNode, NodePos(startPos))
  else:
    if res.parents.len > 0 and res.parents[^1].NodePos.kind == opcodeArray:
      # Insert the copied value before the given index
      diff = span(tree, srcNode.int)
      rawAdd(tree, srcNode, res.node)
    else:
      # Replace an existing node
      diff = span(tree, srcNode.int) - span(tree, res.node.int)
      rawReplace(tree, srcNode, res.node)
  rawUpdateParents(tree, res.parents, diff)

proc move*(tree: var JsonTree, `from`, path: JsonPtr) =
  ## Removes the value at a specified location and
  ## adds it to the target location.
  ##
  ## ``from`` references the location in the `tree` to move the value from.
  ##
  ## The ``from`` location must exist for the operation to be successful.
  ##
  ## This operation is functionally identical to a `remove` operation on
  ## ``from``, followed immediately by an `add` operation at
  ## the `path` with the value that was just removed.
  ##
  ## ``from`` must not be a proper prefix of the `path`;
  ## i.e., a location cannot be moved into one of its children.
  privateAccess(JsonTree)
  # Find the source node
  var src = findNodeMut(tree, `from`.string)
  if src.node.isNil:
    raisePathError(`from`.string)
  # Find the target node
  let dest = findNodeMut(tree, path.string)
  if dest.node == src.node:
    # Source and destination are the same, no need to copy
    return
  if binarySearch(dest.parents, src.node.PatchPos) >= 0:
    raise newException(PathError, "Invalid operation: `from` is an ancestor of `path`")
  var startPos, diff = 0
  if dest.node.isNil:
    # Copy to a new node
    let parent = dest.parents[^1].NodePos
    startPos = parent.int + int(parent.operand)
    if parent.kind == opcodeObject:
      # Copy to a new key-value pair in an object
      diff = 1 + span(tree, src.node.int)
      rawAddKeyValuePair(tree, src.node, NodePos(startPos), dest.key)
    else:
      # Copy to a new element in an array
      diff = span(tree, src.node.int)
      rawAdd(tree, src.node, NodePos(startPos))
  else:
    startPos = dest.node.int
    if dest.parents.len > 0 and dest.parents[^1].NodePos.kind == opcodeArray:
      # Insert the copied value before the given index
      diff = span(tree, src.node.int)
      rawAdd(tree, src.node, dest.node)
    else:
      # Replace an existing node
      diff = span(tree, src.node.int) - span(tree, dest.node.int)
      rawReplace(tree, src.node, dest.node)
  rawUpdateParents(tree, dest.parents, diff)
  if binarySearch(src.parents, dest.node.PatchPos) >= 0:
    # The source was overwritten by the destination
    return
  for parent in mitems(src.parents):
    if parent >= startPos.PatchPos:
      inc parent, diff
  if src.node >= startPos.NodePos:
    inc src.node, diff
  # Remove the source node
  if src.parents.len > 0 and src.parents[^1].NodePos.kind == opcodeObject:
    startPos = src.node.int - 1
    diff = -1 - span(tree, src.node.int)
  else:
    startPos = src.node.int
    diff = -span(tree, src.node.int)
  let endPos = startPos - diff
  tree.nodes.delete(startPos, endPos - 1)
  # Update the operands of the parent nodes
  rawUpdateParents(tree, src.parents, diff)
