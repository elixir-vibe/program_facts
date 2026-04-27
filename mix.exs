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

  defp deps do
    [
      {:ex_doc, "~> 0.38", only: :dev, runtime: false},
      {:stream_data, "~> 1.1", only: [:dev, :test]}
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
