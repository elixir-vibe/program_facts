# ProgramFacts

ProgramFacts generates Elixir programs with known structural facts for analyzer testing.

It is designed for tools that need source code plus ground truth: call edges, call paths, data-flow facts, effects, branch structures, source locations, architecture violations, and project layouts.

The first implementation slice supports deterministic generation of:

- single calls
- linear call chains
- branching call graphs
- module dependency chains
- module cycles
- straight-line data-flow programs
- assignment-chain data-flow programs
- helper-call data-flow programs
- pipeline data-flow programs
- if/else branch programs
- case clause programs
- cond, with, anonymous function branch, and multi-clause function programs
- pure/io/send/raise effect programs
- mixed-effect boundary programs
- plain, umbrella, and package-style project layouts
- temporary Mix projects

## Installation

```elixir
def deps do
  [
    {:program_facts, "~> 0.1", only: [:dev, :test]}
  ]
end
```

## Usage

```elixir
program =
  ProgramFacts.generate!(
    policy: :linear_call_chain,
    seed: 123,
    depth: 4
  )

program.files
program.facts.call_edges
program.facts.call_paths
program.facts.locations

ProgramFacts.to_map(program)
ProgramFacts.to_json!(program)
# JSON includes schema_version and program_facts_version.

umbrella_program =
  ProgramFacts.generate!(
    policy: :linear_call_chain,
    seed: 123,
    depth: 4,
    layout: :umbrella
  )
```

Write a generated Mix project to a temporary directory. The project includes a `program_facts.json` manifest with the generated facts:

```elixir
{:ok, dir, program} =
  ProgramFacts.Project.write_tmp!(
    policy: :straight_line_data_flow,
    seed: 42
  )
```

`ProgramFacts.Project.write!/3` refuses to overwrite non-empty directories unless `force: true` is passed.
Seeds are bounded to `0..10_000` because generated module names are atoms.

Apply fact-aware transformations:

```elixir
variant =
  program
  |> ProgramFacts.Transform.apply!([:rename_variables, :add_dead_pure_statement])

variant.metadata.transforms
```

Use test helpers:

```elixir
ProgramFacts.ExUnit.assert_compiles(program)
ProgramFacts.ExUnit.assert_manifest_round_trip(program)

ProgramFacts.ExUnit.with_tmp_project(program, fn dir, program ->
  assert File.exists?(Path.join(dir, "mix.exs"))
end)
```

Save a replayable corpus entry:

```elixir
program = ProgramFacts.generate!(policy: :case_clauses, seed: 43)
dir = ProgramFacts.Corpus.save!(program, "corpus/reach")
manifest = ProgramFacts.Corpus.load_manifest!(dir)
```

## Policies

```elixir
ProgramFacts.policies()
#=> [
#=>   :single_call,
#=>   :linear_call_chain,
#=>   :branching_call_graph,
#=>   :module_dependency_chain,
#=>   :module_cycle,
#=>   :straight_line_data_flow,
#=>   :assignment_chain,
#=>   :helper_call_data_flow,
#=>   :pipeline_data_flow,
#=>   :if_else,
#=>   :case_clauses,
#=>   :cond_branches,
#=>   :with_chain,
#=>   :anonymous_fn_branch,
#=>   :multi_clause_function,
#=>   :pure,
#=>   :io_effect,
#=>   :send_effect,
#=>   :raise_effect,
#=>   :mixed_effect_boundary
#=> ]
```

## Why not random Elixir strings?

ProgramFacts generates from semantic templates and returns facts from the same model. The goal is not to produce arbitrary syntax; the goal is to produce programs whose expected structural properties are known before an analyzer sees them.

See `ROADMAP.md` for the long-term plan.
