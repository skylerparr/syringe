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

    as_atom =
      module
      |> Atom.to_string()
      |> String.split(".")
      |> Enum.reverse()
      |> hd
      |> String.to_atom()
      |> Injector.as_elixir_module()

    write_alias(module, as_atom)
  end

  defp write_alias(module, as_atom) do
    injector_module =
      ("Injector." <> (module |> Atom.to_string()))
      |> String.to_atom()
      |> Injector.as_elixir_module()

    try do
      injector_module.module_info

      quote do
        alias unquote(injector_module), as: unquote(as_atom)
      end
    rescue
      UndefinedFunctionError ->
        quote do
          try do
            unless Code.ensure_loaded?(unquote(injector_module)) do
              defmodule unquote(injector_module) do
                use AutoMocker, for: unquote(module)
              end
            end
          rescue
            CompileError -> :already_defined
          end

          alias unquote(injector_module), as: unquote(as_atom)
        end
    end
  end
end
