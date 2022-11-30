import doit/[
  api,
]
import std/unittest
import std/[os, osproc]

suite "Using build system":
  let curr = getCurrentDir()
  setup:
    setCurrentDir(curr)

  test "simple C++ project":
    setCurrentDir("tests/simpleCPP")
    removeFile(".doit")
    let (outp, exitCode) = execCmdEx("doit all")
    checkpoint outp
    check exitCode == 0
    check fileExists("main")
