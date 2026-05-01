defmodule ProgramFacts.Fact.Location do
  @moduledoc """
  A source location oracle fact.
  """

  @derive JSON.Encoder
  @enforce_keys [:category, :data]
  defstruct [:category, :data]

  @type t :: %__MODULE__{category: atom(), data: map()}

  def new(category, data) when is_atom(category) and is_map(data) do
    %__MODULE__{category: category, data: data}
  end
end
