import std/[
  tables,
  target
]

type
  Target = object
    unit: Unit
    dependencies: seq[Unit]

  Graph* = Table[string, seq[Target]]


func addNode*(g: var Graph, n: Target) =
  ## Adds a new node into the graph
  g[n] = @[]

proc addEdge*(g: var Graph, parent, child: Target) =
  ## Adds an edge between a parent and a child. Both
  ## child and parent must be added first. Try and use the same
  ## object when you called addNode so you reuse memory
  if child notin g:
    raise (ref KeyError)(msg: "Child doesn't exist in graph")
  
  g[parent] &= child

export tables
