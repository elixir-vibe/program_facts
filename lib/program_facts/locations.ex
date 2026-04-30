defmodule ProgramFacts.Locations do
  @moduledoc """
  Derives source locations from generated source files.
  """

  alias ProgramFacts.Program

  @doc """
  Derives source locations and stores them under `program.facts.locations`.
  """
  def attach(%Program{} = program) do
    locations = %{
      modules: module_locations(program),
      functions: function_locations(program),
      calls: call_locations(program),
      assignments: assignment_locations(program),
      branches: branch_locations(program),
      clauses: clause_locations(program),
      returns: return_locations(program)
    }

    put_in(program.facts.locations, locations)
  end

  defp module_locations(program), do: collect(program, :modules)
  defp function_locations(program), do: collect(program, :functions)
  defp call_locations(program), do: collect(program, :calls)
  defp assignment_locations(program), do: collect(program, :assignments)
  defp branch_locations(program), do: collect(program, :branches)
  defp clause_locations(program), do: collect(program, :clauses)
  defp return_locations(program), do: collect(program, :returns)

  defp collect(program, key) do
    program.files
    |> Enum.filter(&(&1.kind == :elixir))
    |> Enum.flat_map(fn file -> collect_file(file, key) end)
  end

  defp collect_file(file, key) do
    file.source
    |> quoted!()
    |> collect_ast(file.path)
    |> Map.fetch!(key)
  end

  defp quoted!(source) do
    Code.string_to_quoted!(source, columns: true, token_metadata: true)
  end

  defp collect_ast(ast, path) do
    {_ast, acc} = walk(ast, context(path), new_locations())
    reverse_locations(acc)
  end

  defp context(path), do: %{path: path, module: nil, function: nil}

  defp new_locations do
    %{
      modules: [],
      functions: [],
      calls: [],
      assignments: [],
      branches: [],
      clauses: [],
      returns: []
    }
  end

  defp reverse_locations(locations) do
    Map.new(locations, fn {key, values} -> {key, Enum.reverse(values)} end)
  end

  defp walk({:defmodule, meta, [module_ast, [do: body]]} = ast, context, locations) do
    module = module_name(module_ast)
    context = %{context | module: module}

    locations =
      add_location(locations, :modules, %{module: module, file: context.path, line: meta[:line]})

    {_body, locations} = walk(body, context, locations)
    {ast, locations}
  end

  defp walk({kind, meta, [{function, _call_meta, args}, [do: body]]} = ast, context, locations)
       when kind in [:def, :defp, :defmacro, :defmacrop] and is_atom(function) and is_list(args) do
    arity = length(args)
    fun = %{name: function, arity: arity, kind: kind}
    context = %{context | function: fun}

    locations =
      add_location(locations, :functions, %{
        module: context.module,
        function: Atom.to_string(function),
        arity: arity,
        kind: kind,
        file: context.path,
        line: meta[:line]
      })

    {_body, locations} = walk(body, context, locations)

    locations =
      add_location(locations, :returns, %{
        module: context.module,
        function: Atom.to_string(function),
        arity: arity,
        file: context.path,
        line: return_line(body),
        expression: Macro.to_string(last_expression(body))
      })

    {ast, locations}
  end

  defp walk({:=, meta, [left, right]} = ast, context, locations) do
    locations =
      add_location(locations, :assignments, %{
        module: context.module,
        function: function_name(context),
        file: context.path,
        line: meta[:line],
        pattern: Macro.to_string(left),
        expression: Macro.to_string(right)
      })

    {_left, locations} = walk(left, context, locations)
    {_right, locations} = walk(right, context, locations)
    {ast, locations}
  end

  defp walk({kind, meta, args} = ast, context, locations)
       when kind in [:if, :case, :cond, :with, :receive, :try] do
    locations =
      add_location(locations, :branches, %{
        module: context.module,
        function: function_name(context),
        kind: kind,
        file: context.path,
        line: meta[:line],
        clauses: count_branch_clauses(kind, args)
      })

    walk_tuple(ast, context, locations)
  end

  defp walk({{:., meta, [module_ast, function]}, _call_meta, args} = ast, context, locations)
       when is_atom(function) and is_list(args) do
    locations =
      add_location(locations, :calls, %{
        module: context.module,
        function: function_name(context),
        call: "#{Macro.to_string(module_ast)}.#{function}/#{length(args)}",
        arity: length(args),
        file: context.path,
        line: meta[:line]
      })

    {_args, locations} = walk(args, context, locations)
    {ast, locations}
  end

  defp walk({:->, meta, [patterns, body]} = ast, context, locations) do
    locations =
      add_location(locations, :clauses, %{
        module: context.module,
        function: function_name(context),
        file: context.path,
        line: meta[:line],
        patterns: Enum.map(List.wrap(patterns), &Macro.to_string/1)
      })

    {_body, locations} = walk(body, context, locations)
    {ast, locations}
  end

  defp walk({name, meta, args} = ast, context, locations) when is_atom(name) and is_list(args) do
    locations = maybe_add_call_location(locations, ast, name, meta, args, context)
    walk_tuple(ast, context, locations)
  end

  defp walk({key, value}, context, locations) when is_atom(key) do
    {value, locations} = walk(value, context, locations)
    {{key, value}, locations}
  end

  defp walk(list, context, locations) when is_list(list) do
    {items, locations} = map_reduce_walk(list, context, locations)
    {items, locations}
  end

  defp walk(ast, _context, locations), do: {ast, locations}

  defp walk_tuple({name, meta, args}, context, locations) do
    {args, locations} = map_reduce_walk(args, context, locations)
    {{name, meta, args}, locations}
  end

  defp map_reduce_walk(items, context, locations) do
    Enum.map_reduce(items, locations, fn item, acc -> walk(item, context, acc) end)
  end

  defp maybe_add_call_location(locations, _ast, name, meta, args, context) do
    cond do
      not call_location?(name, args) ->
        locations

      name in [:defmodule, :def, :defp, :defmacro, :defmacrop, :->, :=] ->
        locations

      true ->
        add_location(locations, :calls, %{
          module: context.module,
          function: function_name(context),
          call: call_name(name, args),
          arity: call_arity(args),
          file: context.path,
          line: meta[:line]
        })
    end
  end

  defp call_location?(:., _args), do: false
  defp call_location?(_name, args), do: is_list(args)

  defp call_name(_name, [{{:., _meta, [module_ast, function]}, _call_meta, call_args} | _]) do
    "#{Macro.to_string(module_ast)}.#{function}/#{length(call_args)}"
  end

  defp call_name(name, args), do: "#{name}/#{length(args)}"

  defp call_arity([{{:., _meta, [_module_ast, _function]}, _call_meta, call_args} | _]),
    do: length(call_args)

  defp call_arity(args), do: length(args)

  defp count_branch_clauses(:if, _args), do: 2
  defp count_branch_clauses(:with, _args), do: 2

  defp count_branch_clauses(_kind, args) do
    args
    |> Macro.prewalk(0, fn
      {:->, _meta, _children} = node, count -> {node, count + 1}
      node, count -> {node, count}
    end)
    |> elem(1)
  end

  defp add_location(locations, key, location), do: Map.update!(locations, key, &[location | &1])

  defp module_name(module_ast), do: Macro.to_string(module_ast)
  defp function_name(%{function: %{name: name, arity: arity}}), do: "#{name}/#{arity}"
  defp function_name(_context), do: nil

  defp return_line(ast) do
    case last_expression(ast) do
      {_name, meta, _args} -> meta[:line]
      _ -> nil
    end
  end

  defp last_expression({:__block__, _meta, expressions}), do: List.last(expressions)
  defp last_expression(expression), do: expression
end
