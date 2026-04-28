defmodule ProgramFacts.Generate do
  @moduledoc false

  alias ProgramFacts.{Facts, File, Layout, Locations, Naming, Program}

  @max_seed Naming.max_seed()
  @max_module_count Naming.max_module_count()

  @policies [
    :single_call,
    :linear_call_chain,
    :branching_call_graph,
    :module_dependency_chain,
    :module_cycle,
    :straight_line_data_flow,
    :assignment_chain,
    :branch_data_flow,
    :helper_call_data_flow,
    :pipeline_data_flow,
    :return_data_flow,
    :if_else,
    :case_clauses,
    :cond_branches,
    :with_chain,
    :anonymous_fn_branch,
    :multi_clause_function,
    :nested_branches,
    :pure,
    :io_effect,
    :send_effect,
    :raise_effect,
    :read_effect,
    :write_effect,
    :mixed_effect_boundary,
    :layered_valid,
    :forbidden_dependency,
    :layer_cycle,
    :public_api_boundary_violation,
    :internal_boundary_violation,
    :allowed_effect_violation
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

    opts = validate_ranges!(opts)

    opts[:policy]
    |> generate_policy!(opts)
    |> Layout.apply(opts[:layout])
    |> Locations.attach()
  end

  defp validate_ranges!(opts) do
    validate_seed!(opts[:seed])
    validate_depth!(opts[:depth])
    validate_width!(opts[:width])
    opts
  end

  defp validate_seed!(seed) when is_integer(seed) and seed >= 0 and seed <= @max_seed,
    do: :ok

  defp validate_seed!(_seed) do
    raise ArgumentError, ":seed must be an integer between 0 and #{@max_seed}"
  end

  defp validate_depth!(depth)
       when is_integer(depth) and depth >= 1 and depth <= @max_module_count,
       do: :ok

  defp validate_depth!(_depth) do
    raise ArgumentError, ":depth must be an integer between 1 and #{@max_module_count}"
  end

  defp validate_width!(width)
       when is_integer(width) and width >= 1 and width < @max_module_count,
       do: :ok

  defp validate_width!(_width) do
    raise ArgumentError, ":width must be an integer between 1 and #{@max_module_count - 1}"
  end

  defp generate_policy!(:single_call, opts),
    do: linear_call_chain(Keyword.put(opts, :depth, 2), :single_call)

  defp generate_policy!(:linear_call_chain, opts), do: linear_call_chain(opts, :linear_call_chain)

  defp generate_policy!(:module_dependency_chain, opts),
    do: linear_call_chain(opts, :module_dependency_chain)

  defp generate_policy!(:branching_call_graph, opts), do: branching_call_graph(opts)
  defp generate_policy!(:module_cycle, opts), do: module_cycle(opts)

  defp generate_policy!(:straight_line_data_flow, opts),
    do: straight_line_data_flow(opts, :straight_line_data_flow)

  defp generate_policy!(:assignment_chain, opts), do: assignment_chain(opts)
  defp generate_policy!(:branch_data_flow, opts), do: branch_data_flow(opts)

  defp generate_policy!(:helper_call_data_flow, opts),
    do: straight_line_data_flow(opts, :helper_call_data_flow)

  defp generate_policy!(:pipeline_data_flow, opts), do: pipeline_data_flow(opts)
  defp generate_policy!(:return_data_flow, opts), do: return_data_flow(opts)
  defp generate_policy!(:if_else, opts), do: if_else(opts)
  defp generate_policy!(:case_clauses, opts), do: case_clauses(opts)
  defp generate_policy!(:cond_branches, opts), do: cond_branches(opts)
  defp generate_policy!(:with_chain, opts), do: with_chain(opts)
  defp generate_policy!(:anonymous_fn_branch, opts), do: anonymous_fn_branch(opts)
  defp generate_policy!(:multi_clause_function, opts), do: multi_clause_function(opts)
  defp generate_policy!(:nested_branches, opts), do: nested_branches(opts)
  defp generate_policy!(:pure, opts), do: single_effect(opts, :pure)
  defp generate_policy!(:io_effect, opts), do: single_effect(opts, :io)
  defp generate_policy!(:send_effect, opts), do: single_effect(opts, :send)
  defp generate_policy!(:raise_effect, opts), do: single_effect(opts, :exception)
  defp generate_policy!(:read_effect, opts), do: single_effect(opts, :read)
  defp generate_policy!(:write_effect, opts), do: single_effect(opts, :write)
  defp generate_policy!(:mixed_effect_boundary, opts), do: mixed_effect_boundary(opts)
  defp generate_policy!(:layered_valid, opts), do: architecture_program(opts, :layered_valid)

  defp generate_policy!(:forbidden_dependency, opts),
    do: architecture_program(opts, :forbidden_dependency)

  defp generate_policy!(:layer_cycle, opts), do: architecture_program(opts, :layer_cycle)

  defp generate_policy!(:public_api_boundary_violation, opts),
    do: architecture_program(opts, :public_api_boundary_violation)

  defp generate_policy!(:internal_boundary_violation, opts),
    do: architecture_program(opts, :internal_boundary_violation)

  defp generate_policy!(:allowed_effect_violation, opts),
    do: architecture_program(opts, :allowed_effect_violation)

  defp generate_policy!(policy, _opts),
    do: raise(ArgumentError, "unknown generation policy: #{inspect(policy)}")

  defp linear_call_chain(opts, policy) do
    seed = opts[:seed]
    depth = max(opts[:depth], 2)
    modules = Naming.modules(seed, depth)
    functions = Enum.map(modules, &{&1, Naming.function_name(&1), 1})

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
    [entry_module | branch_modules] = Naming.modules(seed, width + 1)
    entry = {entry_module, :entry, 1}
    branches = Enum.map(branch_modules, &{&1, Naming.function_name(&1), 1})

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
    modules = Naming.modules(seed, depth)
    functions = Enum.map(modules, &{&1, Naming.function_name(&1), 1})
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
    [entry_module, helper_module, sink_module] = Naming.modules(seed, 3)

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
    [module] = Naming.modules(seed, 1)
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

  defp branch_data_flow(opts) do
    seed = opts[:seed]
    [entry_module, sink_module] = Naming.modules(seed, 2)
    entry = {entry_module, :entry, 1}
    sink = {sink_module, :sink, 1}

    files = [
      render_branch_data_flow_module(entry_module, sink_module),
      render_sink_module(sink_module)
    ]

    %Program{
      id: id(seed, :branch_data_flow),
      seed: seed,
      files: files,
      facts: %Facts{
        modules: [entry_module, sink_module],
        functions: [entry, sink],
        call_edges: [{entry, sink}],
        call_paths: [[entry, sink]],
        data_flows: [
          %{
            from: {:param, entry, :input},
            through: [{:var, entry, :selected}],
            to: {:arg, sink, 0},
            variable_names: [:input, :selected],
            branch: :if
          }
        ],
        branches: [
          %{
            function: entry,
            kind: :if,
            clauses: 2,
            calls_by_clause: [
              %{label: "input == :ok", call: sink},
              %{label: "else", call: sink}
            ]
          }
        ],
        features: MapSet.new([:branch, :data_flow, :remote_call])
      },
      metadata: %{policy: :branch_data_flow, depth: 2}
    }
  end

  defp return_data_flow(opts) do
    seed = opts[:seed]
    [module] = Naming.modules(seed, 1)
    entry = {module, :entry, 1}

    source = """
    defmodule #{inspect(module)} do
      def entry(input) do
        x = input
        x
      end
    end
    """

    %Program{
      id: id(seed, :return_data_flow),
      seed: seed,
      files: [file(module, source)],
      facts: %Facts{
        modules: [module],
        functions: [entry],
        data_flows: [
          %{
            from: {:param, entry, :input},
            through: [{:var, entry, :x}],
            to: {:return, entry},
            variable_names: [:input, :x]
          }
        ],
        features: MapSet.new([:data_flow, :return_data_flow])
      },
      metadata: %{policy: :return_data_flow, depth: 1}
    }
  end

  defp pipeline_data_flow(opts) do
    seed = opts[:seed]
    [entry_module, helper_module, sink_module] = Naming.modules(seed, 3)
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
    [entry_module, ok_module, error_module] = Naming.modules(seed, 3)
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
    [entry_module, ok_module, error_module] = Naming.modules(seed, 3)
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

  defp cond_branches(opts) do
    seed = opts[:seed]
    [entry_module, ok_module, error_module] = Naming.modules(seed, 3)
    entry = {entry_module, :entry, 1}
    ok = {ok_module, :ok, 1}
    error = {error_module, :error, 1}

    files = [
      render_cond_module(entry_module, ok_module, error_module),
      render_named_sink_module(ok_module, :ok),
      render_named_sink_module(error_module, :error)
    ]

    branch = %{
      function: entry,
      kind: :cond,
      clauses: 2,
      calls_by_clause: [
        %{label: "input == :ok", call: ok},
        %{label: "true", call: error}
      ]
    }

    branch_program(seed, :cond_branches, files, [entry, ok, error], branch)
  end

  defp with_chain(opts) do
    seed = opts[:seed]
    [entry_module, ok_module, error_module] = Naming.modules(seed, 3)
    entry = {entry_module, :entry, 1}
    ok = {ok_module, :ok, 1}
    error = {error_module, :error, 1}

    files = [
      render_with_module(entry_module, ok_module, error_module),
      render_named_sink_module(ok_module, :ok),
      render_named_sink_module(error_module, :error)
    ]

    branch = %{
      function: entry,
      kind: :with,
      clauses: 2,
      calls_by_clause: [
        %{label: "{:ok, value}", call: ok},
        %{label: "else", call: error}
      ]
    }

    branch_program(seed, :with_chain, files, [entry, ok, error], branch)
  end

  defp anonymous_fn_branch(opts) do
    seed = opts[:seed]
    [entry_module, ok_module, error_module] = Naming.modules(seed, 3)
    entry = {entry_module, :entry, 1}
    ok = {ok_module, :ok, 1}
    error = {error_module, :error, 1}

    files = [
      render_anonymous_fn_branch_module(entry_module, ok_module, error_module),
      render_named_sink_module(ok_module, :ok),
      render_named_sink_module(error_module, :error)
    ]

    branch = %{
      function: entry,
      kind: :anonymous_fn,
      clauses: 2,
      calls_by_clause: [
        %{label: "{:ok, value}", call: ok},
        %{label: "{:error, reason}", call: error}
      ]
    }

    branch_program(seed, :anonymous_fn_branch, files, [entry, ok, error], branch)
  end

  defp multi_clause_function(opts) do
    seed = opts[:seed]
    [entry_module, ok_module, error_module] = Naming.modules(seed, 3)
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

  defp nested_branches(opts) do
    seed = opts[:seed]
    [entry_module, ok_module, retry_module, error_module] = Naming.modules(seed, 4)
    entry = {entry_module, :entry, 1}
    ok = {ok_module, :ok, 1}
    retry = {retry_module, :retry, 1}
    error = {error_module, :error, 1}

    files = [
      render_nested_branch_module(entry_module, ok_module, retry_module, error_module),
      render_named_sink_module(ok_module, :ok),
      render_named_sink_module(retry_module, :retry),
      render_named_sink_module(error_module, :error)
    ]

    %Program{
      id: id(seed, :nested_branches),
      seed: seed,
      files: files,
      facts: %Facts{
        modules: [entry_module, ok_module, retry_module, error_module],
        functions: [entry, ok, retry, error],
        call_edges: [{entry, ok}, {entry, retry}, {entry, error}],
        call_paths: [[entry, ok], [entry, retry], [entry, error]],
        branches: [
          %{
            function: entry,
            kind: :case,
            clauses: 2,
            nested: [%{kind: :if, clauses: 2}],
            calls_by_clause: [
              %{label: "{:ok, value}", call: ok},
              %{label: "{:error, reason}", call: retry},
              %{label: "{:error, reason}", call: error}
            ]
          }
        ],
        features: MapSet.new([:remote_call, :branch, :nested_branches])
      },
      metadata: %{policy: :nested_branches, branch_count: 2}
    }
  end

  defp single_effect(opts, effect) do
    seed = opts[:seed]
    [module] = Naming.modules(seed, 1)
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
    [module] = Naming.modules(seed, 1)
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
  defp effect_policy(:read), do: :read_effect
  defp effect_policy(:write), do: :write_effect

  defp effect_function(:pure), do: :pure
  defp effect_function(:io), do: :io
  defp effect_function(:send), do: :sends
  defp effect_function(:exception), do: :raises
  defp effect_function(:read), do: :reads
  defp effect_function(:write), do: :writes

  defp effect_arity(:send), do: 2
  defp effect_arity(:write), do: 2
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

  defp architecture_program(opts, policy) do
    seed = opts[:seed]
    [web_module, domain_module, repo_module] = Naming.modules(seed, 3)
    functions = architecture_functions(web_module, domain_module, repo_module, policy)
    files = architecture_files(web_module, domain_module, repo_module, policy)
    violation = architecture_violation(web_module, domain_module, repo_module, policy)

    %Program{
      id: id(seed, policy),
      seed: seed,
      files: files ++ [architecture_config_file(web_module, domain_module, repo_module, policy)],
      facts: %Facts{
        modules: [web_module, domain_module, repo_module],
        functions: functions,
        call_edges: architecture_edges(functions, policy),
        call_paths: architecture_paths(functions, policy),
        effects: architecture_effects(functions, policy),
        architecture: %{
          policy: policy,
          valid?: violation == nil,
          violations: List.wrap(violation)
        },
        features: MapSet.new([:architecture, policy])
      },
      metadata: %{policy: policy, depth: 3}
    }
  end

  defp architecture_functions(web_module, domain_module, repo_module, :allowed_effect_violation) do
    [{web_module, :entry, 1}, {domain_module, :handle, 1}, {repo_module, :write, 1}]
  end

  defp architecture_functions(web_module, domain_module, repo_module, _policy) do
    [{web_module, :entry, 1}, {domain_module, :handle, 1}, {repo_module, :fetch, 1}]
  end

  defp architecture_files(web_module, domain_module, repo_module, :layered_valid) do
    [
      render_arch_module(web_module, :entry, domain_module, :handle),
      render_arch_module(domain_module, :handle, repo_module, :fetch),
      render_named_sink_module(repo_module, :fetch)
    ]
  end

  defp architecture_files(web_module, domain_module, repo_module, :forbidden_dependency) do
    [
      render_arch_module(web_module, :entry, repo_module, :fetch),
      render_named_sink_module(domain_module, :handle),
      render_named_sink_module(repo_module, :fetch)
    ]
  end

  defp architecture_files(web_module, domain_module, repo_module, :layer_cycle) do
    [
      render_arch_module(web_module, :entry, domain_module, :handle),
      render_arch_module(domain_module, :handle, repo_module, :fetch),
      render_arch_module(repo_module, :fetch, web_module, :entry)
    ]
  end

  defp architecture_files(web_module, domain_module, repo_module, :public_api_boundary_violation) do
    [
      render_arch_module(web_module, :entry, domain_module, :handle_internal),
      render_arch_internal_module(domain_module),
      render_named_sink_module(repo_module, :fetch)
    ]
  end

  defp architecture_files(web_module, domain_module, repo_module, :internal_boundary_violation) do
    [
      render_arch_module(web_module, :entry, domain_module, :internal),
      render_arch_internal_module(domain_module),
      render_named_sink_module(repo_module, :fetch)
    ]
  end

  defp architecture_files(web_module, domain_module, repo_module, :allowed_effect_violation) do
    [
      render_arch_module(web_module, :entry, domain_module, :handle),
      render_arch_module(domain_module, :handle, repo_module, :write),
      render_repo_write_module(repo_module)
    ]
  end

  defp architecture_edges([web, _domain, repo], :forbidden_dependency), do: [{web, repo}]

  defp architecture_edges([web, domain, repo], :layer_cycle),
    do: [{web, domain}, {domain, repo}, {repo, web}]

  defp architecture_edges([web, domain, _repo], policy)
       when policy in [:public_api_boundary_violation, :internal_boundary_violation],
       do: [{web, domain}]

  defp architecture_edges([web, domain, repo], _policy), do: [{web, domain}, {domain, repo}]

  defp architecture_paths(functions, policy) do
    functions
    |> architecture_edges(policy)
    |> Enum.map(fn {source, target} -> [source, target] end)
  end

  defp architecture_effects([_web, _domain, repo], :allowed_effect_violation),
    do: [{repo, :write}]

  defp architecture_effects(_functions, _policy), do: []

  defp architecture_violation(_web, _domain, _repo, :layered_valid), do: nil

  defp architecture_violation(web, _domain, repo, :forbidden_dependency),
    do: %{type: :forbidden_dependency, from: web, to: repo}

  defp architecture_violation(web, domain, repo, :layer_cycle),
    do: %{type: :layer_cycle, cycle: [web, domain, repo, web]}

  defp architecture_violation(web, domain, _repo, :public_api_boundary_violation),
    do: %{type: :public_api_boundary, from: web, to: domain}

  defp architecture_violation(web, domain, _repo, :internal_boundary_violation),
    do: %{type: :internal_boundary, from: web, to: domain}

  defp architecture_violation(_web, domain, repo, :allowed_effect_violation),
    do: %{type: :effect_policy, from: domain, to: repo, effect: :write}

  defp architecture_config_file(web_module, domain_module, repo_module, policy) do
    source = """
    [
      layers: [
        web: [#{inspect(web_module)}],
        domain: [#{inspect(domain_module)}],
        repo: [#{inspect(repo_module)}]
      ],
      forbidden_deps: [
        {#{inspect(web_module)}, #{inspect(repo_module)}}
      ],
      public_api: [#{inspect(domain_module)}],
      internal: [#{inspect(domain_module)}],
      allowed_effects: [
        {#{inspect(repo_module)}, [:read]}
      ],
      metadata: [policy: #{inspect(policy)}]
    ]
    """

    %File{path: ".reach.exs", source: source, kind: :config}
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

  defp render_effect_module(module, :read) do
    source = """
    defmodule #{inspect(module)} do
      def reads(key) do
        Process.get(key)
      end
    end
    """

    file(module, source)
  end

  defp render_effect_module(module, :write) do
    source = """
    defmodule #{inspect(module)} do
      def writes(key, value) do
        Process.put(key, value)
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

  defp render_arch_module(module, function, target_module, target_function) do
    source = """
    defmodule #{inspect(module)} do
      def #{function}(value) do
        #{inspect(target_module)}.#{target_function}(value)
      end
    end
    """

    file(module, source)
  end

  defp render_arch_internal_module(module) do
    source = """
    defmodule #{inspect(module)} do
      def handle_internal(value) do
        value
      end

      def internal(value) do
        value
      end
    end
    """

    file(module, source)
  end

  defp render_repo_write_module(module) do
    source = """
    defmodule #{inspect(module)} do
      def write(value) do
        Process.put(:program_facts_value, value)
      end
    end
    """

    file(module, source)
  end

  defp render_branch_data_flow_module(module, sink_module) do
    source = """
    defmodule #{inspect(module)} do
      def entry(input) do
        selected =
          if input == :ok do
            input
          else
            {:error, input}
          end

        #{inspect(sink_module)}.sink(selected)
      end
    end
    """

    file(module, source)
  end

  defp render_nested_branch_module(module, ok_module, retry_module, error_module) do
    source = """
    defmodule #{inspect(module)} do
      def entry(input) do
        case input do
          {:ok, value} ->
            #{inspect(ok_module)}.ok(value)

          {:error, reason} ->
            if reason == :retry do
              #{inspect(retry_module)}.retry(reason)
            else
              #{inspect(error_module)}.error(reason)
            end
        end
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

  defp render_cond_module(module, ok_module, error_module) do
    source = """
    defmodule #{inspect(module)} do
      def entry(input) do
        cond do
          input == :ok ->
            #{inspect(ok_module)}.ok(input)

          true ->
            #{inspect(error_module)}.error(input)
        end
      end
    end
    """

    file(module, source)
  end

  defp render_with_module(module, ok_module, error_module) do
    source = """
    defmodule #{inspect(module)} do
      def entry(input) do
        with {:ok, value} <- input do
          #{inspect(ok_module)}.ok(value)
        else
          {:error, reason} ->
            #{inspect(error_module)}.error(reason)
        end
      end
    end
    """

    file(module, source)
  end

  defp render_anonymous_fn_branch_module(module, ok_module, error_module) do
    source = """
    defmodule #{inspect(module)} do
      def entry(input) do
        dispatch = fn
          {:ok, value} ->
            #{inspect(ok_module)}.ok(value)

          {:error, reason} ->
            #{inspect(error_module)}.error(reason)
        end

        dispatch.(input)
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
    function = Naming.function_name(module)

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
    function = Naming.function_name(module)
    next_function = Naming.function_name(next_module)

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
      Enum.map_join(branch_modules, ",\n      ", fn branch_module ->
        "#{inspect(branch_module)}.#{Naming.function_name(branch_module)}(value)"
      end)

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
    %File{path: Naming.module_path(module), source: source, kind: :elixir}
  end

  defp pairwise_edges(functions) do
    functions
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [source, target] -> {source, target} end)
  end

  defp id(seed, policy), do: "pf_#{seed}_#{policy}"
end
