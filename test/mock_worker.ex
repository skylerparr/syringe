defmodule MockWorker do
  use AutoMocker, for: RealWorker

  #  def collect_data do
  #  mock_func(__MODULE__, :collect_data, nil, fn() ->
    #    RealWorker.collect_data
    #end)
    #end 
end
