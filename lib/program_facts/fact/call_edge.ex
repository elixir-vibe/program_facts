defmodule ProgramFacts.Fact.CallEdge do
  @moduledoc """
  A directed call edge between two generated functions.
  """

  alias ProgramFacts.Fact.FunctionID

  @derive JSON.Encoder
  @enforce_keys [:source, :target]
  defstruct [:source, :target]

  @type t :: %__MODULE__{source: FunctionID.t(), target: FunctionID.t()}

  def new({source, target}), do: new(source, target)

  def new(source, target) do
    %__MODULE__{source: FunctionID.new(source), target: FunctionID.new(target)}
  end

  def from_map!(%{"source" => source, "target" => target}) do
    from_map!(%{source: source, target: target})
  end

  def from_map!(%{source: source, target: target}) do
    %__MODULE__{source: FunctionID.from_map!(source), target: FunctionID.from_map!(target)}
  end

  def to_tuple(%__MODULE__{} = edge) do
    {FunctionID.to_tuple(edge.source), FunctionID.to_tuple(edge.target)}
  end

  def to_tuple(tuple) when is_tuple(tuple), do: tuple
end
