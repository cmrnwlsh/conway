defmodule Conway.Pattern do
  @moduledoc """
  A named pattern: a set of relative `{x, y}` live cells normalized so the
  top-left of the bounding box is `{0, 0}`, plus its name, description, and
  width/height.
  """

  alias __MODULE__

  @type cell :: {integer(), integer()}
  @type t :: %Pattern{
          name: String.t(),
          description: String.t(),
          cells: MapSet.t(cell()),
          w: non_neg_integer(),
          h: non_neg_integer()
        }

  defstruct name: "", description: "", cells: MapSet.new(), w: 0, h: 0

  @doc "A single live cell — the default cursor stamp."
  @spec dot() :: t()
  def dot, do: %Pattern{name: "single cell", description: "A single live cell.", cells: MapSet.new([{0, 0}]), w: 1, h: 1}

  @doc "Build a pattern from ASCII-art rows. `*` and `O` are live; everything else is dead."
  @spec from_ascii(String.t(), String.t(), [String.t()]) :: t()
  def from_ascii(name, description, lines) do
    cells =
      for {line, y} <- Enum.with_index(lines),
          {ch, x} <- Enum.with_index(String.to_charlist(line)),
          ch == ?* or ch == ?O,
          into: MapSet.new(),
          do: {x, y}

    normalize(%Pattern{name: name, description: description, cells: cells})
  end

  @doc "Shift cells so the bounding box starts at {0,0}; recompute w/h."
  @spec normalize(t()) :: t()
  def normalize(%Pattern{cells: cells} = p) do
    if MapSet.size(cells) == 0 do
      %{p | cells: cells, w: 0, h: 0}
    else
      xs = Enum.map(cells, &elem(&1, 0))
      ys = Enum.map(cells, &elem(&1, 1))
      {minx, maxx} = Enum.min_max(xs)
      {miny, maxy} = Enum.min_max(ys)
      shifted = MapSet.new(cells, fn {x, y} -> {x - minx, y - miny} end)
      %{p | cells: shifted, w: maxx - minx + 1, h: maxy - miny + 1}
    end
  end

  @doc "Rotate 90° clockwise: (x, y) -> (h-1-y, x)."
  @spec rotate_cw(t()) :: t()
  def rotate_cw(%Pattern{cells: cells, h: h} = p) do
    normalize(%{p | cells: MapSet.new(cells, fn {x, y} -> {h - 1 - y, x} end)})
  end

  @doc "Mirror horizontally (flip left-right): (x, y) -> (w-1-x, y)."
  @spec mirror_h(t()) :: t()
  def mirror_h(%Pattern{cells: cells, w: w} = p) do
    normalize(%{p | cells: MapSet.new(cells, fn {x, y} -> {w - 1 - x, y} end)})
  end
end
