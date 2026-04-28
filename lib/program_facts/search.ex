defmodule ProgramFacts.Search do
  @moduledoc """
  Simple feedback-directed generation over ProgramFacts features.
  """

  def run(opts \\ []) do
    iterations = Keyword.get(opts, :iterations, length(ProgramFacts.policies()))
    policies = Keyword.get(opts, :policies, ProgramFacts.policies())
    layouts = Keyword.get(opts, :layouts, ProgramFacts.layouts())
    seed = Keyword.get(opts, :seed, 1)

    0..(iterations - 1)
    |> Enum.reduce(initial_state(), fn index, state ->
      program = generate_candidate(index, seed, policies, layouts)
      maybe_keep(program, state)
    end)
    |> Map.update!(:programs, &Enum.reverse/1)
  end

  defp initial_state do
    %{programs: [], features: MapSet.new(), coverage: %{feature_count: 0, program_count: 0}}
  end

  defp generate_candidate(index, seed, policies, layouts) do
    ProgramFacts.generate!(
      policy: Enum.at(policies, rem(index, length(policies))),
      layout: Enum.at(layouts, rem(index, length(layouts))),
      seed: seed + index,
      depth: 2 + rem(index, 5),
      width: 2 + rem(index, 4)
    )
  end

  defp maybe_keep(program, state) do
    new_features = MapSet.difference(program.facts.features, state.features)

    if MapSet.size(new_features) > 0 do
      features = MapSet.union(state.features, program.facts.features)

      %{
        state
        | programs: [program | state.programs],
          features: features,
          coverage: %{
            feature_count: MapSet.size(features),
            program_count: length(state.programs) + 1
          }
      }
    else
      state
    end
  end
end
