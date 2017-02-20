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
    Application.fetch_env!(:syringe, :injector_strategy)
  end

  def get_module(definition) do
    {:__aliases__, _, module} = definition
    Enum.join(module, ".")
    |> String.to_atom
  end

  def as_elixir_module(module) do
    as_string = module 
      |> Atom.to_string
    @elixir_namespace <> as_string
      |> String.to_atom
  end

end

