defmodule ProgramFacts.Generate.CallGraph do
  @moduledoc false

  alias ProgramFacts.{Facts, Naming, Program}
  alias ProgramFacts.Generate.Helpers
  alias ProgramFacts.Render.Elixir, as: Render

  def single_call(opts), do: linear_call_chain(Keyword.put(opts, :depth, 2), :single_call)
  def linear_call_chain(opts), do: linear_call_chain(opts, :linear_call_chain)
  def module_dependency_chain(opts), do: linear_call_chain(opts, :module_dependency_chain)

  def linear_call_chain(opts, policy) do
    seed = opts[:seed]
    depth = max(opts[:depth], 2)
    modules = Naming.modules(seed, depth)
    functions = Enum.map(modules, &{&1, Naming.function_name(&1), 1})

    files =
      modules
      |> Enum.with_index()
      |> Enum.map(fn {module, index} ->
        Render.chain_module(module, Enum.at(modules, index + 1))
      end)

    %Program{
      id: Helpers.id(seed, policy),
      seed: seed,
      files: files,
      facts: %Facts{
        modules: modules,
        functions: functions,
        call_edges: Helpers.pairwise_edges(functions),
        call_paths: [functions],
        features: MapSet.new([:remote_call, policy])
      },
      metadata: %{policy: policy, depth: depth}
    }
  end

  def branching_call_graph(opts) do
    seed = opts[:seed]
    width = max(opts[:width], 2)
    [entry_module | branch_modules] = Naming.modules(seed, width + 1)
    entry = {entry_module, :entry, 1}
    branches = Enum.map(branch_modules, &{&1, Naming.function_name(&1), 1})

    files = [
      Render.branch_entry_module(entry_module, branch_modules)
      | Enum.map(branch_modules, &Render.chain_module(&1, nil))
    ]

    %Program{
      id: Helpers.id(seed, :branching_call_graph),
      seed: seed,
      files: files,
      facts: %Facts{
        modules: [entry_module | branch_modules],
        functions: [entry | branches],
        call_edges: Enum.map(branches, &{entry, &1}),
        call_paths: Enum.map(branches, &[entry, &1]),
        features: MapSet.new([:remote_call, :branching_call_graph, :fan_out])
      },
      metadata: %{policy: :branching_call_graph, width: width}
    }
  end

  def module_cycle(opts) do
    seed = opts[:seed]
    depth = max(opts[:depth], 2)
    modules = Naming.modules(seed, depth)
    functions = Enum.map(modules, &{&1, Naming.function_name(&1), 1})
    cycle_modules = modules ++ [hd(modules)]
    cycle_functions = functions ++ [hd(functions)]

    files =
      modules
      |> Enum.with_index()
      |> Enum.map(fn {module, index} ->
        Render.chain_module(module, Enum.at(cycle_modules, index + 1))
      end)

    %Program{
      id: Helpers.id(seed, :module_cycle),
      seed: seed,
      files: files,
      facts: %Facts{
        modules: modules,
        functions: functions,
        call_edges: Helpers.pairwise_edges(cycle_functions),
        call_paths: [cycle_functions],
        architecture: %{cycles: [functions]},
        features: MapSet.new([:remote_call, :module_cycle])
      },
      metadata: %{policy: :module_cycle, depth: depth}
    }
  end
end
