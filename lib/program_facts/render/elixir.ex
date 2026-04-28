defmodule ProgramFacts.Render.Elixir do
  @moduledoc false

  alias ProgramFacts.{File, Naming}

  def chain_module(module, nil) do
    function = Naming.function_name(module)

    source = """
    defmodule #{inspect(module)} do
      def #{function}(value) do
        value
      end
    end
    """

    file(module, source)
  end

  def chain_module(module, next_module) do
    function = Naming.function_name(module)
    next_function = Naming.function_name(next_module)

    source = """
    defmodule #{inspect(module)} do
      def #{function}(value) do
        #{inspect(next_module)}.#{next_function}(value)
      end
    end
    """

    file(module, source)
  end

  def branch_entry_module(module, branch_modules) do
    branch_calls =
      Enum.map_join(branch_modules, ",\n      ", fn branch_module ->
        "#{inspect(branch_module)}.#{Naming.function_name(branch_module)}(value)"
      end)

    source = """
    defmodule #{inspect(module)} do
      def entry(value) do
        {
          #{branch_calls}
        }
      end
    end
    """

    file(module, source)
  end

  def assignment_chain_module(module) do
    source = """
    defmodule #{inspect(module)} do
      def entry(input) do
        a = input
        b = a
        c = b
        c
      end
    end
    """

    file(module, source)
  end

  def return_data_flow_module(module) do
    source = """
    defmodule #{inspect(module)} do
      def entry(input) do
        x = input
        x
      end
    end
    """

    file(module, source)
  end

  def entry_data_flow_module(module, helper_module, sink_module) do
    source = """
    defmodule #{inspect(module)} do
      def entry(input) do
        x = input
        y = #{inspect(helper_module)}.normalize(x)
        #{inspect(sink_module)}.sink(y)
      end
    end
    """

    file(module, source)
  end

  def pipeline_entry_module(module, helper_module, sink_module) do
    source = """
    defmodule #{inspect(module)} do
      def entry(input) do
        x = input

        y =
          x
          |> #{inspect(helper_module)}.normalize()

        #{inspect(sink_module)}.sink(y)
      end
    end
    """

    file(module, source)
  end

  def branch_data_flow_module(module, sink_module) do
    source = """
    defmodule #{inspect(module)} do
      def entry(input) do
        selected =
          if input == :ok do
            input
          else
            {:error, input}
          end

        #{inspect(sink_module)}.sink(selected)
      end
    end
    """

    file(module, source)
  end

  def helper_module(module) do
    source = """
    defmodule #{inspect(module)} do
      def normalize(value) do
        value
      end
    end
    """

    file(module, source)
  end

  def sink_module(module) do
    source = """
    defmodule #{inspect(module)} do
      def sink(value) do
        value
      end
    end
    """

    file(module, source)
  end

  def named_sink_module(module, function) do
    source = """
    defmodule #{inspect(module)} do
      def #{function}(value) do
        value
      end
    end
    """

    file(module, source)
  end

  def if_else_module(module, ok_module, error_module) do
    source = """
    defmodule #{inspect(module)} do
      def entry(input) do
        if input == :ok do
          #{inspect(ok_module)}.ok(input)
        else
          #{inspect(error_module)}.error(input)
        end
      end
    end
    """

    file(module, source)
  end

  def case_module(module, ok_module, error_module) do
    source = """
    defmodule #{inspect(module)} do
      def entry(input) do
        case input do
          {:ok, value} ->
            #{inspect(ok_module)}.ok(value)

          {:error, reason} ->
            #{inspect(error_module)}.error(reason)
        end
      end
    end
    """

    file(module, source)
  end

  def cond_module(module, ok_module, error_module) do
    source = """
    defmodule #{inspect(module)} do
      def entry(input) do
        cond do
          input == :ok ->
            #{inspect(ok_module)}.ok(input)

          true ->
            #{inspect(error_module)}.error(input)
        end
      end
    end
    """

    file(module, source)
  end

  def with_module(module, ok_module, error_module) do
    source = """
    defmodule #{inspect(module)} do
      def entry(input) do
        with {:ok, value} <- input do
          #{inspect(ok_module)}.ok(value)
        else
          {:error, reason} ->
            #{inspect(error_module)}.error(reason)
        end
      end
    end
    """

    file(module, source)
  end

  def anonymous_fn_branch_module(module, ok_module, error_module) do
    source = """
    defmodule #{inspect(module)} do
      def entry(input) do
        dispatch = fn
          {:ok, value} ->
            #{inspect(ok_module)}.ok(value)

          {:error, reason} ->
            #{inspect(error_module)}.error(reason)
        end

        dispatch.(input)
      end
    end
    """

    file(module, source)
  end

  def multi_clause_module(module, ok_module, error_module) do
    source = """
    defmodule #{inspect(module)} do
      def entry({:ok, value}) do
        #{inspect(ok_module)}.ok(value)
      end

      def entry({:error, reason}) do
        #{inspect(error_module)}.error(reason)
      end
    end
    """

    file(module, source)
  end

  def nested_branch_module(module, ok_module, retry_module, error_module) do
    source = """
    defmodule #{inspect(module)} do
      def entry(input) do
        case input do
          {:ok, value} ->
            #{inspect(ok_module)}.ok(value)

          {:error, reason} ->
            if reason == :retry do
              #{inspect(retry_module)}.retry(reason)
            else
              #{inspect(error_module)}.error(reason)
            end
        end
      end
    end
    """

    file(module, source)
  end

  def effect_module(module, :pure) do
    source = """
    defmodule #{inspect(module)} do
      def pure(value) do
        value
      end
    end
    """

    file(module, source)
  end

  def effect_module(module, :io) do
    source = """
    defmodule #{inspect(module)} do
      def io(value) do
        IO.inspect(value)
      end
    end
    """

    file(module, source)
  end

  def effect_module(module, :send) do
    source = """
    defmodule #{inspect(module)} do
      def sends(pid, message) do
        send(pid, message)
      end
    end
    """

    file(module, source)
  end

  def effect_module(module, :exception) do
    source = """
    defmodule #{inspect(module)} do
      def raises(reason) do
        raise RuntimeError, message: inspect(reason)
      end
    end
    """

    file(module, source)
  end

  def effect_module(module, :read) do
    source = """
    defmodule #{inspect(module)} do
      def reads(key) do
        Process.get(key)
      end
    end
    """

    file(module, source)
  end

  def effect_module(module, :write) do
    source = """
    defmodule #{inspect(module)} do
      def writes(key, value) do
        Process.put(key, value)
      end
    end
    """

    file(module, source)
  end

  def mixed_effect_module(module) do
    source = """
    defmodule #{inspect(module)} do
      def boundary(pid, message) do
        IO.inspect(message)
        send(pid, message)
      end
    end
    """

    file(module, source)
  end

  def arch_module(module, function, target_module, target_function) do
    source = """
    defmodule #{inspect(module)} do
      def #{function}(value) do
        #{inspect(target_module)}.#{target_function}(value)
      end
    end
    """

    file(module, source)
  end

  def arch_internal_module(module) do
    source = """
    defmodule #{inspect(module)} do
      def handle_internal(value) do
        value
      end

      def internal(value) do
        value
      end
    end
    """

    file(module, source)
  end

  def repo_write_module(module) do
    source = """
    defmodule #{inspect(module)} do
      def write(value) do
        Process.put(:program_facts_value, value)
      end
    end
    """

    file(module, source)
  end

  def architecture_config_file(web_module, domain_module, repo_module, policy) do
    source = """
    [
      layers: [
        web: [#{inspect(module_pattern(web_module))}],
        domain: [#{inspect(module_pattern(domain_module))}],
        repo: [#{inspect(module_pattern(repo_module))}]
      ],
      forbidden_deps: [
        {:web, :repo}
      ],
      public_api: #{inspect(public_api_patterns(domain_module, policy))},
      internal: #{inspect(internal_patterns(domain_module, policy))},
      internal_callers: #{inspect(internal_callers(domain_module, policy))},
      allowed_effects: [
        {#{inspect(module_pattern(repo_module))}, [:pure, :read]}
      ]
    ]
    """

    %File{path: ".reach.exs", source: source, kind: :config}
  end

  defp public_api_patterns(domain_module, :public_api_boundary_violation) do
    [domain_module |> module_pattern() |> String.split(".") |> Enum.drop(-1) |> Enum.join(".")]
  end

  defp public_api_patterns(_domain_module, _policy), do: []

  defp internal_patterns(domain_module, :internal_boundary_violation),
    do: [module_pattern(domain_module)]

  defp internal_patterns(_domain_module, _policy), do: []

  defp internal_callers(domain_module, :internal_boundary_violation) do
    [{module_pattern(domain_module), [module_pattern(domain_module)]}]
  end

  defp internal_callers(_domain_module, _policy), do: []

  defp module_pattern(module) do
    module
    |> Atom.to_string()
    |> String.replace_leading("Elixir.", "")
  end

  def file(module, source),
    do: %File{path: Naming.module_path(module), source: source, kind: :elixir}
end
