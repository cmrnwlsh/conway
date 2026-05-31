defmodule Conway.ViewportTest do
  use ExUnit.Case, async: true
  alias Conway.Viewport

  test "cells_visible follows the per-zoom density (cells per char cell)" do
    assert Viewport.cells_visible(%Viewport{zoom: :full, cols: 80, rows: 24}) == {40, 24}
    assert Viewport.cells_visible(%Viewport{zoom: :half, cols: 80, rows: 24}) == {80, 48}
    assert Viewport.cells_visible(%Viewport{zoom: :braille, cols: 80, rows: 24}) == {160, 96}
  end

  test "visible_window is the inclusive world rectangle from the camera" do
    vp = %Viewport{zoom: :full, cols: 80, rows: 24, cam_x: 5, cam_y: -3}
    assert Viewport.visible_window(vp) == {5, -3, 44, 20}
  end

  test "world_to_screen at full zoom: 2 columns per cell" do
    vp = %Viewport{zoom: :full, cols: 80, rows: 24, cam_x: 5, cam_y: 10}
    assert Viewport.world_to_screen(vp, {5, 10}) == {0, 0}
    assert Viewport.world_to_screen(vp, {7, 12}) == {4, 2}
  end

  test "pan shifts the camera" do
    vp = %Viewport{cam_x: 0, cam_y: 0, zoom: :full, cols: 80, rows: 24}
    assert Viewport.pan(vp, 3, -2) |> Map.take([:cam_x, :cam_y]) == %{cam_x: 3, cam_y: -2}
  end

  test "center_on puts a world point at the middle of the visible cells" do
    vp = %Viewport{zoom: :full, cols: 80, rows: 24, cam_x: 0, cam_y: 0}
    centered = Viewport.center_on(vp, {100, 100})
    # {40, 24} cells visible -> half is {20, 12}
    assert {centered.cam_x, centered.cam_y} == {80, 88}
  end
end
