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

  def from_map!(%{"call" => call, "label" => label}), do: from_map!(%{call: call, label: label})

  def from_map!(%{call: call, label: label}) do
    %__MODULE__{call: FunctionID.from_map!(call), label: label}
  end

  def to_map(%__MODULE__{} = branch_call) do
    %{call: FunctionID.to_tuple(branch_call.call), label: branch_call.label}
  end
end
