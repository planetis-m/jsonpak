type
  Node* = distinct uint32
  JsonNodeKind* = enum ## possible JSON node types
    JNull,
    JBool,
    JInt,
    JFloat,
    JRawNumber,
    JString,
    JObject,
    JArray

const
  opcodeBits = 3'u32

  opcodeNull* = uint32 JNull
  opcodeBool* = uint32 JBool
  opcodeFalse* = opcodeBool
  opcodeTrue* = opcodeBool or 0b0000_1000
  opcodeInt* = uint32 JInt
  opcodeFloat* = uint32 JFloat
  opcodeRawNumber* = uint32 JRawNumber
  opcodeString* = uint32 JString
  opcodeObject* = uint32 JObject
  opcodeArray* = uint32 JArray

  opcodeMask = (1'u32 shl opcodeBits) - 1'u32

template kind*(n: Node): uint32 = n.uint32 and opcodeMask
template operand*(n: Node): uint32 = n.uint32 shr opcodeBits.uint32

template toNode*(kind, operand: uint32): Node =
  Node(operand shl opcodeBits.uint32 or kind)

proc `==`*(a, b: Node): bool {.borrow.}
