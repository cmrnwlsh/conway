defmodule Conway.Cursor do
  @moduledoc """
  The editing cursor: a world position, the active stamp `Conway.Pattern`, and a
  visibility flag. `footprint/1` is the set of world cells the stamp covers (used
  by the renderer for the cursor preview); it is empty when the cursor is hidden.
  """

  alias Conway.Pattern
  alias __MODULE__

  @type t :: %Cursor{x: integer(), y: integer(), stamp: Pattern.t(), visible?: boolean()}

  defstruct x: 0, y: 0, stamp: nil, visible?: true

  @spec new(Pattern.t()) :: t()
  def new(stamp \\ Pattern.dot()), do: %Cursor{stamp: stamp}

  @spec move(t(), integer(), integer()) :: t()
  def move(c, dx, dy), do: %{c | x: c.x + dx, y: c.y + dy}

  @spec set_stamp(t(), Pattern.t()) :: t()
  def set_stamp(c, %Pattern{} = p), do: %{c | stamp: p}

  @spec rotate(t()) :: t()
  def rotate(c), do: %{c | stamp: Pattern.rotate_cw(c.stamp)}

  @spec mirror(t()) :: t()
  def mirror(c), do: %{c | stamp: Pattern.mirror_h(c.stamp)}

  @spec toggle(t()) :: t()
  def toggle(c), do: %{c | visible?: not c.visible?}

  @spec footprint(t()) :: MapSet.t({integer(), integer()})
  def footprint(%Cursor{visible?: false}), do: MapSet.new()
  def footprint(%Cursor{x: x, y: y, stamp: %Pattern{cells: cells}}) do
    MapSet.new(cells, fn {cx, cy} -> {x + cx, y + cy} end)
  end
end
