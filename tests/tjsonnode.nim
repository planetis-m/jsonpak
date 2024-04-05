import jsonpak/private/jsonnode, std/assertions

proc main =
  assert JsonNodeKind(Node(opcodeNull).kind) == JNull
  assert JsonNodeKind(Node(opcodeFalse).kind) == JBool
  assert JsonNodeKind(Node(opcodeTrue).kind) == JBool

  assert toNode(opcodeNull, 0) == Node(opcodeNull)
  assert toNode(opcodeBool, 0) == Node(opcodeFalse)
  assert toNode(opcodeBool, 1) == Node(opcodeTrue)

  assert Node(opcodeNull).operand == 0
  assert Node(opcodeFalse).operand == 0
  assert Node(opcodeTrue).operand == 1

  assert toNode(opcodeString, 7).operand == 7

  assert Node(opcodeNull) != Node(opcodeFalse)
  assert Node(opcodeFalse) != Node(opcodeTrue)

main()
