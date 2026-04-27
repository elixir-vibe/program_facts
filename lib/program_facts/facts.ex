defmodule ProgramFacts.Facts do
  @moduledoc """
  Ground-truth facts expected from a generated program.
  """

  defstruct modules: [],
            functions: [],
            call_edges: [],
            call_paths: [],
            data_flows: [],
            effects: [],
            branches: [],
            architecture: %{},
            locations: %{},
            features: MapSet.new()
end
