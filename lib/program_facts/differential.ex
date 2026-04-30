defmodule ProgramFacts.Differential do
  @moduledoc """
  Differential analyzer comparison.

  An analyzer can be a module implementing `ProgramFacts.Analyzer` or a
  `{name, fun}` callback where `fun.(program)` returns facts, a map, or an
  analyzer result.
  """

  alias ProgramFacts.{Analyzer, Program}
  alias ProgramFacts.Analyzer.Result

  @type analyzer :: module() | {atom() | String.t(), (Program.t() -> term())}

  @doc """
  Runs analyzers against a program and reports whether normalized facts agree.
  """
  @spec compare(Program.t(), [analyzer()]) :: map()
  def compare(%Program{} = program, analyzers) when is_list(analyzers) do
    results = Enum.map(analyzers, &Analyzer.run(&1, program))
    outputs = Enum.map(results, &comparable_output/1)

    %{
      agree?: Enum.uniq(outputs) |> length() <= 1,
      results: results,
      disagreements: disagreements(results)
    }
  end

  defp comparable_output(%Result{error: nil, facts: facts}), do: facts
  defp comparable_output(%Result{error: error}), do: {:error, error}

  defp disagreements([]), do: []

  defp disagreements([first | rest]) do
    first_output = comparable_output(first)

    rest
    |> Enum.reject(&(comparable_output(&1) == first_output))
    |> Enum.map(fn result -> %{left: first.name, right: result.name} end)
  end
end
