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

## Current status

Completed package-side work through the original roadmap, excluding Reach integration.

- Phase 0: complete.
- Phase 1: complete.
- Phase 2: complete for planned Elixir policies.
- Phase 3: complete for planned branch policies.
- Phase 4: complete for planned effect policies.
- Phase 5: complete for package-side architecture fixtures.
- Phase 6: complete for Elixir layouts; Erlang layouts remain future work.
- Phase 7: complete for the planned initial transform set.
- Phase 8: initial feedback-directed feature search implemented.
- Phase 9: initial corpus persistence and manifest loading implemented.
- Reach integration: intentionally not started.

## Public API

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
ProgramFacts.model(program)
ProgramFacts.to_json!(program)
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

Facts include:

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

Status: complete.

Implemented:

- Mix project
- CI alias
- Formatter
- README
- Roadmap
- Basic package metadata
- Deterministic generation API
- Hex build verification
- Credo strict
- ExDNA
- Dialyzer
- ExUnit tests

## Phase 1 — call graph generator

Status: complete.

Implemented policies:

- `:single_call`
- `:linear_call_chain`
- `:branching_call_graph`
- `:module_dependency_chain`
- `:module_cycle`

Facts:

- modules
- functions
- call edges
- call paths
- cycle architecture fact for `:module_cycle`

Reach integration target remains future work:

```sh
mix reach.inspect Generated.A.entry/1 --why Generated.C.sink/1 --format json
```

## Phase 2 — data-flow generator

Status: complete for planned Elixir policies.

Implemented policies:

- `:straight_line_data_flow`
- `:assignment_chain`
- `:branch_data_flow`
- `:helper_call_data_flow`
- `:pipeline_data_flow`
- `:return_data_flow`

Facts:

- parameter-to-variable flow
- variable-to-call-argument flow
- helper argument-to-return flow
- branch data-flow descriptors
- return data-flow descriptors
- source/sink descriptors

Reach integration targets remain future work:

```sh
mix reach.trace --from input --to sink --format json
mix reach.map --data --format json
```

## Phase 3 — branch/control-flow generator

Status: complete for planned branch policies.

Implemented policies:

- `:if_else`
- `:case_clauses`
- `:cond_branches`
- `:with_chain`
- `:multi_clause_function`
- `:anonymous_fn_branch`
- `:nested_branches`

Facts:

- branch kind
- clause count
- clause labels
- nested branch descriptors
- calls by clause
- call edges
- call paths

## Phase 4 — effect generator

Status: complete for planned effect policies.

Implemented policies:

- `:pure`
- `:io_effect`
- `:send_effect`
- `:raise_effect`
- `:read_effect`
- `:write_effect`
- `:mixed_effect_boundary`

Targets remain future Reach integration work:

```sh
mix reach.map --effects --format json
mix reach.check --candidates --format json
```

## Phase 5 — architecture/policy generator

Status: package-side fixtures implemented.

Implemented policies:

- `:layered_valid`
- `:forbidden_dependency`
- `:layer_cycle`
- `:public_api_boundary_violation`
- `:internal_boundary_violation`
- `:allowed_effect_violation`

Generated projects include `.reach.exs` fixtures and architecture facts. Reach validation remains future work.

## Phase 6 — project layout generator

Status: complete for Elixir layouts.

Implemented layouts:

- `lib/**/*.ex` via `:plain`
- `apps/*/lib/**/*.ex` via `:umbrella`
- `*/lib/**/*.ex` via `:package_style`
- generated `deps/` excluded fixture files
- generated `_build/` excluded fixture files
- layout-aware generated `mix.exs` with `elixirc_paths`

Future work:

- `src/**/*.erl`
- `apps/*/src/**/*.erl`
- `*/src/**/*.erl`

## Phase 7 — metamorphic transformations

Status: complete for planned initial transform set.

Implemented transforms:

- `:rename_variables`
- `:add_dead_pure_statement`
- `:add_dead_branch`
- `:extract_helper`
- `:inline_helper`
- `:wrap_in_if_true`
- `:wrap_in_case_identity`
- `:reorder_independent_assignments`
- `:split_module_files`
- `:add_unrelated_module`
- `:add_alias_and_rewrite_remote_call`

All source transforms are AST-based. No library code rewrites Elixir source with regex.

## Phase 8 — feedback-directed generation

Status: initial implementation complete.

Implemented:

```elixir
ProgramFacts.Search.run(iterations: 50, seed: 100)
```

The search keeps programs that add new feature coverage and reports feature/program counts.

## Phase 9 — corpus management

Status: initial implementation complete.

Implemented:

```elixir
ProgramFacts.Corpus.save!(program, root)
ProgramFacts.Corpus.manifests(root)
ProgramFacts.Corpus.load_manifest!(dir)
ProgramFacts.Corpus.load_manifests!(root)
```

Corpus entries include:

```text
program_facts.json
mix.exs
lib/generated/...
```

`program_facts.json` includes `schema_version`, `program_facts_version`, policy, layout, files, metadata, and facts.

## Remaining work

- Reach integration tests.
- Full semantic-model-first generation rather than policy templates projected into `ProgramFacts.Model`.
- Splitting `ProgramFacts.Generate` into smaller policy/render modules.
- Erlang source layout generation.
- Richer source locations for calls, assignments, branches, and clauses.
- Shrinking/minimization for generated failures.
