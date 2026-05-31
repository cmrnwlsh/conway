defmodule Conway.CursorTest do
  use ExUnit.Case, async: true
  alias Conway.{Cursor, Pattern}

  test "new defaults to a visible single-cell stamp at the origin" do
    c = Cursor.new()
    assert {c.x, c.y} == {0, 0}
    assert c.visible?
    assert c.stamp.cells == MapSet.new([{0, 0}])
  end

  test "move offsets the position" do
    c = Cursor.new() |> Cursor.move(3, -2) |> Cursor.move(1, 1)
    assert {c.x, c.y} == {4, -1}
  end

  test "footprint translates the stamp cells to world coordinates" do
    stamp = Pattern.from_ascii("pair", "", ["**"])
    c = %Cursor{x: 10, y: 5, stamp: stamp, visible?: true}
    assert Cursor.footprint(c) == MapSet.new([{10, 5}, {11, 5}])
  end

  test "an invisible cursor has an empty footprint" do
    c = %Cursor{x: 10, y: 5, stamp: Pattern.dot(), visible?: false}
    assert Cursor.footprint(c) == MapSet.new()
  end

  test "toggle flips visibility; rotate and mirror transform the stamp" do
    c = Cursor.new()
    refute Cursor.toggle(c).visible?
    row = Pattern.from_ascii("row", "", ["***"])
    c = Cursor.set_stamp(c, row)
    assert Cursor.rotate(c).stamp.h == 3
    assert Cursor.mirror(c).stamp.cells == row.cells
  end
end
