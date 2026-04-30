defmodule ProgramFacts.Generate.Syntax do
  @moduledoc false

  alias ProgramFacts.Generate.Helpers
  alias ProgramFacts.Naming
  alias ProgramFacts.Render.Elixir, as: Render

  def guard_clause(opts),
    do:
      syntax_model(opts, :guard_clause, :entry, &Render.guard_clause_module/1, [:guard, :branch])

  def try_rescue_after(opts),
    do:
      syntax_model(opts, :try_rescue_after, :entry, &Render.try_rescue_after_module/1, [
        :try,
        :exception,
        :branch
      ])

  def receive_message(opts),
    do:
      syntax_model(opts, :receive_message, :entry, &Render.receive_message_module/1, [
        :receive,
        :send,
        :branch
      ])

  def comprehension(opts),
    do:
      syntax_model(opts, :comprehension, :entry, &Render.comprehension_module/1, [
        :comprehension,
        :data_flow
      ])

  def struct_update(opts),
    do:
      syntax_model(opts, :struct_update, :entry, &Render.struct_update_module/1, [
        :struct,
        :data_flow
      ])

  def default_arguments(opts),
    do:
      syntax_model(opts, :default_arguments, :entry, &Render.default_arguments_module/1, [
        :default_arguments
      ])

  defp syntax_model(opts, policy, function_name, renderer, features) do
    seed = opts[:seed]
    [module] = Naming.modules(seed, 1)
    entry = {module, function_name, 1}

    Helpers.model(
      id: Helpers.id(seed, policy),
      seed: seed,
      policy: policy,
      files: [renderer.(module)],
      modules: [module],
      functions: functions(module, policy, entry),
      data_flows: data_flows(entry, policy),
      effects: effects(entry, policy),
      branches: branches(entry, policy),
      features: MapSet.new(features ++ [policy]),
      metadata: %{policy: policy, depth: 1}
    )
  end

  defp functions(module, :struct_update, entry), do: [entry, {module, :new, 1}]
  defp functions(module, :default_arguments, _entry), do: [{module, :entry, 2}]
  defp functions(_module, _policy, entry), do: [entry]

  defp data_flows(entry, policy) when policy in [:comprehension, :struct_update] do
    [
      %{
        from: {:param, entry, :input},
        through: [{:var, entry, :value}],
        to: {:return, entry},
        variable_names: [:input, :value]
      }
    ]
  end

  defp data_flows(_entry, _policy), do: []

  defp effects(entry, :try_rescue_after), do: [{entry, :exception}]
  defp effects(entry, :receive_message), do: [{entry, :send}]
  defp effects(_entry, _policy), do: []

  defp branches(entry, :guard_clause), do: [%{function: entry, kind: :guard, clauses: 2}]
  defp branches(entry, :try_rescue_after), do: [%{function: entry, kind: :try, clauses: 2}]
  defp branches(entry, :receive_message), do: [%{function: entry, kind: :receive, clauses: 2}]
  defp branches(_entry, _policy), do: []
end
