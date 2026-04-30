defmodule ProgramFacts.Analyzer.Result do
  @moduledoc """
  Normalized analyzer result used for differential comparisons.
  """

  alias ProgramFacts.Facts
  alias ProgramFacts.Program

  @type t :: %__MODULE__{name: String.t(), facts: map(), error: String.t() | nil, metadata: map()}

  defstruct [:name, facts: %{}, error: nil, metadata: %{}]

  @doc """
  Normalizes an analyzer return value into a result struct.
  """
  def new(%__MODULE__{} = result, opts) do
    %{result | name: result.name || normalize_name(Keyword.fetch!(opts, :name))}
  end

  def new(%Program{} = program, opts), do: new(program.facts, opts)

  def new(%Facts{} = facts, opts) do
    %__MODULE__{name: normalize_name(Keyword.fetch!(opts, :name)), facts: facts_map(facts)}
  end

  def new(%{} = facts, opts) do
    %__MODULE__{name: normalize_name(Keyword.fetch!(opts, :name)), facts: facts}
  end

  @doc """
  Builds an error result for a failed analyzer run.
  """
  def error(name, exception) do
    %__MODULE__{name: normalize_name(name), error: Exception.message(exception)}
  end

  defp facts_map(%Facts{} = facts) do
    facts
    |> Map.from_struct()
    |> Map.take([
      :modules,
      :functions,
      :call_edges,
      :call_paths,
      :data_flows,
      :effects,
      :branches,
      :architecture
    ])
  end

  defp normalize_name(name), do: to_string(name)
end
