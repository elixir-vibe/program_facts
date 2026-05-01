defmodule ProgramFacts.ExUnit do
  @moduledoc """
  Test helpers for generated programs.
  """

  alias ProgramFacts.{Manifest, Program}

  @doc """
  Compiles generated source and verifies that expected modules are produced.
  """
  def assert_compiles(%Program{} = program) do
    modules = compile_modules(program)

    assert_equal(
      Enum.sort(modules),
      Enum.sort(program.facts.modules),
      "compiled modules differ from expected modules"
    )

    program
  end

  @doc """
  Encodes and decodes a generated program manifest and validates basic shape.
  """
  def assert_manifest_round_trip(%Program{} = program) do
    json = ProgramFacts.to_json!(program)
    manifest = Manifest.decode!(json)

    assert_equal(manifest.id, program.id, "manifest id differs from program id")

    assert_equal(
      length(manifest.files),
      length(program.files),
      "manifest file count differs from program files"
    )

    manifest
  end

  @doc """
  Writes a temporary Mix project, yields `{dir, program}`, then removes it.
  """
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

  defp assert_equal(left, right, message) do
    if left != right do
      raise ExUnit.AssertionError,
        message: "#{message}: left=#{inspect(left)} right=#{inspect(right)}"
    end
  end

  defp compile_modules(program) do
    purge_modules(program.facts.modules)

    program.files
    |> Enum.map_join("\n", & &1.source)
    |> Code.compile_string("generated_program.exs")
    |> Enum.map(fn {module, _bytecode} -> module end)
  end

  defp purge_modules(modules) do
    Enum.each(modules, fn module ->
      :code.purge(module)
      :code.delete(module)
    end)
  end
end
