defmodule ProgramFacts.Project do
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

    write!(dir, program)

    {:ok, dir, program}
  end

  def write!(dir, %Program{} = program) do
    File.rm_rf!(dir)
    File.mkdir_p!(dir)
    File.write!(Path.join(dir, "mix.exs"), mix_project_source(program))
    File.write!(Path.join(dir, "program_facts.json"), ProgramFacts.to_json!(program))

    Enum.each(program.files, fn file ->
      path = Path.join(dir, file.path)
      File.mkdir_p!(Path.dirname(path))
      File.write!(path, file.source)
    end)

    dir
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

  defp unique_suffix do
    System.unique_integer([:positive, :monotonic])
    |> Integer.to_string(36)
  end
end
