import doit/api
import doit/deps


target("test", "test".nim):
  echo "Compiling test.nim"
  cmd "nim c test.nim"

run()
