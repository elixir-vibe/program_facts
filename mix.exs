defmodule ProgramFacts.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/dannote/program_facts"

  def project do
    [
      app: :program_facts,
      version: @version,
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      dialyzer: [
        plt_file: {:no_warn, "_build/dev/dialyxir_plt.plt"},
        plt_add_apps: [:mix]
      ],
      description: "Generate Elixir programs with known structural facts for analyzer testing.",
      package: package(),
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  def cli do
    [preferred_envs: [ci: :test]]
  end

  defp aliases do
    [
      ci: [
        "compile --warnings-as-errors",
        "format --check-formatted",
        "credo --strict",
        "ex_dna",
        "dialyzer",
        "test"
      ]
    ]
  end

  defp deps do
    [
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.38", only: :dev, runtime: false},
      {:ex_dna, "~> 1.1", only: [:dev, :test], runtime: false},
      {:stream_data, "~> 1.1", optional: true}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib mix.exs README.md ROADMAP.md LICENSE .formatter.exs)
    ]
  end

  defp docs do
    [
      main: "ProgramFacts",
      source_ref: "v#{@version}",
      source_url: @source_url,
      extras: ["README.md", "ROADMAP.md"]
    ]
  end
end
