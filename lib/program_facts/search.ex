defmodule ProgramFacts.Search do
  @moduledoc """
  Feedback-directed generation over ProgramFacts features and user callbacks.
  """

  @doc """
  Runs a deterministic search over generated programs.

  Options include `:iterations`, `:seed`, `:policies`, `:layouts`, `:scoring`,
  `:score`, `:interesting?`, and `:on_candidate`.
  """
  def run, do: run([])

  @doc """
  Runs a deterministic search over generated programs.

  Options include `:iterations`, `:seed`, `:policies`, `:layouts`, `:scoring`,
  `:score`, `:interesting?`, and `:on_candidate`.
  """
  def run(opts) do
    iterations =
      validate_iterations!(Keyword.get(opts, :iterations, length(ProgramFacts.policies())))

    policies =
      validate_non_empty!(Keyword.get(opts, :policies, ProgramFacts.policies()), :policies)

    layouts = validate_non_empty!(Keyword.get(opts, :layouts, ProgramFacts.layouts()), :layouts)
    seed = Keyword.get(opts, :seed, 1)
    scoring = Keyword.get(opts, :scoring, [:features])

    score =
      Keyword.get(opts, :score, fn program, state -> score_program(program, state, scoring) end)

    interesting? = Keyword.get(opts, :interesting?, &default_interesting?/2)
    on_candidate = Keyword.get(opts, :on_candidate, fn _candidate, _state -> :ok end)

    0..(iterations - 1)//1
    |> Enum.reduce(initial_state(), fn index, state ->
      program = generate_candidate(index, seed, policies, layouts)
      candidate = candidate(program, state, score)
      on_candidate.(candidate, state)
      maybe_keep(candidate, state, interesting?)
    end)
    |> finalize()
  end

  defp validate_iterations!(iterations) when is_integer(iterations) and iterations >= 0,
    do: iterations

  defp validate_iterations!(_iterations),
    do: raise(ArgumentError, ":iterations must be a non-negative integer")

  defp validate_non_empty!([_head | _tail] = values, _name), do: values

  defp validate_non_empty!(_values, name),
    do: raise(ArgumentError, ":#{name} must be a non-empty list")

  defp initial_state do
    %{
      programs: [],
      candidates: [],
      features: MapSet.new(),
      best_score: 0,
      coverage: %{feature_count: 0, program_count: 0, candidate_count: 0}
    }
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

  defp candidate(program, state, score) do
    new_features = MapSet.difference(program.facts.features, state.features)

    %{
      program: program,
      features: program.facts.features,
      new_features: new_features,
      graph_metrics: maybe_graph_metrics(program),
      score: score.(program, state)
    }
  end

  defp maybe_keep(candidate, state, interesting?) do
    state = %{state | candidates: [candidate | state.candidates]}

    if interesting?.(candidate, state) do
      keep(candidate, state)
    else
      update_candidate_count(state)
    end
  end

  defp keep(candidate, state) do
    features = MapSet.union(state.features, candidate.features)

    %{
      state
      | programs: [candidate.program | state.programs],
        features: features,
        best_score: max(state.best_score, candidate.score),
        coverage: %{
          feature_count: MapSet.size(features),
          program_count: length(state.programs) + 1,
          candidate_count: length(state.candidates)
        }
    }
  end

  defp update_candidate_count(state) do
    put_in(state.coverage.candidate_count, length(state.candidates))
  end

  defp finalize(state) do
    %{
      state
      | programs: Enum.reverse(state.programs),
        candidates: Enum.reverse(state.candidates),
        coverage: %{state.coverage | candidate_count: length(state.candidates)}
    }
  end

  defp score_program(program, state, scoring) when is_list(scoring) do
    Enum.reduce(scoring, 0, fn scoring_mode, total ->
      total + score_component(program, state, scoring_mode)
    end)
  end

  defp score_component(program, _state, :features), do: MapSet.size(program.facts.features)

  defp score_component(program, state, :new_features) do
    program.facts.features
    |> MapSet.difference(state.features)
    |> MapSet.size()
  end

  defp score_component(program, _state, :graph_complexity) do
    metrics = ProgramFacts.Graph.metrics(program)
    metrics.vertices + metrics.edges + metrics.module_edges
  end

  defp score_component(program, _state, :cycles), do: ProgramFacts.Graph.metrics(program).cycles

  defp score_component(program, _state, :long_paths),
    do: ProgramFacts.Graph.metrics(program).longest_declared_call_path

  defp score_component(_program, _state, mode) do
    raise ArgumentError, "unknown scoring mode: #{inspect(mode)}"
  end

  defp maybe_graph_metrics(program) do
    if Code.ensure_loaded?(Graph) do
      ProgramFacts.Graph.metrics(program)
    else
      nil
    end
  end

  defp default_interesting?(candidate, state) do
    MapSet.size(candidate.new_features) > 0 or candidate.score > state.best_score
  end
end
