defmodule Conway.Render.BarsTest do
  use ExUnit.Case, async: true
  alias Conway.Render.Bars

  test "top is one line padded to exactly cols with key status fields" do
    line =
      Bars.top(
        cols: 100,
        generation: 7,
        population: 42,
        speed: 12,
        playing?: true,
        zoom: :full,
        cursor: {-3, 5}
      )

    assert String.length(line) == 100
    assert line =~ "CONWAY"
    assert line =~ "gen 7"
    assert line =~ "pop 42"
    assert line =~ "12 gen/s"
    assert line =~ "(-3, 5)"
    assert line =~ "q quit"
  end

  test "bottom is two lines (name, description) padded to cols" do
    [l1, l2] = Bars.bottom(cols: 60, name: "glider", description: "small spaceship")
    assert String.length(l1) == 60
    assert String.length(l2) == 60
    assert l1 =~ "glider"
    assert l2 =~ "small spaceship"
  end

  test "long content is truncated to cols, not overflowed" do
    line =
      Bars.top(
        cols: 20,
        generation: 999_999,
        population: 999_999,
        speed: 60,
        playing?: false,
        zoom: :braille,
        cursor: {123, 456}
      )

    assert String.length(line) == 20
  end
end
