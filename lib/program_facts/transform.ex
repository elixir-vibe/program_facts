defmodule ProgramFacts.Transform do
  @moduledoc """
  Fact-aware transformations for generated programs.
  """

  alias ProgramFacts.{File, Locations, Program}

  @transforms [:add_dead_pure_statement, :add_unrelated_module, :rename_variables]

  def transforms, do: @transforms

  def apply!(%Program{} = program, transforms) when is_list(transforms) do
    Enum.reduce(transforms, program, &apply!(&2, &1))
  end

  def apply!(%Program{} = program, :add_dead_pure_statement) do
    program
    |> update_files(&add_dead_pure_statement/1)
    |> record_transform(:add_dead_pure_statement, [
      :modules,
      :functions,
      :call_edges,
      :call_paths,
      :data_flows,
      :effects,
      :branches
    ])
    |> Locations.attach()
  end

  def apply!(%Program{} = program, :add_unrelated_module) do
    module = Module.concat([Generated, ProgramFacts, Extra, Macro.camelize(program.id)])
    function = {module, :unrelated, 1}

    file = %File{
      path: module_path(module),
      kind: :elixir,
      source: """
      defmodule #{inspect(module)} do
        def unrelated(value) do
          value
        end
      end
      """
    }

    program
    |> Map.update!(:files, &(&1 ++ [file]))
    |> put_in([Access.key!(:facts), Access.key!(:modules)], program.facts.modules ++ [module])
    |> put_in(
      [Access.key!(:facts), Access.key!(:functions)],
      program.facts.functions ++ [function]
    )
    |> record_transform(:add_unrelated_module, [
      :call_edges,
      :call_paths,
      :data_flows,
      :effects,
      :branches
    ])
    |> Locations.attach()
  end

  def apply!(%Program{} = program, :rename_variables) do
    mapping = %{input: :arg, value: :item, message: :payload, reason: :cause}

    program
    |> update_files(&rename_source_variables(&1, mapping))
    |> update_in([Access.key!(:facts)], &rename_fact_variables(&1, mapping))
    |> record_transform(:rename_variables, [
      :modules,
      :functions,
      :call_edges,
      :call_paths,
      :effects
    ])
    |> Locations.attach()
  end

  def apply!(%Program{}, transform) do
    raise ArgumentError, "unknown transform: #{inspect(transform)}"
  end

  defp update_files(program, function) do
    Map.update!(program, :files, fn files -> Enum.map(files, function) end)
  end

  defp add_dead_pure_statement(%File{} = file) do
    source =
      Regex.replace(~r/^(\s*def\s+[^\n]+\s+do)$/m, file.source, fn _match, def_line ->
        indent = def_line |> leading_spaces() |> Kernel.<>("  ")
        def_line <> "\n" <> indent <> "_program_facts_dead = 1 + 2"
      end)

    %{file | source: source}
  end

  defp rename_source_variables(%File{} = file, mapping) do
    source =
      Enum.reduce(mapping, file.source, fn {from, to}, source ->
        Regex.replace(~r/\b#{Atom.to_string(from)}\b/, source, Atom.to_string(to))
      end)

    %{file | source: source}
  end

  defp rename_fact_variables(facts, mapping) do
    update_in(facts.data_flows, &rename_data_flows(&1, mapping))
  end

  defp rename_data_flows(data_flows, mapping) do
    Enum.map(data_flows, fn data_flow ->
      Map.update(data_flow, :variable_names, [], fn variables ->
        Enum.map(variables, &Map.get(mapping, &1, &1))
      end)
    end)
  end

  defp record_transform(program, transform, preserved_facts) do
    transform_record = %{name: transform, preserves: preserved_facts}

    Map.update!(program, :metadata, fn metadata ->
      Map.update(metadata, :transforms, [transform_record], &(&1 ++ [transform_record]))
    end)
  end

  defp leading_spaces(line) do
    case Regex.run(~r/^\s*/, line) do
      [spaces] -> spaces
      nil -> ""
    end
  end

  defp module_path(module) do
    path =
      module
      |> Module.split()
      |> Enum.map(&Macro.underscore/1)
      |> Path.join()

    Path.join("lib", path <> ".ex")
  end
end
