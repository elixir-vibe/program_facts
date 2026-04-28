defmodule ProgramFacts.ExUnit do
  @moduledoc """
  Test helpers for generated programs.
  """

  import ExUnit.Assertions

  alias ProgramFacts.Program

  def assert_compiles(%Program{} = program) do
    modules = compile_modules(program)
    assert Enum.sort(modules) == Enum.sort(program.facts.modules)
    program
  end

  def assert_manifest_round_trip(%Program{} = program) do
    json = ProgramFacts.to_json!(program)
    manifest = JSON.decode!(json)

    assert manifest["id"] == program.id
    assert length(manifest["files"]) == length(program.files)

    manifest
  end

  def with_tmp_project(%Program{} = program, function) when is_function(function, 2) do
    {:ok, dir, program} = ProgramFacts.Project.write_tmp!(program)

    try do
      function.(dir, program)
    after
      File.rm_rf!(dir)
    end
  end

  def with_tmp_project(opts, function) when is_list(opts) and is_function(function, 2) do
    opts
    |> ProgramFacts.generate!()
    |> with_tmp_project(function)
  end

  defp compile_modules(program) do
    program.files
    |> Enum.map_join("\n", & &1.source)
    |> Code.compile_string("generated_program.exs")
    |> Enum.map(fn {module, _bytecode} -> module end)
  end
end
