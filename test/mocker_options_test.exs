defmodule MockerOptionsTest do
  use ExUnit.Case

  setup do
    MockerOptions.start_link()
    :ok
  end

  test "should store settings retrieve them" do
    MockerOptions.store_settings(self(), MyModule, [foo: :bar])
    assert MockerOptions.get_setting(self(), MyModule) == [foo: :bar]
  end

  test "should return nil if no setting is set" do
    assert MockerOptions.get_setting(self(), MyModule) == nil
  end

end
