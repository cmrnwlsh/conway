defmodule Conway.GridTest do
  use ExUnit.Case, async: true
  alias Conway.Grid

  test "new/0 is empty, new/1 seeds cells" do
    assert Grid.population(Grid.new()) == 0
    assert Grid.population(Grid.new([{0, 0}, {1, 1}])) == 2
  end

  test "put/delete/toggle/alive?" do
    g = Grid.new() |> Grid.put({3, 4})
    assert Grid.alive?(g, {3, 4})
    refute Grid.alive?(g, {0, 0})
    g = Grid.delete(g, {3, 4})
    refute Grid.alive?(g, {3, 4})
    g = g |> Grid.toggle({5, 5}) |> Grid.toggle({6, 6}) |> Grid.toggle({5, 5})
    refute Grid.alive?(g, {5, 5})
    assert Grid.alive?(g, {6, 6})
  end

  test "stamp places translated cells, erase removes them" do
    g = Grid.stamp(Grid.new(), [{0, 0}, {1, 0}], {10, 20})
    assert Grid.alive?(g, {10, 20})
    assert Grid.alive?(g, {11, 20})
    g = Grid.erase(g, [{0, 0}], {10, 20})
    refute Grid.alive?(g, {10, 20})
    assert Grid.alive?(g, {11, 20})
  end

  test "cells_in returns only cells inside the inclusive window" do
    g = Grid.new([{0, 0}, {5, 5}, {10, 10}, {-1, 0}])
    cells = Grid.cells_in(g, {0, 0, 5, 5}) |> MapSet.new()
    assert cells == MapSet.new([{0, 0}, {5, 5}])
  end

  test "bounds is nil when empty, else min/max corners" do
    assert Grid.bounds(Grid.new()) == nil
    assert Grid.bounds(Grid.new([{-2, 3}, {4, -1}])) == {-2, -1, 4, 3}
  end
end
