import ../vmlib/enu/logo
import macros, strformat, strutils, sequtils, sugar

type
  ActionResult = object
  Context = ref object
    managers: seq[proc:bool]

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
    if args.len > 0:
      args.add ""
  return (name, args.join(", "))

macro to(sig: untyped,  body: untyped): untyped =
  let
    (name, args) = sig.parse
    code = &"""
      proc {name}({args} ctx: Context = nil): ActionResult {{.discardable.}} =
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
  var main_loop = false
  var current_state {.inject.}: string
  var current_state_action {.inject.}: proc(): bool
  when not compiles(ctx):
    let ctx {.inject.} = Context()
    main_loop = true
  proc manager(): bool =
    body
    if current_state_action != nil:
      if current_state_action():
        return true
  while not manager():
    discard

macro `->`(from_state: untyped, to_state: untyped, body: untyped = nil) =
  template transition(from_state_name, to_state_name: string, from_state, to_state, body: untyped) =
    if current_state == from_state_name:
      current_state = to_state_name
      body
      current_state_action = proc(): bool =
        to_state
        false
      if current_state_action():
        return true
      echo to_state_name
      return false

  var
    to_state_name: string
    from_state_name: string
    to_state = to_state
  var body = body
  if body.kind == nnkNilLit:
    body = new_stmt_list()
  if from_state.kind != nnkNilLit:
    from_state_name = $from_state
  if to_state.kind != nnkNilLit:
    let ctx_arg = new_nim_node(nnkExprEqExpr)
    ctx_arg.add(ident"ctx")
    ctx_arg.add(ident"ctx")
    if to_state.kind == nnkIdent:
      to_state_name = $to_state
      to_state = new_call(to_state, ctx_arg) #
    elif to_state.kind == nnkCall:
      to_state_name = $to_state[0]
      to_state.add(ctx_arg)
    else:
      error "to_state must be an identifier or call", to_state

  else:
    to_state = new_nim_node(nnk_return_stmt)
    to_state.add bind_sym"true"
  get_ast transition(from_state_name, to_state_name, from_state, to_state, body)

var counter = 0

expand_macros:
  loop:
    nil -> patrol:
      echo "first"
    inc counter

    if counter == 6:
      patrol -> follow:
        echo "followwwwwwww"
        counter = -2

      follow -> circle(2):
        echo "circ"
        counter = 2
      circle -> shoot:
        echo "shoot"
        counter = -10
      shoot -> nil
    else:
      echo "nothing"



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
