defmodule ProgramFacts.Fact.Effect do
  @moduledoc """
  A side-effect oracle fact for a generated function.
  """

  alias ProgramFacts.Fact.FunctionID

  @derive JSON.Encoder
  @enforce_keys [:function, :effect]
  defstruct [:function, :effect]

  @type t :: %__MODULE__{function: FunctionID.t(), effect: atom()}

  def new({function, effect}), do: %__MODULE__{function: FunctionID.new(function), effect: effect}
end
