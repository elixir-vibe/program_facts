defmodule ProgramFacts.Corpus.Failure do
  @moduledoc """
  Failure metadata saved alongside a promoted corpus entry.
  """

  alias ProgramFacts.Program

  @derive {JSON.Encoder,
           only: [
             :program_id,
             :program_facts_manifest,
             :analyzer,
             :command,
             :mismatch,
             :shrink,
             :metadata
           ]}

  @type t :: %__MODULE__{
          program_id: String.t(),
          program_facts_manifest: String.t(),
          analyzer: atom() | String.t() | nil,
          command: [String.t()] | String.t() | nil,
          mismatch: term(),
          shrink: map() | nil,
          metadata: map()
        }

  @enforce_keys [:program_id]
  defstruct program_id: nil,
            program_facts_manifest: "program_facts.json",
            analyzer: nil,
            command: nil,
            mismatch: nil,
            shrink: nil,
            metadata: %{}

  @doc """
  Builds failure metadata for a generated program.
  """
  def new(%Program{} = program, attrs \\ []) do
    attrs = attrs_map!(attrs)

    %__MODULE__{
      program_id: program.id,
      analyzer: Map.get(attrs, :analyzer),
      command: Map.get(attrs, :command),
      mismatch: Map.get(attrs, :mismatch),
      shrink: Map.get(attrs, :shrink),
      metadata: Map.get(attrs, :metadata, %{})
    }
  end

  @doc """
  Builds failure metadata from a shrink result.
  """
  def from_shrink_result(%{program: %Program{} = program} = shrink_result, attrs \\ []) do
    shrink = %{
      options: Map.new(Map.get(shrink_result, :options, [])),
      steps: Map.get(shrink_result, :steps, [])
    }

    program
    |> new(attrs)
    |> Map.put(:shrink, shrink)
  end

  defp attrs_map!(%__MODULE__{} = failure), do: Map.from_struct(failure)

  defp attrs_map!(attrs) do
    attrs = Map.new(attrs)

    invalid_keys =
      attrs
      |> Map.keys()
      |> Enum.reject(&is_atom/1)

    if invalid_keys != [] do
      raise ArgumentError, "failure metadata keys must be atoms: #{inspect(invalid_keys)}"
    end

    attrs
  end
end
