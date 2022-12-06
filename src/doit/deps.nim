## Implements deps hooks for different file types and allows you to define your own
##
## Currently supports
##
## - **nim**
## - **cpp**
## - **c**

import std/[
  tables,
  os,
  osproc
]

type
  DepHook* = proc (path: string): seq[string]
    ## A hook should take in a path and produce a sequence of dependencies for that file

var hookTable*: Table[string, DepHook]
  ## Hook table is mapping of file extensions to hooks

proc requirementsFor*(ext: string, handler: DepHook) =
  ## Registers a hook that finds requirements
  runnableExamples:
    import api
    import strutils, strformat
    requirementsFor("cpp") do (path: string) -> seq[string]:
      # gcc -MM returns make like rule of file.o: dependent files
      # So we split to only get the dependent files
      "gcc -MM {path}".fmt().cmd().split(":")[1].split(" ")
  #==#
  # Don't do any checks since we want them to override
  hookTable[ext] = handler

proc nimDeps(path: string): seq[string] =
  ## This is more or less taken from nimsuggest
  ## TODO: Slim down, figure out what I can remove
  # There was an RFC for something like this but don't think it was ever merged
  # Least it wasn't too hard to implement
  let p = startProcess("nimdeps", args = [path], options = {poUsePath})
  defer: close p
  for line in p.lines:
    result &= line

requirementsFor("nim", nimDeps)
