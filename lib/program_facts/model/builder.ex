defmodule ProgramFacts.Model.Builder do
  @moduledoc """
  Builder API for constructing `ProgramFacts.Model` values.

  The builder is useful for custom generators and tests that want to describe a
  semantic program model first, then materialize source and facts through
  `ProgramFacts.Model.to_program/1`.
  """

  alias ProgramFacts.{File, Model}

  @type t :: %__MODULE__{
          id: String.t(),
          seed: integer(),
          policy: atom(),
          files: [File.t()],
          modules: MapSet.t(module()),
          functions: MapSet.t(ProgramFacts.Facts.function_id()),
          call_edges: MapSet.t(ProgramFacts.Facts.call_edge()),
          call_paths: [[ProgramFacts.Facts.function_id()]],
          data_flows: [map()],
          effects: MapSet.t(ProgramFacts.Facts.effect()),
          branches: [map()],
          architecture: map(),
          features: MapSet.t(atom()),
          metadata: map()
        }

  defstruct [
    :id,
    :seed,
    :policy,
    files: [],
    modules: MapSet.new(),
    functions: MapSet.new(),
    call_edges: MapSet.new(),
    call_paths: [],
    data_flows: [],
    effects: MapSet.new(),
    branches: [],
    architecture: %{},
    features: MapSet.new(),
    metadata: %{}
  ]

  @doc """
  Starts a model builder.

  Requires `:id`, `:seed`, and `:policy`.
  """
  def new(opts) do
    policy = Keyword.fetch!(opts, :policy)

    %__MODULE__{
      id: Keyword.fetch!(opts, :id),
      seed: Keyword.fetch!(opts, :seed),
      policy: policy,
      metadata: opts |> Keyword.get(:metadata, %{}) |> Map.put_new(:policy, policy)
    }
  end

  @doc """
  Adds a source file to the model.
  """
  def add_file(%__MODULE__{} = builder, %File{} = file),
    do: update_in(builder.files, &(&1 ++ [file]))

  @doc """
  Adds a module to the model.
  """
  def add_module(%__MODULE__{} = builder, module) when is_atom(module) do
    update_in(builder.modules, &MapSet.put(&1, module))
  end

  @doc """
  Adds a function id and its module to the model.
  """
  def add_function(%__MODULE__{} = builder, {module, function, arity} = mfa)
      when is_atom(module) and is_atom(function) and is_integer(arity) do
    builder
    |> add_module(module)
    |> update_in([Access.key!(:functions)], &MapSet.put(&1, mfa))
  end

  @doc """
  Adds a directed function call edge.

  Source and target functions are added automatically.
  """
  def add_call(%__MODULE__{} = builder, source, target) do
    builder
    |> add_function(source)
    |> add_function(target)
    |> update_in([Access.key!(:call_edges)], &MapSet.put(&1, {source, target}))
  end

  @doc """
  Adds a declared call path.

  Functions and pairwise call edges in the path are added automatically.
  """
  def add_call_path(%__MODULE__{} = builder, path) when is_list(path) do
    builder = Enum.reduce(path, builder, &add_function(&2, &1))

    path
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.reduce(builder, fn [source, target], acc -> add_call(acc, source, target) end)
    |> update_in([Access.key!(:call_paths)], &(&1 ++ [path]))
  end

  @doc """
  Adds a data-flow fact.
  """
  def add_data_flow(%__MODULE__{} = builder, data_flow) when is_map(data_flow) do
    update_in(builder.data_flows, &(&1 ++ [data_flow]))
  end

  @doc """
  Adds an effect fact.
  """
  def add_effect(%__MODULE__{} = builder, function, effect) when is_atom(effect) do
    add_effect(builder, {function, effect})
  end

  @doc """
  Adds an effect fact.
  """
  def add_effect(%__MODULE__{} = builder, {function, effect} = fact) when is_atom(effect) do
    builder
    |> add_function(function)
    |> update_in([Access.key!(:effects)], &MapSet.put(&1, fact))
  end

  @doc """
  Adds a branch fact.
  """
  def add_branch(%__MODULE__{} = builder, branch) when is_map(branch) do
    builder
    |> maybe_add_branch_function(branch)
    |> update_in([Access.key!(:branches)], &(&1 ++ [branch]))
  end

  @doc """
  Replaces architecture facts.
  """
  def put_architecture(%__MODULE__{} = builder, architecture) when is_map(architecture) do
    %{builder | architecture: architecture}
  end

  @doc """
  Adds one feature atom.
  """
  def add_feature(%__MODULE__{} = builder, feature) when is_atom(feature) do
    update_in(builder.features, &MapSet.put(&1, feature))
  end

  @doc """
  Adds multiple feature atoms.
  """
  def add_features(%__MODULE__{} = builder, features) do
    Enum.reduce(features, builder, &add_feature(&2, &1))
  end

  @doc """
  Merges metadata into the model metadata.
  """
  def put_metadata(%__MODULE__{} = builder, metadata) when is_map(metadata) do
    update_in(builder.metadata, &Map.merge(&1, metadata))
  end

  @doc """
  Builds a `ProgramFacts.Model`.
  """
  def build(%__MODULE__{} = builder) do
    Model.new(
      id: builder.id,
      seed: builder.seed,
      policy: builder.policy,
      files: builder.files,
      modules: MapSet.to_list(builder.modules),
      functions: MapSet.to_list(builder.functions),
      call_edges: MapSet.to_list(builder.call_edges),
      call_paths: builder.call_paths,
      data_flows: builder.data_flows,
      effects: MapSet.to_list(builder.effects),
      branches: builder.branches,
      architecture: builder.architecture,
      features: builder.features,
      metadata: builder.metadata
    )
  end

  defp maybe_add_branch_function(builder, %{function: function}),
    do: add_function(builder, function)

  defp maybe_add_branch_function(builder, _branch), do: builder
end
