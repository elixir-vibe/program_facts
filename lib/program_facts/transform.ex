defmodule ProgramFacts.Transform do
  @moduledoc """
  Fact-aware transformations for generated programs.
  """

  alias ProgramFacts.{File, Locations, Naming, Program}

  @transforms [:add_dead_pure_statement, :add_unrelated_module, :rename_variables]
  @variable_renames %{input: :arg, value: :item, message: :payload, reason: :cause}
  @preserves_non_structural_facts [:call_edges, :call_paths, :data_flows, :effects, :branches]

  def transforms, do: @transforms

  def apply!(%Program{} = program, transforms) when is_list(transforms) do
    Enum.reduce(transforms, program, &apply!(&2, &1))
  end

  def apply!(%Program{} = program, :add_dead_pure_statement) do
    program
    |> update_files(fn file -> rewrite_source(file, &insert_dead_pure_statement/1) end)
    |> record_transform(:add_dead_pure_statement, [
      :modules,
      :functions | @preserves_non_structural_facts
    ])
    |> Locations.attach()
  end

  def apply!(%Program{} = program, :add_unrelated_module) do
    module = Module.concat([Generated, ProgramFacts, Extra, Macro.camelize(program.id)])
    function = {module, :unrelated, 1}
    file = unrelated_file(module)

    program
    |> Map.update!(:files, &(&1 ++ [file]))
    |> put_in([Access.key!(:facts), Access.key!(:modules)], program.facts.modules ++ [module])
    |> put_in(
      [Access.key!(:facts), Access.key!(:functions)],
      program.facts.functions ++ [function]
    )
    |> record_transform(:add_unrelated_module, @preserves_non_structural_facts)
    |> Locations.attach()
  end

  def apply!(%Program{} = program, :rename_variables) do
    program
    |> update_files(&rewrite_source(&1, rename_variables(@variable_renames)))
    |> update_in([Access.key!(:facts)], &rename_fact_variables(&1, @variable_renames))
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

  defp rewrite_source(%File{} = file, rewrite) when is_function(rewrite, 1) do
    source =
      file.source
      |> Code.string_to_quoted!(columns: true, token_metadata: true)
      |> rewrite.()
      |> Macro.to_string()
      |> Kernel.<>("\n")

    %{file | source: source}
  end

  defp insert_dead_pure_statement(ast) do
    Macro.postwalk(ast, fn
      {:def, meta, [call, body]} ->
        {:def, meta, [call, insert_statement(body, dead_assignment())]}

      node ->
        node
    end)
  end

  defp insert_statement([do: {:__block__, meta, statements}], statement) do
    [do: {:__block__, meta, [statement | statements]}]
  end

  defp insert_statement([do: body], statement) do
    [do: {:__block__, [], [statement, body]}]
  end

  defp insert_statement(body, _statement), do: body

  defp dead_assignment do
    {:=, [], [{:_program_facts_dead, [], Elixir}, {:+, [], [1, 2]}]}
  end

  defp rename_variables(mapping) do
    fn ast ->
      Macro.postwalk(ast, fn
        {name, meta, context} when is_atom(name) and is_atom(context) ->
          {Map.get(mapping, name, name), meta, context}

        node ->
          node
      end)
    end
  end

  defp unrelated_file(module) do
    %File{
      path: Naming.module_path(module),
      kind: :elixir,
      source: """
      defmodule #{inspect(module)} do
        def unrelated(value) do
          value
        end
      end
      """
    }
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
end
