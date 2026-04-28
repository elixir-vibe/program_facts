defmodule ProgramFactsTest do
  use ExUnit.Case
  doctest ProgramFacts

  test "lists supported layouts" do
    assert ProgramFacts.layouts() == [:plain, :umbrella, :package_style]
  end

  test "lists supported transforms" do
    assert ProgramFacts.transforms() == [
             :add_dead_pure_statement,
             :add_unrelated_module,
             :rename_variables
           ]
  end

  test "lists supported policies" do
    assert ProgramFacts.policies() == [
             :single_call,
             :linear_call_chain,
             :branching_call_graph,
             :module_dependency_chain,
             :module_cycle,
             :straight_line_data_flow,
             :assignment_chain,
             :helper_call_data_flow,
             :pipeline_data_flow,
             :if_else,
             :case_clauses,
             :cond_branches,
             :with_chain,
             :anonymous_fn_branch,
             :multi_clause_function,
             :pure,
             :io_effect,
             :send_effect,
             :raise_effect,
             :mixed_effect_boundary
           ]
  end

  test "generates a deterministic linear call chain" do
    program = ProgramFacts.generate!(policy: :linear_call_chain, seed: 11, depth: 4)

    assert program.id == "pf_11_linear_call_chain"
    assert length(program.files) == 4
    assert length(program.facts.modules) == 4
    assert length(program.facts.functions) == 4
    assert length(program.facts.call_edges) == 3
    assert [program.facts.functions] == program.facts.call_paths
  end

  test "generates a branching call graph" do
    program = ProgramFacts.generate!(policy: :branching_call_graph, seed: 12, width: 3)
    [entry | branches] = program.facts.functions

    assert length(program.files) == 4
    assert length(program.facts.call_edges) == 3
    assert program.facts.call_edges == Enum.map(branches, &{entry, &1})
    assert MapSet.member?(program.facts.features, :fan_out)
  end

  test "generates a module cycle" do
    program = ProgramFacts.generate!(policy: :module_cycle, seed: 13, depth: 3)

    assert length(program.facts.call_edges) == 3
    assert [cycle] = program.facts.call_paths
    assert hd(cycle) == List.last(cycle)
    assert %{cycles: [_]} = program.facts.architecture
  end

  test "generates straight-line data-flow facts" do
    program = ProgramFacts.generate!(policy: :straight_line_data_flow, seed: 14)
    [flow] = program.facts.data_flows

    assert length(program.files) == 3
    assert length(program.facts.call_edges) == 2
    assert {:param, {_module, :entry, 1}, :input} = flow.from
    assert {:arg, {_sink_module, :sink, 1}, 0} = flow.to
    assert flow.variable_names == [:input, :x, :value, :y]
  end

  test "generates assignment-chain data-flow facts" do
    program = ProgramFacts.generate!(policy: :assignment_chain, seed: 15)
    [flow] = program.facts.data_flows

    assert program.facts.call_edges == []
    assert {:return, {_module, :entry, 1}} = flow.to
    assert flow.variable_names == [:input, :a, :b, :c]
  end

  test "generates branch facts" do
    for policy <- [
          :if_else,
          :case_clauses,
          :cond_branches,
          :with_chain,
          :anonymous_fn_branch,
          :multi_clause_function
        ] do
      program = ProgramFacts.generate!(policy: policy, seed: 16)
      [branch] = program.facts.branches
      [entry, ok, error] = program.facts.functions

      assert branch.function == entry
      assert branch.clauses == 2
      assert program.facts.call_edges == [{entry, ok}, {entry, error}]
      assert MapSet.member?(program.facts.features, :branch)
    end
  end

  test "attaches generated source locations" do
    program = ProgramFacts.generate!(policy: :case_clauses, seed: 16)

    assert length(program.facts.locations.modules) == 3

    assert [%{module: _, function: "entry", arity: 1, file: _, line: line}] =
             Enum.filter(program.facts.locations.functions, &(&1.function == "entry"))

    assert is_integer(line)
  end

  test "generates effect facts" do
    cases = [
      pure: :pure,
      io_effect: :io,
      send_effect: :send,
      raise_effect: :exception
    ]

    for {policy, effect} <- cases do
      program = ProgramFacts.generate!(policy: policy, seed: 17)
      [function] = program.facts.functions

      assert program.facts.effects == [{function, effect}]
      assert MapSet.member?(program.facts.features, :effect)
    end
  end

  test "generates mixed-effect boundary facts" do
    program = ProgramFacts.generate!(policy: :mixed_effect_boundary, seed: 18)
    [function] = program.facts.functions

    assert Enum.sort(program.facts.effects) == Enum.sort([{function, :io}, {function, :send}])
    assert MapSet.member?(program.facts.features, :mixed_effect_boundary)
  end

  test "applies project layouts" do
    plain = ProgramFacts.generate!(policy: :single_call, seed: 19, layout: :plain)
    umbrella = ProgramFacts.generate!(policy: :single_call, seed: 19, layout: :umbrella)
    package_style = ProgramFacts.generate!(policy: :single_call, seed: 19, layout: :package_style)

    assert Enum.all?(plain.files, &String.starts_with?(&1.path, "lib/"))
    assert Enum.all?(umbrella.files, &String.starts_with?(&1.path, "apps/generated_app/lib/"))
    assert Enum.all?(package_style.files, &String.starts_with?(&1.path, "generated_package/lib/"))
    assert umbrella.metadata.project_layout.excluded_files != []
    assert length(umbrella.facts.locations.functions) == 2
  end

  test "all policies generate compilable source" do
    ProgramFacts.policies()
    |> Enum.with_index(20)
    |> Enum.each(fn {policy, seed} ->
      program = ProgramFacts.generate!(policy: policy, seed: seed, depth: 3, width: 3)
      assert_compiles(program)
    end)
  end

  test "exports programs to JSON-friendly maps" do
    program = ProgramFacts.generate!(policy: :linear_call_chain, seed: 39, depth: 2)
    map = ProgramFacts.to_map(program)

    assert map["id"] == "pf_39_linear_call_chain"
    assert [%{"path" => _, "source" => _, "kind" => "elixir"}, _] = map["files"]

    assert [%{"id" => _, "module" => _, "function" => _, "arity" => 1}, _] =
             map["facts"]["functions"]

    assert is_binary(ProgramFacts.to_json!(program))
  end

  test "writes a temporary Mix project" do
    {:ok, dir, program} =
      ProgramFacts.Project.write_tmp!(policy: :straight_line_data_flow, seed: 40)

    try do
      assert File.exists?(Path.join(dir, "mix.exs"))
      assert File.exists?(Path.join(dir, "program_facts.json"))

      for file <- program.files do
        assert File.read!(Path.join(dir, file.path)) == file.source
      end
    after
      File.rm_rf!(dir)
    end
  end

  test "written temporary project compiles with Mix" do
    {:ok, dir, _program} = ProgramFacts.Project.write_tmp!(policy: :pipeline_data_flow, seed: 41)

    try do
      assert {_, 0} = System.cmd("mix", ["compile"], cd: dir, stderr_to_stdout: true)
    after
      File.rm_rf!(dir)
    end
  end

  test "written layout project includes excluded fixtures" do
    {:ok, dir, program} =
      ProgramFacts.Project.write_tmp!(policy: :single_call, seed: 42, layout: :umbrella)

    try do
      for path <- program.metadata.project_layout.excluded_files do
        assert File.exists?(Path.join(dir, path))
      end
    after
      File.rm_rf!(dir)
    end
  end

  test "applies fact-aware transforms" do
    program = ProgramFacts.generate!(policy: :straight_line_data_flow, seed: 44)

    variant =
      ProgramFacts.Transform.apply!(program, [:rename_variables, :add_dead_pure_statement])

    [flow] = variant.facts.data_flows

    refute hd(variant.files).source == hd(program.files).source
    assert flow.variable_names == [:arg, :x, :item, :y]

    assert Enum.map(variant.metadata.transforms, & &1.name) == [
             :rename_variables,
             :add_dead_pure_statement
           ]

    assert_compiles(variant)
  end

  test "adds unrelated modules without changing existing edges" do
    program = ProgramFacts.generate!(policy: :single_call, seed: 45)
    variant = ProgramFacts.Transform.apply!(program, :add_unrelated_module)

    assert length(variant.files) == length(program.files) + 1
    assert length(variant.facts.modules) == length(program.facts.modules) + 1
    assert variant.facts.call_edges == program.facts.call_edges
    assert_compiles(variant)
  end

  test "saves replayable corpus entries" do
    root =
      Path.join(System.tmp_dir!(), "program_facts_corpus_#{System.unique_integer([:positive])}")

    program = ProgramFacts.generate!(policy: :case_clauses, seed: 43)

    try do
      dir = ProgramFacts.Corpus.save!(program, root)
      manifest = ProgramFacts.Corpus.load_manifest!(dir)

      assert Path.basename(Path.dirname(dir)) == "case_clauses"
      assert manifest["id"] == program.id
      assert File.exists?(Path.join(dir, hd(program.files).path))
    after
      File.rm_rf!(root)
    end
  end

  defp assert_compiles(program) do
    source = Enum.map_join(program.files, "\n", & &1.source)

    modules =
      source
      |> Code.compile_string("generated_program.exs")
      |> Enum.map(fn {module, _bytecode} -> module end)

    assert Enum.sort(modules) == Enum.sort(program.facts.modules)
  end
end
