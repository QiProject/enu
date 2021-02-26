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
  result[0].find_child(it.kind == nnkStmtList).add(body)

to patrol(a):
  #echo "a is ", a
  #echo "b is ", b
  forward 10
  left()

to follow:
 forward()

to circle(distance = 5):
  left 2

to shoot:
  echo "fire_at(player)"

patrol(6)
follow()
circle 4
shoot()
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

# macro loop(states: untyped, body: untyped): untyped =
#   echo "single: ", treeRepr(states)
#   echo len(states)
#   for state in states:
#     echo treeRepr(state)
#     echo len(states)
#   quote do:
#     while true:
#       `body`
macro `->`(from_state: untyped, to_state: untyped): untyped =
  discard

macro loop(args: varargs[untyped]): untyped =
  if args.len == 0:
    error "loop requires a body and/or states", args
  var
    args = args.to_seq
    body: NimNode
  if args[^1].kind == nnkStmtList:
    echo "has body"
    body = args[^1]
    args = args[0..^2]
  else:
    echo "no body"
  if args.len > 0:

    let code = &"""
      block:
        let initial_state = "{args[0]}"
        while true:
          const placeholder = true
    """
    result = parse_stmt(code)
    result[0][1][1][1].add(body)
    echo result.tree_repr
  else:
    echo "no args"
    result = parse_stmt("echo \"no args!\"")

var counter = 0

expand_macros:
  loop follow, shoot:
    echo "first"
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
