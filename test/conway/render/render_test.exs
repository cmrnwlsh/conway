defmodule Conway.RenderTest do
  use ExUnit.Case, async: true
  alias Conway.{Grid, Viewport, Cursor, Pattern, Render}

  test "frame stacks the top bar, the grid rows, then the two bottom bar lines" do
    grid = Grid.new([{0, 0}])
    vp = %Viewport{cam_x: 0, cam_y: 0, zoom: :full, cols: 40, rows: 3}
    cursor = %Cursor{x: 0, y: 0, stamp: Pattern.dot(), visible?: false}

    lines =
      Render.frame(
        grid,
        vp,
        cursor,
        [generation: 0, population: 1, speed: 10, playing?: false, zoom: :full, cursor: {0, 0}],
        [name: "single cell", description: "A single live cell."],
        color: false
      )

    # 1 top bar + 3 grid rows + 2 bottom lines = 6 lines
    assert length(lines) == 6
    assert Enum.all?(lines, &(String.length(&1) == 40))
    assert hd(lines) =~ "CONWAY"
    assert Enum.at(lines, 1) == "██" <> String.duplicate(" ", 38)
    assert List.last(lines) =~ "single live cell"
  end
end
