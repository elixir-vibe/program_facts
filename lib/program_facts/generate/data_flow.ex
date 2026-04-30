defmodule ProgramFacts.Generate.DataFlow do
  @moduledoc false

  alias ProgramFacts.Generate.Helpers
  alias ProgramFacts.Naming
  alias ProgramFacts.Render.Elixir, as: Render

  def straight_line_data_flow(opts), do: helper_flow(opts, :straight_line_data_flow)
  def helper_call_data_flow(opts), do: helper_flow(opts, :helper_call_data_flow)

  def helper_flow(opts, policy) do
    seed = opts[:seed]
    [entry_module, helper_module, sink_module] = Naming.modules(seed, 3)
    entry = {entry_module, :entry, 1}
    helper = {helper_module, :normalize, 1}
    sink = {sink_module, :sink, 1}

    [modules: modules, functions: functions, facts: facts] =
      helper_facts([entry_module, helper_module, sink_module], [entry, helper, sink])

    Helpers.model(
      [
        id: Helpers.id(seed, policy),
        seed: seed,
        policy: policy,
        files: [
          Render.entry_data_flow_module(entry_module, helper_module, sink_module),
          Render.helper_module(helper_module),
          Render.sink_module(sink_module)
        ],
        modules: modules,
        functions: functions,
        metadata: %{policy: policy, depth: 3}
      ] ++ facts
    )
  end

  def assignment_chain(opts) do
    seed = opts[:seed]
    [module] = Naming.modules(seed, 1)
    entry = {module, :entry, 1}

    Helpers.model(
      id: Helpers.id(seed, :assignment_chain),
      seed: seed,
      policy: :assignment_chain,
      files: [Render.assignment_chain_module(module)],
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
      features: MapSet.new([:assignment_chain, :data_flow, :return_data_flow]),
      metadata: %{policy: :assignment_chain, depth: 1}
    )
  end

  def branch_data_flow(opts) do
    seed = opts[:seed]
    [entry_module, sink_module] = Naming.modules(seed, 2)
    entry = {entry_module, :entry, 1}
    sink = {sink_module, :sink, 1}

    Helpers.model(
      id: Helpers.id(seed, :branch_data_flow),
      seed: seed,
      policy: :branch_data_flow,
      files: [
        Render.branch_data_flow_module(entry_module, sink_module),
        Render.sink_module(sink_module)
      ],
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
          calls_by_clause: [%{label: "input == :ok", call: sink}, %{label: "else", call: sink}]
        }
      ],
      features: MapSet.new([:branch, :data_flow, :remote_call]),
      metadata: %{policy: :branch_data_flow, depth: 2}
    )
  end

  def pipeline_data_flow(opts) do
    seed = opts[:seed]
    [entry_module, helper_module, sink_module] = Naming.modules(seed, 3)
    entry = {entry_module, :entry, 1}
    helper = {helper_module, :normalize, 1}
    sink = {sink_module, :sink, 1}

    [modules: modules, functions: functions, facts: facts] =
      helper_facts(
        [entry_module, helper_module, sink_module],
        [entry, helper, sink],
        MapSet.new([:remote_call, :pipeline, :helper_return, :data_flow])
      )

    Helpers.model(
      [
        id: Helpers.id(seed, :pipeline_data_flow),
        seed: seed,
        policy: :pipeline_data_flow,
        files: [
          Render.pipeline_entry_module(entry_module, helper_module, sink_module),
          Render.helper_module(helper_module),
          Render.sink_module(sink_module)
        ],
        modules: modules,
        functions: functions,
        metadata: %{policy: :pipeline_data_flow, depth: 3}
      ] ++ facts
    )
  end

  def return_data_flow(opts) do
    seed = opts[:seed]
    [module] = Naming.modules(seed, 1)
    entry = {module, :entry, 1}

    Helpers.model(
      id: Helpers.id(seed, :return_data_flow),
      seed: seed,
      policy: :return_data_flow,
      files: [Render.return_data_flow_module(module)],
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
      features: MapSet.new([:data_flow, :return_data_flow]),
      metadata: %{policy: :return_data_flow, depth: 1}
    )
  end

  defp helper_facts(
         modules,
         [entry, helper, sink],
         features \\ MapSet.new([:remote_call, :assignment_chain, :helper_return, :data_flow])
       ) do
    [
      modules: modules,
      functions: [entry, helper, sink],
      facts: [
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
        features: features
      ]
    ]
  end
end
