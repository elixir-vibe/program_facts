defmodule ProgramFacts.Facts do
  @moduledoc """
  Ground-truth facts expected from a generated program.
  """

  @type function_id :: {module(), atom(), non_neg_integer()}
  @type call_edge :: {function_id(), function_id()}
  @type data_flow :: map()
  @type effect :: {function_id(), atom()}
  @type branch :: map()
  @type location :: map()

  @type t :: %__MODULE__{
          modules: [module()],
          functions: [function_id()],
          call_edges: [call_edge()],
          call_paths: [[function_id()]],
          data_flows: [data_flow()],
          effects: [effect()],
          branches: [branch()],
          architecture: map(),
          locations: %{optional(atom()) => [location()]},
          features: MapSet.t(atom())
        }

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
