import doit/graph
import std/unittest



test "Adding node":
  var graph: Graph
  graph.addNode(newTarget("test"))
  check graph[newTarget("test")].len == 0

test "Adding edge":
  var graph: Graph
  let 
    parent = newTarget("parent")
    child = newTarget("child")

  graph.addNode(parent)
  graph.addNode(child)
  graph.addEdge(parent, child)

  check:
    graph[parent].len == 1
    graph[child].len == 0
