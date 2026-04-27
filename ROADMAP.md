# ProgramFacts Roadmap

ProgramFacts generates Elixir projects with known structural facts for testing analyzers, refactoring tools, compilers, and code intelligence systems.

The package should not merely generate syntactically valid Elixir. It should generate source code plus ground truth: modules, functions, call edges, call paths, data-flow facts, effect facts, architecture facts, project layout facts, and source locations where practical.

## Principles

- Generate from a semantic model, not random strings.
- Keep generated programs valid by construction.
- Make every generated program reproducible with a seed.
- Return both source files and expected facts.
- Keep Reach-specific assertions outside this package.
- Start with a small Elixir subset and expand only when tests need it.

## Public API target

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

```elixir
{:ok, dir, program} =
  ProgramFacts.Project.write_tmp!(
    policy: :straight_line_data_flow,
    seed: 42
  )
```

## Data model

```elixir
%ProgramFacts.Program{
  id: "pf_123_linear_call_chain",
  seed: 123,
  files: [%ProgramFacts.File{}],
  facts: %ProgramFacts.Facts{},
  metadata: %{}
}
```

Facts should include:

- `modules`
- `functions`
- `call_edges`
- `call_paths`
- `data_flows`
- `effects`
- `branches`
- `architecture`
- `locations`
- `features`

## Phase 0 — package bootstrap

- Mix project
- CI-ready test setup
- Formatter
- README
- Roadmap
- Basic package metadata
- Deterministic generation API

Definition of done:

- `mix test` passes
- `mix format --check-formatted` passes
- `mix hex.build` succeeds

## Phase 1 — call graph generator

Policies:

- `:single_call`
- `:linear_call_chain`
- `:branching_call_graph`
- `:module_dependency_chain`
- `:module_cycle`

Initial facts:

- modules
- functions
- call edges
- call paths

Reach integration target:

```sh
mix reach.inspect Generated.A.entry/1 --why Generated.C.sink/1 --format json
```

Definition of done:

- Generated source compiles
- Facts are deterministic
- Reach can consume generated files

## Phase 2 — data-flow generator

Policies:

- `:straight_line_data_flow`
- `:assignment_chain`
- `:branch_data_flow`
- `:helper_call_data_flow`
- `:pipeline_data_flow`
- `:return_data_flow`

Initial facts:

- parameter-to-variable flow
- variable-to-call-argument flow
- helper argument-to-return flow
- source/sink descriptors

Reach integration targets:

```sh
mix reach.trace --from input --to sink --format json
mix reach.map --data --format json
```

## Phase 3 — branch/control-flow generator

Policies:

- `:if_else`
- `:case_clauses`
- `:cond_branches`
- `:with_chain`
- `:multi_clause_function`
- `:anonymous_fn_branch`
- `:nested_branches`

Targets:

- CFG generation
- block quality
- clause edge labels
- `reach.inspect --graph`
- `reach.map --depth`

## Phase 4 — effect generator

Policies:

- `:pure`
- `:io_effect`
- `:send_effect`
- `:raise_effect`
- `:read_effect`
- `:write_effect`
- `:mixed_effect_boundary`

Targets:

```sh
mix reach.map --effects --format json
mix reach.check --candidates --format json
```

## Phase 5 — architecture/policy generator

Policies:

- `:layered_valid`
- `:forbidden_dependency`
- `:layer_cycle`
- `:public_api_boundary_violation`
- `:internal_boundary_violation`
- `:allowed_effect_violation`

Targets:

```sh
mix reach.check --arch --format json
```

## Phase 6 — project layout generator

Layouts:

- `lib/**/*.ex`
- `apps/*/lib/**/*.ex`
- `*/lib/**/*.ex`
- `src/**/*.erl`
- `apps/*/src/**/*.erl`
- `*/src/**/*.erl`
- exclude `deps/`
- exclude `_build/`

Start with Elixir layouts only.

## Phase 7 — metamorphic transformations

Transforms:

- rename variables
- add dead pure statement
- add dead branch
- extract helper
- inline helper
- wrap in `if true`
- wrap in identity `case`
- reorder independent assignments
- split module files
- add unrelated module
- add alias and rewrite remote call

Each transform must declare which facts it preserves.

## Phase 8 — feedback-directed generation

Track feature coverage:

- constructs
- call shapes
- data shapes
- effects
- layouts
- target resolution forms

Use objectives to generate more structurally diverse programs.

## Phase 9 — corpus management

Save interesting generated programs as replayable fixtures:

```text
corpus/reach/call_chain/seed_000123/
  program_facts.json
  facts.json
  lib/generated/a.ex
```

Corpus entries must include package version, policy, seed, options, files, and facts.

## First implementation slice

Implement now:

- `ProgramFacts.generate!/1`
- `ProgramFacts.generate!/0`
- `ProgramFacts.Project.write_tmp!/1`
- policies:
  - `:linear_call_chain`
  - `:straight_line_data_flow`
- structs:
  - `ProgramFacts.Program`
  - `ProgramFacts.File`
  - `ProgramFacts.Facts`

Then wire into Reach property tests in a separate step.
