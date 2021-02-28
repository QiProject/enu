import ../vmlib/enu/logo
import macros, strformat, strutils, sequtils, sugar

type
  ActionResult = object

proc parse(sig: NimNode): (string, string) =
  var
    name = ""
    args: seq[string]
  if sig.kind == nnkIdent:
    name = $sig
  else:
    name = $sig[0]
    for i, arg in sig[1..^1]:
      case arg.kind
      of nnkExprColonExpr:
        args.add &"{arg[0]}: {arg[1]}"
      of nnkExprEqExpr:
        args.add &"{arg[0]} = {arg[1].to_str_lit}"
      of nnkIdent:
        args.add &"{arg}: auto"
      else:
        error "invalid signature", sig
  return (name, args.join(", "))

macro to(sig: untyped,  body: untyped): untyped =
  let
    (name, args) = sig.parse
    code = &"""
      proc {name}({args}): ActionResult {{.discardable.}} =
        const this_state = "{name}"
    """
  result = parse_stmt(code)
  #echo result.tree_repr
  result[0].find_child(it.kind == nnkStmtList).add(body)

to patrol(a = 2):
  #echo "a is ", a
  #echo "b is ", b
  echo &"patrolling {a}"
  forward 10
  left()

to follow:
 forward()

to circle(distance = 5):
  left 2

to shoot:
  echo "fire_at(player)"


#[
to attack:
  loop circle, follow, shoot:
    if 1 in 50:
      circle -> shoot
    if 1 in 10:
      follow -> circle(3..5)
    if player.shot:
      (1..3).times: jump()
      shoot -> follow
    if player.died:
      current -> done
    if not player.within(10):
      current -> done
]#
# macro loop(body: untyped): untyped =
#   quote do:
#     while true:
#       `body`

template loop(body: untyped) =
  var current_state {.inject.}: string
  while true:
    body

macro `->`(from_state: untyped, to_state: untyped, body: untyped = nil) =
  template transition(from_nil, to_nil: bool, to_state_name: string, from_state, to_state, body: untyped) =
    let from_state_name = from_state.ast_to_str
    echo from_nil
    echo to_state_name
    echo from_nil.bool
    echo current_state == ""
    if (current_state == "") and from_nil.bool:
      current_state = to_state_name
      body
      to_state
      continue
    if current_state == from_state_name:
      current_state = to_state_name
      if to_nil.bool:
        body
        break
      else:
        body
        to_state
  let
    from_nil = from_state.kind == nnkNilLit
    to_nil = to_state.kind == nnkNilLit
  var
    to_state_name: string
    to_state = to_state
  echo tree_repr(to_state)
  var body = body
  echo body.tree_repr
  if body.kind == nnkNilLit:
    body = new_stmt_list()
  if not to_nil:
    if to_state.kind == nnkIdent:
      to_state_name = $to_state
      to_state = new_call(to_state)
    else:
      to_state_name = $to_state[0]
  else:
    to_state = new_stmt_list()
  get_ast transition(from_nil, to_nil, to_state_name, from_state, to_state, body)

var counter = 0

expand_macros:
  loop:
    nil -> patrol()
    echo "first"
    inc counter
    shoot -> nil
    if counter == 6:
      patrol -> follow:
        echo "followwwwwww"
        counter = -2

      follow -> circle(2):
        counter = 2
      circle -> shoot:
        counter = -10
    if counter == 10:
      break



#[
  if counter == 2:
    follow -> patrol
  if counter == 5:
    patrol -> follow
  if player.within(5):
    follow -> attack
  if hit:
    turn_right 180
  if done:
    attack -> patrol

loop patrol:
  player.hit:
    jump()
]#
