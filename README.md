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
      assert was_called(MyThing, :do_mine_things, [:x, :y, zc) == never # success
    end
  end

  ```

## Installation

  1. Add `syringe` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:syringe, "~> 0.9.0"}]
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

  3. You're ready to start injecting implementations
