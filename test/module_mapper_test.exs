defmodule ModuleMapperTest do
  use ExUnit.Case, async: true
  
  test "should collect all modules into map" do
    map = ModuleMapper.map_lib
    assert map == %{
      AutoMocker => AutoMocker,
      Injector => Injector,
      Mocked => Mocked,
      Mocker => Mocker,
      ModuleMapper => ModuleMapper,
      syringe: :syringe}
  end

  test "should collect all modules into map and add refix" do
    map = ModuleMapper.map_lib("Mock")
    assert map == %{
      AutoMocker => MockAutoMocker,
      Injector => MockInjector,
      Mocked => MockMocked,
      Mocker => MockMocker,
      ModuleMapper => MockModuleMapper,
      syringe: :Mocksyringe}
  end
end
