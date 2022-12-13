## Implements deps hooks for different file types and allows you to define your own.
## You should make sure that your proc returns the path that was passed in also (Most dependency tools do so anyways)
##
## Currently supports
##
## - **nim**
## - **cpp**
## - **c**

import std/[
  tables,
  os,
  osproc,
  compilesettings,
  strformat,
  parseutils
]

type
  DepHook* = proc (path: string): seq[string]
    ## A hook should take in a path and produce a sequence of dependencies for that file

var extTable*: Table[string, DepHook]
  ## Table is mapping of file extensions to procs that provide dependencies

proc requirementsFor*(ext: string, handler: DepHook) =
  ## Registers a hook that finds requirements
  runnableExamples:
    import api
    import strutils, strformat
    # Make sure you pass "." in the ext
    requirementsFor(".cpp") do (path: string) -> seq[string]:
      # gcc -MM returns make like rule of file.o: dependent files
      # So we split to only get the dependent files
      "gcc -MM {path}".fmt().cmd().split(":")[1].split(" ")
  #==#
  # Don't do any checks since we want them to override
  extTable[ext] = handler

proc cLikeRequirements(path: string): seq[string] =
  ## Returns requirments for c/c++ file.
  # const cc = querySetting(ccompilerPath)
  # querySetting broke, gotta use this
  const cc = "gcc"
  let command = fmt"{cc} -fsyntax-only -MM {path}"
  let (outp, exitCode) = execCmdEx command
  # Unlikely this would fail, but just incase
  assert exitCode == QuitSuccess, outp
  var i = outp.skipUntil(':')
  # Now parse each requirement thats on the right side of the :
  while i < outp.len:
    var newItem: string
    i += outp.parseUntil(newItem, ' ', i)
    result &= newItem



proc nimDeps(path: string): seq[string] =
  ## This is more or less taken from nimsuggest
  ## TODO: Slim down, figure out what I can remove
  # There was an RFC for something like this but don't think it was ever merged
  # Least it wasn't too hard to implement
  let p = startProcess("nimdeps", args = [path], options = {poUsePath})
  defer: close p
  for line in p.lines:
    result &= line

proc noAutoDeps(ext: string) =
  ## Makes a file not have any auto dependencies found for it
  extTable.del(ext)

requirementsFor(".cpp", cLikeRequirements)
requirementsFor(".c", cLikeRequirements)
requirementsFor(".nim", nimDeps)
