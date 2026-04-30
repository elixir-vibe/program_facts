defmodule ProgramFacts.Generate.Effect do
  @moduledoc false

  alias ProgramFacts.Generate.Helpers
  alias ProgramFacts.Naming
  alias ProgramFacts.Render.Elixir, as: Render

  def pure(opts), do: single_effect(opts, :pure)
  def io_effect(opts), do: single_effect(opts, :io)
  def send_effect(opts), do: single_effect(opts, :send)
  def raise_effect(opts), do: single_effect(opts, :exception)
  def read_effect(opts), do: single_effect(opts, :read)
  def write_effect(opts), do: single_effect(opts, :write)

  def single_effect(opts, effect) do
    seed = opts[:seed]
    [module] = Naming.modules(seed, 1)
    mfa = {module, effect_function(effect), effect_arity(effect)}
    policy = effect_policy(effect)

    Helpers.model(
      id: Helpers.id(seed, policy),
      seed: seed,
      policy: policy,
      files: [Render.effect_module(module, effect)],
      modules: [module],
      functions: [mfa],
      effects: [{mfa, effect}],
      features: MapSet.new([:effect, effect]),
      metadata: %{policy: policy, effect: effect}
    )
  end

  def mixed_effect_boundary(opts) do
    seed = opts[:seed]
    [module] = Naming.modules(seed, 1)
    function = {module, :boundary, 2}

    Helpers.model(
      id: Helpers.id(seed, :mixed_effect_boundary),
      seed: seed,
      policy: :mixed_effect_boundary,
      files: [Render.mixed_effect_module(module)],
      modules: [module],
      functions: [function],
      effects: [{function, :io}, {function, :send}],
      features: MapSet.new([:effect, :io, :send, :mixed_effect_boundary]),
      metadata: %{policy: :mixed_effect_boundary, effects: [:io, :send]}
    )
  end

  defp effect_policy(:pure), do: :pure
  defp effect_policy(:io), do: :io_effect
  defp effect_policy(:send), do: :send_effect
  defp effect_policy(:exception), do: :raise_effect
  defp effect_policy(:read), do: :read_effect
  defp effect_policy(:write), do: :write_effect

  defp effect_function(:pure), do: :pure
  defp effect_function(:io), do: :io
  defp effect_function(:send), do: :sends
  defp effect_function(:exception), do: :raises
  defp effect_function(:read), do: :reads
  defp effect_function(:write), do: :writes

  defp effect_arity(:send), do: 2
  defp effect_arity(:write), do: 2
  defp effect_arity(_effect), do: 1
end
