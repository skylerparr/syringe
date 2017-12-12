defmodule OverrideAliasInjectingStrategy do

  def inject(definition, options) do
    module = Injector.get_module(definition)
    [as: as_option] = options
    as = Injector.get_module(as_option)
    as_atom = Injector.as_elixir_module(as)
    module = module |> Injector.as_elixir_module

    module = get_override_if_present(module)

    write_alias(module, as_atom)
  end

  def inject(definition) do
    module = Injector.get_module(definition)

    as_atom = module
              |> Atom.to_string
              |> String.split(".")
              |> Enum.reverse
              |> hd
              |> String.to_atom
              |> Injector.as_elixir_module

    module = module |> Injector.as_elixir_module

    module = get_override_if_present(module)

    write_alias(module, as_atom)
  end

  defp write_alias(module, as_atom) do
    quote do
      alias unquote(module), as: unquote(as_atom)
    end
  end

  defp get_override_if_present(module) do
    overrides = Application.get_env(:syringe, :overrides) || %{}
    Map.get(overrides, module, module)
  end

end
