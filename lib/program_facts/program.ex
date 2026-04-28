defmodule ProgramFacts.Program do
  @moduledoc """
  A generated program with source files and expected structural facts.
  """

  @type t :: %__MODULE__{
          id: String.t(),
          seed: integer(),
          files: [ProgramFacts.File.t()],
          facts: ProgramFacts.Facts.t(),
          metadata: map()
        }

  defstruct [:id, :seed, :files, :facts, :metadata]

  def model(%__MODULE__{} = program), do: ProgramFacts.Model.from_program(program)
end
