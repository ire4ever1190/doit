import doit/api

target("main.h", []):
  "main.h".writeFile("")

target("main.cpp", ["main.h"])

target("main".exe, ["main.cpp", "foo.h"]):
  cmd "g++ -o main main.cpp"

target("all", ["main".exe])

task("run", ["main".exe]):
  cmd "./main".exe

task("clean", []):
  echo "Removing main"
  rm "main".exe

run()
