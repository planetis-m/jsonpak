## Provides procs for serializing Nim data types to JSON format.

import private/[jsonnode, jsontree, rawops], std/[macros, tables, options, importutils]

proc toJson*(s: string; tree: var JsonTree) =
  storeAtom(tree, opcodeString, s)

proc toJson*[T: SomeInteger](n: T; tree: var JsonTree) =
  storeAtom(tree, opcodeInt, $n)

proc toJson*[T: SomeFloat](n: T; tree: var JsonTree) =
  storeAtom(tree, opcodeFloat, $n)

proc toJson*(b: bool; tree: var JsonTree) =
  storeAtom(tree, if b: opcodeTrue else: opcodeFalse)

proc toJson*[T](elements: openArray[T]; tree: var JsonTree) =
  let patchPos = tree.prepare(opcodeArray)
  for elem in elements:
    toJson(elem, tree)
  tree.patch patchPos

proc toJson*[T: object](o: T; tree: var JsonTree) =
  let patchPos = tree.prepare(opcodeObject)
  for k, v in o.fieldPairs:
    storeAtom(tree, opcodeString, k)
    toJson(v, tree)
  tree.patch patchPos

proc toJson*[T](o: ref T; tree: var JsonTree) =
  if o.isNil:
    storeAtom(tree, opcodeNull)
  else:
    toJson(o[], tree)

proc toJson*[T: enum](o: T; tree: var JsonTree) =
  toJson($o, tree)

proc toJson*(value: JsonTree; tree: var JsonTree) =
  privateAccess(JsonTree)
  rawAdd(tree, value, NodePos tree.nodes.len)

proc toJson*[T](table: Table[string, T]|OrderedTable[string, T]; tree: var JsonTree) =
  let patchPos = tree.prepare(opcodeObject)
  for k, v in pairs(table):
    storeAtom(tree, opcodeString, k)
    toJson(v, tree)
  tree.patch patchPos

proc toJson*[T](opt: Option[T]; tree: var JsonTree) =
  if opt.isSome:
    toJson(opt.get, tree)
  else:
    storeAtom(tree, opcodeNull)

proc toJsonImpl(x, res: NimNode): NimNode =
  case x.kind
  of nnkBracket: # array
    if x.len == 0:
      return newCall(bindSym"storeEmpty", res, bindSym"opcodeArray")
    let tmp = genSym(nskLet, "tmp")
    result = newTree(nnkStmtList)
    result.add newLetStmt(tmp, newCall(bindSym"prepare", res, bindSym"opcodeArray"))
    for i in 0..<x.len:
      result.add toJsonImpl(x[i], res)
    result.add newCall(bindSym"patch", res, tmp)
  of nnkTableConstr: # object
    if x.len == 0:
      return newCall(bindSym"storeEmpty", res, bindSym"opcodeObject")
    let tmp = genSym(nskLet, "tmp")
    result = newTree(nnkStmtList)
    result.add newLetStmt(tmp, newCall(bindSym"prepare", res, bindSym"opcodeObject"))
    for i in 0..<x.len:
      x[i].expectKind nnkExprColonExpr
      result.add newCall(bindSym"storeAtom", res, bindSym"opcodeString", x[i][0])
      result.add toJsonImpl(x[i][1], res)
    result.add newCall(bindSym"patch", res, tmp)
  of nnkCurly: # nil object
    x.expectLen(0)
    result = newCall(bindSym"storeEmpty", res, bindSym"opcodeObject")
  of nnkNilLit:
    result = newCall(bindSym"storeAtom", res, bindSym"opcodeNull")
  of nnkPar:
    if x.len == 1: result = toJsonImpl(x[0], res)
    else: result = newCall(bindSym"toJson", x, res)
  else:
    result = newCall(bindSym"toJson", x, res)

macro `%*`*(x: untyped): untyped =
  ## Convert an expression to a JsonTree.
  let res = genSym(nskVar, "toJsonResult")
  result = newStmtList(newVarStmt(res, newCall(bindSym"JsonTree")), toJsonImpl(x, res), res)

proc toJson*[T](x: T): JsonTree =
  ## Convert `x` to a JsonTree.
  result = JsonTree()
  toJson(x, result)
