defmodule ProgramFacts.Project do
  @moduledoc """
  Writes generated programs to Mix project directories.
  """

  alias ProgramFacts.Program

  def write_tmp!(%Program{} = program) do
    write_tmp!(program, [])
  end

  def write_tmp!(opts) when is_list(opts) do
    program = ProgramFacts.generate!(opts)
    write_tmp!(program, opts)
  end

  def write_tmp!(%Program{} = program, opts) do
    root = Keyword.get(opts, :root, System.tmp_dir!())
    dir = Path.join(root, program.id <> "_" <> unique_suffix())

    write!(dir, program, force: true)

    {:ok, dir, program}
  end

  def write!(dir, %Program{} = program, opts \\ []) do
    prepare_dir!(dir, opts)
    File.write!(Path.join(dir, "mix.exs"), mix_project_source(program))
    File.write!(Path.join(dir, "program_facts.json"), ProgramFacts.to_json!(program))
    write_excluded_files!(dir, program)
    write_source_files!(dir, program.files)
    dir
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
      path = Path.join(dir, file.path)
      File.mkdir_p!(Path.dirname(path))
      File.write!(path, file.source)
    end)
  end

  defp write_excluded_files!(dir, program) do
    program.metadata
    |> get_in([:project_layout, :excluded_files])
    |> List.wrap()
    |> Enum.each(fn relative_path ->
      path = Path.join(dir, relative_path)
      File.mkdir_p!(Path.dirname(path))
      File.write!(path, excluded_source())
    end)
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
