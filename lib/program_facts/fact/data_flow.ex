defmodule ProgramFacts.Fact.DataFlow do
  @moduledoc """
  A ground-truth data-flow oracle fact.
  """

  alias ProgramFacts.Fact.DataRef

  @derive JSON.Encoder
  @enforce_keys [:from, :to]
  defstruct [:from, :to, through: [], variable_names: [], branch: nil]

  @type t :: %__MODULE__{
          from: DataRef.t(),
          to: DataRef.t(),
          through: [DataRef.t()],
          variable_names: [atom()],
          branch: atom() | nil
        }

  def new(%{} = flow) do
    %__MODULE__{
      from: DataRef.new(Map.fetch!(flow, :from)),
      to: DataRef.new(Map.fetch!(flow, :to)),
      through: Enum.map(Map.get(flow, :through, []), &DataRef.new/1),
      variable_names: Map.get(flow, :variable_names, []),
      branch: Map.get(flow, :branch)
    }
  end

  def from_map!(%{"from" => from, "to" => to} = map) do
    from_map!(%{
      from: from,
      to: to,
      through: Map.get(map, "through", []),
      variable_names: Map.get(map, "variable_names", []),
      branch: Map.get(map, "branch")
    })
  end

  def from_map!(%{from: from, to: to} = map) do
    %__MODULE__{
      from: DataRef.from_map!(from),
      to: DataRef.from_map!(to),
      through: Enum.map(Map.get(map, :through, []), &DataRef.from_map!/1),
      variable_names: Enum.map(Map.get(map, :variable_names, []), &variable_name/1),
      branch: optional_atom(Map.get(map, :branch))
    }
  end

  def to_map(%__MODULE__{} = flow) do
    %{
      from: DataRef.to_tuple(flow.from),
      to: DataRef.to_tuple(flow.to),
      through: Enum.map(flow.through, &DataRef.to_tuple/1),
      variable_names: flow.variable_names,
      branch: flow.branch
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp variable_name(name) when is_atom(name), do: name
  defp variable_name(name) when is_binary(name), do: String.to_atom(name)

  defp optional_atom(nil), do: nil
  defp optional_atom(value) when is_atom(value), do: value
  defp optional_atom(value) when is_binary(value), do: String.to_existing_atom(value)
end
