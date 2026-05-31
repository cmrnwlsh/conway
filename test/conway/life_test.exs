defmodule Conway.LifeTest do
  use ExUnit.Case, async: true
  alias Conway.{Grid, Life}

  defp translate(grid, dx, dy), do: MapSet.new(grid, fn {x, y} -> {x + dx, y + dy} end)

  test "empty grid stays empty" do
    assert Life.step(Grid.new()) == Grid.new()
  end

  test "a lone cell and a 2-cell pair both die (underpopulation)" do
    assert Life.step(Grid.new([{0, 0}])) == Grid.new()
    assert Life.step(Grid.new([{0, 0}, {1, 0}])) == Grid.new()
  end

  test "a 2x2 block is a still life" do
    block = Grid.new([{0, 0}, {1, 0}, {0, 1}, {1, 1}])
    assert Life.step(block) == block
  end

  test "a blinker has period 2" do
    horizontal = Grid.new([{0, 0}, {1, 0}, {2, 0}])
    vertical = Grid.new([{1, -1}, {1, 0}, {1, 1}])
    assert Life.step(horizontal) == vertical
    assert Life.step(vertical) == horizontal
    assert Life.step(horizontal, 2) == horizontal
  end

  test "a glider returns to itself translated by (1,1) after 4 generations" do
    glider = Grid.new([{1, 0}, {2, 1}, {0, 2}, {1, 2}, {2, 2}])
    assert Life.step(glider, 4) == translate(glider, 1, 1)
  end
end
