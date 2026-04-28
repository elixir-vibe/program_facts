defmodule ProgramFacts.Corpus do
  @moduledoc """
  Saves generated programs as replayable corpus entries.
  """

  alias ProgramFacts.Program

  def save!(%Program{} = program, root) when is_binary(root) do
    dir = Path.join([root, policy_name(program), program.id])
    ProgramFacts.Project.write!(dir, program, force: true)
    dir
  end

  def load_manifest!(dir) when is_binary(dir) do
    dir
    |> Path.join("program_facts.json")
    |> File.read!()
    |> JSON.decode!()
  end

  defp policy_name(program) do
    program.metadata
    |> Map.fetch!(:policy)
    |> Atom.to_string()
  end
end
