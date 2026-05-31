defmodule Conway.Render.FullBlockTest do
  use ExUnit.Case, async: true
  alias Conway.{Grid, Viewport, Cursor, Pattern}
  alias Conway.Render.FullBlock

  test "renders live cells as blocks and empties as spaces (plain mode)" do
    grid = Grid.new([{0, 0}, {1, 0}, {2, 0}])
    vp = %Viewport{cam_x: 0, cam_y: 0, zoom: :full, cols: 8, rows: 3}
    cursor = %Cursor{x: 0, y: 0, stamp: Pattern.dot(), visible?: false}

    assert FullBlock.render(grid, vp, cursor, color: false) == [
             "██████  ",
             "        ",
             "        "
           ]
  end

  test "a visible cursor draws its stamp footprint in the cursor glyph" do
    grid = Grid.new()
    vp = %Viewport{cam_x: 0, cam_y: 0, zoom: :full, cols: 8, rows: 2}
    cursor = %Cursor{x: 3, y: 1, stamp: Pattern.dot(), visible?: true}

    assert FullBlock.render(grid, vp, cursor, color: false) == [
             "        ",
             "      ░░"
           ]
  end

  test "the cursor preview takes color priority over a live cell underneath" do
    grid = Grid.new([{0, 0}])
    vp = %Viewport{cam_x: 0, cam_y: 0, zoom: :full, cols: 2, rows: 1}
    cursor = %Cursor{x: 0, y: 0, stamp: Pattern.dot(), visible?: true}

    assert FullBlock.render(grid, vp, cursor, color: false) == ["░░"]
  end

  test "color mode wraps glyphs in ANSI and stays the same character width" do
    grid = Grid.new([{0, 0}])
    vp = %Viewport{cam_x: 0, cam_y: 0, zoom: :full, cols: 2, rows: 1}
    cursor = %Cursor{x: 0, y: 0, stamp: Pattern.dot(), visible?: false}

    [row] = FullBlock.render(grid, vp, cursor, color: true)
    assert row =~ "██"
    assert String.contains?(row, IO.ANSI.reset())
  end
end
