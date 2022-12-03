import doit/api

target("main.h", []):
  "main.h".writeFile("")

target("main.cpp", ["main.h"])

target("main", ["main.cpp", "foo.h"]):
  cmd "g++ -o main main.cpp"

target("all", ["main"])

task("run", ["main"]):
  cmd "./main"

task("clean", []):
  echo "Removing main"
  rm "main".exe

run()
