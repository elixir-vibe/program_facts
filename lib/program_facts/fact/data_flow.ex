defmodule ProgramFacts.Fact.DataFlow do
  @moduledoc """
  A ground-truth data-flow oracle fact.
  """

  alias ProgramFacts.Fact.DataRef

  @derive JSON.Encoder
  @enforce_keys [:from, :to]
  defstruct [:from, :to, through: [], variable_names: [], branch: nil]

  @type t :: %__MODULE__{
          from: DataRef.t(),
          to: DataRef.t(),
          through: [DataRef.t()],
          variable_names: [atom()],
          branch: atom() | nil
        }

  def new(%{} = flow) do
    %__MODULE__{
      from: DataRef.new(Map.fetch!(flow, :from)),
      to: DataRef.new(Map.fetch!(flow, :to)),
      through: Enum.map(Map.get(flow, :through, []), &DataRef.new/1),
      variable_names: Map.get(flow, :variable_names, []),
      branch: Map.get(flow, :branch)
    }
  end
end
