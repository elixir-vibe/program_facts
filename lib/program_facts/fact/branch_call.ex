defmodule ProgramFacts.Fact.BranchCall do
  @moduledoc """
  A call associated with one branch clause.
  """

  alias ProgramFacts.Fact.FunctionID

  @derive JSON.Encoder
  @enforce_keys [:call, :label]
  defstruct [:call, :label]

  @type t :: %__MODULE__{call: FunctionID.t(), label: String.t()}

  def new(%{call: call, label: label}) do
    %__MODULE__{call: FunctionID.new(call), label: label}
  end
end
