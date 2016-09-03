defmodule Injector do
  @elixir_namespace "Elixir."

  defmacro __using__(_) do
    quote do
      import Injector, only: [inject: 2, inject: 1]
      unquote(add_inject)
    end
  end

  defmacro inject(definition, options) do
    module = get_module(definition)
    [as: as_option] = options
    as = get_module(as_option)
    as_atom = as_elixir_module(as)
    write_alias(module, as_atom)
  end

  defmacro inject(definition) do
    module = get_module(definition)
    as_atom = as_elixir_module(module)
    write_alias(module, as_atom)
  end

  defp write_alias(module, as_atom) do
    injector_module = ("Injector." <> (module |> Atom.to_string))
      |> String.to_atom
      |> as_elixir_module
    quote do
      defmodule unquote(injector_module) do
        use AutoMocker, for: unquote(module)
      end
      alias unquote(injector_module), as: unquote(as_atom)
    end
  end

  defp get_module(definition) do
    {:__aliases__, _, [module]} = definition
    module
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

