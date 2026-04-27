defmodule ProgramFacts.Export do
  @moduledoc """
  Converts generated programs and facts into JSON-friendly maps.
  """

  alias ProgramFacts.{Facts, File, Program}

  def to_map(%Program{} = program) do
    %{
      id: program.id,
      seed: program.seed,
      files: Enum.map(program.files, &to_map/1),
      facts: to_map(program.facts),
      metadata: jsonable(program.metadata)
    }
    |> jsonable()
  end

  def to_map(%File{} = file) do
    %{
      path: file.path,
      source: file.source,
      kind: file.kind
    }
    |> jsonable()
  end

  def to_map(%Facts{} = facts) do
    facts
    |> Map.from_struct()
    |> jsonable()
  end

  def to_json!(value) do
    value
    |> to_map()
    |> JSON.encode!()
  end

  defp jsonable(%MapSet{} = set) do
    set
    |> MapSet.to_list()
    |> Enum.map(&jsonable/1)
  end

  defp jsonable(%{} = map) do
    Map.new(map, fn {key, value} -> {json_key(key), jsonable(value)} end)
  end

  defp jsonable(list) when is_list(list), do: Enum.map(list, &jsonable/1)

  defp jsonable({module, function, arity})
       when is_atom(module) and is_atom(function) and is_integer(arity) do
    %{
      module: module_name(module),
      function: Atom.to_string(function),
      arity: arity,
      id: "#{module_name(module)}.#{function}/#{arity}"
    }
  end

  defp jsonable(tuple) when is_tuple(tuple) do
    tuple
    |> Tuple.to_list()
    |> Enum.map(&jsonable/1)
  end

  defp jsonable(atom) when is_atom(atom) do
    if module?(atom), do: module_name(atom), else: Atom.to_string(atom)
  end

  defp jsonable(value), do: value

  defp json_key(atom) when is_atom(atom), do: Atom.to_string(atom)
  defp json_key(value), do: to_string(value)

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
end
