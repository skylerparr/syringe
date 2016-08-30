defmodule AutoMocker do

  defmacro __using__([for: {:__aliases__, _, [module]}]) do
    mod_string = module |> Atom.to_string
    module = "Elixir.#{mod_string}" |> String.to_atom
    functions = exported_functions(module)
    quoted = gen_interface(module, functions)
    quote do
      use Mocked
      unquote(quoted)
    end
  end

  defp gen_interface(real_module, functions) do
    Enum.reduce(functions, [], fn({fun, arity}, acc) ->
      def_fun = fun |> Atom.to_string |> String.to_char_list
      quote do
        def unquote(def_fun) do
          mock_func(__MODULE__, unquote(fun), nil, fn ->
            unquote(real_module).unquote(fun)
          end)
        end
      end 
    end)
  end

  defp exported_functions(module) do
    module.module_info
      |> Keyword.get(:exports)
  end
end
