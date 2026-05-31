defmodule Conway.Grid do
  @moduledoc """
  A sparse, infinite Game-of-Life grid: a `MapSet` of live `{x, y}` integer
  coordinates. Coordinates are arbitrary-precision, so the grid is unbounded.
  """

  @type cell :: {integer(), integer()}
  @type t :: MapSet.t(cell())

  @spec new() :: t()
  def new, do: MapSet.new()

  @spec new(Enumerable.t()) :: t()
  def new(cells), do: MapSet.new(cells)

  @spec alive?(t(), cell()) :: boolean()
  def alive?(grid, cell), do: MapSet.member?(grid, cell)

  @spec put(t(), cell()) :: t()
  def put(grid, cell), do: MapSet.put(grid, cell)

  @spec delete(t(), cell()) :: t()
  def delete(grid, cell), do: MapSet.delete(grid, cell)

  @spec toggle(t(), cell()) :: t()
  def toggle(grid, cell) do
    if alive?(grid, cell), do: delete(grid, cell), else: put(grid, cell)
  end

  @spec population(t()) :: non_neg_integer()
  def population(grid), do: MapSet.size(grid)

  @doc "Union `cells` (relative coords) into the grid, translated by `{ox, oy}`."
  @spec stamp(t(), Enumerable.t(), cell()) :: t()
  def stamp(grid, cells, {ox, oy}) do
    Enum.reduce(cells, grid, fn {cx, cy}, acc -> put(acc, {ox + cx, oy + cy}) end)
  end

  @doc "Remove `cells` (relative coords) from the grid, translated by `{ox, oy}`."
  @spec erase(t(), Enumerable.t(), cell()) :: t()
  def erase(grid, cells, {ox, oy}) do
    Enum.reduce(cells, grid, fn {cx, cy}, acc -> delete(acc, {ox + cx, oy + cy}) end)
  end

  @doc "Live cells inside the inclusive window `{x0, y0, x1, y1}`."
  @spec cells_in(t(), {integer(), integer(), integer(), integer()}) :: [cell()]
  def cells_in(grid, {x0, y0, x1, y1}) do
    for {x, y} <- grid, x >= x0, x <= x1, y >= y0, y <= y1, do: {x, y}
  end

  @spec bounds(t()) :: {integer(), integer(), integer(), integer()} | nil
  def bounds(grid) do
    if MapSet.size(grid) == 0 do
      nil
    else
      xs = Enum.map(grid, &elem(&1, 0))
      ys = Enum.map(grid, &elem(&1, 1))
      {Enum.min(xs), Enum.min(ys), Enum.max(xs), Enum.max(ys)}
    end
  end
end
