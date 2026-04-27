defmodule ProgramFactsTest do
  use ExUnit.Case
  doctest ProgramFacts

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
             :pipeline_data_flow
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

  test "all policies generate compilable source" do
    ProgramFacts.policies()
    |> Enum.with_index(20)
    |> Enum.each(fn {policy, seed} ->
      program = ProgramFacts.generate!(policy: policy, seed: seed, depth: 3, width: 3)
      assert_compiles(program)
    end)
  end

  test "writes a temporary Mix project" do
    {:ok, dir, program} =
      ProgramFacts.Project.write_tmp!(policy: :straight_line_data_flow, seed: 40)

    try do
      assert File.exists?(Path.join(dir, "mix.exs"))

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

  defp assert_compiles(program) do
    source = Enum.map_join(program.files, "\n", & &1.source)

    modules =
      source
      |> Code.compile_string("generated_program.exs")
      |> Enum.map(fn {module, _bytecode} -> module end)

    assert Enum.sort(modules) == Enum.sort(program.facts.modules)
  end
end
