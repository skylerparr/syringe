defmodule Injector do
  @elixir_namespace "Elixir."

  defmacro __using__(options) do
    mapper = get_module(options)
    m = mapper |> Atom.to_string
    mapper = "#{@elixir_namespace}#{m}" |> String.to_atom
    map = apply(mapper, :get_mapping, [])
    Agent.start_link(fn -> map end, name: __MODULE__)

    quote do
      import Injector, only: [inject: 2, inject: 1]
      unquote(add_inject)
    end
  end

  defmacro inject(definition, options) do
    module = get_module(definition)
    [as: as_option] = options
    as = get_module(as_option)
    as_atom = module_as(as)
    write_alias(module, as_atom)
  end

  defmacro inject(definition) do
    module = get_module(definition)
    as_atom = module_as(module)
    write_alias(module, as_atom)
  end

  defp write_alias(module, as_atom) do
    module = Map.get(mapping, module)
    quote do
      alias unquote(module), as: unquote(as_atom)
    end
  end

  defp get_module(definition) do
    {:__aliases__, _, [module]} = definition
    module
  end

  defp module_as(module) do
    as_string = module 
      |> Atom.to_string
    "#{@elixir_namespace}#{as_string}"
      |> String.to_atom
  end

  def mapping do
    Agent.get(__MODULE__, fn(map) -> map end)
  end

  defp add_inject do
    quote location: :keep do
      defp inject do
      end
    end
  end
end

