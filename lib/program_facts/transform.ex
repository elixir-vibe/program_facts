defmodule ProgramFacts.Transform do
  @moduledoc """
  Fact-aware transformations for generated programs.
  """

  alias ProgramFacts.{File, Locations, Naming, Program}

  @transforms [
    :rename_variables,
    :add_dead_pure_statement,
    :add_dead_branch,
    :extract_helper,
    :inline_helper,
    :wrap_in_if_true,
    :wrap_in_case_identity,
    :reorder_independent_assignments,
    :split_module_files,
    :add_unrelated_module,
    :add_alias_and_rewrite_remote_call
  ]
  @helper_function :program_facts_identity
  @variable_renames %{input: :arg, value: :item, message: :payload, reason: :cause}
  @preserves_non_structural_facts [:data_flows, :effects, :branches]

  @doc """
  Returns supported fact-aware transforms.
  """
  def transforms, do: @transforms

  @doc """
  Applies one transform or a sequence of transforms to a generated program.
  """
  def apply!(%Program{} = program, transforms) when is_list(transforms) do
    Enum.reduce(transforms, program, &apply!(&2, &1))
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
      :effects,
      :branches
    ])
    |> Locations.attach()
  end

  def apply!(%Program{} = program, :add_dead_pure_statement) do
    program
    |> update_files(fn file -> rewrite_source(file, &insert_dead_pure_statement/1) end)
    |> record_transform(:add_dead_pure_statement, [
      :modules,
      :functions,
      :call_edges,
      :call_paths | @preserves_non_structural_facts
    ])
    |> Locations.attach()
  end

  def apply!(%Program{} = program, :add_dead_branch) do
    program
    |> update_files(fn file -> rewrite_source(file, &insert_dead_branch/1) end)
    |> add_generated_branches(:if, 2, "false")
    |> record_transform(:add_dead_branch, preserved_except(:branches))
    |> Locations.attach()
  end

  def apply!(%Program{} = program, :wrap_in_if_true) do
    program
    |> update_files(fn file -> rewrite_source(file, wrap_bodies(&if_true/1)) end)
    |> add_generated_branches(:if, 2, "true")
    |> record_transform(:wrap_in_if_true, preserved_except(:branches))
    |> Locations.attach()
  end

  def apply!(%Program{} = program, :wrap_in_case_identity) do
    program
    |> update_files(fn file -> rewrite_source(file, wrap_bodies(&case_identity/1)) end)
    |> add_generated_branches(:case, 1, ":ok")
    |> record_transform(:wrap_in_case_identity, preserved_except(:branches))
    |> Locations.attach()
  end

  def apply!(%Program{} = program, :reorder_independent_assignments) do
    program
    |> update_files(fn file ->
      rewrite_source(file, &insert_reordered_independent_assignments/1)
    end)
    |> record_transform(:reorder_independent_assignments, [
      :modules,
      :functions,
      :call_edges,
      :call_paths | @preserves_non_structural_facts
    ])
    |> Locations.attach()
  end

  def apply!(%Program{} = program, :add_unrelated_module) do
    module = Module.concat([Generated, ProgramFacts, Extra, Macro.camelize(program.id)])
    function = {module, :unrelated, 1}

    program
    |> Map.update!(:files, &(&1 ++ [unrelated_file(module)]))
    |> update_in([Access.key!(:facts), Access.key!(:modules)], &(&1 ++ [module]))
    |> update_in([Access.key!(:facts), Access.key!(:functions)], &(&1 ++ [function]))
    |> record_transform(:add_unrelated_module, @preserves_non_structural_facts)
    |> Locations.attach()
  end

  def apply!(%Program{} = program, :split_module_files) do
    program
    |> Map.update!(:files, &Enum.flat_map(&1, fn file -> split_file(file) end))
    |> record_transform(:split_module_files, [
      :modules,
      :functions,
      :call_edges,
      :call_paths | @preserves_non_structural_facts
    ])
    |> Locations.attach()
  end

  def apply!(%Program{} = program, :add_alias_and_rewrite_remote_call) do
    program
    |> update_files(fn file -> rewrite_source(file, &alias_rewrite/1) end)
    |> record_transform(:add_alias_and_rewrite_remote_call, [
      :modules,
      :functions,
      :call_edges,
      :call_paths | @preserves_non_structural_facts
    ])
    |> Locations.attach()
  end

  def apply!(%Program{} = program, :extract_helper) do
    modules = program.facts.modules
    helper_functions = Enum.map(modules, &{&1, @helper_function, 1})
    helper_edges = helper_edges(program.facts.functions, modules)

    program
    |> update_files(fn file -> rewrite_source(file, &extract_helper/1) end)
    |> update_in(
      [Access.key!(:facts), Access.key!(:functions)],
      &Enum.uniq(&1 ++ helper_functions)
    )
    |> update_in([Access.key!(:facts), Access.key!(:call_edges)], &Enum.uniq(&1 ++ helper_edges))
    |> record_transform(:extract_helper, @preserves_non_structural_facts)
    |> Locations.attach()
  end

  def apply!(%Program{} = program, :inline_helper) do
    program
    |> update_files(fn file -> rewrite_source(file, &inline_helper/1) end)
    |> update_in([Access.key!(:facts)], &remove_helper_facts/1)
    |> record_transform(:inline_helper, @preserves_non_structural_facts)
    |> Locations.attach()
  end

  def apply!(%Program{}, transform) do
    raise ArgumentError, "unknown transform: #{inspect(transform)}"
  end

  defp update_files(program, function), do: Map.update!(program, :files, &Enum.map(&1, function))

  defp rewrite_source(%File{kind: :elixir} = file, rewrite) when is_function(rewrite, 1) do
    source =
      file.source
      |> Code.string_to_quoted!(columns: true, token_metadata: true)
      |> rewrite.()
      |> Macro.to_string()
      |> Kernel.<>("\n")

    %{file | source: source}
  end

  defp rewrite_source(%File{} = file, _rewrite), do: file

  defp insert_dead_pure_statement(ast), do: insert_statement_in_defs(ast, dead_assignment())
  defp insert_dead_branch(ast), do: insert_statement_in_defs(ast, dead_branch())

  defp insert_reordered_independent_assignments(ast) do
    ast
    |> insert_statement_in_defs({:=, [], [{:_program_facts_b, [], Elixir}, 2]})
    |> insert_statement_in_defs({:=, [], [{:_program_facts_a, [], Elixir}, 1]})
  end

  defp insert_statement_in_defs(ast, statement) do
    Macro.postwalk(ast, fn
      {:def, meta, [call, body]} -> {:def, meta, [call, insert_statement(body, statement)]}
      node -> node
    end)
  end

  defp wrap_bodies(wrapper) do
    fn ast ->
      Macro.postwalk(ast, fn
        {:def, meta, [call, [do: body]]} -> {:def, meta, [call, [do: wrapper.(body)]]}
        node -> node
      end)
    end
  end

  defp extract_helper(ast) do
    Macro.postwalk(ast, fn
      {:defmodule, meta, [module_ast, [do: body]]} ->
        {:defmodule, meta, [module_ast, [do: add_helper_to_module(body)]]}

      {:def, _meta, [{@helper_function, _call_meta, _args}, _body]} = node ->
        node

      {:def, meta, [call, [do: body]]} ->
        {:def, meta, [call, [do: {@helper_function, [], [body]}]]}

      node ->
        node
    end)
  end

  defp inline_helper(ast) do
    ast
    |> remove_helper_definitions()
    |> Macro.postwalk(fn
      {@helper_function, _meta, [body]} -> body
      node -> node
    end)
  end

  defp remove_helper_definitions(ast) do
    Macro.postwalk(ast, fn
      {:defmodule, meta, [module_ast, [do: body]]} ->
        {:defmodule, meta, [module_ast, [do: remove_helper_from_module(body)]]}

      node ->
        node
    end)
  end

  defp alias_rewrite(ast) do
    case first_remote_module(ast) do
      nil -> ast
      module_ast -> add_alias_and_rewrite(ast, module_ast)
    end
  end

  defp add_alias_and_rewrite(ast, module_ast) do
    short =
      module_ast |> Macro.to_string() |> String.split(".") |> List.last() |> String.to_atom()

    Macro.postwalk(ast, fn
      {:defmodule, meta, [own_module, [do: body]]} ->
        {:defmodule, meta,
         [own_module, [do: prepend_statement(body, {:alias, [], [module_ast]})]]}

      {{:., dot_meta, [^module_ast, function]}, call_meta, args} ->
        {{:., dot_meta, [{:__aliases__, [], [short]}, function]}, call_meta, args}

      node ->
        node
    end)
  end

  defp first_remote_module(ast) do
    {_ast, module} =
      Macro.prewalk(ast, nil, fn
        {{:., _dot_meta, [module_ast, _function]}, _call_meta, _args} = node, nil ->
          {node, module_ast}

        node, module ->
          {node, module}
      end)

    module
  end

  defp add_helper_to_module({:__block__, meta, statements}) do
    {:__block__, meta, statements ++ [helper_definition()]}
  end

  defp add_helper_to_module(statement), do: {:__block__, [], [statement, helper_definition()]}

  defp remove_helper_from_module({:__block__, meta, statements}) do
    {:__block__, meta, Enum.reject(statements, &helper_definition?/1)}
  end

  defp remove_helper_from_module(statement), do: statement

  defp helper_definition?({:defp, _meta, [{{@helper_function, _call_meta, _args}, _body}]}),
    do: true

  defp helper_definition?({:defp, _meta, [{@helper_function, _call_meta, _args}, _body]}),
    do: true

  defp helper_definition?(_node), do: false

  defp helper_definition do
    {:defp, [], [{@helper_function, [], [{:value, [], nil}]}, [do: {:value, [], nil}]]}
  end

  defp insert_statement([do: {:__block__, meta, statements}], statement),
    do: [do: {:__block__, meta, [statement | statements]}]

  defp insert_statement([do: body], statement), do: [do: {:__block__, [], [statement, body]}]
  defp insert_statement(body, _statement), do: body

  defp prepend_statement({:__block__, meta, statements}, statement),
    do: {:__block__, meta, [statement | statements]}

  defp prepend_statement(statement, prepended), do: {:__block__, [], [prepended, statement]}

  defp dead_assignment, do: {:=, [], [{:_program_facts_dead, [], Elixir}, {:+, [], [1, 2]}]}

  defp dead_branch do
    {:if, [], [false, [do: :unreachable, else: nil]]}
  end

  defp if_true(body), do: {:if, [], [true, [do: body]]}

  defp case_identity(body) do
    {:case, [], [:ok, [do: [{:->, [], [[:ok], body]}]]]}
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

  defp split_file(%File{kind: :elixir} = file) do
    file.source
    |> Code.string_to_quoted!(columns: true, token_metadata: true)
    |> modules_from_ast()
    |> case do
      [] -> [file]
      [_single] -> [file]
      modules -> Enum.map(modules, &module_file(file, &1))
    end
  end

  defp split_file(%File{} = file), do: [file]

  defp modules_from_ast({:__block__, _meta, statements}),
    do: Enum.filter(statements, &match?({:defmodule, _, _}, &1))

  defp modules_from_ast({:defmodule, _, _} = module_ast), do: [module_ast]
  defp modules_from_ast(_ast), do: []

  defp module_file(file, {:defmodule, _meta, [module_ast, _body]} = module_node) do
    module = Module.concat([Macro.to_string(module_ast)])
    %{file | path: Naming.module_path(module), source: Macro.to_string(module_node) <> "\n"}
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

  defp helper_edges(functions, modules) do
    helpers = MapSet.new(Enum.map(modules, &{&1, @helper_function, 1}))

    functions
    |> Enum.reject(&MapSet.member?(helpers, &1))
    |> Enum.map(fn {module, function, arity} ->
      {{module, function, arity}, {module, @helper_function, 1}}
    end)
  end

  defp remove_helper_facts(facts) do
    helper? = fn {_module, function, _arity} -> function == @helper_function end

    facts
    |> Map.update!(:functions, &Enum.reject(&1, helper?))
    |> Map.update!(:call_edges, fn edges ->
      Enum.reject(edges, fn {_source, target} -> helper?.(target) end)
    end)
    |> Map.update!(:call_paths, fn paths -> Enum.reject(paths, &Enum.any?(&1, helper?)) end)
  end

  defp rename_fact_variables(facts, mapping) do
    facts
    |> update_in([Access.key!(:data_flows)], &rename_data_flows(&1, mapping))
    |> update_in([Access.key!(:branches)], &rename_branches(&1, mapping))
  end

  defp rename_data_flows(data_flows, mapping) do
    Enum.map(data_flows, fn data_flow ->
      Map.update(data_flow, :variable_names, [], fn variables ->
        Enum.map(variables, &Map.get(mapping, &1, &1))
      end)
    end)
  end

  defp rename_branches(branches, mapping), do: Enum.map(branches, &rename_branch(&1, mapping))

  defp rename_branch(branch, mapping) when is_map(branch) do
    branch
    |> Map.update(:calls_by_clause, [], &rename_branch_clauses(&1, mapping))
    |> Map.update(:nested, [], &rename_branches(&1, mapping))
  end

  defp rename_branch_clauses(clauses, mapping) do
    Enum.map(clauses, fn clause ->
      Map.update(clause, :label, nil, &rename_label(&1, mapping))
    end)
  end

  defp rename_label(label, mapping) when is_binary(label) do
    label
    |> Code.string_to_quoted!()
    |> rename_variables(mapping).()
    |> Macro.to_string()
  rescue
    SyntaxError -> label
  end

  defp add_generated_branches(program, kind, clauses, label) do
    generated_branches =
      Enum.map(program.facts.functions, fn function ->
        %{
          function: function,
          kind: kind,
          clauses: clauses,
          calls_by_clause: [],
          generated_by: :transform,
          label: label
        }
      end)

    program
    |> update_in([Access.key!(:facts), Access.key!(:branches)], &(&1 ++ generated_branches))
    |> update_in([Access.key!(:facts), Access.key!(:features)], &MapSet.put(&1, :branch))
  end

  defp preserved_except(fact) do
    [
      :modules,
      :functions,
      :call_edges,
      :call_paths | @preserves_non_structural_facts
    ]
    |> Enum.reject(&(&1 == fact))
  end

  defp record_transform(program, transform, preserved_facts) do
    transform_record = %{name: transform, preserves: preserved_facts}

    Map.update!(program, :metadata, fn metadata ->
      Map.update(metadata, :transforms, [transform_record], &(&1 ++ [transform_record]))
    end)
  end
end
