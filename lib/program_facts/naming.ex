defmodule ProgramFacts.Naming do
  @moduledoc false

  @max_seed 10_000
  @max_module_count 26

  def max_seed, do: @max_seed
  def max_module_count, do: @max_module_count

  def modules(seed, count) when is_integer(seed) and is_integer(count) do
    namespace = Module.concat([Generated, ProgramFacts, "Seed#{seed}"])

    0..(count - 1)
    |> Enum.map(fn index -> Module.concat(namespace, module_suffix(index)) end)
  end

  def function_name(module) do
    module
    |> Module.split()
    |> List.last()
    |> String.downcase()
    |> String.to_atom()
  end

  def module_path(module) do
    path =
      module
      |> Module.split()
      |> Enum.map(&Macro.underscore/1)
      |> Path.join()

    Path.join("lib", path <> ".ex")
  end

  defp module_suffix(index) when index >= 0 and index < @max_module_count do
    index
    |> then(&(&1 + ?A))
    |> List.wrap()
    |> to_string()
  end
end
