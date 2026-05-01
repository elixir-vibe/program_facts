defmodule ProgramFactsTest do
  use ExUnit.Case
  use ExUnitProperties
  doctest ProgramFacts

  alias ProgramFacts.Corpus.Failure
  alias ProgramFacts.Fact.{Branch, CallEdge, DataFlow, Effect, FunctionID}
  alias ProgramFacts.Manifest
  alias ProgramFacts.Manifest.Facts, as: ManifestFacts
  alias ProgramFacts.Manifest.File, as: ManifestFile
  alias ProgramFacts.Model.Builder

  test "lists supported layouts" do
    assert ProgramFacts.layouts() == [:plain, :umbrella, :package_style]
  end

  test "lists supported transforms" do
    assert ProgramFacts.transforms() == [
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
             :branch_data_flow,
             :helper_call_data_flow,
             :pipeline_data_flow,
             :return_data_flow,
             :if_else,
             :case_clauses,
             :cond_branches,
             :with_chain,
             :anonymous_fn_branch,
             :multi_clause_function,
             :nested_branches,
             :pure,
             :io_effect,
             :send_effect,
             :raise_effect,
             :read_effect,
             :write_effect,
             :mixed_effect_boundary,
             :gen_server_callbacks,
             :guard_clause,
             :try_rescue_after,
             :receive_message,
             :comprehension,
             :struct_update,
             :default_arguments,
             :layered_valid,
             :forbidden_dependency,
             :layer_cycle,
             :public_api_boundary_violation,
             :internal_boundary_violation,
             :allowed_effect_violation
           ]
  end

  test "all policies round-trip through typed JSON manifests" do
    ProgramFacts.policies()
    |> Enum.with_index(1)
    |> Enum.each(fn {policy, seed} ->
      program = ProgramFacts.generate!(policy: policy, seed: seed, depth: 3, width: 3)
      manifest = Manifest.new(program)
      decoded = program |> ProgramFacts.to_json!() |> Manifest.decode!()

      assert %Manifest{} = manifest
      assert %Manifest{} = decoded
      assert %ManifestFile{} = hd(manifest.files)
      assert %ManifestFacts{} = manifest.facts
      assert Enum.all?(manifest.facts.functions, &match?(%FunctionID{}, &1))
      assert Enum.all?(manifest.facts.call_edges, &match?(%CallEdge{}, &1))
      assert Enum.all?(manifest.facts.data_flows, &match?(%DataFlow{}, &1))
      assert Enum.all?(manifest.facts.effects, &match?(%Effect{}, &1))
      assert Enum.all?(manifest.facts.branches, &match?(%Branch{}, &1))
      assert decoded.id == program.id
      assert decoded.facts.modules == manifest.facts.modules
      assert length(decoded.facts.functions) == length(program.facts.functions)
    end)
  end

  test "rejects unbounded seeds and sizes" do
    assert_raise ArgumentError, ~r/seed/, fn -> ProgramFacts.generate!(seed: 10_001) end
    assert_raise ArgumentError, ~r/depth/, fn -> ProgramFacts.generate!(depth: 27) end
    assert_raise ArgumentError, ~r/width/, fn -> ProgramFacts.generate!(width: 26) end
  end

  test "projects programs into semantic summary models" do
    program = ProgramFacts.generate!(policy: :linear_call_chain, seed: 10, depth: 3)
    model = ProgramFacts.model(program)

    assert model.id == program.id
    assert model.seed == program.seed
    assert model.policy == :linear_call_chain
    assert model.files == program.files
    assert model.relationships.call_edges == program.facts.call_edges
  end

  test "builds libgraph-compatible graph adapters" do
    program = ProgramFacts.generate!(policy: :module_cycle, seed: 10, depth: 3)
    [path] = program.facts.call_paths
    [source, target | _rest] = path

    call_graph = ProgramFacts.Graph.call_graph(program)
    module_graph = ProgramFacts.Graph.module_graph(program)

    assert Graph.num_vertices(call_graph) == length(program.facts.functions)
    assert Graph.num_edges(call_graph) == length(program.facts.call_edges)
    assert Graph.num_vertices(module_graph) == length(program.facts.modules)
    assert ProgramFacts.Graph.reachable?(program, source, target)
    assert ProgramFacts.Graph.path?(program, path)
    assert ProgramFacts.Graph.cycles(program) != []
    assert ProgramFacts.Graph.validate!(program) == program

    assert %{
             vertices: 3,
             edges: 3,
             modules: 3,
             cycles: 1,
             cyclic?: true,
             longest_declared_call_path: 4
           } = ProgramFacts.Graph.metrics(program)

    assert Graph.num_vertices(ProgramFacts.Graph.subgraph(program, [source, target])) == 2
  end

  test "graph validation rejects impossible paths" do
    program = ProgramFacts.generate!(policy: :single_call, seed: 11)
    [source, target] = program.facts.functions

    broken = put_in(program.facts.call_paths, [[target, source]])

    assert_raise ArgumentError, ~r/declared call path/, fn ->
      ProgramFacts.Graph.validate!(broken)
    end
  end

  test "builds custom semantic models with the builder API" do
    source = {Generated.ProgramFacts.Custom.A, :entry, 1}
    target = {Generated.ProgramFacts.Custom.B, :sink, 1}

    model =
      ProgramFacts.Model.builder(id: "custom", seed: 1, policy: :custom)
      |> Builder.add_call(source, target)
      |> Builder.add_call_path([source, target])
      |> Builder.add_effect(target, :io)
      |> Builder.add_branch(%{function: source, kind: :if, clauses: 2})
      |> Builder.add_features([:custom, :remote_call])
      |> Builder.build()

    program = ProgramFacts.Model.to_program(model)

    assert Enum.sort(program.facts.modules) ==
             Enum.sort([Generated.ProgramFacts.Custom.A, Generated.ProgramFacts.Custom.B])

    assert {source, target} in program.facts.call_edges
    assert [source, target] in program.facts.call_paths
    assert {target, :io} in program.facts.effects
    assert [%{function: ^source, kind: :if, clauses: 2}] = program.facts.branches
  end

  test "materializes facts from semantic models" do
    program = ProgramFacts.generate!(policy: :case_clauses, seed: 10)
    model = ProgramFacts.model(program)
    rematerialized = ProgramFacts.Model.to_program(model)

    assert rematerialized.files == program.files
    assert rematerialized.facts.modules == program.facts.modules
    assert rematerialized.facts.functions == program.facts.functions
    assert rematerialized.facts.call_edges == program.facts.call_edges
    assert rematerialized.facts.branches == program.facts.branches
    assert rematerialized.facts.features == program.facts.features
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
    assert [first | _] = cycle
    assert first == cycle |> Enum.reverse() |> hd()
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
          :multi_clause_function,
          :nested_branches
        ] do
      program = ProgramFacts.generate!(policy: policy, seed: 16)
      [branch] = program.facts.branches
      [entry, ok | _rest] = program.facts.functions

      assert branch.function == entry
      assert branch.clauses == 2
      assert length(program.facts.call_edges) >= 2
      assert {entry, ok} in program.facts.call_edges
      assert MapSet.member?(program.facts.features, :branch)
    end
  end

  test "attaches generated source locations" do
    program = ProgramFacts.generate!(policy: :case_clauses, seed: 16)

    assert length(program.facts.locations.modules) == 3

    assert [%{module: _, function: "entry", arity: 1, file: _, line: line}] =
             Enum.filter(program.facts.locations.functions, &(&1.function == "entry"))

    assert is_integer(line)
    assert Enum.any?(program.facts.locations.calls, &(&1.call =~ ".ok/1"))
    assert Enum.any?(program.facts.locations.branches, &(&1.kind == :case))
    assert Enum.any?(program.facts.locations.clauses, &(&1.patterns != []))
    assert Enum.any?(program.facts.locations.returns, &(&1.function == "entry"))
  end

  test "generates effect facts" do
    cases = [
      pure: :pure,
      io_effect: :io,
      send_effect: :send,
      raise_effect: :exception,
      read_effect: :read,
      write_effect: :write
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

  test "generates OTP callback facts" do
    program = ProgramFacts.generate!(policy: :gen_server_callbacks, seed: 18)

    assert Enum.any?(program.files, &(&1.source =~ "use GenServer"))

    assert {_, :handle_call, 3} =
             Enum.find(program.facts.functions, &(elem(&1, 1) == :handle_call))

    assert MapSet.member?(program.facts.features, :gen_server)
    assert_compiles(program)
  end

  test "generates richer Elixir syntax facts" do
    for policy <- [
          :guard_clause,
          :try_rescue_after,
          :receive_message,
          :comprehension,
          :struct_update,
          :default_arguments
        ] do
      program = ProgramFacts.generate!(policy: policy, seed: 19)

      assert MapSet.member?(program.facts.features, policy)
      assert_compiles(program)
    end
  end

  test "generates architecture policy facts" do
    valid = ProgramFacts.generate!(policy: :layered_valid, seed: 18)
    invalid = ProgramFacts.generate!(policy: :forbidden_dependency, seed: 19)

    assert valid.facts.architecture.valid?
    refute invalid.facts.architecture.valid?
    assert [%{type: :forbidden_dependency}] = invalid.facts.architecture.violations
    assert Enum.any?(invalid.files, &(&1.path == ".reach.exs"))
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

    assert map.schema_version == 1
    assert map.program_facts_version == "0.2.0"
    assert map.id == "pf_39_linear_call_chain"
    assert [%{path: _, source: _, kind: :elixir}, _] = map.files

    assert [%{id: _, module: _, function: _, arity: 1}, _] = map.facts.functions

    json = ProgramFacts.to_json!(program)
    assert is_binary(json)
    assert %{id: "pf_39_linear_call_chain"} = ProgramFacts.Manifest.decode!(json)
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

  test "refuses to overwrite non-empty directories unless forced" do
    root =
      Path.join(System.tmp_dir!(), "program_facts_write_#{System.unique_integer([:positive])}")

    program = ProgramFacts.generate!(policy: :single_call, seed: 41)

    try do
      File.mkdir_p!(root)
      File.write!(Path.join(root, "existing.txt"), "keep")

      assert_raise ArgumentError, ~r/non-empty/, fn ->
        ProgramFacts.Project.write!(root, program)
      end

      assert ProgramFacts.Project.write!(root, program, force: true) == root
      assert File.exists?(Path.join(root, "mix.exs"))
    after
      File.rm_rf!(root)
    end
  end

  test "written temporary projects compile generated files with Mix across layouts" do
    for layout <- ProgramFacts.layouts() do
      {:ok, dir, program} =
        ProgramFacts.Project.write_tmp!(policy: :pipeline_data_flow, seed: 41, layout: layout)

      try do
        assert {_, 0} = System.cmd("mix", ["compile"], cd: dir, stderr_to_stdout: true)

        beam_paths =
          Path.wildcard(
            Path.join(dir, "_build/dev/lib/*/ebin/Elixir.Generated.ProgramFacts*.beam")
          )

        assert length(beam_paths) == length(program.facts.modules)
      after
        File.rm_rf!(dir)
      end
    end
  end

  test "rejects source paths that escape the project root" do
    root =
      Path.join(System.tmp_dir!(), "program_facts_escape_#{System.unique_integer([:positive])}")

    program = %ProgramFacts.Program{
      id: "escape",
      seed: 1,
      files: [
        %ProgramFacts.File{
          path: "../escape.ex",
          source: "defmodule Escape do\nend\n",
          kind: :elixir
        }
      ],
      facts: %ProgramFacts.Facts{}
    }

    try do
      assert_raise ArgumentError, ~r/escapes project root/, fn ->
        ProgramFacts.Project.write!(root, program, force: true)
      end

      refute File.exists?(Path.expand(Path.join(root, "../escape.ex")))
    after
      File.rm_rf!(root)
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

  test "rename_variables keeps branch labels in sync with source" do
    variant =
      ProgramFacts.generate!(policy: :case_clauses, seed: 16)
      |> ProgramFacts.Transform.apply!(:rename_variables)

    [branch] = variant.facts.branches
    labels = Enum.map(branch.calls_by_clause, & &1.label)

    assert hd(variant.files).source =~ "case arg do"
    assert "{:ok, item}" in labels
    assert "{:error, cause}" in labels
    refute Enum.any?(labels, &String.contains?(&1, "value"))
    refute Enum.any?(labels, &String.contains?(&1, "reason"))
  end

  test "branch-adding transforms keep semantic branch facts complete" do
    for {transform, kind} <- [
          wrap_in_if_true: :if,
          wrap_in_case_identity: :case,
          add_dead_branch: :if
        ] do
      variant =
        ProgramFacts.generate!(policy: :single_call, seed: 1)
        |> ProgramFacts.Transform.apply!(transform)

      assert Enum.any?(variant.facts.branches, fn branch ->
               branch.kind == kind and branch.generated_by == :transform
             end)

      assert length(variant.facts.branches) == length(variant.facts.locations.branches)
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

  test "all transforms produce compilable programs" do
    for transform <- ProgramFacts.transforms() do
      program = ProgramFacts.generate!(policy: :straight_line_data_flow, seed: 48)
      variant = ProgramFacts.Transform.apply!(program, transform)

      assert Enum.any?(variant.metadata.transforms, &(&1.name == transform))
      assert_compiles(variant)
    end
  end

  test "extracts and inlines helper calls" do
    program = ProgramFacts.generate!(policy: :single_call, seed: 49)
    extracted = ProgramFacts.Transform.apply!(program, :extract_helper)
    inlined = ProgramFacts.Transform.apply!(extracted, :inline_helper)

    assert Enum.any?(extracted.facts.functions, fn {_module, function, _arity} ->
             function == :program_facts_identity
           end)

    refute Enum.any?(inlined.facts.functions, fn {_module, function, _arity} ->
             function == :program_facts_identity
           end)

    assert_compiles(extracted)
    assert_compiles(inlined)
  end

  test "adds unrelated modules without changing existing edges" do
    program = ProgramFacts.generate!(policy: :single_call, seed: 45)
    variant = ProgramFacts.Transform.apply!(program, :add_unrelated_module)

    assert length(variant.files) == length(program.files) + 1
    assert length(variant.facts.modules) == length(program.facts.modules) + 1
    assert variant.facts.call_edges == program.facts.call_edges
    assert_compiles(variant)
  end

  test "provides ExUnit helpers" do
    program = ProgramFacts.generate!(policy: :if_else, seed: 46)

    assert ProgramFacts.ExUnit.assert_compiles(program) == program
    assert ProgramFacts.ExUnit.assert_manifest_round_trip(program).id == program.id

    ProgramFacts.ExUnit.with_tmp_project(program, fn dir, tmp_program ->
      assert tmp_program.id == program.id
      assert File.exists?(Path.join(dir, "mix.exs"))
    end)
  end

  test "runs feedback-directed feature search" do
    result = ProgramFacts.Search.run(iterations: 10, seed: 60)

    assert result.coverage.program_count == length(result.programs)
    assert result.coverage.feature_count == MapSet.size(result.features)
    assert result.coverage.candidate_count == length(result.candidates)
    assert result.coverage.program_count > 0
  end

  test "search supports graph-backed scoring" do
    result =
      ProgramFacts.Search.run(
        iterations: 3,
        seed: 90,
        policies: [:single_call, :module_cycle],
        scoring: [:features, :graph_complexity, :cycles, :long_paths]
      )

    assert result.best_score > 0
    assert Enum.all?(result.candidates, &is_map(&1.graph_metrics))
    assert Enum.any?(result.candidates, &(&1.graph_metrics.cycles > 0))
  end

  test "search handles zero iterations and validates empty inputs" do
    result = ProgramFacts.Search.run(iterations: 0)

    assert result.programs == []
    assert result.candidates == []
    assert result.coverage == %{candidate_count: 0, feature_count: 0, program_count: 0}

    assert_raise ArgumentError, ~r/iterations/, fn -> ProgramFacts.Search.run(iterations: -1) end
    assert_raise ArgumentError, ~r/policies/, fn -> ProgramFacts.Search.run(policies: []) end
    assert_raise ArgumentError, ~r/layouts/, fn -> ProgramFacts.Search.run(layouts: []) end
  end

  property "StreamData program supports range options" do
    check all(
            program <-
              ProgramFacts.StreamData.program(
                policies: [:linear_call_chain],
                seed_range: 5..5,
                depth_range: 2..2,
                width_range: 3..3
              ),
            max_runs: 3
          ) do
      assert program.seed == 5
      assert program.metadata.depth in [1, 2]
    end
  end

  test "accepts feedback callbacks during search" do
    parent = self()

    result =
      ProgramFacts.Search.run(
        iterations: 3,
        seed: 70,
        score: fn program, _state -> length(program.files) end,
        interesting?: fn candidate, _state -> candidate.score >= 2 end,
        on_candidate: fn candidate, _state -> send(parent, {:candidate, candidate.program.id}) end
      )

    assert_receive {:candidate, _id}
    assert result.best_score >= 2
  end

  test "shrinks generated programs while a failure predicate holds" do
    program = ProgramFacts.generate!(policy: :linear_call_chain, seed: 80, depth: 5, width: 4)
    result = ProgramFacts.shrink(program, &(length(&1.facts.functions) >= 2))

    assert result.options[:depth] <= 2
    assert length(result.program.facts.functions) == 2
    assert Enum.any?(result.steps, & &1.accepted?)
  end

  test "shrinks transform sequences" do
    program =
      ProgramFacts.generate!(policy: :single_call, seed: 83)
      |> ProgramFacts.Transform.apply!([:add_dead_pure_statement, :add_unrelated_module])

    result =
      ProgramFacts.shrink(
        program,
        fn candidate ->
          candidate.metadata
          |> Map.get(:transforms, [])
          |> Enum.any?(&(&1.name == :add_unrelated_module))
        end,
        option_shrink: false
      )

    assert Enum.map(result.program.metadata.transforms, & &1.name) == [:add_unrelated_module]
    assert Enum.any?(result.steps, &(&1.kind == :remove_transform and &1.accepted?))
  end

  test "shrinks unrelated modules structurally" do
    program =
      ProgramFacts.generate!(policy: :single_call, seed: 81)
      |> ProgramFacts.Transform.apply!(:add_unrelated_module)

    result =
      ProgramFacts.shrink(program, &(length(&1.facts.call_edges) == 1), option_shrink: false)

    refute Enum.any?(result.program.facts.functions, fn {_module, function, _arity} ->
             function == :unrelated
           end)

    assert length(result.program.files) == 2
    assert Enum.any?(result.steps, &(&1.kind == :remove_module and &1.accepted?))
    assert_compiles(result.program)
  end

  test "compares transform invariant claims" do
    program = ProgramFacts.generate!(policy: :single_call, seed: 81)
    transformed = ProgramFacts.Transform.apply!(program, :add_dead_pure_statement)

    assert %{valid?: true} = ProgramFacts.compare_transform(program, transformed)
    assert ProgramFacts.assert_transform_preserved!(program, transformed) == transformed
  end

  test "runs differential analyzer callbacks" do
    program = ProgramFacts.generate!(policy: :single_call, seed: 82)

    result =
      ProgramFacts.differential(program, [
        {:a, fn program -> %{functions: length(program.facts.functions)} end},
        {:b, fn program -> %{functions: length(program.facts.functions)} end}
      ])

    assert result.agree?
    assert result.disagreements == []
    assert Enum.all?(result.results, &match?(%ProgramFacts.Analyzer.Result{}, &1))
  end

  test "promotes failures with failure structs" do
    root =
      Path.join(System.tmp_dir!(), "program_facts_failure_#{System.unique_integer([:positive])}")

    program = ProgramFacts.generate!(policy: :single_call, seed: 85)

    failure = Failure.new(program, analyzer: :reach, command: ["mix", "reach"])

    try do
      dir = ProgramFacts.Corpus.promote_failure!(program, root, failure)
      manifest = dir |> Path.join("failure.json") |> File.read!() |> Failure.decode!()

      assert manifest.program_id == program.id
      assert manifest.analyzer == "reach"
      assert manifest.command == ["mix", "reach"]
    after
      File.rm_rf!(root)
    end
  end

  test "promotes shrink results with replay metadata" do
    root =
      Path.join(System.tmp_dir!(), "program_facts_failure_#{System.unique_integer([:positive])}")

    program = ProgramFacts.generate!(policy: :linear_call_chain, seed: 84, depth: 4)
    shrink = ProgramFacts.shrink(program, &(length(&1.facts.functions) >= 2))

    try do
      dir = ProgramFacts.Corpus.promote_failure!(shrink, root)
      failure = dir |> Path.join("failure.json") |> File.read!() |> Failure.decode!()

      assert failure.program_id == shrink.program.id
      assert failure.shrink.steps != []
      assert failure.shrink.options.policy == "linear_call_chain"
    after
      File.rm_rf!(root)
    end
  end

  test "saves replayable corpus entries" do
    root =
      Path.join(System.tmp_dir!(), "program_facts_corpus_#{System.unique_integer([:positive])}")

    program = ProgramFacts.generate!(policy: :case_clauses, seed: 43)

    try do
      dir = ProgramFacts.Corpus.save!(program, root)
      manifest = ProgramFacts.Corpus.load_manifest!(dir)

      assert Path.basename(Path.dirname(dir)) == "case_clauses"
      assert manifest.id == program.id
      assert File.exists?(Path.join(dir, hd(program.files).path))
      assert ProgramFacts.Corpus.manifests(root) == [Path.join(dir, "program_facts.json")]
      assert [loaded] = ProgramFacts.Corpus.load_manifests!(root)
      assert loaded.id == program.id
    after
      File.rm_rf!(root)
    end
  end

  defp assert_compiles(program) do
    purge_modules(program.facts.modules)
    source = Enum.map_join(program.files, "\n", & &1.source)

    modules =
      source
      |> Code.compile_string("generated_program.exs")
      |> Enum.map(fn {module, _bytecode} -> module end)

    assert Enum.sort(modules) == Enum.sort(program.facts.modules)
  end

  defp purge_modules(modules) do
    Enum.each(modules, fn module ->
      :code.purge(module)
      :code.delete(module)
    end)
  end
end
