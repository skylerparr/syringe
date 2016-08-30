defmodule Mapper do
  def get_mapping do
    get_map(Mix.env)
  end

  defp get_map(:test) do
    %{RealWorker: MockWorker}
  end

  defp get_map(_) do
    %{RealWorker: RealWorker}
  end
end
