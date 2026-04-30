# ProgramFacts

[![Hex.pm](https://img.shields.io/hexpm/v/program_facts.svg)](https://hex.pm/packages/program_facts)
[![HexDocs](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/program_facts)
[![License](https://img.shields.io/hexpm/l/program_facts.svg)](LICENSE)

ProgramFacts generates valid Elixir projects with known structural facts.

Use it to test analyzers, refactoring tools, code-intelligence systems, compilers, and graph builders against programs whose expected behavior is known before the tool runs.

Instead of generating arbitrary Elixir strings, ProgramFacts creates small deterministic programs from semantic templates and returns both:

1. source files, and
2. ground-truth facts about the generated program.

Those facts include modules, functions, call edges, call paths, data flow, effects, branches, source locations, architecture-policy fixtures, project layouts, and replay metadata.

## Why ProgramFacts?

Analyzer tests often have two weak options:

- handwritten fixtures, which are accurate but small and repetitive
- random source generation, which finds parser bugs but rarely has useful expected facts

ProgramFacts sits between those approaches. It generates source code procedurally, but every generated program carries a manifest of expected structural facts.

That makes it useful for tests like:

- “does my call graph recover this expected path?”
- “does my data-flow analysis see this parameter reaching that sink?”
- “does my effect classifier detect IO/send/read/write boundaries?”
- “does my project scanner include umbrella/package-style sources and exclude `deps/` / `_build/`?”
- “does my architecture checker report the expected forbidden dependency?”

## Installation

```elixir
def deps do
  [
    {:program_facts, "~> 0.1", only: [:dev, :test]}
  ]
end
```

`ProgramFacts.StreamData` requires `stream_data`, which is optional. Add it if you want property-style generators:

```elixir
def deps do
  [
    {:program_facts, "~> 0.1", only: [:dev, :test]},
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

JSON export is versioned:

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

## Feedback-directed search

ProgramFacts can run a simple feature-coverage search:

```elixir
result = ProgramFacts.Search.run(iterations: 50, seed: 100)

result.programs
result.coverage
result.features
```

This is intentionally small today, but it gives analyzer test suites a starting point for collecting diverse generated programs.

## Semantic model projection

Project a generated program into a semantic summary:

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

See [`ROADMAP.md`](ROADMAP.md) for long-term plans, including model-first generation, richer source-location facts, shrinking/minimization, and more project layouts.

## License

MIT. See [`LICENSE`](LICENSE).
