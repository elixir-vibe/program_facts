defmodule ProgramFacts.Corpus do
  @moduledoc """
  Saves generated programs as replayable corpus entries.
  """

  alias ProgramFacts.Corpus.Failure
  alias ProgramFacts.Program

  @doc """
  Writes a generated program to a replayable corpus directory under `root`.
  """
  def save!(%Program{} = program, root) when is_binary(root) do
    dir = Path.join([root, policy_name(program), program.id])
    ProgramFacts.Project.write!(dir, program, force: true)
    dir
  end

  @doc """
  Returns sorted `program_facts.json` manifest paths below `root`.
  """
  def manifests(root) when is_binary(root) do
    root
    |> Path.join("**/program_facts.json")
    |> Path.wildcard()
    |> Enum.sort()
  end

  @doc """
  Loads the `program_facts.json` manifest from a corpus entry directory.
  """
  def load_manifest!(dir) when is_binary(dir) do
    dir
    |> Path.join("program_facts.json")
    |> File.read!()
    |> JSON.decode!()
  end

  @doc """
  Loads all manifests below a corpus root.
  """
  def load_manifests!(root) when is_binary(root) do
    root
    |> manifests()
    |> Enum.map(fn manifest ->
      manifest
      |> File.read!()
      |> JSON.decode!()
    end)
  end

  @doc """
  Saves a failing program or shrink result and writes failure metadata for replay.
  """
  def promote_failure!(%Program{} = program, root),
    do: promote_failure!(program, root, Failure.new(program))

  def promote_failure!(%{program: %Program{}} = shrink_result, root) when is_binary(root) do
    promote_failure!(shrink_result.program, root, Failure.from_shrink_result(shrink_result))
  end

  @doc """
  Saves a failing program and writes failure metadata for later replay.
  """
  def promote_failure!(%Program{} = program, root, %Failure{} = failure) when is_binary(root) do
    dir = save!(program, Path.join(root, "failures"))
    failure_path = Path.join(dir, "failure.json")

    File.write!(failure_path, JSON.encode!(failure))

    dir
  end

  def promote_failure!(%Program{} = program, root, metadata)
      when is_binary(root) and is_list(metadata) do
    promote_failure!(program, root, Failure.new(program, metadata))
  end

  @doc """
  Loads a manifest and passes `%{dir: dir, manifest: manifest}` to `analyzer`.
  """
  def replay!(manifest_path, analyzer)
      when is_binary(manifest_path) and is_function(analyzer, 1) do
    manifest = manifest_path |> File.read!() |> JSON.decode!()
    dir = Path.dirname(manifest_path)
    analyzer.(%{dir: dir, manifest: manifest})
  end

  defp policy_name(program) do
    program.metadata
    |> Map.fetch!(:policy)
    |> Atom.to_string()
  end
end
