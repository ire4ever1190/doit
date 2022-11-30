import doit/api
import std/[os, unittest, times]

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
