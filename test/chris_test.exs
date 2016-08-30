defmodule ChrisTest do
  use ExUnit.Case, async: true
  import Mocker

  setup do 
    Mocker.start_link
    :ok
  end

  test "should operate on data" do
    mock(MockWorker)
    assert Chris.operate == nil
  end

  test "should get real data" do
    mock(MockWorker)
    intercept(MockWorker, :collect_data, nil, with: :original_function)
    assert Chris.operate == {:ok, %{id: 1}}
  end

  test "should return fake data" do
    mock(MockWorker)
    intercept(MockWorker, :collect_data, nil, with: fn() -> {:error, :nofile} end)
    assert Chris.operate == {:error, :nofile}
  end
end
