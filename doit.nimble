# Package

version       = "0.1.1"
author        = "Jake Leahy"
description   = "Slightly more complex make alternative"
license       = "MIT"
srcDir        = "src"
installExt    = @["nim"]
bin           = @["doit", "nimdeps"]


# Dependencies

requires "nim >= 1.6.0"
