defmodule ProgramFacts.Model do
  @moduledoc """
  Semantic summary model for generated programs.

  The current generator still renders from policy templates, but every generated
  program can be projected into this model. Future generators can build this
  model first and derive both source and facts from it.
  """

  alias ProgramFacts.Program

  @type t :: %__MODULE__{
          id: String.t(),
          policy: atom(),
          modules: [module()],
          functions: [ProgramFacts.Facts.function_id()],
          relationships: map(),
          features: MapSet.t(atom())
        }

  defstruct [:id, :policy, modules: [], functions: [], relationships: %{}, features: MapSet.new()]

  def from_program(%Program{} = program) do
    %__MODULE__{
      id: program.id,
      policy: program.metadata.policy,
      modules: program.facts.modules,
      functions: program.facts.functions,
      relationships: %{
        call_edges: program.facts.call_edges,
        call_paths: program.facts.call_paths,
        data_flows: program.facts.data_flows,
        effects: program.facts.effects,
        branches: program.facts.branches,
        architecture: program.facts.architecture
      },
      features: program.facts.features
    }
  end
end
