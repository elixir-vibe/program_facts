defmodule ProgramFacts do
  @moduledoc """
  Generate Elixir programs with known structural facts.

  ProgramFacts creates small Elixir projects that are valid by construction and
  include ground-truth facts such as modules, functions, call edges, call paths,
  and data-flow relationships.
  """

  alias ProgramFacts.{Differential, Export, Generate, Layout, Metamorphic, Shrink, Transform}

  @doc """
  Returns the supported generation policies.
  """
  def policies, do: Generate.policies()

  @doc """
  Returns the supported project layouts.
  """
  def layouts, do: Layout.layouts()

  @doc """
  Returns the supported program transforms.
  """
  def transforms, do: Transform.transforms()

  @doc """
  Generates a program with source files and expected facts.

  ## Options

    * `:policy` - generation policy, defaults to `:linear_call_chain`
    * `:seed` - deterministic seed namespace, defaults to `1`
    * `:depth` - call-chain depth for `:linear_call_chain`, defaults to `3`

  ## Examples

      iex> program = ProgramFacts.generate!(policy: :linear_call_chain, seed: 7, depth: 2)
      iex> length(program.files)
      2
      iex> length(program.facts.call_edges)
      1
  """
  def generate!, do: Generate.generate!([])

  @doc """
  Generates a program with source files and expected facts.
  """
  def generate!(opts), do: Generate.generate!(opts)

  @doc """
  Projects a generated program into its semantic summary model.
  """
  def model(program), do: ProgramFacts.Model.from_program(program)

  @doc """
  Shrinks a failing generated program while `failure?` continues to return true.
  """
  def shrink(program, failure?), do: Shrink.shrink(program, failure?, [])

  @doc """
  Shrinks a failing generated program while `failure?` continues to return true.
  """
  def shrink(program, failure?, opts), do: Shrink.shrink(program, failure?, opts)

  @doc """
  Compares transform invariant claims between an original and transformed program.
  """
  def compare_transform(original, transformed), do: Metamorphic.compare(original, transformed)

  @doc """
  Raises if a transform changed a fact it claimed to preserve.
  """
  def assert_transform_preserved!(original, transformed),
    do: Metamorphic.assert_preserved!(original, transformed)

  @doc """
  Runs multiple analyzer callbacks against a generated program and compares outputs.
  """
  def differential(program, analyzers), do: Differential.compare(program, analyzers)

  @doc """
  Converts a generated program, file, or facts struct into a JSON-friendly map.
  """
  def to_map(value), do: Export.to_map(value)

  @doc """
  Encodes a generated program, file, or facts struct as JSON.
  """
  def to_json!(value), do: Export.to_json!(value)
end
