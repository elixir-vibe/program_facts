defmodule ProgramFacts.Manifest do
  @moduledoc """
  JSON manifest for a generated program.
  """

  alias ProgramFacts.{Facts, File, Program}

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
      files: Enum.map(program.files, &file/1),
      facts: facts(program.facts),
      metadata: value(program.metadata)
    }
  end

  @doc """
  Converts a manifest or supported ProgramFacts struct to a JSON-friendly map.
  """
  def to_map(%__MODULE__{} = manifest) do
    manifest
    |> Map.from_struct()
    |> value()
  end

  def to_map(%Program{} = program), do: program |> new() |> to_map()
  def to_map(%File{} = file), do: file(file)
  def to_map(%Facts{} = facts), do: facts(facts)

  defp file(%File{} = file) do
    %{
      path: file.path,
      source: file.source,
      kind: file.kind
    }
    |> value()
  end

  defp facts(%Facts{} = facts) do
    facts
    |> Map.from_struct()
    |> value()
  end

  defp value(%MapSet{} = set) do
    set
    |> MapSet.to_list()
    |> Enum.sort_by(&inspect/1)
    |> Enum.map(&value/1)
  end

  defp value(%{} = map) do
    Map.new(map, fn {key, nested} -> {key, value(nested)} end)
  end

  defp value(list) when is_list(list), do: Enum.map(list, &value/1)

  defp value({:param, function, name}) do
    %{
      type: :param,
      function: value(function),
      name: name
    }
  end

  defp value({:arg, function, index}) do
    %{
      type: :arg,
      function: value(function),
      index: index
    }
  end

  defp value({:return, function}) do
    %{
      type: :return,
      function: value(function)
    }
  end

  defp value({:var, function, name}) do
    %{
      type: :var,
      function: value(function),
      name: name
    }
  end

  defp value(
         {{source_module, source_function, source_arity},
          {target_module, target_function, target_arity}}
       ) do
    %{
      source: value({source_module, source_function, source_arity}),
      target: value({target_module, target_function, target_arity})
    }
  end

  defp value({{module, function, arity}, effect})
       when is_atom(module) and is_atom(function) and is_integer(arity) and is_atom(effect) do
    %{
      function: value({module, function, arity}),
      effect: effect
    }
  end

  defp value({module, function, arity})
       when is_atom(module) and is_atom(function) and is_integer(arity) do
    %{
      module: module_name(module),
      function: Atom.to_string(function),
      arity: arity,
      id: "#{module_name(module)}.#{function}/#{arity}"
    }
  end

  defp value(tuple) when is_tuple(tuple) do
    tuple
    |> Tuple.to_list()
    |> Enum.map(&value/1)
  end

  defp value(atom) when is_atom(atom) do
    if module?(atom), do: module_name(atom), else: atom
  end

  defp value(other), do: other

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
