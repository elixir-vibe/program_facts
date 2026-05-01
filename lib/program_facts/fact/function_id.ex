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

  defp module_name(module) do
    module
    |> inspect()
    |> String.trim_leading("Elixir.")
  end
end
