defmodule ProgramFacts.Generate do
  alias ProgramFacts.{Facts, File, Layout, Locations, Program}

  @policies [
    :single_call,
    :linear_call_chain,
    :branching_call_graph,
    :module_dependency_chain,
    :module_cycle,
    :straight_line_data_flow,
    :assignment_chain,
    :helper_call_data_flow,
    :pipeline_data_flow,
    :if_else,
    :case_clauses,
    :multi_clause_function,
    :pure,
    :io_effect,
    :send_effect,
    :raise_effect,
    :mixed_effect_boundary
  ]

  def policies, do: @policies

  def generate!(opts \\ []) do
    opts =
      Keyword.validate!(opts,
        policy: :linear_call_chain,
        seed: 1,
        depth: 3,
        width: 2,
        layout: :plain
      )

    program =
      case opts[:policy] do
        :single_call -> linear_call_chain(Keyword.put(opts, :depth, 2), :single_call)
        :linear_call_chain -> linear_call_chain(opts, :linear_call_chain)
        :module_dependency_chain -> linear_call_chain(opts, :module_dependency_chain)
        :branching_call_graph -> branching_call_graph(opts)
        :module_cycle -> module_cycle(opts)
        :straight_line_data_flow -> straight_line_data_flow(opts, :straight_line_data_flow)
        :assignment_chain -> assignment_chain(opts)
        :helper_call_data_flow -> straight_line_data_flow(opts, :helper_call_data_flow)
        :pipeline_data_flow -> pipeline_data_flow(opts)
        :if_else -> if_else(opts)
        :case_clauses -> case_clauses(opts)
        :multi_clause_function -> multi_clause_function(opts)
        :pure -> single_effect(opts, :pure)
        :io_effect -> single_effect(opts, :io)
        :send_effect -> single_effect(opts, :send)
        :raise_effect -> single_effect(opts, :exception)
        :mixed_effect_boundary -> mixed_effect_boundary(opts)
        policy -> raise ArgumentError, "unknown generation policy: #{inspect(policy)}"
      end

    program
    |> Layout.apply(opts[:layout])
    |> Locations.attach()
  end

  defp linear_call_chain(opts, policy) do
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

    call_edges = pairwise_edges(functions)

    %Program{
      id: id(seed, policy),
      seed: seed,
      files: files,
      facts: %Facts{
        modules: modules,
        functions: functions,
        call_edges: call_edges,
        call_paths: [functions],
        features: MapSet.new([:remote_call, policy])
      },
      metadata: %{policy: policy, depth: depth}
    }
  end

  defp branching_call_graph(opts) do
    seed = opts[:seed]
    width = max(opts[:width], 2)
    [entry_module | branch_modules] = modules(seed, width + 1)
    entry = {entry_module, :entry, 1}
    branches = Enum.map(branch_modules, &{&1, function_name(&1), 1})

    files =
      [
        render_branch_entry_module(entry_module, branch_modules)
        | Enum.map(branch_modules, &render_chain_module(&1, nil))
      ]

    %Program{
      id: id(seed, :branching_call_graph),
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

  defp module_cycle(opts) do
    seed = opts[:seed]
    depth = max(opts[:depth], 2)
    modules = modules(seed, depth)
    functions = Enum.map(modules, &{&1, function_name(&1), 1})
    cycle_modules = modules ++ [hd(modules)]
    cycle_functions = functions ++ [hd(functions)]

    files =
      modules
      |> Enum.with_index()
      |> Enum.map(fn {module, index} ->
        render_chain_module(module, Enum.at(cycle_modules, index + 1))
      end)

    %Program{
      id: id(seed, :module_cycle),
      seed: seed,
      files: files,
      facts: %Facts{
        modules: modules,
        functions: functions,
        call_edges: pairwise_edges(cycle_functions),
        call_paths: [cycle_functions],
        architecture: %{cycles: [functions]},
        features: MapSet.new([:remote_call, :module_cycle])
      },
      metadata: %{policy: :module_cycle, depth: depth}
    }
  end

  defp straight_line_data_flow(opts, policy) do
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
      id: id(seed, policy),
      seed: seed,
      files: files,
      facts: %Facts{
        modules: [entry_module, helper_module, sink_module],
        functions: [entry, helper, sink],
        call_edges: [{entry, helper}, {entry, sink}],
        call_paths: [[entry, helper], [entry, sink]],
        data_flows: [helper_data_flow(entry, helper, sink)],
        features: MapSet.new([:remote_call, :assignment_chain, :helper_return, :data_flow])
      },
      metadata: %{policy: policy, depth: 3}
    }
  end

  defp assignment_chain(opts) do
    seed = opts[:seed]
    [module] = modules(seed, 1)
    entry = {module, :entry, 1}

    source = """
    defmodule #{inspect(module)} do
      def entry(input) do
        a = input
        b = a
        c = b
        c
      end
    end
    """

    %Program{
      id: id(seed, :assignment_chain),
      seed: seed,
      files: [file(module, source)],
      facts: %Facts{
        modules: [module],
        functions: [entry],
        data_flows: [
          %{
            from: {:param, entry, :input},
            through: [{:var, entry, :a}, {:var, entry, :b}],
            to: {:return, entry},
            variable_names: [:input, :a, :b, :c]
          }
        ],
        features: MapSet.new([:assignment_chain, :data_flow, :return_data_flow])
      },
      metadata: %{policy: :assignment_chain, depth: 1}
    }
  end

  defp pipeline_data_flow(opts) do
    seed = opts[:seed]
    [entry_module, helper_module, sink_module] = modules(seed, 3)
    entry = {entry_module, :entry, 1}
    helper = {helper_module, :normalize, 1}
    sink = {sink_module, :sink, 1}

    files = [
      render_pipeline_entry_module(entry_module, helper_module, sink_module),
      render_helper_module(helper_module),
      render_sink_module(sink_module)
    ]

    %Program{
      id: id(seed, :pipeline_data_flow),
      seed: seed,
      files: files,
      facts: %Facts{
        modules: [entry_module, helper_module, sink_module],
        functions: [entry, helper, sink],
        call_edges: [{entry, helper}, {entry, sink}],
        call_paths: [[entry, helper], [entry, sink]],
        data_flows: [helper_data_flow(entry, helper, sink)],
        features: MapSet.new([:remote_call, :pipeline, :helper_return, :data_flow])
      },
      metadata: %{policy: :pipeline_data_flow, depth: 3}
    }
  end

  defp if_else(opts) do
    seed = opts[:seed]
    [entry_module, ok_module, error_module] = modules(seed, 3)
    entry = {entry_module, :entry, 1}
    ok = {ok_module, :ok, 1}
    error = {error_module, :error, 1}

    files = [
      render_if_else_module(entry_module, ok_module, error_module),
      render_named_sink_module(ok_module, :ok),
      render_named_sink_module(error_module, :error)
    ]

    branch = %{
      function: entry,
      kind: :if,
      clauses: 2,
      calls_by_clause: [
        %{label: "true", call: ok},
        %{label: "false", call: error}
      ]
    }

    branch_program(seed, :if_else, files, [entry, ok, error], branch)
  end

  defp case_clauses(opts) do
    seed = opts[:seed]
    [entry_module, ok_module, error_module] = modules(seed, 3)
    entry = {entry_module, :entry, 1}
    ok = {ok_module, :ok, 1}
    error = {error_module, :error, 1}

    files = [
      render_case_module(entry_module, ok_module, error_module),
      render_named_sink_module(ok_module, :ok),
      render_named_sink_module(error_module, :error)
    ]

    branch = %{
      function: entry,
      kind: :case,
      clauses: 2,
      calls_by_clause: [
        %{label: "{:ok, value}", call: ok},
        %{label: "{:error, reason}", call: error}
      ]
    }

    branch_program(seed, :case_clauses, files, [entry, ok, error], branch)
  end

  defp multi_clause_function(opts) do
    seed = opts[:seed]
    [entry_module, ok_module, error_module] = modules(seed, 3)
    entry = {entry_module, :entry, 1}
    ok = {ok_module, :ok, 1}
    error = {error_module, :error, 1}

    files = [
      render_multi_clause_module(entry_module, ok_module, error_module),
      render_named_sink_module(ok_module, :ok),
      render_named_sink_module(error_module, :error)
    ]

    branch = %{
      function: entry,
      kind: :multi_clause_function,
      clauses: 2,
      calls_by_clause: [
        %{label: "{:ok, value}", call: ok},
        %{label: "{:error, reason}", call: error}
      ]
    }

    branch_program(seed, :multi_clause_function, files, [entry, ok, error], branch)
  end

  defp branch_program(seed, policy, files, [entry, ok, error] = functions, branch) do
    %Program{
      id: id(seed, policy),
      seed: seed,
      files: files,
      facts: %Facts{
        modules: Enum.map(functions, fn {module, _function, _arity} -> module end),
        functions: functions,
        call_edges: [{entry, ok}, {entry, error}],
        call_paths: [[entry, ok], [entry, error]],
        branches: [branch],
        features: MapSet.new([:remote_call, :branch, policy])
      },
      metadata: %{policy: policy, branch_count: 2}
    }
  end

  defp single_effect(opts, effect) do
    seed = opts[:seed]
    [module] = modules(seed, 1)
    function = effect_function(effect)
    mfa = {module, function, effect_arity(effect)}

    %Program{
      id: id(seed, effect_policy(effect)),
      seed: seed,
      files: [render_effect_module(module, effect)],
      facts: %Facts{
        modules: [module],
        functions: [mfa],
        effects: [{mfa, effect}],
        features: MapSet.new([:effect, effect])
      },
      metadata: %{policy: effect_policy(effect), effect: effect}
    }
  end

  defp mixed_effect_boundary(opts) do
    seed = opts[:seed]
    [module] = modules(seed, 1)
    function = {module, :boundary, 2}

    %Program{
      id: id(seed, :mixed_effect_boundary),
      seed: seed,
      files: [render_mixed_effect_module(module)],
      facts: %Facts{
        modules: [module],
        functions: [function],
        effects: [{function, :io}, {function, :send}],
        features: MapSet.new([:effect, :io, :send, :mixed_effect_boundary])
      },
      metadata: %{policy: :mixed_effect_boundary, effects: [:io, :send]}
    }
  end

  defp effect_policy(:pure), do: :pure
  defp effect_policy(:io), do: :io_effect
  defp effect_policy(:send), do: :send_effect
  defp effect_policy(:exception), do: :raise_effect

  defp effect_function(:pure), do: :pure
  defp effect_function(:io), do: :io
  defp effect_function(:send), do: :sends
  defp effect_function(:exception), do: :raises

  defp effect_arity(:send), do: 2
  defp effect_arity(_effect), do: 1

  defp helper_data_flow(entry, helper, sink) do
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
  end

  defp render_effect_module(module, :pure) do
    source = """
    defmodule #{inspect(module)} do
      def pure(value) do
        value
      end
    end
    """

    file(module, source)
  end

  defp render_effect_module(module, :io) do
    source = """
    defmodule #{inspect(module)} do
      def io(value) do
        IO.inspect(value)
      end
    end
    """

    file(module, source)
  end

  defp render_effect_module(module, :send) do
    source = """
    defmodule #{inspect(module)} do
      def sends(pid, message) do
        send(pid, message)
      end
    end
    """

    file(module, source)
  end

  defp render_effect_module(module, :exception) do
    source = """
    defmodule #{inspect(module)} do
      def raises(reason) do
        raise RuntimeError, message: inspect(reason)
      end
    end
    """

    file(module, source)
  end

  defp render_mixed_effect_module(module) do
    source = """
    defmodule #{inspect(module)} do
      def boundary(pid, message) do
        IO.inspect(message)
        send(pid, message)
      end
    end
    """

    file(module, source)
  end

  defp render_if_else_module(module, ok_module, error_module) do
    source = """
    defmodule #{inspect(module)} do
      def entry(input) do
        if input == :ok do
          #{inspect(ok_module)}.ok(input)
        else
          #{inspect(error_module)}.error(input)
        end
      end
    end
    """

    file(module, source)
  end

  defp render_case_module(module, ok_module, error_module) do
    source = """
    defmodule #{inspect(module)} do
      def entry(input) do
        case input do
          {:ok, value} ->
            #{inspect(ok_module)}.ok(value)

          {:error, reason} ->
            #{inspect(error_module)}.error(reason)
        end
      end
    end
    """

    file(module, source)
  end

  defp render_multi_clause_module(module, ok_module, error_module) do
    source = """
    defmodule #{inspect(module)} do
      def entry({:ok, value}) do
        #{inspect(ok_module)}.ok(value)
      end

      def entry({:error, reason}) do
        #{inspect(error_module)}.error(reason)
      end
    end
    """

    file(module, source)
  end

  defp render_named_sink_module(module, function) do
    source = """
    defmodule #{inspect(module)} do
      def #{function}(value) do
        value
      end
    end
    """

    file(module, source)
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

  defp render_branch_entry_module(module, branch_modules) do
    branch_calls =
      branch_modules
      |> Enum.map(fn branch_module ->
        "#{inspect(branch_module)}.#{function_name(branch_module)}(value)"
      end)
      |> Enum.join(",\n      ")

    source = """
    defmodule #{inspect(module)} do
      def entry(value) do
        {
          #{branch_calls}
        }
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

  defp render_pipeline_entry_module(module, helper_module, sink_module) do
    source = """
    defmodule #{inspect(module)} do
      def entry(input) do
        x = input

        y =
          x
          |> #{inspect(helper_module)}.normalize()

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

  defp pairwise_edges(functions) do
    functions
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [source, target] -> {source, target} end)
  end

  defp id(seed, policy), do: "pf_#{seed}_#{policy}"
end
