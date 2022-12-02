import doit/[api, glob]
import std/[os, unittest, times, strutils]
import std/sequtils

suite "touch":
  test "File created if it doesn't exist":
    const file = "noExist"
    removeFile file
    touch file
    check file.fileExists()

  test "File modification time is updated":
    const file = "exists"
    writeFile(file, "")
    let mtime = file.getLastModificationTime()
    sleep 10 # Need to sleep a second cause of windows precision
    touch file
    check mtime < file.getLastModificationTime()

suite "Glob":
  test "* matches files":
    let g = glob"*"
    check:
      "test.nim".matches(g)
      "hello.txt".matches(g)
      not "test/hello.txt".matches(g)

  test "Multiple * in glob can match":
    let g = glob"*foo*"
    check:
      "foo".matches(g)
      "ffoo".matches(g)
      "foofoofoofoo".matches(g)

  test "** matches directories":
    let g = glob"**"
    check:
      "/home/here/".matches(g)
      "/home/test/hello.txt".matches(g)
      "hello.txt".matches(g)

  test "**/*.nim only matches nim files":
    let g = glob"**/*.nim"
    check:
      "/home/test/test.nim".matches(g)
      "/test.nim".matches(g)
      not "test.nims".matches(g)

  test "Expand finds all files":
    let files = toSeq("**/doit.nim".glob.expand("."))
    for file in walkDirRec("tests/"):
      if file.endsWith("doit.nim"):
        check ("./" & file) in files

