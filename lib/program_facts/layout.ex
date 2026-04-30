defmodule ProgramFacts.Layout do
  @moduledoc """
  Applies project-layout path conventions to generated programs.
  """

  alias ProgramFacts.{File, Program}

  @layouts [:plain, :umbrella, :package_style]

  @doc """
  Returns supported generated project layouts.
  """
  def layouts, do: @layouts

  @doc """
  Rewrites generated file paths and layout metadata for `layout`.
  """
  def apply(%Program{} = program, layout) when layout in @layouts do
    files = Enum.map(program.files, &apply_to_file(&1, layout))
    included_files = Enum.map(files, & &1.path)

    metadata =
      program.metadata
      |> Map.put(:layout, layout)
      |> Map.put(:project_layout, %{
        layout: layout,
        included_files: included_files,
        excluded_files: excluded_files(layout)
      })

    %{program | files: files, metadata: metadata}
  end

  def apply(%Program{}, layout) do
    raise ArgumentError, "unknown project layout: #{inspect(layout)}"
  end

  defp apply_to_file(%File{} = file, :plain), do: file

  defp apply_to_file(%File{} = file, :umbrella) do
    %{file | path: Path.join(["apps", "generated_app", file.path])}
  end

  defp apply_to_file(%File{} = file, :package_style) do
    %{file | path: Path.join(["generated_package", file.path])}
  end

  defp excluded_files(:plain), do: ["deps/ignored/lib/ignored.ex", "_build/dev/lib/ignored.ex"]

  defp excluded_files(:umbrella) do
    [
      "apps/generated_app/deps/ignored/lib/ignored.ex",
      "apps/generated_app/_build/dev/lib/ignored.ex"
    ]
  end

  defp excluded_files(:package_style) do
    [
      "generated_package/deps/ignored/lib/ignored.ex",
      "generated_package/_build/dev/lib/ignored.ex"
    ]
  end
end
