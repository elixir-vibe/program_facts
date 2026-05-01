defmodule ProgramFacts.Export do
  @moduledoc """
  Converts generated programs and facts into JSON-friendly manifests.
  """

  alias ProgramFacts.{Facts, File, Manifest, Program}

  @doc """
  Converts a generated program, file, or facts struct into JSON-friendly data.
  """
  def to_map(%Program{} = program), do: Manifest.to_map(program)
  def to_map(%File{} = file), do: Manifest.to_map(file)
  def to_map(%Facts{} = facts), do: Manifest.to_map(facts)

  @doc """
  Encodes a generated program, file, or facts struct as JSON.
  """
  def to_json!(%Program{} = program) do
    program
    |> Manifest.new()
    |> JSON.encode!()
  end

  def to_json!(value) do
    value
    |> to_map()
    |> JSON.encode!()
  end
end
