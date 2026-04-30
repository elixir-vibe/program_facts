defmodule ProgramFacts.Project do
  @moduledoc """
  Writes generated programs to Mix project directories.
  """

  alias ProgramFacts.Program

  @doc """
  Writes a generated program or generated options to a temporary Mix project.
  """
  def write_tmp!(%Program{} = program) do
    write_tmp!(program, [])
  end

  def write_tmp!(opts) when is_list(opts) do
    program = ProgramFacts.generate!(opts)
    write_tmp!(program, opts)
  end

  @doc """
  Writes a generated program to a temporary Mix project using `opts`.
  """
  def write_tmp!(%Program{} = program, opts) do
    root = Keyword.get(opts, :root, System.tmp_dir!())
    dir = Path.join(root, program.id <> "_" <> unique_suffix())

    write!(dir, program, force: true)

    {:ok, dir, program}
  end

  @doc """
  Writes `program` to `dir` as a Mix project.

  By default the target directory must be empty. Pass `force: true` to replace
  it. Source paths are checked so arbitrary program structs cannot write outside
  the target directory.
  """
  def write!(dir, %Program{} = program), do: write!(dir, program, [])

  @doc """
  Writes `program` to `dir` as a Mix project.

  By default the target directory must be empty. Pass `force: true` to replace
  it. Source paths are checked so arbitrary program structs cannot write outside
  the target directory.
  """
  def write!(dir, %Program{} = program, opts) do
    root = Path.expand(dir)

    prepare_dir!(root, opts)
    File.write!(Path.join(root, "mix.exs"), mix_project_source(program))
    File.write!(Path.join(root, "program_facts.json"), ProgramFacts.to_json!(program))
    write_excluded_files!(root, program)
    write_source_files!(root, program.files)
    root
  end

  defp prepare_dir!(dir, opts) do
    if Keyword.get(opts, :force, false) do
      File.rm_rf!(dir)
      File.mkdir_p!(dir)
    else
      create_empty_dir!(dir)
    end
  end

  defp create_empty_dir!(dir) do
    case File.ls(dir) do
      {:ok, []} -> :ok
      {:ok, _entries} -> raise ArgumentError, "refusing to write into non-empty directory: #{dir}"
      {:error, :enoent} -> File.mkdir_p!(dir)
      {:error, reason} -> raise File.Error, reason: reason, action: "list directory", path: dir
    end
  end

  defp write_source_files!(dir, files) do
    Enum.each(files, fn file ->
      path = safe_join!(dir, file.path)
      File.mkdir_p!(Path.dirname(path))
      File.write!(path, file.source)
    end)
  end

  defp write_excluded_files!(dir, program) do
    program.metadata
    |> get_in([:project_layout, :excluded_files])
    |> List.wrap()
    |> Enum.each(fn relative_path ->
      path = safe_join!(dir, relative_path)
      File.mkdir_p!(Path.dirname(path))
      File.write!(path, excluded_source())
    end)
  end

  defp safe_join!(root, relative_path) do
    if Path.type(relative_path) == :absolute do
      raise ArgumentError, "file path escapes project root: #{relative_path}"
    end

    root = Path.expand(root)
    path = Path.expand(Path.join(root, relative_path))

    unless String.starts_with?(path, root <> "/") do
      raise ArgumentError, "file path escapes project root: #{relative_path}"
    end

    path
  end

  defp excluded_source do
    """
    defmodule Generated.ProgramFacts.Excluded do
      def ignored(value), do: value
    end
    """
  end

  defp mix_project_source(program) do
    app = program.id |> String.replace("-", "_") |> String.to_atom()

    """
    defmodule GeneratedProject.MixProject do
      use Mix.Project

      def project do
        [
          app: #{inspect(app)},
          version: "0.1.0",
          elixir: "~> 1.19",
          elixirc_paths: #{inspect(elixirc_paths(program))},
          start_permanent: Mix.env() == :prod,
          deps: []
        ]
      end

      def application do
        [extra_applications: [:logger]]
      end
    end
    """
  end

  defp elixirc_paths(program) do
    program.files
    |> Enum.filter(&(&1.kind == :elixir))
    |> Enum.map(&source_root/1)
    |> Enum.uniq()
  end

  defp source_root(file) do
    file.path
    |> Path.split()
    |> Enum.split_while(&(&1 != "lib"))
    |> case do
      {prefix, ["lib" | _rest]} -> Path.join(prefix ++ ["lib"])
      _no_lib_path -> Path.dirname(file.path)
    end
  end

  defp unique_suffix do
    System.unique_integer([:positive, :monotonic])
    |> Integer.to_string(36)
  end
end
