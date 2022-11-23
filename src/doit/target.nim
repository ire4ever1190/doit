import std/[hashes, tables]
import std/times
type
  Unit* = ref object of RootObj
    ## Basic unit of work
    name*: string
  FileUnit* = ref object of Unit
    path*: string


method modified*(t: Unit): DateTime {.base.} = discard

method hash*(t: Unit): Hash {.base.} =
  result = !$t.name.hash

method `$`*(t: Unit): string {.base.} =
  result = t.name

method `==`*(a, b: Unit): bool {.base.} =
  a.name == b.name

func newUnit*(name: string): Unit =
  result = Unit(name: name)
