defmodule Chris do
  use Injector, Mapper

  inject RealWorker

  def operate do 
    RealWorker.collect_data
  end
end
