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
    |> Enum.flat_map(&ast_modules/1)
    |> Enum.map(fn {module, line, path} -> %{module: module, file: path, line: line} end)
  end

  defp function_locations(program) do
    program.files
    |> Enum.flat_map(&ast_functions/1)
    |> Enum.map(fn {module, function, arity, line, path} ->
      %{module: module, function: Atom.to_string(function), arity: arity, file: path, line: line}
    end)
  end

  defp ast_modules(file) do
    file.source
    |> quoted!()
    |> collect_modules(file.path)
  end

  defp ast_functions(file) do
    file.source
    |> quoted!()
    |> collect_functions(file.path)
  end

  defp quoted!(source) do
    Code.string_to_quoted!(source, columns: true, token_metadata: true)
  end

  defp collect_modules(ast, path) do
    {_ast, modules} =
      Macro.prewalk(ast, [], fn
        {:defmodule, meta, [module_ast, _body]} = node, modules ->
          {node, [{module_name(module_ast), meta[:line], path} | modules]}

        node, modules ->
          {node, modules}
      end)

    Enum.reverse(modules)
  end

  defp collect_functions(ast, path) do
    {_ast, functions} = collect_functions(ast, path, nil, [])
    Enum.reverse(functions)
  end

  defp collect_functions(
         {:defmodule, _meta, [module_ast, [do: body]]} = ast,
         path,
         _module,
         functions
       ) do
    module = module_name(module_ast)
    {_body, functions} = collect_functions(body, path, module, functions)
    {ast, functions}
  end

  defp collect_functions(
         {:def, meta, [{function, _call_meta, args}, _body]} = ast,
         path,
         module,
         functions
       )
       when is_atom(function) and is_list(args) do
    {ast, [{module, function, length(args), meta[:line], path} | functions]}
  end

  defp collect_functions(ast, path, module, functions) do
    Macro.prewalk(ast, functions, fn
      {:defmodule, _meta, [_module_ast, _body]} = node, acc ->
        {_node, acc} = collect_functions(node, path, module, acc)
        {node, acc}

      {:def, _meta, [_call, _body]} = node, acc ->
        {_node, acc} = collect_functions(node, path, module, acc)
        {node, acc}

      node, acc ->
        {node, acc}
    end)
  end

  defp module_name(module_ast) do
    Macro.to_string(module_ast)
  end
end
