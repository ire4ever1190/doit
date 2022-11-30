import std/unittest
import std/[os, osproc, strutils]

suite "Black box tests":
  let curr = getCurrentDir()
  setup:
    setCurrentDir(curr)

  proc runTask(task: string): string =
    ## Just runs a task in the current dir
    let (outp, exitCode) = execCmdEx("doit " & task)
    checkpoint outp
    check exitCode == 0
    result = outp

  template goto(folder) =
    ## Goes into a project folder and compiles the doit runner
    setCurrentDir("tests" / folder)
    if compileOption("forceBuild"):
      removeFile(".doit")
    let (outp, exitCode) = execCmdEx("doit ")
    checkpoint outp
    check exitCode == 0

  test "simple C++ project":
    goto("simpleCPP")
    removeFile("main")
    discard runTask("main")
    check fileExists("main")

  test "Tasks always run":
    goto("simpleCPP")
    writeFile("clean", "")
    discard runTask("main")
    check:
      fileExists("main")
      "Removing main" in runTask("clean")
      not fileExists("main")
      "Removing main" in runTask("clean")

  test "Target runs if not satisfied":
    goto("depTests")
    check "Running foo" in runTask("foo")

  test "Target doesn't run if satisfied":
    goto("depTests")
    writeFile("foo", "")
    defer: removeFile("foo")
    check "Running foo" notin runTask("foo")

  test "Fails if requirement missing":
    goto("depTests")
    removeFile("someFile")
    let (outp, exitCode) = execCmdEx("doit bar")
    check:
      "Cannot satisfy requirement: someFile" in outp
      exitCode == 1

  test "Runs if requirement is newer":
    goto("depTests")
    writeFile("bar", "")
    sleep 10
    writeFile("someFile", "")
    let (outp, exitCode) = execCmdEx("doit bar")
    check:
      "Writing bar" in outp
      exitCode == 0
