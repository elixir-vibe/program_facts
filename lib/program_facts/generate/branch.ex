defmodule ProgramFacts.Generate.Branch do
  @moduledoc false

  alias ProgramFacts.Generate.Helpers
  alias ProgramFacts.Naming
  alias ProgramFacts.Render.Elixir, as: Render

  def if_else(opts),
    do:
      branch_model(opts, :if_else, :if, &Render.if_else_module/3, [
        %{label: "true", target: :ok},
        %{label: "false", target: :error}
      ])

  def case_clauses(opts),
    do:
      branch_model(opts, :case_clauses, :case, &Render.case_module/3, [
        %{label: "{:ok, value}", target: :ok},
        %{label: "{:error, reason}", target: :error}
      ])

  def cond_branches(opts),
    do:
      branch_model(opts, :cond_branches, :cond, &Render.cond_module/3, [
        %{label: "input == :ok", target: :ok},
        %{label: "true", target: :error}
      ])

  def with_chain(opts),
    do:
      branch_model(opts, :with_chain, :with, &Render.with_module/3, [
        %{label: "{:ok, value}", target: :ok},
        %{label: "else", target: :error}
      ])

  def anonymous_fn_branch(opts),
    do:
      branch_model(
        opts,
        :anonymous_fn_branch,
        :anonymous_fn,
        &Render.anonymous_fn_branch_module/3,
        [%{label: "{:ok, value}", target: :ok}, %{label: "{:error, reason}", target: :error}]
      )

  def multi_clause_function(opts),
    do:
      branch_model(
        opts,
        :multi_clause_function,
        :multi_clause_function,
        &Render.multi_clause_module/3,
        [%{label: "{:ok, value}", target: :ok}, %{label: "{:error, reason}", target: :error}]
      )

  def nested_branches(opts) do
    seed = opts[:seed]
    [entry_module, ok_module, retry_module, error_module] = Naming.modules(seed, 4)
    entry = {entry_module, :entry, 1}
    ok = {ok_module, :ok, 1}
    retry = {retry_module, :retry, 1}
    error = {error_module, :error, 1}

    Helpers.model(
      id: Helpers.id(seed, :nested_branches),
      seed: seed,
      policy: :nested_branches,
      files: [
        Render.nested_branch_module(entry_module, ok_module, retry_module, error_module),
        Render.named_sink_module(ok_module, :ok),
        Render.named_sink_module(retry_module, :retry),
        Render.named_sink_module(error_module, :error)
      ],
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
      features: MapSet.new([:remote_call, :branch, :nested_branches]),
      metadata: %{policy: :nested_branches, branch_count: 2}
    )
  end

  defp branch_model(opts, policy, kind, renderer, clauses) do
    seed = opts[:seed]
    [entry_module, ok_module, error_module] = Naming.modules(seed, 3)
    entry = {entry_module, :entry, 1}
    ok = {ok_module, :ok, 1}
    error = {error_module, :error, 1}
    calls_by_clause = Enum.map(clauses, &clause_call(&1, ok, error))

    Helpers.model(
      id: Helpers.id(seed, policy),
      seed: seed,
      policy: policy,
      files: [
        renderer.(entry_module, ok_module, error_module),
        Render.named_sink_module(ok_module, :ok),
        Render.named_sink_module(error_module, :error)
      ],
      modules: [entry_module, ok_module, error_module],
      functions: [entry, ok, error],
      call_edges: [{entry, ok}, {entry, error}],
      call_paths: [[entry, ok], [entry, error]],
      branches: [%{function: entry, kind: kind, clauses: 2, calls_by_clause: calls_by_clause}],
      features: MapSet.new([:remote_call, :branch, policy]),
      metadata: %{policy: policy, branch_count: 2}
    )
  end

  defp clause_call(%{label: label, target: :ok}, ok, _error), do: %{label: label, call: ok}
  defp clause_call(%{label: label, target: :error}, _ok, error), do: %{label: label, call: error}
end
