defmodule MockBar do
  
  def start_link() do
    GenServer.start_link(__MODULE__, %{})
  end

  def mock do
    IO.inspect self
  end

  def cat do
    IO.inspect self
    #GenServer.call
    "I'm a test function"
  end

end

defmodule Mocker do
  defmacro mock(definition) do
    IO.inspect definition
  end
end
