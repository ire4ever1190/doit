import std/tables
import std/times
import std/os
import strformat
import std/osproc
import std/terminal
import glob

type
  LastModifiedHandler* = proc (t: Target): Time
    ## Gets ran see when the target was last modified. This is then compared
    ## against the dependencies to see if a target needs to be reran
  TargetHandler* = proc (t: Target)
    ## Gets ran when dependencies are newer than the targe

  SatisfiedHandler* = proc (t: Target): bool
    ## Gets ran to check if a target is satisfied or not.
    ## You won't need to edit this 90% of the time

  Target = object
    name: string
    requires: seq[string]
    # At this point am I just reimplementing inheritance?
    lastModifiedProc: LastModifiedHandler
    satisfiedProc: SatisfiedHandler
    handler: TargetHandler

  CommandFailedError* = object of OSError
    ## Raised when command failed (If using procs here)
    command*, output*: string
    code*: int

# TODO: Lazy load dependencies

var targets: Table[string, Target]

proc safeLastModified(t: Target): Time =
  ## Acts like normal getLastModificationTime except returns oldest date
  ## if file doesnt exist instead of erroring
  if t.name.fileExists:
    result = t.name.getLastModificationTime()

proc target*(name: string, requires: varargs[string] = [],
             lastModified: LastModifiedHandler = safeLastModified,
             handler: TargetHandler = nil,
             satisfier: SatisfiedHandler = nil) =
  targets[name] = Target(
      name: name,
      requires: @requires,
      lastModifiedProc: lastModified,
      handler: handler,
      satisfiedProc: satisfier
  )

proc task*(name: string, requires: openArray[string] = [],
           handler: TargetHandler = nil) =
  target(name, requires, nil, handler, proc (t: Target): bool = false)

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
    target.name.fileExists

proc handle(target: Target) =
  ## Runs targets handler if it exists
  if target.handler != nil:
    target.handler(target)

proc cmd*(cmd: string): string {.discardable.} =
  let process = startProcess(cmd, options = {poUsePath, poEvalCommand, poStdErrToStdOut, poParentStreams})
  let code = process.waitForExit()
  if code != 0:
    raise (ref CommandFailedError)(code: code, command: cmd)

proc rm*(path: string) =
  ## Alias for [removeFile](https://nim-lang.org/docs/os.html#removeFile%2Cstring)
  removeFile(path)

func exe*(file: string): string {.inline, raises: [].} =
  ## Adds platform executable extension to binary name.
  ## Make sure to use this when referring to binaries so they work
  ## across platforms
  runnableExamples:
    when defined(windows):
      assert "main".exe == "main.exe"
    else:
      assert "main".exe == "main"
  #==#
  file.addFileExt(ExeExt)


proc touch*(path: string) =
  ## Acts like touch command. Creates file if it doesn't exist and updates modification time
  ## if it does
  if not path.fileExists:
    path.writeFile("")
  else:
    path.setLastModificationTime(getTime())

proc error(msg: string) =
  stderr.styledWriteLine(fgRed, "[Error] ", resetStyle, msg)

proc run(target: Target) =
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

