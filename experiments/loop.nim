import ../vmlib/enu/logo
import macros, strformat, strutils, sequtils, sugar

type
  ActionResult = object
  Context = ref object
    managers: seq[proc:bool]
    current_state_action: proc(): bool

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

proc pump(ctx: Context): bool =
  ## pump state machine. Returns true if state changes.
  let last_action = ctx.current_state_action
  var remove_after = ctx.managers.len - 1
  for i, manager in ctx.managers:
    if manager():
      remove_after = i
      break
  ctx.managers = ctx.managers[0..remove_after]
  return last_action != ctx.current_state_action

template loop(body: untyped) =
  block:
    var main_loop = false
    var current_state {.inject.}: string

    when not compiles(ctx):
      let ctx {.inject.} = Context()
      main_loop = true
    proc manager(): bool =
      result = true
      while true:
        body
        return false


    ctx.managers.add(manager)
    if main_loop:
      discard ctx.pump()
      if ctx.current_state_action == nil:
        ctx.current_state_action = proc(): bool =
          manager()
      while ctx.current_state_action != nil:
        if ctx.current_state_action():
          break
        discard ctx.pump()

macro `->`(from_state: untyped, to_state: untyped, body: untyped = nil) =
  template transition(from_state_name, to_state_name: string, from_state, to_state, body: untyped) =
    if current_state == from_state_name:
      current_state = to_state_name
      body
      ctx.current_state_action = proc(): bool =
        to_state
        false
      return true

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
    echo "looping"
    inc counter
    if counter == 6:
      break

  counter = 0
  loop:
    nil -> patrol:
      echo "transition to patrol"
    inc counter
    if counter == 6:
      patrol -> follow:
        echo "transition to follow"
        counter = -2

      follow -> circle(2):
        echo "transition to circle"
        counter = 2
      circle -> shoot:
        echo "transition to circle"
        counter = -10
      shoot -> nil
    else:
      echo "no transition"



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
