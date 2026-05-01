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

  def from_map!(%{"type" => type, "function" => function} = map) do
    from_map!(%{
      type: type,
      function: function,
      name: Map.get(map, "name"),
      index: Map.get(map, "index")
    })
  end

  def from_map!(%{type: type, function: function} = map) do
    %__MODULE__{
      type: ref_type(type),
      function: FunctionID.from_map!(function),
      name: optional_atom(Map.get(map, :name)),
      index: Map.get(map, :index)
    }
  end

  def to_tuple(%__MODULE__{type: :param} = ref),
    do: {:param, FunctionID.to_tuple(ref.function), ref.name}

  def to_tuple(%__MODULE__{type: :arg} = ref),
    do: {:arg, FunctionID.to_tuple(ref.function), ref.index}

  def to_tuple(%__MODULE__{type: :return} = ref), do: {:return, FunctionID.to_tuple(ref.function)}

  def to_tuple(%__MODULE__{type: :var} = ref),
    do: {:var, FunctionID.to_tuple(ref.function), ref.name}

  def to_tuple(tuple) when is_tuple(tuple), do: tuple

  defp ref_type(type) when is_atom(type), do: type
  defp ref_type(type) when is_binary(type), do: String.to_existing_atom(type)

  defp optional_atom(nil), do: nil
  defp optional_atom(name) when is_atom(name), do: name
  defp optional_atom(name) when is_binary(name), do: String.to_atom(name)
end
