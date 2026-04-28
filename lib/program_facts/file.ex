defmodule ProgramFacts.File do
  @moduledoc """
  A generated source file.
  """

  @type kind :: :elixir | :erlang | :test | :config | :mix_project

  @type t :: %__MODULE__{
          path: String.t(),
          source: String.t(),
          kind: kind()
        }

  defstruct [:path, :source, :kind]
end
