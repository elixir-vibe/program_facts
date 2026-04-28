defmodule ProgramFacts.Generate.Architecture do
  @moduledoc false

  alias ProgramFacts.{Facts, Naming, Program}
  alias ProgramFacts.Generate.Helpers
  alias ProgramFacts.Render.Elixir, as: Render

  def generate(opts, policy) do
    seed = opts[:seed]
    [web_module, domain_module, repo_module] = architecture_modules(seed, policy)
    functions = functions(web_module, domain_module, repo_module, policy)
    violation = violation(web_module, domain_module, repo_module, policy)

    %Program{
      id: Helpers.id(seed, policy),
      seed: seed,
      files:
        files(web_module, domain_module, repo_module, policy) ++
          [Render.architecture_config_file(web_module, domain_module, repo_module, policy)],
      facts: %Facts{
        modules: [web_module, domain_module, repo_module],
        functions: functions,
        call_edges: edges(functions, policy),
        call_paths: paths(functions, policy),
        effects: effects(functions, policy),
        architecture: %{
          policy: policy,
          valid?: violation == nil,
          violations: List.wrap(violation)
        },
        features: MapSet.new([:architecture, policy])
      },
      metadata: %{policy: policy, depth: 3}
    }
  end

  defp architecture_modules(seed, :public_api_boundary_violation) do
    [
      Module.concat([Generated.ProgramFacts.External, "Seed#{seed}", Web]),
      Module.concat([Generated.ProgramFacts.PublicApi, "Seed#{seed}", Internal]),
      Module.concat([Generated.ProgramFacts.PublicApi, "Seed#{seed}", Repo])
    ]
  end

  defp architecture_modules(seed, _policy), do: Naming.modules(seed, 3)

  defp functions(web_module, domain_module, repo_module, :allowed_effect_violation),
    do: [{web_module, :entry, 1}, {domain_module, :handle, 1}, {repo_module, :write, 1}]

  defp functions(web_module, domain_module, repo_module, _policy),
    do: [{web_module, :entry, 1}, {domain_module, :handle, 1}, {repo_module, :fetch, 1}]

  defp files(web_module, domain_module, repo_module, :layered_valid),
    do: [
      Render.arch_module(web_module, :entry, domain_module, :handle),
      Render.arch_module(domain_module, :handle, repo_module, :fetch),
      Render.named_sink_module(repo_module, :fetch)
    ]

  defp files(web_module, domain_module, repo_module, :forbidden_dependency),
    do: [
      Render.arch_module(web_module, :entry, repo_module, :fetch),
      Render.named_sink_module(domain_module, :handle),
      Render.named_sink_module(repo_module, :fetch)
    ]

  defp files(web_module, domain_module, repo_module, :layer_cycle),
    do: [
      Render.arch_module(web_module, :entry, domain_module, :handle),
      Render.arch_module(domain_module, :handle, repo_module, :fetch),
      Render.arch_module(repo_module, :fetch, web_module, :entry)
    ]

  defp files(web_module, domain_module, repo_module, :public_api_boundary_violation),
    do: [
      Render.arch_module(web_module, :entry, domain_module, :handle_internal),
      Render.arch_internal_module(domain_module),
      Render.named_sink_module(repo_module, :fetch)
    ]

  defp files(web_module, domain_module, repo_module, :internal_boundary_violation),
    do: [
      Render.arch_module(web_module, :entry, domain_module, :internal),
      Render.arch_internal_module(domain_module),
      Render.named_sink_module(repo_module, :fetch)
    ]

  defp files(web_module, domain_module, repo_module, :allowed_effect_violation),
    do: [
      Render.arch_module(web_module, :entry, domain_module, :handle),
      Render.arch_module(domain_module, :handle, repo_module, :write),
      Render.repo_write_module(repo_module)
    ]

  defp edges([web, _domain, repo], :forbidden_dependency), do: [{web, repo}]
  defp edges([web, domain, repo], :layer_cycle), do: [{web, domain}, {domain, repo}, {repo, web}]

  defp edges([web, domain, _repo], policy)
       when policy in [:public_api_boundary_violation, :internal_boundary_violation],
       do: [{web, domain}]

  defp edges([web, domain, repo], _policy), do: [{web, domain}, {domain, repo}]

  defp paths(functions, policy),
    do: Enum.map(edges(functions, policy), fn {source, target} -> [source, target] end)

  defp effects([_web, _domain, repo], :allowed_effect_violation), do: [{repo, :write}]
  defp effects(_functions, _policy), do: []

  defp violation(_web, _domain, _repo, :layered_valid), do: nil

  defp violation(web, _domain, repo, :forbidden_dependency),
    do: %{type: :forbidden_dependency, from: web, to: repo}

  defp violation(web, domain, repo, :layer_cycle),
    do: %{type: :layer_cycle, cycle: [web, domain, repo, web]}

  defp violation(web, domain, _repo, :public_api_boundary_violation),
    do: %{type: :public_api_boundary, from: web, to: domain}

  defp violation(web, domain, _repo, :internal_boundary_violation),
    do: %{type: :internal_boundary, from: web, to: domain}

  defp violation(_web, domain, repo, :allowed_effect_violation),
    do: %{type: :effect_policy, from: domain, to: repo, effect: :write}
end
