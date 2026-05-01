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
end
