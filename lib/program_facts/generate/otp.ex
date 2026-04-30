defmodule ProgramFacts.Generate.Otp do
  @moduledoc false

  alias ProgramFacts.Generate.Helpers
  alias ProgramFacts.Naming
  alias ProgramFacts.Render.Elixir, as: Render

  def gen_server_callbacks(opts) do
    seed = opts[:seed]
    [module] = Naming.modules(seed, 1)

    functions = [
      {module, :start_link, 1},
      {module, :init, 1},
      {module, :handle_call, 3},
      {module, :handle_info, 2}
    ]

    Helpers.model(
      id: Helpers.id(seed, :gen_server_callbacks),
      seed: seed,
      policy: :gen_server_callbacks,
      files: [Render.gen_server_module(module)],
      modules: [module],
      functions: functions,
      call_edges: [{{module, :start_link, 1}, {GenServer, :start_link, 3}}],
      effects: [{{module, :handle_info, 2}, :send}],
      branches: [
        %{
          function: {module, :handle_call, 3},
          kind: :callback,
          clauses: 1,
          state_action: :read_write
        },
        %{
          function: {module, :handle_info, 2},
          kind: :callback,
          clauses: 1,
          state_action: :read_write
        }
      ],
      features: MapSet.new([:otp, :gen_server, :callback, :send]),
      metadata: %{policy: :gen_server_callbacks, depth: 1}
    )
  end
end
