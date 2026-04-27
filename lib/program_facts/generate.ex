defmodule ProgramFacts.Generate do
  alias ProgramFacts.{Facts, File, Program}

  @policies [:linear_call_chain, :straight_line_data_flow]

  def policies, do: @policies

  def generate!(opts \\ []) do
    opts = Keyword.validate!(opts, policy: :linear_call_chain, seed: 1, depth: 3)

    case opts[:policy] do
      :linear_call_chain -> linear_call_chain(opts)
      :straight_line_data_flow -> straight_line_data_flow(opts)
      policy -> raise ArgumentError, "unknown generation policy: #{inspect(policy)}"
    end
  end

  defp linear_call_chain(opts) do
    seed = opts[:seed]
    depth = max(opts[:depth], 2)
    modules = modules(seed, depth)
    functions = Enum.map(modules, &{&1, function_name(&1), 1})

    files =
      modules
      |> Enum.with_index()
      |> Enum.map(fn {module, index} ->
        next_module = Enum.at(modules, index + 1)
        render_chain_module(module, next_module)
      end)

    call_edges =
      functions
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map(fn [source, target] -> {source, target} end)

    %Program{
      id: id(seed, :linear_call_chain),
      seed: seed,
      files: files,
      facts: %Facts{
        modules: modules,
        functions: functions,
        call_edges: call_edges,
        call_paths: [functions],
        features: MapSet.new([:remote_call, :linear_call_chain])
      },
      metadata: %{policy: :linear_call_chain, depth: depth}
    }
  end

  defp straight_line_data_flow(opts) do
    seed = opts[:seed]
    [entry_module, helper_module, sink_module] = modules(seed, 3)

    entry = {entry_module, :entry, 1}
    helper = {helper_module, :normalize, 1}
    sink = {sink_module, :sink, 1}

    files = [
      render_entry_data_flow_module(entry_module, helper_module, sink_module),
      render_helper_module(helper_module),
      render_sink_module(sink_module)
    ]

    %Program{
      id: id(seed, :straight_line_data_flow),
      seed: seed,
      files: files,
      facts: %Facts{
        modules: [entry_module, helper_module, sink_module],
        functions: [entry, helper, sink],
        call_edges: [{entry, helper}, {entry, sink}],
        call_paths: [[entry, helper], [entry, sink]],
        data_flows: [
          %{
            from: {:param, entry, :input},
            through: [
              {:var, entry, :x},
              {:arg, helper, 0},
              {:return, helper},
              {:var, entry, :y}
            ],
            to: {:arg, sink, 0},
            variable_names: [:input, :x, :value, :y]
          }
        ],
        features: MapSet.new([:remote_call, :assignment_chain, :helper_return, :data_flow])
      },
      metadata: %{policy: :straight_line_data_flow, depth: 3}
    }
  end

  defp render_chain_module(module, nil) do
    function = function_name(module)

    source = """
    defmodule #{inspect(module)} do
      def #{function}(value) do
        value
      end
    end
    """

    file(module, source)
  end

  defp render_chain_module(module, next_module) do
    function = function_name(module)
    next_function = function_name(next_module)

    source = """
    defmodule #{inspect(module)} do
      def #{function}(value) do
        #{inspect(next_module)}.#{next_function}(value)
      end
    end
    """

    file(module, source)
  end

  defp render_entry_data_flow_module(module, helper_module, sink_module) do
    source = """
    defmodule #{inspect(module)} do
      def entry(input) do
        x = input
        y = #{inspect(helper_module)}.normalize(x)
        #{inspect(sink_module)}.sink(y)
      end
    end
    """

    file(module, source)
  end

  defp render_helper_module(module) do
    source = """
    defmodule #{inspect(module)} do
      def normalize(value) do
        value
      end
    end
    """

    file(module, source)
  end

  defp render_sink_module(module) do
    source = """
    defmodule #{inspect(module)} do
      def sink(value) do
        value
      end
    end
    """

    file(module, source)
  end

  defp file(module, source) do
    %File{path: module_path(module), source: source, kind: :elixir}
  end

  defp modules(seed, count) do
    namespace = Module.concat([Generated, ProgramFacts, "Seed#{seed}"])

    0..(count - 1)
    |> Enum.map(fn index -> Module.concat(namespace, module_suffix(index)) end)
  end

  defp module_suffix(index) do
    index
    |> then(&(&1 + ?A))
    |> List.wrap()
    |> to_string()
  end

  defp function_name(module) do
    module
    |> Module.split()
    |> List.last()
    |> String.downcase()
    |> String.to_atom()
  end

  defp module_path(module) do
    path =
      module
      |> Module.split()
      |> Enum.map(&Macro.underscore/1)
      |> Path.join()

    Path.join("lib", path <> ".ex")
  end

  defp id(seed, policy), do: "pf_#{seed}_#{policy}"
end
