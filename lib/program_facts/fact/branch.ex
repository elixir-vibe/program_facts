defmodule ProgramFacts.Fact.Branch do
  @moduledoc """
  A branch/control-flow oracle fact.
  """

  alias ProgramFacts.Fact.{BranchCall, FunctionID}

  @derive JSON.Encoder
  @enforce_keys [:kind, :clauses]
  defstruct [:function, :kind, :clauses, calls_by_clause: [], nested: [], state_action: nil]

  @type t :: %__MODULE__{
          function: FunctionID.t() | nil,
          kind: atom(),
          clauses: non_neg_integer(),
          calls_by_clause: [BranchCall.t()],
          nested: [t()],
          state_action: atom() | nil
        }

  def new(%{} = branch) do
    %__MODULE__{
      function: optional_function(Map.get(branch, :function)),
      kind: Map.fetch!(branch, :kind),
      clauses: Map.fetch!(branch, :clauses),
      calls_by_clause: Enum.map(Map.get(branch, :calls_by_clause, []), &BranchCall.new/1),
      nested: Enum.map(Map.get(branch, :nested, []), &new/1),
      state_action: Map.get(branch, :state_action)
    }
  end

  def from_map!(%{"kind" => kind, "clauses" => clauses} = map) do
    from_map!(%{
      function: Map.get(map, "function"),
      kind: kind,
      clauses: clauses,
      calls_by_clause: Map.get(map, "calls_by_clause", []),
      nested: Map.get(map, "nested", []),
      state_action: Map.get(map, "state_action")
    })
  end

  def from_map!(%{function: function, kind: kind, clauses: clauses} = map) do
    %__MODULE__{
      function: optional_function(function),
      kind: atom(kind),
      clauses: clauses,
      calls_by_clause: Enum.map(Map.get(map, :calls_by_clause, []), &BranchCall.from_map!/1),
      nested: Enum.map(Map.get(map, :nested, []), &from_map!/1),
      state_action: optional_atom(Map.get(map, :state_action))
    }
  end

  def to_map(%__MODULE__{} = branch) do
    %{
      function: optional_function_tuple(branch.function),
      kind: branch.kind,
      clauses: branch.clauses,
      calls_by_clause: Enum.map(branch.calls_by_clause, &BranchCall.to_map/1),
      nested: Enum.map(branch.nested, &to_map/1),
      state_action: branch.state_action
    }
    |> Enum.reject(fn {_key, value} -> value in [nil, []] end)
    |> Map.new()
  end

  defp optional_function(nil), do: nil
  defp optional_function(%{} = function), do: FunctionID.from_map!(function)
  defp optional_function(function), do: FunctionID.new(function)

  defp optional_function_tuple(nil), do: nil
  defp optional_function_tuple(function), do: FunctionID.to_tuple(function)

  defp optional_atom(nil), do: nil
  defp optional_atom(value), do: atom(value)

  defp atom(value) when is_atom(value), do: value
  defp atom(value) when is_binary(value), do: String.to_existing_atom(value)
end
