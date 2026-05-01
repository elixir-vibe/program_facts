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

  def from_map!(%{"function" => function, "effect" => effect}) do
    from_map!(%{function: function, effect: effect})
  end

  def from_map!(%{function: function, effect: effect}) do
    %__MODULE__{function: FunctionID.from_map!(function), effect: effect_atom(effect)}
  end

  def to_tuple(%__MODULE__{} = effect) do
    {FunctionID.to_tuple(effect.function), effect.effect}
  end

  def to_tuple(tuple) when is_tuple(tuple), do: tuple

  defp effect_atom(effect) when is_atom(effect), do: effect
  defp effect_atom(effect) when is_binary(effect), do: String.to_existing_atom(effect)
end
