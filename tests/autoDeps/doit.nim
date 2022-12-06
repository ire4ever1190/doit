import doit/api
import doit/deps


target("test", ["test.nim"]):
  echo "Compiling test.nim"
  cmd "nim c test.nim"

task("allDeps", ["*.nim"]):
  echo "Listing requirements"
  for requirement in t.requirements:
    echo requirement

run()
