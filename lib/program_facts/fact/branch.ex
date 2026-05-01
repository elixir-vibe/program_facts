defmodule ProgramFacts.Fact.Branch do
  @moduledoc """
  A branch/control-flow oracle fact.
  """

  alias ProgramFacts.Fact.{BranchCall, FunctionID}

  @derive JSON.Encoder
  @enforce_keys [:function, :kind, :clauses]
  defstruct [:function, :kind, :clauses, calls_by_clause: [], nested: [], state_action: nil]

  @type t :: %__MODULE__{
          function: FunctionID.t(),
          kind: atom(),
          clauses: non_neg_integer(),
          calls_by_clause: [BranchCall.t()],
          nested: [t()],
          state_action: atom() | nil
        }

  def new(%{} = branch) do
    %__MODULE__{
      function: FunctionID.new(Map.fetch!(branch, :function)),
      kind: Map.fetch!(branch, :kind),
      clauses: Map.fetch!(branch, :clauses),
      calls_by_clause: Enum.map(Map.get(branch, :calls_by_clause, []), &BranchCall.new/1),
      nested: Enum.map(Map.get(branch, :nested, []), &new/1),
      state_action: Map.get(branch, :state_action)
    }
  end
end
