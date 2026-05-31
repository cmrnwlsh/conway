defmodule Conway.Demo do
  @moduledoc """
  TEMPORARY: prints one static frame to stdout so we can eyeball the full-block
  renderer and bars. Not part of the real app — replaced by `Conway.Loop` in
  Phase 2. Run with: `mix run -e "Conway.Demo.run()"`.
  """

  alias Conway.{Grid, Viewport, Cursor, Pattern, Render}

  @spec run() :: :ok
  def run do
    glider = Grid.new([{1, 0}, {2, 1}, {0, 2}, {1, 2}, {2, 2}])
    vp = %Viewport{cam_x: -2, cam_y: -2, zoom: :full, cols: 80, rows: 16}
    cursor = %Cursor{x: 6, y: 4, stamp: Pattern.dot(), visible?: true}

    lines =
      Render.frame(
        glider,
        vp,
        cursor,
        [generation: 0, population: Grid.population(glider), speed: 10, playing?: false, zoom: :full, cursor: {cursor.x, cursor.y}],
        [name: "glider", description: "c/4 diagonal spaceship; the smallest, most common spaceship."],
        color: true
      )

    IO.write(IO.ANSI.clear() <> IO.ANSI.home())
    Enum.each(lines, &IO.puts/1)
  end
end
