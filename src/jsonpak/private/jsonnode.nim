type
  Node* = distinct uint
  JsonNodeKind* = enum ## possible JSON node types
    JNull,
    JBool,
    JInt,
    JFloat,
    JString,
    JObject,
    JArray

const
  opcodeBits = 3'u

  opcodeNull* = uint JNull
  opcodeBool* = uint JBool
  opcodeFalse* = opcodeBool
  opcodeTrue* = opcodeBool or 0b0000_1000
  opcodeInt* = uint JInt
  opcodeFloat* = uint JFloat
  opcodeString* = uint JString
  opcodeObject* = uint JObject
  opcodeArray* = uint JArray

  opcodeMask = (1'u shl opcodeBits) - 1'u

template kind*(n: Node): uint = n.uint and opcodeMask
template operand*(n: Node): uint = n.uint shr opcodeBits.uint

template toNode*(kind, operand: uint): Node =
  Node(operand shl opcodeBits.uint or kind)

proc `==`*(a, b: Node): bool {.borrow.}
