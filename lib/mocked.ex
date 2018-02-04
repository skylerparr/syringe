defmodule Mocked do

  defmacro __using__(_) do

    quote do
      use GenServer
      
      def start_mock_link do
        GenServer.start(__MODULE__, %{call_count: %{}, interceptors: %{}})
      end

      def init(opt) do
        {:ok, opt}
      end
      
      def handle_call({:call_count, func, args}, _from, %{call_count: call_count, interceptors: interceptors} = state) do
        {func, args} = get_matching_args([], interceptors, func, args) |> elem(0)
        count = Map.get(call_count, {func, args}, 0)
        {:reply, count, state}
      end

      def handle_call({:increment_call_count, func, args}, _from, %{call_count: call_count, interceptors: interceptors} = state) do
        {func, args} = get_matching_args([], interceptors, func, args) |> elem(0)
        count = Map.get(call_count, {func, args}, 0)
        call_count = Map.put(call_count, {func, args}, count + 1)
        state = Map.put(state, :call_count, call_count)
        {:reply, state, state}
      end

      def handle_call({:set_interceptor, func, args, intercept_func}, _from, %{interceptors: interceptors} = state) do
        args = args || []
        interceptors_list = Map.get(interceptors, {func, args}, [])
        interceptors_list = interceptors_list ++ [intercept_func] 
        interceptors = Map.put(interceptors, {func, args}, interceptors_list)
        state = Map.put(state, :interceptors, interceptors) 
        {:reply, state, state}
      end

      def handle_call({:get_interceptor, func, args}, _from, %{interceptors: interceptors} = state) do
        interceptors_list = get_interceptors(interceptors, func, args)
        {interceptor, interceptors_list} = get_next_interceptor(interceptors_list)

        interceptors = cond do
          interceptors_list == [] -> interceptors
          true -> Map.put(interceptors, {func, args}, interceptors_list)
        end
        state = Map.put(state, :interceptors, interceptors) 

        {:reply, interceptor, state}
      end

      defp get_interceptors(interceptors, func, args) do
        found = Map.get(interceptors, {func, args}, [])
          |> get_matching_args(interceptors, func, args)
          |> elem(1)
      end

      defp get_matching_args([], map, func, args) do
        Enum.find(map, fn({{function, arguments}, interceptor}) ->
          if(function == func) do
            found = Enum.with_index(arguments)
              |> Enum.all?(fn({item, index}) ->
                original_arg = Enum.at(args, index)
                (item == original_arg || item == :any)
              end)
          else
            false
          end
        end)
        |> matched_args(func, args)
      end
      defp get_matching_args(found, _, func, args), do: {{func, args}, found}

      defp matched_args(nil, func, args), do: {{func, args}, []}
      defp matched_args(ret_val, _, _), do: ret_val

      defp get_next_interceptor([]), do: {nil, []}
      defp get_next_interceptor(list) when length(list) == 1, do: {list |> hd, list}
      defp get_next_interceptor([fun | tail]), do: {fun, tail}

      defp call_interceptor(nil), do: nil
      defp call_interceptor(nil, _), do: nil
      defp call_interceptor(interceptor, nil), do: interceptor.()
      defp call_interceptor(interceptor, args), do: apply(interceptor, args)

      defp mock_func(module, :__struct__, args, original_func) do
        original_func.()
      end
      defp mock_func(module, func_atom, args, original_func) do
        GenServer.call(Mocker, {module, func_atom, args, self()})
        interceptor = GenServer.call(Mocker, {:get_interceptor, module, func_atom, args, self()})
        if(interceptor == :original_function) do
          original_func.()
        else
          call_interceptor(interceptor, args)
        end
      end

   end
  end

end


