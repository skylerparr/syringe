defmodule RealWorker do
  def collect_data do
    {:ok, %{id: 1}}
  end

  def collect_data(arg) do
    arg
  end

  def foo do
    :ok
  end

  def collect_more_data(a, b, c) do
    {a, b, c}
  end
end
