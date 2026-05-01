defmodule ProgramFacts.Manifest.Facts do
  @moduledoc """
  JSON manifest facts payload.
  """

  alias ProgramFacts.Fact.{Branch, CallEdge, DataFlow, Effect, FunctionID, Location}
  alias ProgramFacts.Facts

  @derive JSON.Encoder
  @enforce_keys [
    :modules,
    :functions,
    :call_edges,
    :call_paths,
    :data_flows,
    :effects,
    :branches,
    :architecture,
    :locations,
    :features
  ]
  defstruct modules: [],
            functions: [],
            call_edges: [],
            call_paths: [],
            data_flows: [],
            effects: [],
            branches: [],
            architecture: %{},
            locations: %{},
            features: []

  @type t :: %__MODULE__{}

  def new(%Facts{} = facts), do: Facts.to_manifest(facts)

  def from_map!(%{} = facts) do
    facts = ProgramFacts.Manifest.to_map(facts)

    %__MODULE__{
      modules: Map.fetch!(facts, :modules),
      functions: Enum.map(Map.fetch!(facts, :functions), &FunctionID.from_map!/1),
      call_edges: Enum.map(Map.fetch!(facts, :call_edges), &CallEdge.from_map!/1),
      call_paths:
        facts
        |> Map.fetch!(:call_paths)
        |> Enum.map(&Enum.map(&1, fn function -> FunctionID.from_map!(function) end)),
      data_flows: Enum.map(Map.fetch!(facts, :data_flows), &DataFlow.from_map!/1),
      effects: Enum.map(Map.fetch!(facts, :effects), &Effect.from_map!/1),
      branches: Enum.map(Map.fetch!(facts, :branches), &Branch.from_map!/1),
      architecture: Map.fetch!(facts, :architecture),
      locations: Map.fetch!(facts, :locations),
      features: Enum.map(Map.fetch!(facts, :features), &feature/1)
    }
  end

  def build(%Facts{} = facts) do
    %__MODULE__{
      modules: Enum.map(facts.modules, &module_name/1),
      functions: Enum.map(facts.functions, &FunctionID.new/1),
      call_edges: Enum.map(facts.call_edges, &CallEdge.new/1),
      call_paths:
        Enum.map(facts.call_paths, &Enum.map(&1, fn function -> FunctionID.new(function) end)),
      data_flows: Enum.map(facts.data_flows, &DataFlow.new/1),
      effects: Enum.map(facts.effects, &Effect.new/1),
      branches: Enum.map(facts.branches, &Branch.new/1),
      architecture: ProgramFacts.Manifest.to_map(facts.architecture),
      locations: locations(facts.locations),
      features: facts.features |> MapSet.to_list() |> Enum.sort_by(&to_string/1)
    }
  end

  defp feature(feature) when is_atom(feature), do: feature
  defp feature(feature) when is_binary(feature), do: String.to_existing_atom(feature)

  defp locations(locations) do
    Map.new(locations, fn {category, entries} ->
      {category, Enum.map(entries, &Location.new(category, ProgramFacts.Manifest.to_map(&1)))}
    end)
  end

  defp module_name(module) do
    module
    |> inspect()
    |> String.trim_leading("Elixir.")
  end
end
