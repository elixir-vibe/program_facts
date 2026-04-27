defmodule ProgramFacts.StreamData do
  @moduledoc """
  StreamData generators for generated programs.

  This module is intended for test environments where `stream_data` is
  available.
  """

  @doc """
  Returns a StreamData generator that emits `ProgramFacts.Program` structs.
  """
  def program(opts \\ []) do
    stream_data!()

    policies = Keyword.get(opts, :policies, ProgramFacts.policies())
    min_seed = Keyword.get(opts, :min_seed, 1)
    max_seed = Keyword.get(opts, :max_seed, 1_000_000)
    min_depth = Keyword.get(opts, :min_depth, 2)
    max_depth = Keyword.get(opts, :max_depth, 8)
    min_width = Keyword.get(opts, :min_width, 2)
    max_width = Keyword.get(opts, :max_width, 6)

    bind(member_of(policies), fn policy ->
      bind(integer(min_seed..max_seed), fn seed ->
        bind(integer(min_depth..max_depth), fn depth ->
          map(integer(min_width..max_width), fn width ->
            ProgramFacts.generate!(policy: policy, seed: seed, depth: depth, width: width)
          end)
        end)
      end)
    end)
  end

  defp stream_data! do
    unless Code.ensure_loaded?(StreamData) do
      raise "ProgramFacts.StreamData requires the :stream_data dependency"
    end
  end

  defp bind(generator, function), do: apply(StreamData, :bind, [generator, function])
  defp integer(range), do: apply(StreamData, :integer, [range])
  defp map(generator, function), do: apply(StreamData, :map, [generator, function])
  defp member_of(values), do: apply(StreamData, :member_of, [values])
end
