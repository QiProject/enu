import ../vmlib/enu/logo
import macros, strformat, strutils, sequtils, sugar

type
  ActionResult = object
  Context = ref object
    stack: seq[Frame]
  Frame = ref object
    manager: proc(active: bool):bool
    action: proc()
  Halt = object of CatchableError
    manager: proc(active: bool):bool

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

proc advance(ctx: Context, frame: Frame): bool =
  ## advance state machine. Returns true if state changes.
  var stack = ctx.stack
  for i, stackframe in stack:
    try:
      discard stackframe.manager(i + 1 == stack.len)
    except Halt as h:
      ctx.stack = ctx.stack[0..i]
      if stackframe.action == nil and stackframe in ctx.stack:
        ctx.stack.delete ctx.stack.find(stackframe)
      if frame != stackframe:
        raise h
      break
  result = frame.action != nil

template loop(body: untyped) =
  block:
    var main_loop = false
    var current_state {.inject.}: string
    var done {.inject.} = false
    var frame {.inject.} = Frame()
    when not compiles(ctx):
      let ctx {.inject.} = Context()
      main_loop = true

    proc manager(active: bool): bool =
      let active {.inject.} = active
      while true:
        body
        return true
    frame.manager = manager
    ctx.stack.add frame
    var looping = ctx.advance(frame)
    if main_loop and not looping:
        # regular while loop.
        while manager(true):
          discard
    else:
      while looping:
        done = false
        try:
          frame.action()
        except Halt as h:
          #if h.manager == manager:
          break
          #else:
          #  raise h
        done = true
        looping = ctx.advance(frame)

macro `->`(from_state: untyped, to_state: untyped, body: untyped = nil) =
  template transition(from_state_name, to_state_name: string, from_state, to_state, body: untyped) =
    if current_state == from_state_name:
      current_state = to_state_name
      body
      proc action() =
        to_state
      if to_state_name != "":
        frame.action = action
      else:
        frame.action = nil
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

to action_a(name: string):
  echo "action_a ", name

to action_b(name: string):
  echo "action_b ", name

to action_c(name: string):
  echo "action_c ", name

to action_d(name: string):
  echo "action_d ", name

to action_e(name: string):
  echo "action_e ", name

to loop_b:
  var
    counter = 0
    name = "loop_b"
  loop:
    inc counter
    nil -> action_c(name)
    if counter == 5:
      action_d -> action_e(name)
    if counter == 10:
      action_e -> action_d(name)
    if counter == 15:
      counter = 0

to loop_a:
  var
    counter = 0
    name = "loop_a"

  loop:
    nil -> action_b(name)
    inc counter
    if counter == 2:
      action_b -> loop_b:
        counter = -20
      loop_b -> action_c(name)
    if counter == 6:
      action_c -> nil
  echo name, " done ", counter

var counter = 0
loop:
  echo "looping"
  inc counter
  if counter == 6:
    break

counter = 0
var loop_a_finished = false
loop:
  var name = "loop_main"
  nil -> loop_a
  inc counter
  if not loop_a_finished and done:
    loop_a -> action_a(name):
      counter = 0
  if counter == 3:
    action_a -> action_b(name):
      counter = 0
    action_b -> action_c(name):
      counter = 0
    action_c -> loop_a:
      counter = 0
      loop_a_finished = true
  if loop_a_finished and counter == 70:
    loop_a -> nil:
      echo "mainloop done ", counter

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
