# ProgramFacts Agent Guidelines

This repository is part of the Elixir Vibe organization.

ProgramFacts generates Elixir programs with known structural facts for analyzer testing.

## Development

Use the project’s Mix aliases whenever possible.

```sh
mix deps.get
mix compile
mix test
mix format
```

Preferred full check:

```sh
mix ci
```

Current full CI alias includes:

```sh
mix compile --warnings-as-errors
mix format --check-formatted
mix credo --strict
mix ex_dna
mix dialyzer
mix test
```

## Guidelines

- Generated programs must be valid Elixir.
- Keep expected facts explicit and machine-checkable.
- Avoid brittle random generation unless seeded and reproducible.
- Prefer small, focused generators over huge opaque fixtures.
- When adding a new fact category, add both generator coverage and validation tests.
- Do not publish, tag, or bump versions unless explicitly requested.
