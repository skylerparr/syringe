defmodule Injector do
  @elixir_namespace "Elixir."

  defmacro __using__(_) do
    quote do
      import Injector, only: [inject: 2, inject: 1]
    end
  end

  defmacro inject(definition, options) do
    strategy().inject(definition, options)
  end

  defmacro inject(definition) do
    strategy().inject(definition)
  end

  defp strategy() do
    Application.get_env(:syringe, :injector_strategy, AliasInjectingStrategy)
  end

  def get_module(definition) do
    case definition do
      {:__aliases__, _, module} ->
        Enum.join(module, ".")
        |> String.to_atom()

      atom ->
        atom
    end
  end

  def as_elixir_module(module) do
    as_string =
      module
      |> Atom.to_string()

    case elixir_module?(as_string) do
      true ->
        (@elixir_namespace <> as_string)
        |> String.to_atom()

      false ->
        module
    end
  end

  def elixir_module?(module) do
    case String.first(module) do
      <<char>> when char in ?A..?Z ->
        true

      _ ->
        false
    end
  end
end
