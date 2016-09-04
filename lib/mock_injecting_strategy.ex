defmodule MockInjectingStrategy do
  def inject(definition, options) do
    module = Injector.get_module(definition)
    [as: as_option] = options
    as = Injector.get_module(as_option)
    as_atom = Injector.as_elixir_module(as)
    write_alias(module, as_atom)
  end

  def inject(definition) do
    module = Injector.get_module(definition)
    as_atom = Injector.as_elixir_module(module)
    write_alias(module, as_atom)
  end

  defp write_alias(module, as_atom) do
    injector_module = ("Injector." <> (module |> Atom.to_string))
      |> String.to_atom
      |> Injector.as_elixir_module
    quote do
      defmodule unquote(injector_module) do
        use AutoMocker, for: unquote(module)
      end
      alias unquote(injector_module), as: unquote(as_atom)
    end
  end

end

