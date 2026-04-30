defmodule ProgramFacts.Analyzer do
  @moduledoc """
  Behaviour and helpers for analyzer adapters.

  An adapter turns a generated `ProgramFacts.Program` into normalized analyzer
  facts that can be compared by `ProgramFacts.Differential`.
  """

  alias ProgramFacts.Analyzer.Result
  alias ProgramFacts.Program

  @callback name() :: atom() | String.t()
  @callback analyze(Program.t()) :: Result.t() | map()

  @doc """
  Runs an adapter module or `{name, function}` analyzer callback.
  """
  def run(adapter, %Program{} = program) when is_atom(adapter) do
    adapter.analyze(program)
    |> Result.new(name: adapter.name())
  rescue
    exception -> Result.error(adapter.name(), exception)
  end

  def run({name, function}, %Program{} = program) when is_function(function, 1) do
    function.(program)
    |> Result.new(name: name)
  rescue
    exception -> Result.error(name, exception)
  end
end
