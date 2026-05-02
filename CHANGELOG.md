# Changelog

## 0.2.1 - 2026-05-01

### Changed

- Updated ExSlop to `~> 0.4` and enabled the expanded Credence-inspired check set in Credo.

### Fixed

- Replaced remaining `List.last/1` and `length/1` guard patterns reported by the expanded ExSlop checks.

## 0.2.0 - 2026-05-01

### Added

- Typed JSON/export boundary with `%ProgramFacts.Manifest{}`.
- Typed manifest fact payloads under `%ProgramFacts.Fact.*{}` for function ids, call edges, effects, data-flow refs, data flows, branches, branch calls, and source locations.
- Manifest decoding with `ProgramFacts.Manifest.decode!/1` and `ProgramFacts.Manifest.from_map!/1`.
- Corpus failure metadata with `%ProgramFacts.Corpus.Failure{}` and JSON decoding helpers.
- Fact conversion contracts with `ProgramFacts.Facts.normalize/1` and `ProgramFacts.Facts.to_manifest/1`.
- Feedback search scoring modes backed by graph metrics.
- Shrinking support for options, transforms, isolated modules, and failure promotion metadata.
- Analyzer adapter, differential comparison, and metamorphic comparison APIs.
- Optional `libgraph` helpers for call/module/architecture graph validation.
- Additional generator policies for data flow, branches, effects, OTP, richer syntax, and architecture fixtures.
- GitHub Actions CI plus strict local `mix ci` checks including Credo, ExDNA, Dialyzer, and ExSlop.

### Changed

- ProgramFacts now targets `0.2.0` and treats manifests as typed structs at the JSON boundary.
- `ProgramFacts.to_map/1` returns atom-keyed Elixir data; `ProgramFacts.to_json!/1` delegates JSON key encoding to Elixir's JSON protocol.
- Corpus manifest loaders now return `%ProgramFacts.Manifest{}` instead of raw decoded JSON maps.
- Public ExUnit helpers now fail with `ExUnit.AssertionError` for better test output.
- Core `%ProgramFacts.Facts{}` remains tuple/map-compatible for generator, transform, shrinker, and analyzer assertions while manifest facts are typed.

### Fixed

- Avoided mixed atom/string-key metadata contracts in failure manifests.
- Tightened generated project path safety against traversal and absolute paths.
- Updated transform metadata/facts so branch-changing transforms no longer claim branch preservation.
- Fixed StreamData option support and zero-iteration search behavior.
