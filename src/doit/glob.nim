## Implements POSIX glob style pattern matching. Supports `**` and `*` matching

import std/os

# TODO: Benchmark
# TODO: Add support for %: %.nim style rules
# TODO: Use https://man7.org/linux/man-pages/man3/glob.3.html when on POSIX platform

type
  Glob* = object

proc glob*(x: string): Glob = discard

proc matches*(x: string, g: Glob): bool = discard

iterator expand*(g: Glob, dir: string): string =
  for file in walkDirRec(dir):
    if file.matches(g):
      yield file
