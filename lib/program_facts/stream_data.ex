defmodule ProgramFacts.StreamData do
  @moduledoc """
  StreamData generators for generated programs.

  This module is intended for test environments where `stream_data` is
  available.
  """

  @doc """
  Returns a StreamData generator that emits `ProgramFacts.Program` structs.
  """
  def program, do: program([])

  @doc """
  Returns a StreamData generator that emits `ProgramFacts.Program` structs.
  """
  def program(opts) do
    stream_data!()

    opts
    |> generator_options()
    |> options_generator()
    |> StreamData.map(fn %{policy: policy, seed: seed, depth: depth, width: width} ->
      ProgramFacts.generate!(policy: policy, seed: seed, depth: depth, width: width)
    end)
  end

  defp generator_options(opts) do
    %{
      policies: Keyword.get(opts, :policies, ProgramFacts.policies()),
      seed_range: range_option(opts, :seed_range, :min_seed, :max_seed, 1..1_000),
      depth_range: range_option(opts, :depth_range, :min_depth, :max_depth, 2..8),
      width_range: range_option(opts, :width_range, :min_width, :max_width, 2..6)
    }
  end

  defp range_option(opts, range_key, min_key, max_key, default) do
    case Keyword.fetch(opts, range_key) do
      {:ok, %Range{} = range} ->
        range

      :error ->
        Keyword.get(opts, min_key, default.first)..Keyword.get(opts, max_key, default.last)
    end
  end

  defp options_generator(opts) do
    StreamData.fixed_map(%{
      policy: StreamData.member_of(opts.policies),
      seed: StreamData.integer(opts.seed_range),
      depth: StreamData.integer(opts.depth_range),
      width: StreamData.integer(opts.width_range)
    })
  end

  defp stream_data! do
    unless Code.ensure_loaded?(StreamData) do
      raise "ProgramFacts.StreamData requires the :stream_data dependency"
    end
  end
end
