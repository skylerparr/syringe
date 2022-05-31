defmodule Mocker do
  use GenServer

  def start_link do
    MockPidMapServer.start_link()
    MockerOptions.start_link()
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(init_arg) do
    {:ok, init_arg}
  end

  def mock(module), do: mock(module, self(), no_auto_mock: false)

  def mock(module, no_auto_mock: true) do
    mock(module, self(), no_auto_mock: true)
  end

  def mock(module, pid, opts \\ nil) do
    MockPidMapServer.map(self(), pid)
    map_pid = MockPidMapServer.get(self())
    module = get_injector_module(module)
    MockerOptions.store_settings(self(), module, opts)
    {:ok, module_pid} = apply(module, :start_mock_link, [])
    GenServer.call(__MODULE__, {:map_to_pid, map_pid, module_pid, module})
  end

  def was_called({module, func, args}), do: was_called(module, func, args)

  def was_called(module, func, args \\ []) do
    map_pid = MockPidMapServer.get(self())
    module = get_injector_module(module)
    module_pid = GenServer.call(__MODULE__, {:get_module_pid, map_pid, module})
    call_count = GenServer.call(module_pid, {:call_count, func, args})
    times(call_count)
  end

  def at_least(actual_count, expected_count) do
    actual_count = get_count(actual_count)
    {:at_least, actual_count >= expected_count}
  end

  def more_than(actual_count, expected_count) do
    actual_count = get_count(actual_count)
    {:more_than, actual_count > expected_count}
  end

  def at_most(actual_count, expect_count) do
    actual_count = get_count(actual_count)
    {:at_most, actual_count <= expect_count}
  end

  def less_than(actual_count, expect_count) do
    actual_count = get_count(actual_count)
    {:less_than, actual_count < expect_count}
  end

  def between(actual_count, range) do
    actual_count = get_count(actual_count)
    {:between, Enum.member?(range, actual_count)}
  end

  defp get_count(count_atom) do
    case count_atom do
      :never -> 0
      :once -> 1
      :twice -> 2
      _ -> count_atom |> Atom.to_string() |> String.split(" ") |> hd |> String.to_integer()
    end
  end

  def intercept(module, func, args, returns: value) do
    value = :erlang.term_to_binary(value)
    {:ok, ast_value} = Macro.to_string(value) |> Code.string_to_quoted()
    anon_args = Macro.generate_arguments(length(args), __MODULE__)
    fn_ast =
      quote do
        fn unquote_splicing(anon_args) ->
          unquote(ast_value) |> :erlang.binary_to_term()
        end
      end
    {handler_func, _} = Code.eval_quoted(fn_ast)
    intercept(module, func, args, with: handler_func)
  end

  def intercept(module, func, args, raises: error) do
    {:ok, ast_value} = Code.string_to_quoted("raise #{error}")
    handler_func = create_handler_function(args, ast_value)
    intercept(module, func, args, with: handler_func)
  end

  def intercept(module, func, args, with: intercept_func) do
    args = args || []
    orig_module = module
    map_pid = MockPidMapServer.get(self())

    unless function_exists?(module, func, args) do
      raise MockerApiError,
        message:
          "Attempting to mock #{module}.#{func} with arg count: #{length(args)}. Not function matching that criteria found"
    end

    module = get_injector_module(module)
    module_pid = GenServer.call(__MODULE__, {:get_module_pid, map_pid, module})
    GenServer.call(module_pid, {:set_interceptor, func, args, intercept_func})
    {orig_module, func, args}
  end

  def intercept(module, func, args, messages) do
    error = Keyword.fetch!(messages, :raises)
    messages = Keyword.delete(messages, :raises)
    messages_list = Enum.into(messages, [], fn({key, value}) ->
      "#{Atom.to_string(key)}: \"#{value}\""
    end)
    messages_string = messages_list |> Enum.join(", ")
    {:ok, ast_value} = Code.string_to_quoted("raise #{error}, #{messages_string}")
    handler_func = create_handler_function(args, ast_value)
    intercept(module, func, args, with: handler_func)
  end

  defp create_handler_function(args, ast_value) do
    anon_args = Macro.generate_arguments(length(args), __MODULE__)
    fn_ast =
      quote do
        fn unquote_splicing(anon_args) ->
          unquote(ast_value)
        end
      end
    {handler_func, _} = Code.eval_quoted(fn_ast)
    handler_func
  end

  defp function_exists?(module, func, args) do
    arg_count = length(args)

    module
    |> exported_functions()
    |> Enum.find(fn {fun, arity} ->
      fun == func && arity == arg_count
    end)
    |> case do
      nil -> false
      _ -> true
    end
  end

  defp get_injector_module(module) do
    module =
      module
      |> Atom.to_string()
      |> String.split(".")
      |> tl
      |> Enum.join(".")

    ("Injector." <> module)
    |> String.to_atom()
    |> Injector.as_elixir_module()
  end

  def handle_call({:get_module_pid, test_pid, module}, _from, state) do
    module_pid = get_module_pid(state, module, test_pid)
    {:reply, module_pid, state}
  end

  def handle_call({:map_to_pid, test_pid, module_pid, module}, _from, state) do
    module_map =
      Map.get(state, test_pid, %{})
      |> Map.put(module, module_pid)

    state = Map.put(state, test_pid, module_map)
    {:reply, state, state}
  end

  def handle_call({:get_interceptor, module, func, args, test_pid}, from, state) do
    module_pid = get_module_pid(state, module, test_pid)

    interceptor =
      cond do
        is_atom(test_pid) -> :original_function
        module_pid == nil -> find_ancestor_interceptor(module, func, args, from, state, test_pid)
        module_pid == nil && is_pid(test_pid) -> :original_function
        true -> GenServer.call(module_pid, {:get_interceptor, func, args}, 60000)
      end

    {:reply, interceptor, state}
  end

  def handle_call({module, func, args, test_pid}, _from, state) do
    module_pid = get_module_pid(state, module, test_pid)

    if(module_pid != nil) do
      GenServer.call(module_pid, {:increment_call_count, func, args})
    end

    {:reply, state, state}
  end

  defp find_ancestor_interceptor(module, func, args, from, state, test_pid) do
    pid_info = Process.info(test_pid) || [dictionary: []]

    case pid_info |> Keyword.get(:dictionary, "$ancestors": []) |> Keyword.get(:"$ancestors") do
      nil ->
        :original_function

      ancestor_pids ->
        ancestor_pid = List.last(ancestor_pids)

        {:reply, interceptor, _state} =
          handle_call({:get_interceptor, module, func, args, ancestor_pid}, from, state)

        interceptor || :original_function
    end
  end

  defp get_module_pid(state, module, test_pid) do
    module_pid =
      Map.get(state, test_pid, %{})
      |> Map.get(module)

    test_pid =
      case(test_pid |> is_atom()) do
        true -> Process.whereis(test_pid)
        false -> test_pid
      end

    if(test_pid) do
      case module_pid do
        nil ->
          pid_info = Process.info(test_pid) || [dictionary: []]

          case pid_info
               |> Keyword.get(:dictionary, "$ancestors": [])
               |> Keyword.get(:"$ancestors") do
            nil ->
              check_linked_pids(state, module, test_pid)

            ancestor_pids ->
              ancestor_pid = List.last(ancestor_pids)

              if(ancestor_pid == test_pid) do
                ancestor_pid
              else
                case ancestor_pid do
                  nil -> nil
                  ancestor_pid -> get_module_pid(state, module, ancestor_pid)
                end
              end
          end

        module_pid ->
          module_pid
      end
    else
      nil
    end
  end

  defp check_linked_pids(state, module, test_pid) do
    case (Process.info(test_pid)[:links] || []) |> List.first() do
      nil ->
        nil

      pid ->
        pid_info = Process.info(pid) || [dictionary: []]

        case pid_info
             |> Keyword.get(:dictionary, "$ancestors": [])
             |> Keyword.get(:"$ancestors") do
          nil ->
            nil

          ancestor_pids ->
            ancestor_pid = List.last(ancestor_pids)

            if(ancestor_pid == test_pid) do
              ancestor_pid
            else
              case ancestor_pid do
                nil -> nil
                ancestor_pid -> get_module_pid(state, module, ancestor_pid)
              end
            end
        end
    end

    nil
  end

  defp exported_functions(module) do
    module.module_info
    |> Keyword.get(:exports)
    |> Keyword.delete(:__info__)
    |> Keyword.delete(:module_info)
  end

  def never, do: :never
  def once, do: :once
  def twice, do: :twice
  def times(0), do: never()
  def times(1), do: once()
  def times(2), do: twice()
  def times({:at_least, status}), do: status
  def times({:more_than, status}), do: status
  def times({:at_most, status}), do: status
  def times({:less_than, status}), do: status
  def times({:between, status}), do: status

  def times(num) do
    "#{num} times" |> String.to_atom()
  end

  def any, do: :any
end
