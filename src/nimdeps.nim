## Small utility to list the dependencies of a Nim file
# Put it its own binary so that the user doesn't need to compile the nim compiler
# for their tasks

import "$nim"/compiler / [options, commands, modules, sem,
  passes, passaux,
  idents, modulegraphs, lineinfos, cmdlinehelper,
  pathutils
]
import std/os

if paramCount() != 1:
  echo "Specify a single nim file to get dependencies of e.g. nimdeps test.nim"
  quit 1

let path = paramStr(1)

var retval: ModuleGraph
proc mockCommand(graph: ModuleGraph) =
  retval = graph
  let conf = graph.config
  clearPasses(graph)
  registerPass graph, verbosePass
  registerPass graph, semPass
  conf.setCmd cmdIdeTools
  wantMainModule(conf)

  if not fileExists(conf.projectFull):
    quit "cannot find file: " & conf.projectFull.string

  add(conf.searchPaths, conf.libpath)

  conf.setErrorMaxHighMaybe
  conf.structuredErrorHook = nil

  # compile the project before showing any input so that we already
  # can answer questions right away:
  compileProject(graph)


proc mockCmdLine(pass: TCmdLinePass, cmd: string; conf: ConfigRef) =
  conf.suggestVersion = 0
  if dirExists(path) and not fileExists(path.addFileExt("nim")):
    conf.projectName = findProjectNimFile(conf, path)
    # don't make it worse, report the error the old way:
    if conf.projectName.len == 0: conf.projectName = path
  else:
    conf.projectName = path
let
  cache = newIdentCache()
  conf = newConfigRef()
  self = NimProg(
    suggestMode: true,
    processCmdLine: mockCmdLine
  )
self.initDefinesProg(conf, "nimsuggest")
self.processCmdLineAndProjectPath(conf)

# Find Nim's prefix dir.
let binaryPath = findExe("nim")
if binaryPath == "":
  raise newException(IOError, "Cannot find Nim standard library: Nim compiler not in PATH")

conf.prefixDir = AbsoluteDir"/home/jake/.choosenim/toolchains/nim-#devel/"

var graph = newModuleGraph(cache, conf)
if self.loadConfigsAndProcessCmdLine(cache, conf, graph):
  mockCommand(graph)
  for x in conf.m.fileinfos:
    let path = x.fullPath.string
    echo path
