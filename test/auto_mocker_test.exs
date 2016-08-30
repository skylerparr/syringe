defmodule AutoMockerTest do
  use ExUnit.Case, async: true
  import Mocker

  test "should auto mock entire module" do
    mock(MockWorker)
    intercept(MockWorker, :collect_data, nil, with: fn -> "fully mocked" end)
    intercept(MockWorker, :collect_more_data, [1, 2, 3], with: fn(a,b,c) -> {a,b,c} end)
    assert MockWorker.collect_data == "fully mocked"
    assert MockWorker.collect_more_data(1,2,3) == {1,2,3}
  end

  test "should allow overloaded functions" do
    mock(MockWorker)
    intercept(MockWorker, :collect_data, nil, with: fn -> "mocked" end)
    intercept(MockWorker, :collect_data, [1], with: fn(arg) -> arg end)
    
    assert MockWorker.collect_data == "mocked"
    assert MockWorker.collect_data(1) == 1
  end
end
