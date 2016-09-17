defmodule Mocked do

  defmacro __using__(_) do

    quote do
      use GenServer
      
      def start_link do
        GenServer.start_link(__MODULE__, %{call_count: %{}, interceptors: %{}})
      end

      def init(opt) do
        {:ok, opt}
      end
      
      def handle_call({:call_count, func, args}, _from, %{call_count: call_count} = state) do
        count = Map.get(call_count, {func, args}, 0)
        {:reply, count, state}
      end

      def handle_call({:increment_call_count, func, args}, _from, %{call_count: call_count} = state) do
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
        interceptors_list = Map.get(interceptors, {func, args}, [])
        {interceptor, interceptors_list} = get_next_interceptor(interceptors_list)

        interceptors = Map.put(interceptors, {func, args}, interceptors_list)
        state = Map.put(state, :interceptors, interceptors) 
 
        {:reply, interceptor, state}
      end

      defp get_next_interceptor([]), do: {nil, []}
      defp get_next_interceptor(list) when length(list) == 1, do: {list |> hd, list}
      defp get_next_interceptor([fun | tail]), do: {fun, tail}

      def call_interceptor(nil), do: nil
      def call_interceptor(nil, _), do: nil
      def call_interceptor(interceptor, nil), do: interceptor.()
      def call_interceptor(interceptor, args), do: apply(interceptor, args)

      def mock_func(module, func_atom, args, original_func) do
        GenServer.call(Mocker, {module, func_atom, args, self})
        interceptor = GenServer.call(Mocker, {:get_interceptor, module, func_atom, args, self})
        if(interceptor == :original_function) do
          original_func.() 
        else 
          call_interceptor(interceptor, args)
        end
      end

   end
  end

end


