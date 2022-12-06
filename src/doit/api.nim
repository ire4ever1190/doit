import std/tables
import std/times
import std/os
import strformat
import std/terminal
import std/macros
import std/strutils

import glob, scriptUtils


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
    help*: string
    requires: seq[string]
    # At this point am I just reimplementing inheritance?
    lastModifiedProc: LastModifiedHandler
    satisfiedProc: SatisfiedHandler
    handler: TargetHandler
# TODO: Lazy load dependencies

var targets*: Table[string, Target]
  ## All the targets


proc safeLastModified(t: Target): Time =
  ## Acts like normal getLastModificationTime except returns oldest date
  ## if file doesnt exist instead of erroring
  if t.name.fileExists or t.name.dirExists:
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

iterator requirements*(t: Target): string =
  # Keep track of when the original rules end
  # so that we don't keep expanding rules
  let origEnd = t.requires.len - 1
  var
    requirements = t.requires
    i = 0
  # Expand globs all at once. Says having to recurse through directories multiple times
  block:
    var globs: seq[Glob]
    for requirement in requirements:
      if '*' in requirement:
        globs &= glob(requirement)
    for file in globs.expand("."):
      requirements &= file
  echo requirements
  while i < requirements.len:
    let requirement = requirements[i]
    if '*' notin requirement:
      yield requirement
    inc i

proc parseTargetImpl(body: NimNode, isTask: bool): tuple[hand, lastMod, satisfied: NimNode, help: string] =
  result.hand = newStmtList()
  result.lastMod = newNilLit()
  result.satisfied = newNilLit()


  for node in body:
    if node.kind == nnkCall and node[0].kind == nnkIdent:
      case node[0].strVal.nimIdentNormalize():
      of "lastmodified":
        if result.lastMod.kind != nnkNilLit:
          "lastModified handler already specified".error(node)
        result.lastMod = node[1]
      of "satisfied":
        if isTask:
          "Cannot have custom satisfier in a task".error(node)
        else:
          if result.satisfied.kind != nnkNilLit:
            "satisfied handler already specified".error(node)
          result.satisfied = node[1]
      else:
        result.hand &= node
    elif node.kind == nnkCommentStmt:
      if result.help == "":
        result.help = node.strVal
    else:
      result.hand &= node
  # Build the needed procs
  proc targetParam(): NimNode = newIdentDefs(ident"t", bindSym"Target")
  if result.lastMod.kind != nnkNilLit:
    result.lastMod = newProc(
      params = [bindSym"Time", targetParam()],
      body = result.lastMod
    )
  if result.satisfied.kind != nnkNilLit:
    result.satisfied = newProc(
      params = [bindSym"bool", targetParam()],
      body = result.satisfied
    )
  result.hand = newProc(
    params = [newEmptyNode(), targetParam()],
    body = result.hand
  )


macro target*(name: string, requirements: openArray[string], body: untyped) =
  ## Allows you to attach some code to a target.handlerBody
  ## The target can be accessed from within the handler with variable `t`
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
  let (handler, lastModified, satisifed, help) = parseTargetImpl(body, false)
  result = quote do:
    addTarget(`name`, `requirements`, `help`, `lastModified`, `satisifed`, `handler`)

macro task*(name: string, requirements: untyped, body: untyped): untyped =
  ## Like [macro target] except doesn't support satisfied block (Since tasks can never be satisifed)
  let (handler, lastModified, _, help) = parseTargetImpl(body, true)
  result = quote do:
    addTask(`name`, `requirements`, `help`, `lastModified`, `handler`)

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
    target.name.fileExists or target.name.dirExists

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

proc run*(target: Target) =
  ## Runs a target. Target will only run if its out of date or unsatisfied
  let modified = target.lastModified

  var outOfDate = modified == Time.high
  for requirement in target.requirements:
    var requirementModTime: Time
    if requirement in targets:
      let requireTarget = targets[requirement]
      run requireTarget
      requirementModTime = requireTarget.lastModified:
    elif requirement.fileExists:
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
