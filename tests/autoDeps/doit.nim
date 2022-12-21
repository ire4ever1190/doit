import doit/api
import sequtils
import strutils

target("test", ["test.nim"]):
  echo "Compiling test.nim"
  cmd "nim c test.nim"

task("allDeps", ["*.nim"]):
  echo "Listing requirements"
  for requirement in t.requirements:
    echo requirement

proc echoRequirements(t: Target) =
  echo t.requirements.toSeq().join("\n")

task("frontend.js", ["frontend.nim"]):
  t.echoRequirements()

task("c++", ["test.cpp"]):
  t.echoRequirements()

run()
