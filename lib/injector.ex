defmodule Injector do

  defmacro __using__(options) do
    {:__aliases__, _, [mapper]} = options
    m = mapper |> Atom.to_string
    mapper = "Elixir.#{m}" |> String.to_atom
    map = apply(mapper, :get_mapping, [])
    Agent.start_link(fn -> map end, name: __MODULE__)

    quote do
      import Injector, only: [inject: 2, inject: 1]
      unquote(add_inject)
    end
  end

  defmacro inject(definition, options) do
    {:__aliases__, _, [module]} = definition
    [as: {:__aliases__, _, [as]}] = options
    as_string = as 
      |> Atom.to_string
    as_atom = "Elixir.#{as_string}"
      |> String.to_atom
  
    quote do
      alias unquote(Map.get(mapping, module)), as: unquote(as_atom)
    end
  end

  defmacro inject(definition) do
    {:__aliases__, _, [module]} = definition

    as_string = module 
      |> Atom.to_string
    as_atom = "Elixir.#{as_string}"
      |> String.to_atom
  
    module = Map.get(mapping, module)
    quote do
      alias unquote(module), as: unquote(as_atom)
    end
 
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

