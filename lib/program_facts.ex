defmodule ProgramFacts do
  @moduledoc """
  Generate Elixir programs with known structural facts.

  ProgramFacts creates small Elixir projects that are valid by construction and
  include ground-truth facts such as modules, functions, call edges, call paths,
  and data-flow relationships.
  """

  alias ProgramFacts.{Export, Generate, Layout}

  @doc """
  Returns the supported generation policies.
  """
  def policies, do: Generate.policies()

  @doc """
  Returns the supported project layouts.
  """
  def layouts, do: Layout.layouts()

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
  def generate!(opts \\ []), do: Generate.generate!(opts)

  @doc """
  Converts a generated program, file, or facts struct into a JSON-friendly map.
  """
  def to_map(value), do: Export.to_map(value)

  @doc """
  Encodes a generated program, file, or facts struct as JSON.
  """
  def to_json!(value), do: Export.to_json!(value)
end
