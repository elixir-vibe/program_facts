# ProgramFacts Roadmap

ProgramFacts generates Elixir projects with ground-truth static-analysis facts for testing analyzers, refactoring tools, compilers, and code intelligence systems.

In this roadmap, “program facts” means machine-checkable facts about source code: modules, functions, call edges, call paths, data-flow facts, effect facts, branch facts, architecture facts, project layout facts, and source locations where practical. These are oracle facts: analyzers should rediscover them from the generated source.

The package should not merely generate syntactically valid Elixir. It should generate source code plus ground truth.

## Principles

- Generate from a semantic model, not random strings.
- Keep generated programs valid by construction.
- Make every generated program reproducible with a seed.
- Return both source files and expected oracle facts.
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
- Phase 8: feedback-directed feature search implemented with scoring/interesting callbacks.
- Phase 9: corpus persistence, manifest loading, failure promotion, and replay helpers implemented.
- Phase 10: model-first generation implemented for built-in policies; policy modules build `ProgramFacts.Model` values and `ProgramFacts.Model.to_program/1` derives `ProgramFacts.Facts`.
- Graph adapter: optional `libgraph` integration implemented through `ProgramFacts.Graph` for call graphs, module graphs, path validation, reachability, cycle checks, graph metrics, and subgraph extraction.
- Phase 11: option shrinker, transform-sequence minimization, and initial structural module/file minimization implemented.
- Phase 12: analyzer feedback callbacks and graph-backed scoring modes implemented.
- Phase 13: transform invariant comparison implemented.
- Phase 14: OTP/GenServer plus initial richer Elixir syntax fixtures implemented.
- Phase 15: differential analyzer callback comparison and adapter/result normalization implemented.
- Typed manifest boundary: `%ProgramFacts.Manifest{}`, `%ProgramFacts.Manifest.Facts{}`, `%ProgramFacts.Manifest.File{}`, and `%ProgramFacts.Fact.*{}` payloads implemented with JSON protocol encoding/decoding.
- Static quality checks: GitHub Actions and `mix ci` include compile warnings-as-errors, format, Credo strict, ExDNA, Dialyzer, ExSlop, and tests.
- Reach integration: implemented in Reach test/dev validation.

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

## Fuzzing roadmap

The initial motivation was fuzz/property testing for Reach and other Elixir analyzers. Research into Csmith, YARPGen, QuickChick, FuzzChick, EMI/Orion, NAUTILUS, Gramatron, GRIMOIRE, GLADE, Athena, and Hermes led to one core decision: analyzer tests need generated programs with known facts, not arbitrary random strings.

ProgramFacts is therefore a structural-oracle generator first, and a fuzzing engine second. The next phases move it closer to mature fuzzing workflows while preserving source-plus-ground-truth-facts as the core value.

### Phase 10 — model-first generation

Goal: move from policy templates that project into a model toward a semantic model as the source of truth.

Tasks:

- Add explicit model builders for modules, functions, calls, data flows, effects, branches, and architecture facts.
- Render source from the model.
- Derive facts from the model rather than maintaining source/facts by hand.
- Keep policy generators as model constructors.
- Support multiple renderers from the same model over time.

### Phase 11 — shrinking and minimization

Goal: make generated failures easy to reduce.

Tasks:

- Add `ProgramFacts.Shrink`.
- Reduce `depth` and `width` while a failure predicate still fails.
- Try simpler layouts.
- Remove unrelated modules/files while preserving the failure.
- Minimize transform sequences.
- Return a replayable minimized program and shrink trace.

### Phase 12 — analyzer feedback loop

Goal: support feedback-directed generation instead of only feature coverage.

Tasks:

- Extend `ProgramFacts.Search.run/1` with `:score`, `:interesting?`, and `:on_candidate` callbacks.
- Track crashes, mismatches, new analyzer coverage, slow cases, and feature novelty.
- Keep corpus-worthy programs automatically.
- Support deterministic replay of interesting seeds.

### Phase 13 — metamorphic properties

Goal: make transforms testable as equivalence/near-equivalence claims.

Tasks:

- Add transform invariant metadata.
- Record which facts should be preserved and which facts may change.
- Provide helpers to compare original/transformed facts.
- Support EMI-style equivalent variants such as wrapping in `if true`, identity cases, alias rewrites, helper extraction/inlining, and independent assignment reordering.

### Phase 14 — richer Elixir subset

Goal: broaden generated Elixir while keeping known facts.

Tasks:

- Add guards.
- Add `try/rescue/after`.
- Add `receive`.
- Add comprehensions.
- Add protocols.
- Add structs and nested updates.
- Add default arguments.
- Add alias/import/require combinations.
- Add macro-generated functions.
- Add OTP/GenServer modules.
- Add Phoenix/Ecto-style DSL fixtures.
- Add Erlang source layouts.

### Phase 15 — differential testing

Goal: compare analyzers or analyzer versions.

Tasks:

- Compare Reach source frontend vs BEAM frontend.
- Compare current Reach vs previous release.
- Compare canonical CLI JSON vs internal APIs.
- Allow users to register multiple analyzer adapters.
- Save disagreement repros to corpus.

### Phase 16 — corpus promotion

Goal: turn generated failures into stable regression fixtures.

Tasks:

- Promote minimized failures into named corpus entries.
- Store failure metadata, analyzer command, expected mismatch, and minimized seed/options.
- Add replay helpers that run analyzers against saved corpus entries.
- Support CI-friendly corpus subsets.

## Remaining work

- Keep expanding Reach integration coverage as ProgramFacts grows.
- Keep enriching model-first generation with more renderer backends.
- Expand `ProgramFacts.Graph` for analyzer differential comparisons.
- More powerful shrinking/minimization: remove branches/edges and use source-aware structural reductions beyond isolated modules.
- Erlang source layout generation.
- Broader Elixir syntax: protocols, macros, richer alias/import/require combinations, Phoenix/Ecto-style DSL fixtures, and deeper variants of guards, try/rescue/after, receive, comprehensions, structs, and default args.
- Richer source locations for nested/generated constructs and macro-expanded code.
- Analyzer coverage-guided search adapters.
- Richer metamorphic transform invariant specifications.
- Differential testing adapters for real analyzers and version comparisons, built on `ProgramFacts.Analyzer`.
