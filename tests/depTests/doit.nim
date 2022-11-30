import doit/api

target("foo", []):
  echo "Running foo"

target("bar", ["someFile"]):
  echo "Writing bar"
  writeFile("bar", "")
run()
