defmodule AutoMockerTest do
  use ExUnit.Case, async: true
  import Mocker

  setup do
    Mocker.start_link
    :ok
  end

  test "should auto mock entire module" do
    mock(MockWorker)
    intercept(MockWorker, :collect_data, nil, with: fn -> "fully mocked" end)
    assert MockWorker.collect_data == "fully mocked"
  end
end
