import doit/api


target("lastMod", []):
  ## Target with custom last modification time
  lastModified: initTime(10, 0)
  echo t.lastModified

target("satisfied", []):
  ## Target that tests if satisifed or not
  satisfied: true
  echo "This shouldn't happen"


run()
