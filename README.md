# Syringe

Syringe is a injection framework that also opens the opportunity for 
clearer mocking and to run mocked test asynchronously.

To use the injector, it behaves similar to ```alias```, except you use the word ```inject```.

### Example

  ```elixir
  defmodule MyThing do
    def do_mine_things do
      1 + 2
    end
  end

  defmodule MyModule do
    use Injector

    inject MyThing, as: Mine

    def do_things do
      Mine.do_mine_things
    end
  end
  ```

  Now that we are injecting our module we can mock it in test.

  ```elixir
  defmodule MyModuleTest do
    use ExUnit.Case, async: true
    import Mocker # need this to use easy mocking functions

    test "Mine must be called" do
      mock(MyThing)
      MyModule.do_things
      assert was_called(MyThing, :do_mine_things, nil) == once # success
    end
  end
  ```

  You can even take control and handle how the mocked functions can fit your test data
  ```elixir
  defmodule MyModuleTest do
    use ExUnit.Case, async: true
    import Mocker

    test "Mine must be called" do
      mock(MyThing)
      assert MyModule.do_things == nil
      intercept(MyThing, :do_mine_things, nil, with: fn() -> "my mocked return" end)
      assert MyModule.do_things == "my mocked return"
      assert was_called(MyThing, :do_mine_things, nil) == twice # success
    end
  end
  ```

  You can also just call the original function if you want.

  ```elixir
  defmodule MyModuleTest do
    use ExUnit.Case, async: true
    import Mocker 

    test "Mine must be called" do
      mock(MyThing)
      assert MyModule.do_things == nil
      intercept(MyThing, :do_mine_things, nil, with: :original_function)
      assert MyModule.do_things == 3
      assert was_called(MyThing, :do_mine_things, nil) == twice # success
    end
  end
  ```

  It gets better, you can control the order in which the functions return data.

  ```elixir
  defmodule MyModuleTest do
    use ExUnit.Case, async: true
    import Mocker 

    test "Mine must be called" do
      mock(MyThing)
      assert MyModule.do_things == nil
      intercept(MyThing, :do_mine_things, nil, with: fn -> "do the things" end)
      intercept(MyThing, :do_mine_things, nil, with: fn -> "do some other things" end)
      intercept(MyThing, :do_mine_things, nil, with: :original_function)
      intercept(MyThing, :do_mine_things, nil, with: fn -> "one more thing" end)
      assert MyModule.do_things == "do the things"
      assert MyModule.do_things == "do some other things"
      assert MyModule.do_things == 3
      assert MyModule.do_things == "one more thing"
      
      # The last specified intercept with persist
      assert MyModule.do_things == "one more thing"
      assert MyModule.do_things == "one more thing"
      assert was_called(MyThing, :do_mine_things, nil) == times(6) # success
    end
  end
  ```

  Finally you can match against function arguments.
  ```elixir
  defmodule MyThing do
    def do_mine_things(arg1, arg2, arg3) do
      {arg1, arg2, arg3}
    end
  end

  defmodule MyModuleTest do
    use ExUnit.Case, async: true
    import Mocker 

    test "Mine must be called with correct arguments" do
      mock(MyThing)
      assert MyModule.do_things(:a, :b, :c) == nil
      intercept(MyThing, :do_mine_things, [:b, :c, :d], with: fn(_, _, _) -> :ok)
      intercept(MyThing, :do_mine_things, [:a, :b, :c], with: :original_function)
      
      assert MyModule.do_things(:b, :c, :d) == :ok
      assert MyModule.do_things(:a, :b, :c) == {:a, :b, :c}
      
      MyModule.do_things(:x, :y, :z)

      assert was_called(MyThing, :do_mine_things, [:b, :c, :d) == once # success
      assert was_called(MyThing, :do_mine_things, [:a, :b, :c) == once # success
      assert was_called(MyThing, :do_mine_things, [:x, :y, :z) == never # success
    end
  end

  ```

  Sometimes you want match on any arguments
  ```elixir
  defmodule SampleModule do
    def do_some_work(how_much, call_me_when_i_am_done) do
      call_me_when_i_am_done.()
    end
  end

  defmodule ModuleImTesting do
    use Injector
    inject SampleModule

    def do_work(how_much) do
      SampleModule.do_some_work(how_much, &on_complete/0)
    end

    def on_complete do
      IO.inspect "I'm done!"
    end

  end

  defmodule ModuleImTestingTest do
    use ExUnit.Case, async: true
    import Mocker

    setup do
      mock(SampleModule)
      :ok
    end

    test "should notify SampleModule to do some work" do
      intercept(SampleModule, :do_some_work, [10, any], fn(_, on_complete) -> on_complete.() end) # the arguments are passed in and you can do what you want here
      ModuleImTesting.do_work(10)
      assert was_called(SampleModule, :do_some_work, [10, any]) == once # truthy
    end
  end

  ```

  Based on the nature of how tests execute, sometimes you need to be able
  to mock modules that are running in different processes. Generally used
  when interacting with GenServers referred by name, but can be used 
  whenever things are being run in a different process than your test.

  ```elxir
  defmodule MyWork do
    def handle_work(state) do
      # I'm out of fake implementations. Does it matter
      # what this is at this point?
    end
  end

  defmodule MyServer do
    use GenServer
    use Injector

    inject MyWork

    def start_link do
      GenServer.start_link(__MODULE__, 0, name: __MODULE__)
    end

    def increment do
      GenServer.call(__MODULE__, :increment)
    end

    def handle_call(:increment, _from, state) do
      output = MyWork.handle_work(state)
      {:reply, output, state}
    end
  end

  defmodule MyServerTest do
    use ExUnit.Case, async: true
    use Mocker

    test "should outsource work to MyWork module in the GenServer process" do
      {:ok, pid} = MyServer.start_link

      # now that we're operating on a different pid we need to notify the
      # mocker to work within that pid
      mock(MyWork, pid)
      
      # now you can intercept the functions as before
      intercept(MyWork, :handle_work, [0], fn(_) -> 100 end)

      assert MyServer.increment() == 100
      assert was_called(MyWork, :handle_work, [0]) == once #truthy
    end
  end
  ```

## Installation

  1. Add `syringe` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:syringe, "~> 0.10.0"}]
    end
    ```

  2. Configure syringe for your environments
    in test/config.exs (if you want to use mocking)

    ```elixir
    config :syringe, injector_strategy: MockInjectingStrategy
    ```
    in your other configs
    ```elixir
    config :syringe, injector_strategy: AliasInjectingStrategy
    ```
  3. Turn on mocking for your tests. In your test/test_helper.exs
  
    ```elixir
    Mocker.start_link
    ```
  4. You're ready to start injecting implementations
