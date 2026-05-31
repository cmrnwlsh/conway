defmodule Conway.Viewport do
  @moduledoc """
  The camera over the infinite world: top-left world coordinate (`cam_x`,
  `cam_y`), a `zoom` (`:full | :half | :braille`), and the grid area size in
  character cells (`cols`, `rows`).

  Zoom sets how many Life cells map to one character cell (spec §7):
  full = 2 cols × 1 row per cell; half = 1 col × ½ row; braille = ½ col × ¼ row.
  """

  alias __MODULE__

  @type zoom :: :full | :half | :braille
  @type t :: %Viewport{cam_x: integer(), cam_y: integer(), zoom: zoom(), cols: non_neg_integer(), rows: non_neg_integer()}

  defstruct cam_x: 0, cam_y: 0, zoom: :full, cols: 0, rows: 0

  @spec new(non_neg_integer(), non_neg_integer()) :: t()
  def new(cols, rows), do: %Viewport{cols: cols, rows: rows}

  @doc "How many world cells fit, as `{width, height}`, for the current zoom."
  @spec cells_visible(t()) :: {non_neg_integer(), non_neg_integer()}
  def cells_visible(%Viewport{zoom: :full, cols: c, rows: r}), do: {div(c, 2), r}
  def cells_visible(%Viewport{zoom: :half, cols: c, rows: r}), do: {c, r * 2}
  def cells_visible(%Viewport{zoom: :braille, cols: c, rows: r}), do: {c * 2, r * 4}

  @doc "Inclusive world rectangle `{x0, y0, x1, y1}` currently visible."
  @spec visible_window(t()) :: {integer(), integer(), integer(), integer()}
  def visible_window(vp) do
    {w, h} = cells_visible(vp)
    {vp.cam_x, vp.cam_y, vp.cam_x + w - 1, vp.cam_y + h - 1}
  end

  @doc "Screen `{col, row}` of a world cell at full zoom (2 columns per cell)."
  @spec world_to_screen(t(), {integer(), integer()}) :: {integer(), integer()}
  def world_to_screen(%Viewport{zoom: :full} = vp, {wx, wy}), do: {(wx - vp.cam_x) * 2, wy - vp.cam_y}

  @spec pan(t(), integer(), integer()) :: t()
  def pan(vp, dx, dy), do: %{vp | cam_x: vp.cam_x + dx, cam_y: vp.cam_y + dy}

  @spec center_on(t(), {integer(), integer()}) :: t()
  def center_on(vp, {wx, wy}) do
    {w, h} = cells_visible(vp)
    %{vp | cam_x: wx - div(w, 2), cam_y: wy - div(h, 2)}
  end

  @spec resize(t(), non_neg_integer(), non_neg_integer()) :: t()
  def resize(vp, cols, rows), do: %{vp | cols: cols, rows: rows}

  @spec set_zoom(t(), zoom()) :: t()
  def set_zoom(vp, zoom) when zoom in [:full, :half, :braille], do: %{vp | zoom: zoom}
end
