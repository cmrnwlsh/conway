defmodule ConwayTest do
  use ExUnit.Case
  doctest Conway

  test "greets the world" do
    assert Conway.hello() == :world
  end
end
