import macros

proc one() =
  echo "one"

proc two(a: string) =
  echo "two ", a

var current_state = "one"
template `->`(from_state: untyped, to_state: untyped) =
  if current_state == from_state.ast_to_str:
    current_state = to_state.ast_to_str
    to_state

one -> two("scott")
echo current_state
