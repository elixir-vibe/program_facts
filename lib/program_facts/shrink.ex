defmodule ProgramFacts.Shrink do
  @moduledoc """
  Deterministic minimization helpers for generated failures.

  `shrink/2` takes a failing program and a predicate that returns true while a
  candidate still reproduces the failure. It tries smaller generation options
  and returns the smallest candidate it can find without losing the failure.
  """

  alias ProgramFacts.Program

  @type predicate :: (Program.t() -> boolean())
  @type step :: %{from: map(), to: map(), accepted?: boolean(), kind: atom()}
  @type result :: %{program: Program.t(), options: keyword(), steps: [step()]}

  @doc """
  Attempts to minimize a failing generated program.

  `failure?` must return true for the original program and for each accepted
  candidate. The result contains the minimized program, its generation options,
  and a trace of attempted shrink steps.
  """
  @spec shrink(Program.t(), predicate()) :: result()
  def shrink(%Program{} = program, failure?) when is_function(failure?, 1) do
    shrink(program, failure?, [])
  end

  @doc """
  Attempts to minimize a failing generated program.

  `failure?` must return true for the original program and for each accepted
  candidate. The result contains the minimized program, its generation options,
  and a trace of attempted shrink steps.
  """
  @spec shrink(Program.t(), predicate(), keyword()) :: result()
  def shrink(%Program{} = program, failure?, opts) when is_function(failure?, 1) do
    unless failure?.(program) do
      raise ArgumentError, "cannot shrink a program that does not reproduce the failure"
    end

    options = options_from_program(program, opts)

    initial = %{program: program, options: options, steps: []}

    option_candidates =
      if Keyword.get(opts, :option_shrink, true), do: candidate_options(options), else: []

    result =
      option_candidates
      |> Enum.reduce(initial, fn candidate, current ->
        try_option_candidate(candidate, current, failure?)
      end)
      |> shrink_transforms(failure?, Keyword.get(opts, :transform_shrink, true))
      |> shrink_structure(failure?)

    %{program: result.program, options: result.options, steps: Enum.reverse(result.steps)}
  end

  defp try_option_candidate(candidate, current, failure?) do
    if comparable?(candidate, current.options) do
      program = ProgramFacts.generate!(candidate)
      accepted? = failure?.(program)

      step = %{
        kind: :options,
        from: Map.new(current.options),
        to: Map.new(candidate),
        accepted?: accepted?
      }

      if accepted? do
        %{current | program: program, options: candidate, steps: [step | current.steps]}
      else
        %{current | steps: [step | current.steps]}
      end
    else
      current
    end
  end

  defp shrink_structure(current, failure?) do
    current.program
    |> structural_candidates()
    |> Enum.reduce(current, fn candidate, current ->
      accepted? = failure?.(candidate.program)

      step = %{
        kind: candidate.kind,
        from: structural_summary(current.program),
        to: structural_summary(candidate.program),
        accepted?: accepted?
      }

      if accepted? do
        %{current | program: candidate.program, steps: [step | current.steps]}
      else
        %{current | steps: [step | current.steps]}
      end
    end)
  end

  defp shrink_transforms(current, _failure?, false), do: current

  defp shrink_transforms(current, failure?, true) do
    case transform_names(current.program) do
      [] -> current
      [_single] -> current
      transforms -> shrink_transform_sequence(current, transforms, failure?)
    end
  end

  defp shrink_transform_sequence(current, transforms, failure?) do
    transforms
    |> transform_removal_candidates()
    |> Enum.reduce_while(current, fn candidate_transforms, current ->
      candidate = rebuild_with_transforms(current.options, candidate_transforms)
      accepted? = failure?.(candidate)

      step = %{
        kind: :remove_transform,
        from: %{transforms: transforms},
        to: %{transforms: candidate_transforms},
        accepted?: accepted?
      }

      if accepted? do
        next = %{current | program: candidate, steps: [step | current.steps]}
        {:halt, shrink_transform_sequence(next, candidate_transforms, failure?)}
      else
        {:cont, %{current | steps: [step | current.steps]}}
      end
    end)
  end

  defp transform_names(program) do
    program.metadata
    |> Map.get(:transforms, [])
    |> Enum.map(& &1.name)
  end

  defp transform_removal_candidates(transforms) do
    transforms
    |> Enum.with_index()
    |> Enum.map(fn {_transform, index} -> List.delete_at(transforms, index) end)
  end

  defp rebuild_with_transforms(options, transforms) do
    options
    |> ProgramFacts.generate!()
    |> ProgramFacts.Transform.apply!(transforms)
  end

  defp structural_candidates(program) do
    program.facts.modules
    |> Enum.filter(&removable_module?(program, &1))
    |> Enum.map(fn module -> %{kind: :remove_module, program: remove_module(program, module)} end)
  end

  defp removable_module?(program, module) do
    module_functions = functions_for_module(program, module)

    module_functions != [] and
      isolated_functions?(program, module_functions) and
      unreferenced_by_non_call_facts?(program, module_functions) and
      removable_file?(program, module)
  end

  defp functions_for_module(program, module) do
    Enum.filter(program.facts.functions, fn {function_module, _function, _arity} ->
      function_module == module
    end)
  end

  defp isolated_functions?(program, module_functions) do
    module_functions = MapSet.new(module_functions)

    Enum.all?(program.facts.call_edges, fn {source, target} ->
      not MapSet.member?(module_functions, source) and
        not MapSet.member?(module_functions, target)
    end)
  end

  defp unreferenced_by_non_call_facts?(program, module_functions) do
    module_functions = MapSet.new(module_functions)

    not referenced_by_effects?(program, module_functions) and
      not referenced_by_branches?(program, module_functions) and
      not referenced_by_data_flows?(program, module_functions) and
      not referenced_by_architecture?(program, module_functions)
  end

  defp referenced_by_effects?(program, module_functions) do
    Enum.any?(program.facts.effects, fn {function, _effect} ->
      MapSet.member?(module_functions, function)
    end)
  end

  defp referenced_by_branches?(program, module_functions) do
    Enum.any?(program.facts.branches, fn branch ->
      branch_functions(branch)
      |> Enum.any?(&MapSet.member?(module_functions, &1))
    end)
  end

  defp referenced_by_data_flows?(program, module_functions),
    do: contains_function_ref?(program.facts.data_flows, module_functions)

  defp referenced_by_architecture?(program, module_functions),
    do: contains_function_ref?(program.facts.architecture, module_functions)

  defp contains_function_ref?(term, module_functions) do
    term
    |> Macro.prewalk(false, fn
      {module, function, arity} = mfa, seen
      when is_atom(module) and is_atom(function) and is_integer(arity) ->
        {mfa, seen or MapSet.member?(module_functions, mfa)}

      node, seen ->
        {node, seen}
    end)
    |> elem(1)
  end

  defp branch_functions(branch) do
    branch
    |> Macro.prewalk([], fn
      {module, function, arity} = mfa, acc
      when is_atom(module) and is_atom(function) and is_integer(arity) ->
        {mfa, [mfa | acc]}

      node, acc ->
        {node, acc}
    end)
    |> elem(1)
  end

  defp removable_file?(program, module) do
    case module_file(program, module) do
      nil -> false
      file -> module_count_in_file(program, file.path) == 1
    end
  end

  defp remove_module(program, module) do
    module_functions = functions_for_module(program, module)
    file = module_file(program, module)

    program
    |> update_in(
      [Access.key!(:files)],
      &Enum.reject(&1, fn candidate -> candidate.path == file.path end)
    )
    |> update_in([Access.key!(:facts), Access.key!(:modules)], &List.delete(&1, module))
    |> update_in([Access.key!(:facts), Access.key!(:functions)], &(&1 -- module_functions))
    |> ProgramFacts.Locations.attach()
  end

  defp module_file(program, module) do
    module_name = inspect(module)

    Enum.find(program.files, fn file ->
      file.kind == :elixir and String.contains?(file.source, "defmodule #{module_name} do")
    end)
  end

  defp module_count_in_file(program, path) do
    program.facts.locations
    |> Map.get(:modules, [])
    |> Enum.count(&(&1.file == path))
  end

  defp structural_summary(program) do
    %{
      files: length(program.files),
      modules: length(program.facts.modules),
      functions: length(program.facts.functions),
      edges: length(program.facts.call_edges)
    }
  end

  defp options_from_program(program, opts) do
    metadata = program.metadata

    [
      policy: Keyword.get(opts, :policy, metadata.policy),
      seed: Keyword.get(opts, :seed, program.seed),
      depth: Keyword.get(opts, :depth, Map.get(metadata, :depth, 3)),
      width: Keyword.get(opts, :width, Map.get(metadata, :width, 2)),
      layout: Keyword.get(opts, :layout, Map.get(metadata, :layout, :plain))
    ]
  end

  defp candidate_options(options) do
    smaller_layouts(options) ++ smaller_widths(options) ++ smaller_depths(options)
  end

  defp smaller_layouts(options) do
    if options[:layout] == :plain do
      []
    else
      [Keyword.put(options, :layout, :plain)]
    end
  end

  defp smaller_widths(options) do
    options[:width]
    |> range_down_to(1)
    |> Enum.map(&Keyword.put(options, :width, &1))
  end

  defp smaller_depths(options) do
    options[:depth]
    |> range_down_to(1)
    |> Enum.map(&Keyword.put(options, :depth, &1))
  end

  defp range_down_to(value, minimum) when is_integer(value) and value > minimum do
    (value - 1)..minimum//-1
  end

  defp range_down_to(_value, _minimum), do: []

  defp comparable?(candidate, current) do
    candidate[:layout] != current[:layout] or
      candidate[:width] < current[:width] or
      candidate[:depth] < current[:depth]
  end
end
