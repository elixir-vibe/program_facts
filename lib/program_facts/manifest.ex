defmodule ProgramFacts.Manifest do
  @moduledoc """
  JSON manifest for a generated program.
  """

  alias ProgramFacts.{Facts, Program}

  @schema_version 1

  @derive JSON.Encoder
  @enforce_keys [:id, :seed, :files, :facts, :metadata]
  defstruct schema_version: @schema_version,
            program_facts_version: nil,
            id: nil,
            seed: nil,
            files: [],
            facts: nil,
            metadata: %{}

  @type t :: %__MODULE__{
          schema_version: pos_integer(),
          program_facts_version: String.t(),
          id: String.t(),
          seed: integer(),
          files: [map()],
          facts: map(),
          metadata: map()
        }

  @doc """
  Builds the JSON manifest for a generated program.
  """
  def new(%Program{} = program) do
    %__MODULE__{
      program_facts_version: package_version(),
      id: program.id,
      seed: program.seed,
      files: Enum.map(program.files, &ProgramFacts.Manifest.File.new/1),
      facts: ProgramFacts.Manifest.Facts.new(program.facts),
      metadata: value(program.metadata)
    }
  end

  @doc """
  Decodes a JSON manifest into a manifest struct.
  """
  def decode!(json) when is_binary(json) do
    json
    |> JSON.decode!()
    |> from_map!()
  end

  @doc """
  Builds a manifest struct from decoded JSON data.
  """
  def from_map!(%{
        "schema_version" => schema_version,
        "program_facts_version" => program_facts_version,
        "id" => id,
        "seed" => seed,
        "files" => files,
        "facts" => facts,
        "metadata" => metadata
      }) do
    %__MODULE__{
      schema_version: schema_version,
      program_facts_version: program_facts_version,
      id: id,
      seed: seed,
      files: value(files),
      facts: value(facts),
      metadata: value(metadata)
    }
  end

  def from_map!(%__MODULE__{} = manifest), do: manifest

  @doc """
  Converts a manifest or supported ProgramFacts struct to JSON-friendly Elixir data.
  """
  def to_map(%__MODULE__{} = manifest) do
    manifest
    |> Map.from_struct()
    |> value()
  end

  def to_map(%Program{} = program), do: program |> new() |> to_map()

  def to_map(%ProgramFacts.File{} = file),
    do: file |> ProgramFacts.Manifest.File.new() |> to_map()

  def to_map(%Facts{} = facts), do: facts |> ProgramFacts.Manifest.Facts.new() |> to_map()

  def to_map(%{__struct__: _} = struct) do
    struct
    |> Map.from_struct()
    |> value()
  end

  def to_map(%{} = map), do: value(map)

  defp value(%MapSet{} = set) do
    set
    |> MapSet.to_list()
    |> Enum.sort_by(&inspect/1)
    |> Enum.map(&value/1)
  end

  defp value(%{__struct__: _} = struct), do: to_map(struct)

  defp value(%{} = map) do
    Map.new(map, fn {key, nested} -> {manifest_key(key), value(nested)} end)
  end

  defp value(list) when is_list(list), do: Enum.map(list, &value/1)

  defp value(tuple) when is_tuple(tuple) do
    tuple
    |> Tuple.to_list()
    |> Enum.map(&value/1)
  end

  defp value(atom) when is_atom(atom) do
    if module?(atom), do: module_name(atom), else: atom
  end

  defp value(other), do: other

  defp manifest_key(key) when is_atom(key), do: key

  defp manifest_key(key) when is_binary(key) do
    Map.get(manifest_keys(), key, key)
  end

  defp manifest_keys do
    %{
      "analyzer" => :analyzer,
      "architecture" => :architecture,
      "arity" => :arity,
      "assignments" => :assignments,
      "branch_count" => :branch_count,
      "branches" => :branches,
      "call" => :call,
      "call_edges" => :call_edges,
      "call_paths" => :call_paths,
      "clauses" => :clauses,
      "command" => :command,
      "data_flows" => :data_flows,
      "depth" => :depth,
      "effect" => :effect,
      "effects" => :effects,
      "excluded_files" => :excluded_files,
      "expression" => :expression,
      "facts" => :facts,
      "features" => :features,
      "file" => :file,
      "files" => :files,
      "function" => :function,
      "functions" => :functions,
      "id" => :id,
      "index" => :index,
      "kind" => :kind,
      "layout" => :layout,
      "line" => :line,
      "metadata" => :metadata,
      "mismatch" => :mismatch,
      "module" => :module,
      "modules" => :modules,
      "name" => :name,
      "options" => :options,
      "path" => :path,
      "policy" => :policy,
      "program_facts_manifest" => :program_facts_manifest,
      "program_facts_version" => :program_facts_version,
      "program_id" => :program_id,
      "project_layout" => :project_layout,
      "schema_version" => :schema_version,
      "seed" => :seed,
      "shrink" => :shrink,
      "source" => :source,
      "steps" => :steps,
      "target" => :target,
      "transforms" => :transforms,
      "type" => :type,
      "width" => :width
    }
  end

  defp module?(atom) do
    atom
    |> Atom.to_string()
    |> String.starts_with?("Elixir.")
  end

  defp module_name(module) do
    module
    |> inspect()
    |> String.trim_leading("Elixir.")
  end

  defp package_version do
    case :application.get_key(:program_facts, :vsn) do
      {:ok, version} -> List.to_string(version)
      :undefined -> "0.2.0"
    end
  end
end
