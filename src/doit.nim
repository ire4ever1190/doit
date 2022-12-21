

when isMainModule:
  import os, osproc, strformat
  const
    srcName = "doit.nim"
    binName = ".doit"
  if not fileExists("doit.nim"):
    echo "Can't find doit.nim in current directory"
    quit 1

  let shouldRebuild = (not fileExists(binName)) or srcName.fileNewer(binName)
  # Build the runner which has all the tasks
  if shouldRebuild:
    echo "Rebuilding runner..."
    let nimExe = findExe("nim")
    if nimExe == "":
      echo "You need the Nim compiler installed"
      quit 1
    let process = startProcess(
      fmt"{nimExe}",
      args = [fmt"--out:{binName}",  "-d:release", "c", srcName],
      options = {poParentStreams, poUsePath}
    )
    if process.waitForExit != 0:
      quit 1
  # Run the runner
  let process = startProcess(
      fmt"./{binName}",
      args = commandLineParams(),
      options = {poParentStreams, poUsePath}
    )
  quit process.waitForExit
