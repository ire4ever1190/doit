import std/unittest
import doit/api
import std/[os, osproc, strutils]
import doit/api

# Build doit first
block:
  let (outp, exitCode) = execCmdEx("nimble build")
  assert exitCode == QuitSuccess, outp


let doitBin = expandFileName("doit".exe)


template runTask(task: string): string =
  ## Just runs a task in the current dir
  let (outp, exitCode) = execCmdEx(doitBin & " " & task)
  checkpoint outp
  check exitCode == QuitSuccess
  outp

template goto(folder) =
  ## Goes into a project folder and compiles the doit runner
  setCurrentDir("tests" / folder)
  if compileOption("forceBuild"):
    rm ".doit".exe
  let (outp, exitCode) = execCmdEx(doitBin)
  checkpoint outp
  check exitCode == QuitSuccess

suite "Black box tests":
  let curr = getCurrentDir()
  setup:
    setCurrentDir(curr)


  test "simple C++ project":
    goto("simpleCPP")
    removeFile("main".exe)
    discard runTask("main".exe)
    check fileExists("main".exe)

  test "Tasks always run":
    goto("simpleCPP")
    writeFile("clean", "")
    discard runTask("main".exe)
    check:
      fileExists("main".exe)
      "Removing main" in runTask("clean")
      not fileExists("main".exe)
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
    let (outp, exitCode) = execCmdEx(doItBin & " bar")
    check:
      "Cannot satisfy requirement: 'someFile'" in outp
      exitCode == QuitFailure

  test "Runs if requirement is newer":
    goto("depTests")
    touch "bar"
    sleep 10
    touch "someFile"
    check "Writing bar" in runTask("bar")

  test "Automatically finds dependencies":
    goto("autoDeps")
    rm "test"
    check "Compiling test.nim" in runTask("test")
    check "Compiling test.nim" notin runTask("test")
    touch "foo.nim"
    check "Compiling test.nim" in runTask("test")

  test "Globs are expanded":
    goto "autoDeps"
    let outp = runTask("allDeps")
    check:
      "doit.nim" in outp
      "foo.nim" in outp
      "test.nim" in  outp

  test "Last modification handler":
    goto "macroDSL"
    check $initTime(10, 0) in runTask("lastMod")

  test "Satisified handler":
    goto "macroDSL"
    check "This shouldn't happen" notin runTask("satisfied")

  test "Help message in output":
    goto "macroDSL"
    let help = runTask("")
    check:
      "Target with custom last modification time" in help
      "Target that tests if satisifed or not" in help
  setCurrentDir(curr)

suite "Auto deps":
  cd "tests/autoDeps"
  when compileOption("forceBuild"):
    rm ".doit".exe

  test "Nim (JS backend)":
    let outp = runTask("frontend.js")
    check:
      "frontend.nim" in outp

  test "C++":
    let outp = runTask("c++")
    check:
      "test.cpp" in outp
      "test.h" in outp
