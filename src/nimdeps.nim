## Small utility to list the dependencies of a Nim file
# Put it its own binary so that the user doesn't need to compile the nim compiler
# for their tasks

import "$nim"/compiler / [options, commands, modules, sem,
  passes, passaux,
  idents, modulegraphs, lineinfos, cmdlinehelper,
  pathutils, platform, condsyms, syntaxes, depends
]

import std/[os, strutils, times]

if paramCount() != 1:
  echo "Specify a single nim file to get dependencies of e.g. nimdeps test.nim"
  quit 1

let path = paramStr(1).expandFileName()

proc log(x: string) = echo x

var retval: ModuleGraph
proc mockCommand(graph: ModuleGraph) =
  retval = graph
  let
    conf = graph.config
    cache = graph.cache
  clearPasses(graph)
  conf.lastCmdTime = epochTime()
  add(conf.searchPaths, conf.libpath)
  conf.setCmd cmdCheck

  defineSymbol(conf.symbols, $conf.backend)
  defineSymbol(conf.symbols, "nimcheck")
  conf.exc = excCpp
  conf.setErrorMaxHighMaybe
  if conf.backend == backendJs:
    conf.globalOptions.excl optThreads
    setTarget(conf.target, osJS, cpuJS)

  registerPass graph, verbosePass
  registerPass graph, semPass

  wantMainModule(conf)

  if not fileExists(conf.projectFull):
    quit "cannot find file: " & conf.projectFull.string


  # Try and remove all output
  excl(conf.notes, hintProcessing)
  excl(conf.mainPackageNotes, hintProcessing)
  conf.writeLnHook = proc (a: string) = discard
  conf.structuredErrorHook = proc (config: ConfigRef; info: TLineInfo; msg: string; severity: Severity) = discard
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
self.initDefinesProg(conf, "nimdeps")
self.processCmdLineAndProjectPath(conf)

# Find Nim's prefix dir.
let binaryPath = findExe("nim")
if binaryPath == "":
  raise newException(IOError, "Cannot find Nim standard library: Nim compiler not in PATH")

conf.prefixDir = getCurrentCompilerExe().parentDir.parentDir.AbsoluteDir
if not dirExists(conf.prefixDir / RelativeDir"lib"):
  conf.prefixDir = AbsoluteDir""

var graph = newModuleGraph(cache, conf)
if self.loadConfigsAndProcessCmdLine(cache, conf, graph):
  mockCommand(graph)
  for x in conf.m.fileinfos:
    let path = x.fullPath.string
    if not path.isEmptyOrWhitespace() and not path.isRelativeTo(conf.prefixDir.string):
      echo path
