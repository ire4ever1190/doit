# Do it

![Just do it? Mkay](https://media3.giphy.com/media/UqZ4imFIoljlr5O2sM/giphy.gif?cid=ecf05e476ep7oe79xztdvjrq8ae63lj4dxz57nnlhfa3jjyc&rid=giphy.gif&ct=g)

Was bored over summer holidays and decided to finally build the build system I had in my head. Think `make` but with bit more spice.
Is mostly file based (So language agnostic) since my main use for `make` was compiling random scripts and tex files together for assignments.

This really is more of just a hobby thing for personal use so don't expect it to be too fancy

#### Basic usage

First make sure you have both [Nim](nim-lang.org/) and [nimble](https://github.com/nim-lang/nimble) installed and then install `doit` by running `nimble install https://github.com/ire4ever1190/doit`

Then you create a file called `doit.nim` and put this basic structure in it

```nim
import doit/api

# targets and tasks go here

run()
```

You can write any Nim code in here but since you are using this you'll probably want to write some targets and tasks.

- **target**: Code that takes in some **requirement** files and produces a **target file**
- **task**: Code that always runs when its a requirement

A basic Nim project would look like this

```nim
import doit/api

target("program", ["program.nim", "other.nim"]):
  cmd "nim c program.nim"

task("clean"): # Just like .PHONY in make, means this always runs
  rm "./program"

run()
```

Running `doit program` will then compile the program (Running it again will do nothing since it detects no modification) and `doit clean` will remove it

#### Roadmap

- [x] Basic make like operations
- [ ] Detecting cycles in operations
- [ ] Expand the API
- [ ] Documentation
- [ ] Pattern matching
- [ ] Lazy loading of dependencies
- [x] Automatic finding of dependencies for different file types (Maybe through some form of a hooks system for file extensions)
