# ProgramFacts

[![Hex.pm](https://img.shields.io/hexpm/v/program_facts.svg)](https://hex.pm/packages/program_facts)
[![HexDocs](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/program_facts)
[![License](https://img.shields.io/hexpm/l/program_facts.svg)](LICENSE)

ProgramFacts generates valid Elixir projects with **ground-truth static-analysis facts**.

Use it to test analyzers, refactoring tools, code-intelligence systems, compilers, and graph builders against programs whose expected structure is known before the tool runs.

In this project, a “program fact” means a machine-checkable statement about source code: “module A exists”, “function A.entry/1 calls B.sink/1”, “parameter input reaches this call argument”, “this function performs IO”, or “this generated architecture policy is violated”.

Instead of generating arbitrary Elixir strings, ProgramFacts creates small deterministic programs from semantic templates and returns both:

1. source files, and
2. oracle facts about the generated program.

Those facts include modules, functions, call edges, call paths, data flow, effects, branches, source locations, architecture-policy fixtures, project layouts, and replay metadata.

## Why ProgramFacts?

Analyzer tests often have two weak options:

- handwritten fixtures, which are accurate but small and repetitive
- random source generation, which finds parser bugs but rarely has useful expected facts

ProgramFacts sits between those approaches. It generates source code procedurally, but every generated program carries a manifest of expected static-analysis facts. The manifest is the oracle: analyzers should rediscover the same facts from the generated source.

That makes it useful for tests like:

- “does my call graph recover this expected path?”
- “does my data-flow analysis see this parameter reaching that sink?”
- “does my effect classifier detect IO/send/read/write boundaries?”
- “does my project scanner include umbrella/package-style sources and exclude `deps/` / `_build/`?”
- “does my architecture checker report the expected forbidden dependency?”

## From oracle facts to fuzzy testing

A normal fuzzer can generate random source and ask only “did the analyzer crash?”. That is useful, but it does not tell you whether the analyzer’s answer is correct.

ProgramFacts generates **known-answer programs**. Each generated program comes with source plus oracle facts:

```text
semantic model -> source files -> ground-truth facts
```

So a property test can repeatedly generate valid programs, run an analyzer, and compare the analyzer result to the oracle facts that came with the program:

```elixir
property "analyzer finds generated call edges" do
  check all program <- ProgramFacts.StreamData.program(policies: [:single_call, :linear_call_chain]) do
    {:ok, dir, program} = ProgramFacts.Project.write_tmp!(program)

    try do
      actual_edges = MyAnalyzer.call_edges(dir) |> MapSet.new()
      expected_edges = program.facts.call_edges |> MapSet.new()

      assert MapSet.subset?(expected_edges, actual_edges)
    after
      File.rm_rf!(dir)
    end
  end
end
```

If seed `347` fails, the failure is reproducible because the generator is deterministic:

```elixir
ProgramFacts.generate!(policy: :linear_call_chain, seed: 347, depth: 4)
```

Then the shrinker can reduce the failing case by trying smaller generation options, shorter transform sequences, and removable unrelated modules/files.

## What is a program fact?

The term “fact” is common in static analysis and Datalog-style tooling: analyzers often extract relations such as `function/1`, `call/2`, `reads/2`, `writes/2`, or `data_flow/2` before running rules over them.

ProgramFacts uses “program fact” in that sense. A program fact is a machine-checkable structural truth about generated source. For example, this generated code:

```elixir
defmodule Generated.A do
  def entry(input), do: Generated.B.sink(input)
end

defmodule Generated.B do
  def sink(value), do: value
end
```

has facts like:

```elixir
modules: [Generated.A, Generated.B],
functions: [
  {Generated.A, :entry, 1},
  {Generated.B, :sink, 1}
],
call_edges: [
  {{Generated.A, :entry, 1}, {Generated.B, :sink, 1}}
],
call_paths: [
  [{Generated.A, :entry, 1}, {Generated.B, :sink, 1}]
]
```

Analyzers can compare their discovered facts against these expected facts. That turns generated programs into oracle-backed fuzz cases rather than just random parser inputs.

Related terminology you may see elsewhere: static-analysis facts, code facts, Datalog facts, semantic facts, structural facts, ground-truth facts, and oracle facts. ProgramFacts deliberately uses plain JSON-friendly facts so different analyzers can consume the same generated cases.

## Installation

```elixir
def deps do
  [
    {:program_facts, "~> 0.2", only: [:dev, :test]}
  ]
end
```

`ProgramFacts.StreamData` requires `stream_data`, which is optional. Add it if you want property-style generators:

```elixir
def deps do
  [
    {:program_facts, "~> 0.2", only: [:dev, :test]},
    {:stream_data, "~> 1.1", only: [:dev, :test]}
  ]
end
```

## Quick start

Generate a program:

```elixir
program =
  ProgramFacts.generate!(
    policy: :linear_call_chain,
    seed: 123,
    depth: 4
  )
```

Inspect the generated source:

```elixir
program.files
#=> [
#=>   %ProgramFacts.File{path: "lib/generated/program_facts/seed123/a.ex", ...},
#=>   %ProgramFacts.File{path: "lib/generated/program_facts/seed123/b.ex", ...},
#=>   ...
#=> ]
```

Inspect the facts:

```elixir
program.facts.modules
program.facts.functions
program.facts.call_edges
program.facts.call_paths
program.facts.locations
```

Export facts as JSON:

```elixir
ProgramFacts.to_json!(program)
# JSON includes schema_version and program_facts_version.
```

## Example: write a temporary Mix project

```elixir
{:ok, dir, program} =
  ProgramFacts.Project.write_tmp!(
    policy: :straight_line_data_flow,
    seed: 42
  )

File.ls!(dir)
#=> ["_build", "deps", "lib", "mix.exs", "program_facts.json"]
```

The generated project includes:

```text
mix.exs
program_facts.json
lib/generated/...
deps/ignored/...
_build/dev/...
```

The ignored files are intentional fixtures for source-discovery tests.

`ProgramFacts.Project.write!/3` refuses to overwrite non-empty directories unless `force: true` is passed.

Seeds are bounded to `0..10_000` because generated module names are atoms.

## Example: test an analyzer

```elixir
test "generated call path is present" do
  {:ok, dir, program} =
    ProgramFacts.Project.write_tmp!(
      policy: :linear_call_chain,
      seed: 100,
      depth: 3
    )

  project = MyAnalyzer.load_project!(dir)

  expected_edges = MapSet.new(program.facts.call_edges)
  actual_edges = MapSet.new(MyAnalyzer.call_edges(project))

  assert MapSet.subset?(expected_edges, actual_edges)
end
```

## Policies

Policies choose the shape of the generated program.

### Call graph

```elixir
:single_call
:linear_call_chain
:branching_call_graph
:module_dependency_chain
:module_cycle
```

### Data flow

```elixir
:straight_line_data_flow
:assignment_chain
:branch_data_flow
:helper_call_data_flow
:pipeline_data_flow
:return_data_flow
```

### Branches and control flow

```elixir
:if_else
:case_clauses
:cond_branches
:with_chain
:anonymous_fn_branch
:multi_clause_function
:nested_branches
```

### Effects

```elixir
:pure
:io_effect
:send_effect
:raise_effect
:read_effect
:write_effect
:mixed_effect_boundary
```

### OTP fixtures

```elixir
:gen_server_callbacks
```

### Richer Elixir syntax fixtures

```elixir
:guard_clause
:try_rescue_after
:receive_message
:comprehension
:struct_update
:default_arguments
```

### Architecture fixtures

```elixir
:layered_valid
:forbidden_dependency
:layer_cycle
:public_api_boundary_violation
:internal_boundary_violation
:allowed_effect_violation
```

List them at runtime:

```elixir
ProgramFacts.policies()
```

## Project layouts

ProgramFacts can render the same generated program into different project layouts:

```elixir
ProgramFacts.layouts()
#=> [:plain, :umbrella, :package_style]
```

Examples:

```elixir
ProgramFacts.generate!(policy: :linear_call_chain, layout: :plain)
ProgramFacts.generate!(policy: :linear_call_chain, layout: :umbrella)
ProgramFacts.generate!(policy: :linear_call_chain, layout: :package_style)
```

Supported layout patterns:

- `lib/**/*.ex`
- `apps/*/lib/**/*.ex`
- `*/lib/**/*.ex`

Generated projects also include excluded fixtures under `deps/` and `_build/`.

## Facts

A generated program has this shape:

```elixir
%ProgramFacts.Program{
  id: "pf_123_linear_call_chain",
  seed: 123,
  files: [%ProgramFacts.File{}],
  facts: %ProgramFacts.Facts{},
  metadata: %{}
}
```

Facts include:

```elixir
program.facts.modules
program.facts.functions
program.facts.call_edges
program.facts.call_paths
program.facts.data_flows
program.facts.effects
program.facts.branches
program.facts.architecture
program.facts.locations
program.facts.features
```

JSON export is versioned. `to_map/1` returns atom-keyed Elixir data; `to_json!/1` lets the JSON encoder produce JSON object keys.

```elixir
ProgramFacts.to_map(program)
ProgramFacts.to_json!(program)
```

The JSON manifest includes:

- `schema_version`
- `program_facts_version`
- source files
- metadata
- facts

## Shrinking

ProgramFacts can minimize a generated failure by trying smaller deterministic generation options while a predicate still reproduces the failure:

```elixir
program = ProgramFacts.generate!(policy: :linear_call_chain, seed: 80, depth: 5)

result =
  ProgramFacts.shrink(program, fn candidate ->
    MyAnalyzer.fails?(candidate)
  end)

result.program
result.options
result.steps
```

The shrinker reduces layout, width, and depth, minimizes transform sequences, then tries structural reductions such as removing unrelated modules/files. Pass `option_shrink: false` to skip regeneration-based option shrinking and focus on transforms/structure. It is deterministic and returns a trace of accepted/rejected shrink steps.

## Transforms

ProgramFacts includes AST-based transforms for metamorphic testing.

```elixir
variant =
  program
  |> ProgramFacts.Transform.apply!([
    :rename_variables,
    :add_dead_pure_statement,
    :wrap_in_if_true
  ])

variant.metadata.transforms

ProgramFacts.compare_transform(program, variant)
ProgramFacts.assert_transform_preserved!(program, variant)
```

Available transforms:

```elixir
ProgramFacts.transforms()
```

Current transforms include:

```elixir
:rename_variables
:add_dead_pure_statement
:add_dead_branch
:extract_helper
:inline_helper
:wrap_in_if_true
:wrap_in_case_identity
:reorder_independent_assignments
:split_module_files
:add_unrelated_module
:add_alias_and_rewrite_remote_call
```

Source transforms use Elixir AST tools such as `Code.string_to_quoted!/2`, `Macro`, and `Macro.to_string/1`. ProgramFacts does not parse or rewrite Elixir source with regex.

## Corpus and replay

Save generated projects as replayable corpus entries:

```elixir
program = ProgramFacts.generate!(policy: :case_clauses, seed: 43)

dir = ProgramFacts.Corpus.save!(program, "corpus/analyzer")
manifest = ProgramFacts.Corpus.load_manifest!(dir)
```

Discover saved manifests:

```elixir
ProgramFacts.Corpus.manifests("corpus/analyzer")
ProgramFacts.Corpus.load_manifests!("corpus/analyzer")
```

Each corpus entry includes the source project and `program_facts.json` manifest.

## ExUnit helpers

```elixir
ProgramFacts.ExUnit.assert_compiles(program)
ProgramFacts.ExUnit.assert_manifest_round_trip(program)

ProgramFacts.ExUnit.with_tmp_project(program, fn dir, program ->
  assert File.exists?(Path.join(dir, "mix.exs"))
end)
```

## StreamData integration

With `stream_data` installed:

```elixir
use ExUnitProperties

property "generated programs load" do
  check all program <- ProgramFacts.StreamData.program(seed_range: 0..100) do
    ProgramFacts.ExUnit.assert_compiles(program)
  end
end
```

## Graph adapters

ProgramFacts keeps manifests as plain JSON-friendly facts, but can expose `libgraph` graphs when the optional dependency is available:

```elixir
call_graph = ProgramFacts.Graph.call_graph(program)
module_graph = ProgramFacts.Graph.module_graph(program)

ProgramFacts.Graph.reachable?(program, source, target)
ProgramFacts.Graph.path?(program, program.facts.call_paths |> hd())
ProgramFacts.Graph.cycles(program)
ProgramFacts.Graph.metrics(program)
ProgramFacts.Graph.subgraph(program, vertices)
ProgramFacts.Graph.validate!(program)
```

Use these helpers when integrating with analyzers such as Reach that already operate on `Graph.t()` values.

## Differential testing

Compare multiple analyzer callbacks or adapter modules against the same generated program:

```elixir
ProgramFacts.differential(program, [
  {:source_frontend, &SourceAnalyzer.facts/1},
  {:beam_frontend, &BeamAnalyzer.facts/1},
  MyAnalyzerAdapter
])
```

Adapter modules implement `ProgramFacts.Analyzer` and return maps, facts, programs, or `ProgramFacts.Analyzer.Result` structs. The result reports whether normalized analyzer facts agree and records pairwise disagreements.

## Feedback-directed search

ProgramFacts can run a feature-coverage or callback-driven search:

```elixir
result =
  ProgramFacts.Search.run(
    iterations: 50,
    seed: 100,
    scoring: [:features, :graph_complexity, :cycles, :long_paths],
    interesting?: fn candidate, state -> candidate.score > state.best_score end
  )

result.programs
result.candidates
result.coverage
result.features
```

Built-in scoring modes include `:features`, `:new_features`, `:graph_complexity`, `:cycles`, and `:long_paths`. You can still pass a custom `:score` callback for analyzer-specific scoring. This gives analyzer test suites a starting point for collecting diverse or analyzer-interesting generated programs.

## Semantic model

Built-in policies construct a `ProgramFacts.Model` first, then materialize source and facts from that model. Custom generators can use the builder API:

```elixir
source = {MyApp.A, :entry, 1}
target = {MyApp.B, :sink, 1}

model =
  ProgramFacts.Model.builder(id: "custom", seed: 1, policy: :custom)
  |> ProgramFacts.Model.Builder.add_call(source, target)
  |> ProgramFacts.Model.Builder.add_call_path([source, target])
  |> ProgramFacts.Model.Builder.add_feature(:remote_call)
  |> ProgramFacts.Model.Builder.build()

program = ProgramFacts.Model.to_program(model)
```

You can also project a generated program back into the semantic summary:

```elixir
model = ProgramFacts.model(program)

model.modules
model.functions
model.relationships.call_edges
model.relationships.data_flows
model.features
```

## Design principles

- valid Elixir by construction
- deterministic output from seed + policy
- facts generated with source, not inferred afterward by the analyzer under test
- explicit manifests for replay
- bounded atom generation
- AST-based transforms, no regex source rewriting
- generic analyzer-testing package, not a Reach-specific helper

## Roadmap

See [`ROADMAP.md`](ROADMAP.md) for long-term plans, including richer model builder APIs, more renderer backends, shrinking/minimization, Erlang generation, and broader Elixir syntax.

## License

MIT. See [`LICENSE`](LICENSE).
