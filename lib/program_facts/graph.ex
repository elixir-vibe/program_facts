defmodule ProgramFacts.Graph do
  @moduledoc """
  Converts ProgramFacts models and facts into `libgraph` graphs.

  ProgramFacts manifests stay JSON-friendly lists and maps. This module is a
  runtime adapter for analyzers and tests that want `Graph.t()` values for
  reachability, path, cycle, and module-dependency checks.
  """

  alias ProgramFacts.{Model, Program}

  @type graph_input :: Program.t() | Model.t()

  @doc """
  Builds a function-level call graph from a generated program or model.
  """
  def call_graph(input) do
    graph!()

    input
    |> model()
    |> then(fn model -> build_graph(model.functions, relationship(model, :call_edges)) end)
  end

  @doc """
  Builds a module-level graph by collapsing function-level call edges to modules.
  """
  def module_graph(input) do
    graph!()

    model = model(input)
    edges = model |> relationship(:call_edges) |> Enum.map(&module_edge/1) |> Enum.uniq()

    build_graph(model.modules, edges)
  end

  @doc """
  Builds the graph used by architecture facts.

  Architecture fixtures express dependency violations through the same call-edge
  model, so this currently aliases `module_graph/1`.
  """
  def architecture_graph(input), do: module_graph(input)

  @doc """
  Returns call edges from a generated program or model.
  """
  def call_edges(input), do: input |> model() |> relationship(:call_edges)

  @doc """
  Returns true when `target` is reachable from `source` in the call graph.
  """
  def reachable?(input, source, target) do
    graph = call_graph(input)

    Graph.has_vertex?(graph, source) and target in Graph.reachable(graph, [source])
  end

  @doc """
  Returns true when every consecutive pair in `path` is an edge in the call graph.
  """
  def path?(input, path) when is_list(path) do
    graph = call_graph(input)

    path
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.all?(fn [source, target] -> Graph.edge(graph, source, target) != nil end)
  end

  @doc """
  Returns strongly connected components that represent cycles in the call graph.
  """
  def cycles(input) do
    graph = call_graph(input)

    graph
    |> Graph.strong_components()
    |> Enum.filter(fn component -> cyclic_component?(graph, component) end)
  end

  @doc """
  Returns graph metrics useful for search scoring and shrink decisions.
  """
  def metrics(input) do
    graph = call_graph(input)
    module_graph = module_graph(input)
    paths = input |> model() |> relationship(:call_paths)

    %{
      vertices: Graph.num_vertices(graph),
      edges: Graph.num_edges(graph),
      modules: Graph.num_vertices(module_graph),
      module_edges: Graph.num_edges(module_graph),
      max_out_degree: max_degree(graph, &Graph.out_degree/2),
      max_in_degree: max_degree(graph, &Graph.in_degree/2),
      components: length(Graph.components(graph)),
      strong_components: length(Graph.strong_components(graph)),
      cycles: length(cycles(input)),
      cyclic?: Graph.is_cyclic?(graph),
      acyclic?: Graph.is_acyclic?(graph),
      longest_declared_call_path: longest_path(paths)
    }
  end

  @doc """
  Returns the induced call subgraph for `vertices`.
  """
  def subgraph(input, vertices) when is_list(vertices) do
    input
    |> call_graph()
    |> Graph.subgraph(vertices)
  end

  @doc """
  Validates graph-derived facts declared by the model.

  Currently validates all declared call paths and declared architecture cycles.
  Raises `ArgumentError` if a declared graph fact is impossible for the edges.
  """
  def validate!(input) do
    model = model(input)
    graph = call_graph(model)

    Enum.each(relationship(model, :call_paths), fn path ->
      unless path?(model, path) do
        raise ArgumentError, "declared call path is not backed by call edges: #{inspect(path)}"
      end
    end)

    model
    |> relationship(:architecture)
    |> Map.get(:cycles, [])
    |> Enum.each(fn cycle ->
      unless cycle_path?(graph, cycle) do
        raise ArgumentError, "declared cycle is not backed by call edges: #{inspect(cycle)}"
      end
    end)

    input
  end

  defp max_degree(graph, degree) do
    graph
    |> Graph.vertices()
    |> Enum.map(&degree.(graph, &1))
    |> Enum.max(fn -> 0 end)
  end

  defp longest_path(paths) do
    paths
    |> Enum.map(&length/1)
    |> Enum.max(fn -> 0 end)
  end

  defp build_graph(vertices, edges) do
    graph = Graph.add_vertices(Graph.new(), vertices)
    Enum.reduce(edges, graph, fn {source, target}, acc -> Graph.add_edge(acc, source, target) end)
  end

  defp model(%Model{} = model), do: model
  defp model(%Program{} = program), do: Model.from_program(program)

  defp relationship(model, key), do: Map.get(model.relationships, key, default_relationship(key))
  defp default_relationship(:architecture), do: %{}
  defp default_relationship(_key), do: []

  defp module_edge(
         {{source_module, _source_function, _source_arity},
          {target_module, _target_function, _target_arity}}
       ),
       do: {source_module, target_module}

  defp cyclic_component?(graph, [_single] = component) do
    vertex = hd(component)
    Graph.edge(graph, vertex, vertex) != nil
  end

  defp cyclic_component?(_graph, [_left, _right | _rest]), do: true
  defp cyclic_component?(_graph, _component), do: false

  defp cycle_path?(_graph, []), do: false
  defp cycle_path?(_graph, [_single]), do: false

  defp cycle_path?(graph, [_left, _right | _rest] = cycle) do
    cycle
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.all?(fn [source, target] -> Graph.edge(graph, source, target) != nil end)
  end

  defp graph! do
    unless Code.ensure_loaded?(Graph) do
      raise "ProgramFacts.Graph requires the optional :libgraph dependency"
    end
  end
end
