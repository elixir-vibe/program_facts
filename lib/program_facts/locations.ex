defmodule ProgramFacts.Locations do
  @moduledoc """
  Derives coarse source locations from generated source files.
  """

  alias ProgramFacts.Program

  def attach(%Program{} = program) do
    locations = %{
      modules: module_locations(program),
      functions: function_locations(program)
    }

    put_in(program.facts.locations, locations)
  end

  defp module_locations(program) do
    program.files
    |> Enum.flat_map(fn file ->
      file.source
      |> lines()
      |> Enum.flat_map(fn {line, line_number} ->
        case Regex.run(~r/^defmodule\s+([^\s]+)\s+do$/, String.trim(line)) do
          [_, module] -> [%{module: module, file: file.path, line: line_number}]
          _no_match -> []
        end
      end)
    end)
  end

  defp function_locations(program) do
    program.files
    |> Enum.flat_map(fn file ->
      module = module_name(file.source)

      file.source
      |> lines()
      |> Enum.flat_map(fn {line, line_number} ->
        case Regex.run(~r/^def\s+([a-zA-Z_][a-zA-Z0-9_?!]*)\((.*)\)\s+do$/, String.trim(line)) do
          [_, function, args] ->
            [
              %{
                module: module,
                function: function,
                arity: arity(args),
                file: file.path,
                line: line_number
              }
            ]

          _no_match ->
            []
        end
      end)
    end)
  end

  defp module_name(source) do
    source
    |> lines()
    |> Enum.find_value(fn {line, _line_number} ->
      case Regex.run(~r/^defmodule\s+([^\s]+)\s+do$/, String.trim(line)) do
        [_, module] -> module
        _no_match -> nil
      end
    end)
  end

  defp lines(source) do
    source
    |> String.split("\n", trim: false)
    |> Enum.with_index(1)
  end

  defp arity("") do
    0
  end

  defp arity(args) do
    args
    |> String.split(",")
    |> length()
  end
end
