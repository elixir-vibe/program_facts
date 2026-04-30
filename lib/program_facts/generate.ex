defmodule ProgramFacts.Generate do
  @moduledoc false

  alias ProgramFacts.Generate.{Architecture, Branch, CallGraph, DataFlow, Effect, Otp, Syntax}
  alias ProgramFacts.{Layout, Locations, Model, Naming}

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
    :gen_server_callbacks,
    :guard_clause,
    :try_rescue_after,
    :receive_message,
    :comprehension,
    :struct_update,
    :default_arguments,
    :layered_valid,
    :forbidden_dependency,
    :layer_cycle,
    :public_api_boundary_violation,
    :internal_boundary_violation,
    :allowed_effect_violation
  ]

  @architecture_policies [
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
      opts
      |> Keyword.validate!(
        policy: :linear_call_chain,
        seed: 1,
        depth: 3,
        width: 2,
        layout: :plain
      )
      |> validate_ranges!()

    opts[:policy]
    |> generate_policy!(opts)
    |> Model.to_program()
    |> Layout.apply(opts[:layout])
    |> Locations.attach()
  end

  defp validate_ranges!(opts) do
    validate_seed!(opts[:seed])
    validate_depth!(opts[:depth])
    validate_width!(opts[:width])
    opts
  end

  defp validate_seed!(seed) when is_integer(seed) and seed >= 0 and seed <= @max_seed, do: :ok

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

  defp generate_policy!(:single_call, opts), do: CallGraph.single_call(opts)
  defp generate_policy!(:linear_call_chain, opts), do: CallGraph.linear_call_chain(opts)
  defp generate_policy!(:branching_call_graph, opts), do: CallGraph.branching_call_graph(opts)

  defp generate_policy!(:module_dependency_chain, opts),
    do: CallGraph.module_dependency_chain(opts)

  defp generate_policy!(:module_cycle, opts), do: CallGraph.module_cycle(opts)

  defp generate_policy!(:straight_line_data_flow, opts),
    do: DataFlow.straight_line_data_flow(opts)

  defp generate_policy!(:assignment_chain, opts), do: DataFlow.assignment_chain(opts)
  defp generate_policy!(:branch_data_flow, opts), do: DataFlow.branch_data_flow(opts)
  defp generate_policy!(:helper_call_data_flow, opts), do: DataFlow.helper_call_data_flow(opts)
  defp generate_policy!(:pipeline_data_flow, opts), do: DataFlow.pipeline_data_flow(opts)
  defp generate_policy!(:return_data_flow, opts), do: DataFlow.return_data_flow(opts)
  defp generate_policy!(:if_else, opts), do: Branch.if_else(opts)
  defp generate_policy!(:case_clauses, opts), do: Branch.case_clauses(opts)
  defp generate_policy!(:cond_branches, opts), do: Branch.cond_branches(opts)
  defp generate_policy!(:with_chain, opts), do: Branch.with_chain(opts)
  defp generate_policy!(:anonymous_fn_branch, opts), do: Branch.anonymous_fn_branch(opts)
  defp generate_policy!(:multi_clause_function, opts), do: Branch.multi_clause_function(opts)
  defp generate_policy!(:nested_branches, opts), do: Branch.nested_branches(opts)
  defp generate_policy!(:pure, opts), do: Effect.pure(opts)
  defp generate_policy!(:io_effect, opts), do: Effect.io_effect(opts)
  defp generate_policy!(:send_effect, opts), do: Effect.send_effect(opts)
  defp generate_policy!(:raise_effect, opts), do: Effect.raise_effect(opts)
  defp generate_policy!(:read_effect, opts), do: Effect.read_effect(opts)
  defp generate_policy!(:write_effect, opts), do: Effect.write_effect(opts)
  defp generate_policy!(:mixed_effect_boundary, opts), do: Effect.mixed_effect_boundary(opts)
  defp generate_policy!(:gen_server_callbacks, opts), do: Otp.gen_server_callbacks(opts)
  defp generate_policy!(:guard_clause, opts), do: Syntax.guard_clause(opts)
  defp generate_policy!(:try_rescue_after, opts), do: Syntax.try_rescue_after(opts)
  defp generate_policy!(:receive_message, opts), do: Syntax.receive_message(opts)
  defp generate_policy!(:comprehension, opts), do: Syntax.comprehension(opts)
  defp generate_policy!(:struct_update, opts), do: Syntax.struct_update(opts)
  defp generate_policy!(:default_arguments, opts), do: Syntax.default_arguments(opts)

  defp generate_policy!(policy, opts) when policy in @architecture_policies,
    do: Architecture.generate(opts, policy)

  defp generate_policy!(policy, _opts) do
    raise ArgumentError, "unknown generation policy: #{inspect(policy)}"
  end
end
