import std/tables
import std/times
import std/os
import std/strformat
import std/osproc
import std/terminal


import deps

type
  LastModifiedHandler* = proc (t: Target): Time
    ## Gets ran see when the target was last modified. This is then compared
    ## against the dependencies to see if a target needs to be reran
  TargetHandler* = proc (t: Target)
    ## Gets ran when dependencies are newer than the targe

  SatisfiedHandler* = proc (t: Target): bool
    ## Gets ran to check if a target is satisfied or not.
    ## You won't need to edit this 90% of the time

  Target* = object
    name*: string
    requires*: seq[string]
    # At this point am I just reimplementing inheritance?
    lastModifiedProc: LastModifiedHandler
    satisfiedProc: SatisfiedHandler
    handler: TargetHandler

  CommandFailedError* = object of OSError
    ## Raised when command failed (If using procs here)
    command*, output*: string
    code*: int

# TODO: Lazy load dependencies

var targets*: Table[string, Target]
  ## All the targets

proc safeLastModified(t: Target): Time =
  ## Acts like normal getLastModificationTime except returns oldest date
  ## if file doesnt exist instead of erroring
  if t.name.fileExists or t.name.dirExists:
    result = t.name.getLastModificationTime()


func fileExt*(path: string): string =
  ## Returns the file extension of a path
  let pos = path.searchExtPos()
  if pos != -1:
    result = path[pos + 1 .. ^1]

proc target*(name: string, requires: openArray[string] = [],
             lastModified: LastModifiedHandler = safeLastModified,
             satisfier: SatisfiedHandler = nil,
             handler: TargetHandler = nil) =
  let ext = name.fileExt
  targets[name] = Target(
      name: name,
      requires: @requires,
      lastModifiedProc: lastModified,
      handler: handler,
      satisfiedProc: satisfier
  )

proc task*(name: string, requires: openArray[string] = [],
           lastModified: LastModifiedHandler = nil,
           handler: TargetHandler = nil) =
  target(name, requires, lastModified, proc (t: Target): bool = false, handler)

template target*(name: string, dependencies: openArray[string], body: untyped) =
  target(name, dependencies, handler = proc (target: Target) =
    let t {.inject.} = target
    body
  )

template task*(name: string, dependencies: openArray[string], body: untyped) =
  task(name, dependencies, handler = proc (target: Target) =
    let t {.inject.} = target
    body
  )

proc lastModified*(target: Target): Time =
  ## Returns the time a target was last modified.
  ## If the target as no way of telling then we assume its always modified
  if target.lastModifiedProc != nil:
    target.lastModifiedProc(target)
  else:
    Time.high

proc satisified*(target: Target): bool =
  ## Returns true if a target is satisifed. Doesn't care if
  ## its out of date or not
  if target.satisfiedProc != nil:
    target.satisfiedProc(target)
  else:
    # If the target doesn't have a custom satisifier then we just
    # check if there is a file with the same name
    target.name.fileExists or target.name.dirExists

proc handle(target: Target) =
  ## Runs targets handler if it exists
  if target.handler != nil:
    target.handler(target)

proc cmd*(cmd: string) =
  ## Runs command and sends output to console
  let process = startProcess(cmd, options = {poUsePath, poEvalCommand, poStdErrToStdOut, poParentStreams})
  let code = process.waitForExit()
  if code != 0:
    raise (ref CommandFailedError)(code: code, command: cmd)

proc rm*(path: string, recursive = false) =
  ## Acts like `rm` command except doesn't fail if file doesn't exist.
  ## Only deletes directorys if `recursive = true`
  if recursive and existsDir(path):
    removeDir(path)
  else:
    removeFile(path)

proc mv*(src, dest: string) =
  ## Moves **src** to **dest**. Acts like `mv` command
  if dirExists(src):
    moveDir(src, dest)
  else:
    moveFile(src, dest)
# Some aliases to make the experience more shell like
{.push inline.}
proc cd*(path: string) =
  ## Alias for [setCurrentDir](https://nim-lang.org/docs/os.html#setCurrentDir%2Cstring)
  setCurrentDir(path)

proc pwd*(): string =
  ## Alias for [getCurrentDir](https://nim-lang.org/docs/os.html#getCurrentDir)
  getCurrentDir()

proc mkdir*(dir: string) =
  ## Alias for [https://nim-lang.org/docs/os.html#createDir%2Cstring]. Works like `mkdir -p`
  createDir(dir)

{.pop.}

template cd*(path: string, body) =
  ## Runs **body** inside **path** and returns to previous directory when finished
  let parent = pwd()
  cd path
  body
  cd parent
proc touch*(path: string) =
  ## Acts like touch command. Creates file if it doesn't exist and updates modification time
  ## if it does
  if not path.fileExists:
    path.writeFile("")
  else:
    path.setLastModificationTime(getTime())

proc error(msg: string) =
  stderr.styledWriteLine(fgRed, "[Error] ", resetStyle, msg)

proc run*(target: Target) =
  ## Runs a target. Target will only run if its out of date or unsatisfied
  let modified = target.lastModified

  var outOfDate = modified == Time.high
  for requirement in target.requires:
    var requirementModTime: Time
    if requirement in targets:
      let requireTarget = targets[requirement]
      run requireTarget
      requirementModTime = requireTarget.lastModified:
    elif requirement.fileExists: # It might be a file
      requirementModTime = requirement.getLastModificationTime()
    else:
      error "Cannot satisfy requirement: " & requirement
      quit 1
    outOfDate = outOfDate or modified < requirementModTime
  if outOfDate or not target.satisified:
    echo "Running ", target.name, "..."
    handle target

proc run*() =
  ## Have at the end of your doit file.
  ## Finds all dependencies and builds as needed
  # TODO: Support multiple targets
  # TODO: Support arguments
  if paramCount() > 0:
    try:
      run targets[paramStr(1)]
    except CommandFailedError as e:
      echo &"Command \"{e.command}\" with exit code {e.code}:"
      echo e.output

  else:
    echo "Available targets:"
    for target in targets.keys:
      echo "  ", target

