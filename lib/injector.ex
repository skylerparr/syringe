defmodule Injector do
  @elixir_namespace "Elixir."

  defmacro __using__(_) do
    quote do
      @on_definition Injector
      @before_compile Injector
      import Injector, only: [inject: 2, inject: 1]
    end
  end

  defmacro inject(definition, options) do
    strategy().inject(definition, options)
  end

  defmacro inject(definition) do
    strategy().inject(definition)
  end

  defp strategy() do
    Application.get_env(:syringe, :injector_strategy, AliasInjectingStrategy)
  end

  def get_module({:__aliases__, _, module}) do
    Enum.join(module, ".")
    |> String.to_atom
  end

  def __on_definition__(%{module: module}, :def, fun, args, _guards, _body) do
    pid = case LocalModuleDefinition.get_pid(module) do
      nil -> LocalModuleDefinition.start_link(module)
      p -> p
    end

#    IO.inspect(args, label: "args")
    LocalModuleDefinition.save_function(pid, {fun, args |> length})
  end

  def __on_definition__(env, _, fun, args, guards, body) do
  end

  def __before_compile__(%{module: module}) do
    pid = case LocalModuleDefinition.get_pid(module) do
      nil -> LocalModuleDefinition.start_link(module)
      p -> p
    end
    functions = LocalModuleDefinition.get_functions(pid)

    code = Mocked.mock_module_code()
    Module.eval_quoted(module, code)

    code = AutoMocker.gen_interface(module, functions)
    IO.inspect(code, label: "code")
    Module.eval_quoted(module, code)
  end

  def as_elixir_module(module) do
    as_string = module 
      |> Atom.to_string
    @elixir_namespace <> as_string
      |> String.to_atom
  end

end

defmodule LocalModuleDefinition do
  use GenServer

  def start_link(module_atom) do
    {:ok, pid} = GenServer.start_link(__MODULE__, [], name: module_atom)
    pid
  end

  def init(args) do
    {:ok, args}
  end

  def get_pid(module_atom) do
    Process.whereis(module_atom)
  end

  def save_function(pid, fun) do
    GenServer.call(pid, {:save, fun})
  end

  def get_functions(pid) do
    GenServer.call(pid, :get)
  end

  def handle_call({:save, fun}, _from, state) do
    state = [fun | state]
    {:reply, fun, state}
  end

  def handle_call(:get, _from, state) do
    {:reply, state, state}
  end
end