defmodule Conway.Life do
  @moduledoc """
  Conway's Game of Life rule (B3/S23) over a sparse `Conway.Grid`.

  The next generation is built solely from a neighbor-count map: a coordinate is
  live next iff it has exactly 3 live neighbors, or exactly 2 and is currently
  live. The previous live set is never unioned in, which is what makes isolated
  cells die correctly.
  """

  alias Conway.Grid

  @offsets for dx <- -1..1, dy <- -1..1, {dx, dy} != {0, 0}, do: {dx, dy}

  @spec step(Grid.t()) :: Grid.t()
  def step(grid) do
    counts = neighbor_counts(grid)

    for {cell, n} <- counts,
        n == 3 or (n == 2 and Grid.alive?(grid, cell)),
        into: MapSet.new(),
        do: cell
  end

  @spec step(Grid.t(), non_neg_integer()) :: Grid.t()
  def step(grid, 0), do: grid
  def step(grid, n) when is_integer(n) and n > 0, do: step(step(grid), n - 1)

  defp neighbor_counts(grid) do
    Enum.reduce(grid, %{}, fn {x, y}, acc ->
      Enum.reduce(@offsets, acc, fn {dx, dy}, acc2 ->
        Map.update(acc2, {x + dx, y + dy}, 1, &(&1 + 1))
      end)
    end)
  end
end
