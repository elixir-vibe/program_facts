# ProgramFacts

ProgramFacts generates Elixir programs with known structural facts for analyzer testing.

It is designed for tools that need source code plus ground truth: call edges, call paths, data-flow facts, effects, branch structures, architecture violations, and project layouts.

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
```

Write a generated Mix project to a temporary directory:

```elixir
{:ok, dir, program} =
  ProgramFacts.Project.write_tmp!(
    policy: :straight_line_data_flow,
    seed: 42
  )
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
#=>   :pipeline_data_flow
#=> ]
```

## Why not random Elixir strings?

ProgramFacts generates from semantic templates and returns facts from the same model. The goal is not to produce arbitrary syntax; the goal is to produce programs whose expected structural properties are known before an analyzer sees them.

See `ROADMAP.md` for the long-term plan.
