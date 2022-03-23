defmodule AutoMockerTest do
  use ExUnit.Case, async: true

  test "should auto mock entire module" do
    assert MockWorker.collect_data() == {:ok, %{id: 1}}
    assert MockWorker.collect_data(1) == 1
    assert MockWorker.collect_more_data(1, 2, 3) == {1, 2, 3}
  end
end
