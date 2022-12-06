import std/[
  osproc,
  os,
  times
]

##[
  Contains utils to make the experience more shell script like
]##


type
  CommandFailedError* = object of OSError
    ## Raised when command failed (If using procs here)
    command*, output*: string
    code*: int


proc cmd*(cmd: string) =
  ## Runs command. Displays output in your terminal.
  ## If you want to get output or exit code then use [execCmd](https://nim-lang.org/docs/osproc.html#execCmd%2Cstring) or [execCmdEx](https://nim-lang.org/docs/osproc.html#execCmdEx%2Cstring%2Cset%5BProcessOption%5D%2CStringTableRef%2Cstring%2Cstring) instead
  let process = startProcess(cmd, options = {poUsePath, poEvalCommand, poStdErrToStdOut, poParentStreams})
  defer: close process
  let code = process.waitForExit()
  if code != 0:
    raise (ref CommandFailedError)(code: code, command: cmd)

proc rm*(path: string, recursive = false) =
  ## Acts like `rm` command except doesn't fail if file doesn't exist.
  ## Only deletes directorys if `recursive = true`
  if recursive and dirExists(path):
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
  runnableExamples "-r:off":
    let orig = pwd()
    cd "someFolder":
      assert pwd() == orig / "someFolder"
    # Once we exit the block we are back in the original
    assert pwd() == orig
  #==#
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
