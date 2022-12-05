import std/tables
import std/times
import std/os
import strformat
import std/terminal
import std/macros
import std/strutils

import glob, scriptUtils

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
    help: string
    requires: seq[string]
    # At this point am I just reimplementing inheritance?
    lastModifiedProc: LastModifiedHandler
    satisfiedProc: SatisfiedHandler
    handler: TargetHandler
# TODO: Lazy load dependencies


var targets: Table[string, Target]


proc safeLastModified(t: Target): Time =
  ## Acts like normal getLastModificationTime except returns oldest date
  ## if file doesnt exist instead of erroring
  if t.name.fileExists:
    result = t.name.getLastModificationTime()

proc alwaysFalse(t: Target): bool = false

proc addTarget(name: string, requires: openArray[string],
               help = "",
               lastModified: LastModifiedHandler = nil,
               satisfier: SatisfiedHandler = nil,
               handler: TargetHandler = nil) =
  ## Proc to add target directly with your own handlers
  targets[name] = Target(
      name: name,
      requires: @requires,
      help: help,
      lastModifiedProc: lastModified,
      handler: handler,
      satisfiedProc: satisfier
  )


proc addTask*(name: string, requires: openArray[string],
              help = "",
              lastModified: LastModifiedHandler = nil,
              handler: TargetHandler = nil) =
  ## Proc to add task directly with your own handlers
  addTarget(name, requires, help, nil, alwaysFalse, handler)

proc target*(name: string, requirements: openArray[string]) =
  ## Add a target with no handler but with requirements.
  ## Can be used to alias a target but [proc task] is more recommended when needing to alias
  addTarget(name, requirements)

proc task*(name: string, requirements: openArray[string]) =
  ## Adds a task with no handler but with requirements.
  ## Use this to alias a series of requirements
  addTask(name, requirements)

macro target*(name: string, requirements: openArray[string], body: untyped) =
  ## Allows you to attach some code to a target.
  runnableExamples:
    target("something", ["something.nim"]):
      cmd "nim c something.nim"
  ## The body allows a DSL to overwrite how `doit` checks if a target
  ## is satisified and when it was last modified (This are both optional)
  runnableExamples:
    import std/random
    target("something", ["something.nim"]):
      lastModified:
        getTime() + 5.minutes # Lets say it was modified in the future
      satisifed:
        # Might be satisifed, might not be
        rand(0..10) mod 2 == 0

      cmd "nim c something.nim"
  #==#
  # Copy the handler body across.
  # We need to do this since we need to find blocks that are other handlers
  result = newStmtList()
  var
    handlerBody = newStmtList()
    lastModifiedBody: NimNode = newNilLit()
    satisfiedBody: NimNode = newNilLit()
    help = ""
  for node in body:
    if node.kind == nnkCall and node[0].kind == nnkIdent:
      case node[0].strVal.nimIdentNormalize():
      of "lastmodified":
        if lastModifiedBody.kind != nnkNilLit:
          "lastModified handler already specified".error(node)
        lastModifiedBody = node[1]
      of "satisfied":
        if satisfiedBody.kind != nnkNilLit:
          "satisfied handler already specified".error(node)
        satisfiedBody = node[1]
      else:
        handlerBody &= node
    elif node.kind == nnkCommentStmt:
      if help == "":
        help = node.strVal
    else:
      handlerBody &= node
  # Build the needed procs
  proc targetParam(): NimNode = newIdentDefs(ident"t", bindSym"Target")
  if lastModifiedBody.kind != nnkNilLit:
    lastModifiedBody = newProc(
      params = [bindSym"Time", targetParam()],
      body = lastModifiedBody
    )
  if satisfiedBody.kind != nnkNilLit:
    satisfiedBody = newProc(
      params = [bindSym"bool", targetParam()],
      body = satisfiedBody
    )
  handlerBody = newProc(
    params = [newEmptyNode(), targetParam()],
    body = handlerBody
  )
  result = quote do:
    addTarget(`name`, `requirements`, `help`, `lastModifiedBody`, `satisfiedBody`, `handlerBody`)

macro task*(name: string, requirements: untyped, body: untyped): untyped =
  ## Like [macro target] except doesn't support satisfied block (Since tasks can never be satisifed)
  result = newStmtList()
  var
    handlerBody = newStmtList()
    lastModifiedBody: NimNode = newNilLit()
    help = ""
  for node in body:
    if node.kind == nnkCall and node[0].kind == nnkIdent:
      case node[0].strVal.nimIdentNormalize():
      of "lastmodified":
        if lastModifiedBody.kind != nnkNilLit:
          "lastModified handler already specified".error(node)
        lastModifiedBody = node[1]
      of "satisfied":
        "Cannot have custom satisfier in a task".error(node)
      else:
        handlerBody &= node
    elif node.kind == nnkCommentStmt:
      if help == "":
        help = node.strVal
      else:
        "Please have all help comments together".error(node)
    else:
      handlerBody &= node
  # Build the needed procs
  proc targetParam(): NimNode = newIdentDefs(ident"t", bindSym"Target")
  if lastModifiedBody.kind != nnkNilLit:
    lastModifiedBody = newProc(
      params = [bindSym"Time", targetParam()],
      body = lastModifiedBody
    )
  handlerBody = newProc(
    params = [newEmptyNode(), targetParam()],
    body = handlerBody
  )
  result = quote do:
    addTask(`name`, `requirements`, `help`, `lastModifiedBody`, `handlerBody`)

proc lastModified*(target: Target): Time =
  ## Returns the time a target was last modified.
  ## If the target as no way of telling then we assume its always modified
  if target.lastModifiedProc != nil:
    target.lastModifiedProc(target)
  else:
    target.safeLastModified()

proc satisfied*(target: Target): bool =
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

proc error(msg: string) =
  stderr.styledWriteLine(fgRed, "[Error] ", resetStyle, msg)
  quit 1

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
  if outOfDate or not target.satisfied:
    echo "Running ", target.name, "..."
    handle target

proc run*() =
  ## Have at the end of your doit file.
  ## Finds all dependencies and builds as needed
  # TODO: Support multiple targets
  # TODO: Support arguments
  if paramCount() > 0:
    try:
      let target = paramStr(1)
      if targets.hasKey(target):
        run targets[paramStr(1)]
      else:
        error("Cannot find target: " & target) # Use this when ever running checks
    except CommandFailedError as e:
      error(&"Command \"{e.command}\" with exit code {e.code}:\n{e.output}")
  else:
    echo "Available targets:"
    for target in targets.values:
      stdout.styledWriteLine(fgCyan, target.name, resetStyle)
      echo target.help.indent(2)

export scriptUtils
export times
