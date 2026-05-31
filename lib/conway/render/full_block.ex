defmodule Conway.Render.FullBlock do
  @moduledoc """
  Full-block zoom renderer: each Life cell occupies one character row and two
  columns. Live cells render as `██`, the cursor stamp preview as `░░` (cursor
  color, taking priority over any live cell beneath it), empties as two spaces.
  Returns one binary per grid-area row.
  """

  alias Conway.{Cursor, Grid, Viewport}

  @spec render(Grid.t(), Viewport.t(), Cursor.t(), keyword()) :: [binary()]
  def render(grid, %Viewport{zoom: :full} = vp, cursor, opts \\ []) do
    color = Keyword.get(opts, :color, true)
    {wide, _tall} = Viewport.cells_visible(vp)
    footprint = Cursor.footprint(cursor)

    for r <- 0..(vp.rows - 1)//1 do
      row =
        for c <- 0..(wide - 1)//1 do
          cell_glyph(grid, footprint, {vp.cam_x + c, vp.cam_y + r}, color)
        end

      IO.iodata_to_binary(row)
    end
  end

  defp cell_glyph(grid, footprint, cell, color) do
    cond do
      MapSet.member?(footprint, cell) -> glyph(:cursor, color)
      Grid.alive?(grid, cell) -> glyph(:live, color)
      true -> glyph(:empty, color)
    end
  end

  defp glyph(:empty, _), do: "  "
  defp glyph(:live, false), do: "██"
  defp glyph(:live, true), do: [IO.ANSI.green(), "██", IO.ANSI.reset()]
  defp glyph(:cursor, false), do: "░░"
  defp glyph(:cursor, true), do: [IO.ANSI.cyan(), "░░", IO.ANSI.reset()]
end
