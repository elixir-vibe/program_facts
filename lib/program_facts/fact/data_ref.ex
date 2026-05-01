defmodule ProgramFacts.Fact.DataRef do
  @moduledoc """
  A typed data-flow endpoint or intermediate reference.
  """

  alias ProgramFacts.Fact.FunctionID

  @derive JSON.Encoder
  @enforce_keys [:type, :function]
  defstruct [:type, :function, :name, :index]

  @type t :: %__MODULE__{
          type: :param | :arg | :return | :var,
          function: FunctionID.t(),
          name: atom() | nil,
          index: non_neg_integer() | nil
        }

  def new({:param, function, name}) do
    %__MODULE__{type: :param, function: FunctionID.new(function), name: name}
  end

  def new({:arg, function, index}) do
    %__MODULE__{type: :arg, function: FunctionID.new(function), index: index}
  end

  def new({:return, function}) do
    %__MODULE__{type: :return, function: FunctionID.new(function)}
  end

  def new({:var, function, name}) do
    %__MODULE__{type: :var, function: FunctionID.new(function), name: name}
  end

  def new(%__MODULE__{} = ref), do: ref
end
