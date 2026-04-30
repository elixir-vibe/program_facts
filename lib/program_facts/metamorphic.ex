defmodule ProgramFacts.Metamorphic do
  @moduledoc """
  Helpers for checking transform invariants.
  """

  alias ProgramFacts.Program

  @fact_keys [
    :modules,
    :functions,
    :call_edges,
    :call_paths,
    :data_flows,
    :effects,
    :branches,
    :architecture,
    :features
  ]

  @doc """
  Compares facts that a transform claimed to preserve.
  """
  def compare(%Program{} = before, %Program{} = after_) do
    preserved = preserved_facts(after_)

    mismatches =
      preserved
      |> Enum.filter(&(&1 in @fact_keys))
      |> Enum.reject(fn key -> Map.fetch!(before.facts, key) == Map.fetch!(after_.facts, key) end)

    %{valid?: mismatches == [], preserved: preserved, mismatches: mismatches}
  end

  @doc """
  Raises if a transform changed a fact it claimed to preserve.
  """
  def assert_preserved!(%Program{} = before, %Program{} = after_) do
    result = compare(before, after_)

    unless result.valid? do
      raise ArgumentError, "transform invariant mismatch for #{inspect(result.mismatches)}"
    end

    after_
  end

  defp preserved_facts(program) do
    program.metadata
    |> Map.get(:transforms, [])
    |> List.wrap()
    |> Enum.flat_map(&Map.get(&1, :preserves, []))
    |> Enum.uniq()
  end
end
