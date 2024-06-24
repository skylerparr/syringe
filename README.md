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
      
      # The last specified intercept will persist
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

  ```elixir
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

## New in version 1.2

By default, when you call `mock` on a module, it'll auto stub all function
calls and return `nil` by default. Sometimes you may have a module that
is used pretty extensively in your test and you don't want to go through
and intercept all the functions just to call the `:original_function`.
Well, you can tell the mock function to not auto mock. In your unit test,
when you call mock, just pass `no_auto_mock: true` and it'll default
to call your original_functions instead of the auto-mocked ones.

Here's an example:

Given this module:
```elixir
defmodule Foo do
  def first(), do: 1
  def second(), do: 2
end

defmodule Bar do
  use Injector
  inject Foo

  def call_foo() do
    a = Foo.first()
    b = Foo.second()

    {a, b}
  end
end

defmodule BarTest do
  use ExUnit.Case, async: true

  import Mocker

  test "foo should return a tuple of numbers" do
    mock(Foo)
    intercept(Foo, :first, [], with: fn() -> 100 end)
    assert Bar.call_foo() == {100, nil} # nil because we didn't intercept the :second function

    mock(Foo, no_auto_mock: true)
    intercept(Foo, :first, [], with: fn() -> 100 end)
    assert Bar.call_foo() == {100, 2} # called the original function as specified
  end
end
```  

## New in version 1.3

Added some new verification functions. Before version 1.3 you could only verify
if the function was exactly N times. Now you can verify at least, more than, at most,
less than, and between. Here are some examples:

```elixir
# the set up is the same
outcome = intercept(MockBar, :with_args, [any(), any(), any()], with: :original_function)
...
# now we can
assert outcome |> was_called() |> at_least(3) |> times()
assert outcome |> was_called() |> more_than(3) |> times()
assert outcome |> was_called() |> at_most(3) |> times()
assert outcome |> was_called() |> less_than(3) |> times()
assert outcome |> was_called() |> between(3..4) |> times()
``` 

## New in version 1.4

Added a check at test run time to verify if the intercept api arity matches 
the true arity of the function. If the intercept argument count does not match
any of the functions of the same name but doesn't match the arity count, then
an error will be raised. Here's an example:

```elixir
defmodule MockBar do
  def with_args(a, b) do
    ...
  end
end
# the set up is the same
mock(MockBar)
# Raises MockerApiError, the with_args function has an arity of 2, but the intercept
# is mocking an arity of 3. This allows a developer to change the arity of a function
# and the mocker will let them know that the intercepts need to be updated as well
outcome = intercept(MockBar, :with_args, [any(), any(), any()], with: fn(_, _, _) -> :ok end)
``` 

Also added some convenience options for the intercept function to simplify your mocking.
You can now just tell the intercept to return a value without specifying a function or
specifying an error to raise. Here's some examples:

```elixir
# the set up is the same
mock(MockBar)
# will return foo if args match
intercept(MockBar, :with_args, [any(), any()], returns: "foo")
``` 
For raising errors
```elixir
defmodule SomeError do
  defexception [:message]
end

mock(MockBar)
# will raise if matches args
intercept(MockBar, :with_args, [any(), any()], raises: SomeError)
```
or if you want to set a specific messages to the error
```elixir
defmodule SomeError do
  defexception [:message, :more_detail]
end

mock(MockBar)
# will raise if matches args and assign the message to the :message field in the error
intercept(MockBar, :with_args, [any(), any()], raises: SomeError, message: "My special message", more_detail: "rtfm")
```

## New in version 1.5

You can now mock erlang modules. When injected, you must set the new alias:

```elixir
defmodule SampleModule do
  use Injector
  inject(:gen_tcp, as: GenTcp) # now it can be mocked

  def listen()
    GenTcp.listen(5000, [:binary])
  end
end
```

## Gotcha's/Limitations

Due to the way that syringe handles the inject as an alias, if you refer
to the full module name, syringe is unable to intercept the function
calls. Here's an example:

```elixir
defmodule Oh.My.Foo do
  def bar() do

  end
end

defmodule Oh.My.Bar do
  use Injector
  inject Oh.My.Foo

  def call_foo() do
    Oh.My.Foo.bar() # <-- cannot be intercepted, you must strictly call Foo.bar()
  end
end
```

Sometimes you may need to mock or test modules that are GenServers that get started by the application. This can
be problematic since the Application will start before `Mocker.start_link()` gets called causing the process to 
exit before the tests even start. This is only an issue during testing. The recommended approach is to not start 
the workers during tests for several reasons. It makes testing the GenServers problematic in general, especially 
with regards to named GenServers. You can read more into the details on this issue (https://github.com/skylerparr/syringe/issues/6).

## Installation

1. Add `syringe` to your list of dependencies in `mix.exs`:
  
   ```elixir
   def deps do
     [{:syringe, "~> 1.0.0"}]
   end
   ```

2. Configure syringe for your environments in `test/config.exs` (if you want to use mocking):

   ```elixir
   config :syringe, injector_strategy: MockInjectingStrategy
   ```
   
    in your other configs:
   
   ```elixir
   config :syringe, injector_strategy: AliasInjectingStrategy
   ```

3. Turn on mocking for your tests. In your `test/test_helper.exs`:
  
   ```elixir
   Mocker.start_link
   ```

4. You're ready to start injecting implementations!
