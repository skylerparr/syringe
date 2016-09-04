defmodule Injector do
  @elixir_namespace "Elixir."

  defmacro __using__(_) do
    quote do
      import Injector, only: [inject: 2, inject: 1]
      unquote(add_inject)
    end
  end

  defmacro inject(definition, options) do
    strategy = Application.fetch_env!(:syringe, :injector_strategy)
    strategy.inject(definition, options)
  end

  defmacro inject(definition) do
    strategy = Application.fetch_env!(:syringe, :injector_strategy)
    strategy.inject(definition)
  end

  def get_module(definition) do
    {:__aliases__, _, module} = definition
    Enum.join(module, ".") |> String.to_atom
  end

  def as_elixir_module(module) do
    as_string = module 
      |> Atom.to_string
    @elixir_namespace <> as_string
      |> String.to_atom
  end

  defp add_inject do
    quote location: :keep do
      defp inject do
      end
    end
  end
end

