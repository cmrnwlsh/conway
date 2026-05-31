defmodule Conway.PatternTest do
  use ExUnit.Case, async: true
  alias Conway.Pattern

  test "from_ascii maps * and O to live, . to dead, normalized to origin" do
    p = Pattern.from_ascii("glider", "desc", [".*.", "..*", "***"])
    assert p.name == "glider"
    assert p.description == "desc"
    assert p.w == 3
    assert p.h == 3
    assert p.cells == MapSet.new([{1, 0}, {2, 1}, {0, 2}, {1, 2}, {2, 2}])
  end

  test "from_ascii shifts a non-origin diagram back to (0,0)" do
    p = Pattern.from_ascii("pair", "", ["...", ".**"])
    assert p.cells == MapSet.new([{0, 0}, {1, 0}])
    assert p.w == 2
    assert p.h == 1
  end

  test "dot is a single live cell" do
    d = Pattern.dot()
    assert d.cells == MapSet.new([{0, 0}])
    assert {d.w, d.h} == {1, 1}
  end

  test "rotate_cw four times is the identity" do
    p = Pattern.from_ascii("glider", "", [".*.", "..*", "***"])

    assert p
           |> Pattern.rotate_cw()
           |> Pattern.rotate_cw()
           |> Pattern.rotate_cw()
           |> Pattern.rotate_cw() == p
  end

  test "rotate_cw turns a 3x1 row into a 1x3 column" do
    row = Pattern.from_ascii("row", "", ["***"])
    rotated = Pattern.rotate_cw(row)
    assert {rotated.w, rotated.h} == {1, 3}
    assert rotated.cells == MapSet.new([{0, 0}, {0, 1}, {0, 2}])
  end

  test "mirror_h twice is the identity, and flips left-right once" do
    p = Pattern.from_ascii("L", "", ["*.", "*.", "**"])
    assert p |> Pattern.mirror_h() |> Pattern.mirror_h() == p
    assert Pattern.mirror_h(p).cells == MapSet.new([{1, 0}, {1, 1}, {0, 2}, {1, 2}])
  end
end
