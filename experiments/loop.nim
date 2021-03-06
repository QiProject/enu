import ../vmlib/enu/logo
import macros, strformat, strutils, sequtils, sugar

type
  ActionResult = object
  Context = ref object
    managers: seq[proc:bool]
    current_action: proc()
    depth: int
  Halt = object of CatchableError
    manager: proc:bool

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
  echo &"patrolling {a}"
  forward 10
  left()

to follow:
 echo "follow"

to circle(distance = 5):
  echo "circle"

to shoot(name = "nothing"):
  echo "fire_at(player) ", name


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

proc advance(ctx: Context): bool =
  ## advance state machine. Returns true if state changes.
  var managers = ctx.managers
  for i, manager in managers:
    try:
      discard manager()
    except Halt:
      ctx.managers = ctx.managers[0..i]
      if ctx.current_action == nil and manager in ctx.managers:
        ctx.managers.delete ctx.managers.find(manager)
      break
  result = ctx.current_action != nil

template loop(body: untyped) =
  block:
    var main_loop = false
    var current_state {.inject.}: string
    var done {.inject.} = false
    when not compiles(ctx):
      let ctx {.inject.} = Context()
      main_loop = true
    else:
      inc ctx.depth
    proc manager(): bool =
      while true:
        body
        return true
    ctx.managers.add(manager)
    var looping = ctx.advance()
    if main_loop and ctx.current_action == nil:
        # regular loop.
        while manager():
          discard
    else:
      while looping:
        done = false
        ctx.current_action()
        done = true
        looping = ctx.advance()

macro `->`(from_state: untyped, to_state: untyped, body: untyped = nil) =
  template transition(from_state_name, to_state_name: string, from_state, to_state, body: untyped) =
    if current_state == from_state_name:
      current_state = to_state_name
      body
      proc action() =
        to_state
      if to_state_name != "":
        ctx.current_action = action
      else:
        ctx.current_action = nil
      raise (ref Halt)(manager: manager)

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
    to_state = new_stmt_list()
  get_ast transition(from_state_name, to_state_name, from_state, to_state, body)

var counter = 0

to lookout:
  var counter = 0

  loop:
    nil -> follow:
      echo "subloop follow"
    inc counter
    if counter == 2:
      follow -> shoot("subloop"):
        echo "subloop shoot"
    if counter == 6:
      counter = 0
      shoot -> nil:
        echo "subloop done"
  echo "lookout done"

loop:
  echo "looping"
  inc counter
  if counter == 6:
    break

counter = 0
var looking_out = false
loop:
  nil -> lookout:
    echo "transition to lookout"
  inc counter
  if done:
    lookout -> patrol:
      echo "transition to patrol"
      counter = 0
  if counter == 3:
    patrol -> circle(2):
      echo "transition to circle"
      counter = 0
    circle -> shoot:
      echo "transition to shoot"
      counter = 0
    shoot -> lookout:
      counter = 0
      looking_out = true
      echo "lookout 2"
    if looking_out:
      lookout -> nil:
        echo "mainloop done"

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
