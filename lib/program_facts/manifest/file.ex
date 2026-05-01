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
end
