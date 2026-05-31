defmodule Conway.Render do
  @moduledoc """
  Assembles a full screen frame: the top bar, the grid-area rows for the current
  zoom, then the two bottom bar lines. Returns a list of line binaries/iolists,
  one per terminal row. (Half-block, braille, overlays, and diffing arrive in
  later phases.)
  """

  alias Conway.{Grid, Viewport, Cursor}
  alias Conway.Render.{FullBlock, Bars}

  @spec frame(Grid.t(), Viewport.t(), Cursor.t(), keyword(), keyword(), keyword()) :: [iodata()]
  def frame(grid, %Viewport{zoom: :full} = vp, cursor, top_opts, bottom_opts, opts \\ []) do
    grid_rows = FullBlock.render(grid, vp, cursor, opts)
    top = Bars.top([cols: vp.cols] ++ top_opts)
    bottom = Bars.bottom([cols: vp.cols] ++ bottom_opts)
    [top | grid_rows] ++ bottom
  end
end
