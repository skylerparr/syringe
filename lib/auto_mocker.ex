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
      args = generate_args(arity)
      content = quote do
        def unquote({fun, [], args}) do
          mock_func(__MODULE__, unquote(fun), unquote(args), fn ->
            unquote(real_module).unquote(fun)
          end)
        end
      end 
      acc = [content | acc]
    end)
  end

  defp generate_args(0), do: nil
  defp generate_args(num_args) do
    for i <- 1..num_args, do: {"arg#{i}" |> String.to_atom, [], Elixir}
  end

  defp exported_functions(module) do
    module.module_info
      |> Keyword.get(:exports)
      |> Keyword.delete(:__info__)
      |> Keyword.delete(:module_info)
  end

end
