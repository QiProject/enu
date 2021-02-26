import macros, strformat, sugar

proc one() =
  discard

proc two(a: int) =
  discard

macro check(thing: untyped): untyped =
  parse_stmt &"bind_sym\"{thing}\""
let a = (check(one), two,"k")
let a1 = check(one)
let a2 = check(one)
let b1 = check(two)
echo repr(a)
#let b2 = check(two)
#dump a1 == a2
#dump a1 == b1

