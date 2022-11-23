
import graph
import std/sequtils

var dependencies: Graph

proc target*(name: string, dependencies: seq[string]) =
  ## Adds a series of generic targets to the graph
  let parent = newTarget(name)
  graph.addNode(parent)
  for child in dependencies:
    chi
  graph[newTarget(name)] = dependencies.mapIt(newTarget())
