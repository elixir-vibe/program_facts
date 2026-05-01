defmodule ProgramFacts.Fact.FunctionID do
  @moduledoc """
  A function identity in generated oracle facts.
  """

  @derive JSON.Encoder
  @enforce_keys [:module, :function, :arity, :id]
  defstruct [:module, :function, :arity, :id]

  @type t :: %__MODULE__{
          module: String.t(),
          function: String.t(),
          arity: non_neg_integer(),
          id: String.t()
        }

  @doc """
  Builds a function identity from an MFA tuple.
  """
  def new({module, function, arity}) when is_atom(module) and is_atom(function) do
    module_name = module_name(module)

    %__MODULE__{
      module: module_name,
      function: Atom.to_string(function),
      arity: arity,
      id: "#{module_name}.#{function}/#{arity}"
    }
  end

  def new(%__MODULE__{} = function), do: function

  def from_map!(%{"module" => module, "function" => function, "arity" => arity}) do
    from_map!(%{module: module, function: function, arity: arity})
  end

  def from_map!(%{module: module, function: function, arity: arity}) do
    %__MODULE__{
      module: module,
      function: function,
      arity: arity,
      id: "#{module}.#{function}/#{arity}"
    }
  end

  def to_tuple(%__MODULE__{} = function) do
    {Module.concat([function.module]), String.to_atom(function.function), function.arity}
  end

  def to_tuple(tuple) when is_tuple(tuple), do: tuple

  defp module_name(module) do
    module
    |> inspect()
    |> String.trim_leading("Elixir.")
  end
end
