defmodule ProgramFacts.Facts do
  @moduledoc """
  Ground-truth facts expected from a generated program.
  """

  alias ProgramFacts.Fact.{Branch, CallEdge, DataFlow, Effect, FunctionID}
  alias ProgramFacts.Manifest

  @type function_id :: {module(), atom(), non_neg_integer()}
  @type call_edge :: {function_id(), function_id()}
  @type data_flow :: map()
  @type effect :: {function_id(), atom()}
  @type branch :: map()
  @type location :: map()

  @type t :: %__MODULE__{
          modules: [module()],
          functions: [function_id()],
          call_edges: [call_edge()],
          call_paths: [[function_id()]],
          data_flows: [data_flow()],
          effects: [effect()],
          branches: [branch()],
          architecture: map(),
          locations: %{optional(atom()) => [location()]},
          features: MapSet.t(atom())
        }

  defstruct modules: [],
            functions: [],
            call_edges: [],
            call_paths: [],
            data_flows: [],
            effects: [],
            branches: [],
            architecture: %{},
            locations: %{},
            features: MapSet.new()

  @doc """
  Normalizes compatible fact input into the core `%ProgramFacts.Facts{}` shape.
  """
  def normalize(%__MODULE__{} = facts) do
    %__MODULE__{
      facts
      | functions: Enum.map(facts.functions, &FunctionID.to_tuple/1),
        call_edges: Enum.map(facts.call_edges, &CallEdge.to_tuple/1),
        call_paths:
          Enum.map(facts.call_paths, fn path ->
            Enum.map(path, &FunctionID.to_tuple/1)
          end),
        data_flows: Enum.map(facts.data_flows, &normalize_data_flow/1),
        effects: Enum.map(facts.effects, &Effect.to_tuple/1),
        branches: Enum.map(facts.branches, &normalize_branch/1),
        features: normalize_features(facts.features)
    }
  end

  @doc """
  Projects core oracle facts into the typed manifest facts payload.
  """
  def to_manifest(%__MODULE__{} = facts) do
    facts
    |> normalize()
    |> Manifest.Facts.build()
  end

  defp normalize_data_flow(%DataFlow{} = flow), do: DataFlow.to_map(flow)

  defp normalize_data_flow(flow), do: flow

  defp normalize_branch(%Branch{} = branch), do: Branch.to_map(branch)

  defp normalize_branch(branch), do: branch

  defp normalize_features(%MapSet{} = features), do: features
  defp normalize_features(features) when is_list(features), do: MapSet.new(features)
end
