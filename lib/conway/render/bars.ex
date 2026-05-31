defmodule Conway.Render.Bars do
  @moduledoc """
  Pure formatting for the top status bar and the bottom stamp bar. Each function
  returns line(s) fitted to `cols` (truncated or space-padded). Width uses
  `String.length/1`; wide-glyph display width is a later concern.
  """

  @spec top(keyword()) :: binary()
  def top(opts) do
    cols = Keyword.fetch!(opts, :cols)
    gen = Keyword.get(opts, :generation, 0)
    pop = Keyword.get(opts, :population, 0)
    speed = Keyword.get(opts, :speed, 10)
    {cx, cy} = Keyword.get(opts, :cursor, {0, 0})
    zoom = Keyword.get(opts, :zoom, :full)
    state = if Keyword.get(opts, :playing?, false), do: "> playing", else: "|| paused"

    left =
      " CONWAY   #{state}   gen #{gen}   pop #{pop}   #{speed} gen/s   zoom #{zoom}   cur (#{cx}, #{cy})"

    pad_between(left, "? help   q quit ", cols)
  end

  @spec bottom(keyword()) :: [binary()]
  def bottom(opts) do
    cols = Keyword.fetch!(opts, :cols)
    name = Keyword.get(opts, :name, "")
    desc = Keyword.get(opts, :description, "")
    [fit(" stamp > #{name}", cols), fit("   #{desc}", cols)]
  end

  defp pad_between(left, right, cols) do
    avail = max(cols - String.length(right), 0)
    fit(fit(left, avail) <> right, cols)
  end

  defp fit(s, cols) do
    len = String.length(s)

    cond do
      len == cols -> s
      len < cols -> s <> String.duplicate(" ", cols - len)
      true -> String.slice(s, 0, cols)
    end
  end
end
