defmodule ProgramFacts.Manifest.File do
  @moduledoc """
  JSON manifest source file entry.
  """

  alias ProgramFacts.File

  @derive JSON.Encoder
  @enforce_keys [:path, :source, :kind]
  defstruct [:path, :source, :kind]

  @type t :: %__MODULE__{path: String.t(), source: String.t(), kind: File.kind()}

  def new(%File{} = file), do: %__MODULE__{path: file.path, source: file.source, kind: file.kind}

  def from_map!(%{"path" => path, "source" => source, "kind" => kind}) do
    from_map!(%{path: path, source: source, kind: kind})
  end

  def from_map!(%{path: path, source: source, kind: kind}) do
    %__MODULE__{path: path, source: source, kind: kind_atom(kind)}
  end

  defp kind_atom(kind) when is_atom(kind), do: kind
  defp kind_atom(kind) when is_binary(kind), do: String.to_existing_atom(kind)
end
