defmodule ProgramFacts.Model do
  @moduledoc """
  Semantic summary model for generated programs.

  Built-in generators construct this model first, then materialize source files
  and facts through `to_program/1`. Existing generated programs can also be
  projected back into this model with `from_program/1`.
  """

  alias ProgramFacts.{Model, Program}

  @type t :: %__MODULE__{
          id: String.t(),
          seed: integer(),
          policy: atom(),
          files: [ProgramFacts.File.t()],
          modules: [module()],
          functions: [ProgramFacts.Facts.function_id()],
          relationships: map(),
          features: MapSet.t(atom()),
          metadata: map()
        }

  defstruct [
    :id,
    :seed,
    :policy,
    files: [],
    modules: [],
    functions: [],
    relationships: %{},
    features: MapSet.new(),
    metadata: %{}
  ]

  @doc """
  Projects a generated program into its semantic summary model.
  """
  def from_program(%Program{} = program) do
    %__MODULE__{
      id: program.id,
      seed: program.seed,
      policy: program.metadata.policy,
      files: program.files,
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
      features: program.facts.features,
      metadata: program.metadata
    }
  end

  @doc """
  Starts a fluent semantic model builder.
  """
  def builder(opts), do: Model.Builder.new(opts)

  @doc """
  Builds a semantic model from generated source files and structural facts.
  """
  def new(attrs) when is_list(attrs) do
    modules = Keyword.fetch!(attrs, :modules)
    functions = Keyword.fetch!(attrs, :functions)
    policy = Keyword.fetch!(attrs, :policy)
    metadata = attrs |> Keyword.get(:metadata, %{}) |> Map.put_new(:policy, policy)

    %__MODULE__{
      id: Keyword.fetch!(attrs, :id),
      seed: Keyword.fetch!(attrs, :seed),
      policy: policy,
      files: Keyword.get(attrs, :files, []),
      modules: modules,
      functions: functions,
      relationships: %{
        call_edges: Keyword.get(attrs, :call_edges, []),
        call_paths: Keyword.get(attrs, :call_paths, []),
        data_flows: Keyword.get(attrs, :data_flows, []),
        effects: Keyword.get(attrs, :effects, []),
        branches: Keyword.get(attrs, :branches, []),
        architecture: Keyword.get(attrs, :architecture, %{})
      },
      features: Keyword.get(attrs, :features, MapSet.new()),
      metadata: metadata
    }
  end

  @doc """
  Materializes a semantic model as a generated program with facts derived from the model.
  """
  def to_program(%__MODULE__{} = model) do
    %Program{
      id: model.id,
      seed: model.seed,
      files: model.files,
      facts: %ProgramFacts.Facts{
        modules: model.modules,
        functions: model.functions,
        call_edges: Map.get(model.relationships, :call_edges, []),
        call_paths: Map.get(model.relationships, :call_paths, []),
        data_flows: Map.get(model.relationships, :data_flows, []),
        effects: Map.get(model.relationships, :effects, []),
        branches: Map.get(model.relationships, :branches, []),
        architecture: Map.get(model.relationships, :architecture, %{}),
        features: model.features
      },
      metadata: model.metadata
    }
  end
end
