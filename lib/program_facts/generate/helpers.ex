defmodule ProgramFacts.Generate.Helpers do
  @moduledoc false

  def pairwise_edges(functions) do
    functions
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [source, target] -> {source, target} end)
  end

  def id(seed, policy), do: "pf_#{seed}_#{policy}"
end
