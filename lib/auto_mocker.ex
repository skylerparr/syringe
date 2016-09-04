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

  defmacro __using__([for: module]) do
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
    Enum.map(functions, fn({fun, arity}) ->
      args = generate_args(arity)
      var_args = generate_var_args(arity) 
      real_function = quote do unquote(real_module).unquote(fun)() end
      real_function = real_function |> put_elem(2, var_args)
      quote do
        def unquote({fun, [], args}) do
          mock_func(__MODULE__, unquote(fun), unquote(var_args), fn ->
            unquote(real_function)
          end)
        end
      end 
    end)
  end

  defp generate_var_args(0), do: []
  defp generate_var_args(num_args) do
    for i <- 1..num_args, do: {:var!, [], [{"arg#{i}" |> String.to_atom, [], nil}]}
  end

  defp generate_args(0), do: nil
  defp generate_args(num_args) do
    for i <- 1..num_args, do: {"arg#{i}" |> String.to_atom, [], nil}
  end

  defp exported_functions(module) do
    module.module_info
      |> Keyword.get(:exports)
      |> Keyword.delete(:__info__)
      |> Keyword.delete(:module_info)
  end

end
