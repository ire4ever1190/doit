import doit/api


target("lastMod", []):
  lastModified: initTime(10, 0)
  echo t.lastModified

target("satisfied", []):
  satisfied: true
  echo "This shouldn't happen"


run()
