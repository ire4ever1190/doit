## Implements a basic glob style
##
## - Supports `*` matching e.g. `*.nim` `hello*.txt`
## - Supports `**` to match any number of directories
##

import std/[
  os,
  strutils,
  parseutils
]

# TODO: Benchmark
# TODO: Add support for %: %.nim style rules
# NOTE: Was going to use globby by tree form but that seems to do the opposite of what I want

const
  singleStar = "*"
  doubleStar = "**"
  stars = [singleStar, doubleStar]

type
  Glob* = object
    parts: seq[string]


func startsWith(s: openArray[char], with: string): bool =
  var i = 0
  # Keep track of the max index that we can't go past
  let max = min(s.len, with.len)
  while i < max and s[i] == with[i]:
    inc i
  result = i == with.len

proc glob*(x: string): Glob =
  ## Creates a glob pattern
  # This basically tokenises the string into globs and non glob parts
  var i = 0
  while i < x.len:
    var token: string
    if x[i] == '*':
      # Check if double or single star
      if x.skip("**", i) >= 2:
        i += 2
        token = "**"
      else:
        i += 1
        token = "*"
    else:
      i += x.parseUntil(token, '*', i)
    result.parts &= token

func matches(x: openArray[char], tokens: openArray[string]): bool {.raises: [].} =
  ## Internal function that does actual matching.
  # Keep stack of where branches happened
  if tokens.len > 0 and tokens[0] in stars:
    # Make sure we aren't a single star trying to make a dir seperator
    if x.len > 0 and x[0] == '/' and tokens[0] == singleStar:
      return false
    # First check if if matches 0 amount of x
    # Then check if it matches 1 amount of x (And see if it can continue)
    return x.matches(tokens[1 ..^ 1]) or (x.len > 0 and x[1 .. ^1].matches(tokens))
  elif tokens.len > 0 and x.startsWith(tokens[0]):
    # The string continues with the normal string so
    # we chop off the token from the start and continue trying
    # more tokens
    return x[tokens[0].len .. ^1].matches(tokens[1..^1])
  else:
    return x.len == 0 and tokens.len == 0

func matches*(path: openArray[char], g: Glob): bool {.raises: [].}=
  ## Checks if a path matches a glob
  runnableExamples:
    let pat = glob"**/*.nim"
    assert "/test.nim".matches(pat)
    assert "tests/hello.nim".matches(pat)
  #==#
  return path.matches(g.parts)


iterator expand*(g: Glob, dir: string): string =
  for file in walkDirRec(dir):
    if file.matches(g):
      yield file

when isMainModule:
  let g = glob"*.nim"
  echo "testSample/hello/hello.nim".matches(g)
