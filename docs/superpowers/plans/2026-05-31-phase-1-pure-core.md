# Conway Phase 1 — Pure Core Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the fully-pure, terminal-free core of the Conway TUI — the simulation engine, the Life Lexicon pattern layer, and a viewport + full-block renderer — ending in a runnable static frame printed to stdout.

**Architecture:** Sparse infinite grid (`MapSet` of `{x, y}`). All modules in this phase are pure functions with no terminal I/O (the one exception is reading the vendored lexicon file from `priv/`). Covers spec §18 milestones 1–3. No GenServers, no raw mode, no input handling yet — those arrive in Phase 2.

**Tech Stack:** Elixir 1.19.5 / OTP 28, ExUnit, zero runtime dependencies.

**Spec:** [`../specs/2026-05-31-conway-tui-design.md`](../specs/2026-05-31-conway-tui-design.md) (see §6 engine, §7 viewport/zoom, §8 rendering, §10 lexicon, §18 milestones 1–3).

---

## File structure produced by this phase

```
lib/conway/
  grid.ex                  # Conway.Grid       — sparse live-cell set
  life.ex                  # Conway.Life       — step/1, step/2
  pattern.ex               # Conway.Pattern    — struct + from_ascii + transforms
  lexicon.ex               # Conway.Lexicon    — parse/1, load/0
  catalog.ex               # Conway.Catalog    — navigable index over patterns
  viewport.ex              # Conway.Viewport   — camera + zoom math
  cursor.ex                # Conway.Cursor     — position + stamp + visibility
  render/
    full_block.ex          # Conway.Render.FullBlock — full-block zoom renderer
    bars.ex                # Conway.Render.Bars      — top/bottom bar formatting
    render.ex              # Conway.Render           — frame assembly
  demo.ex                  # Conway.Demo       — TEMPORARY static-frame demo (removed in Phase 2)
priv/
  life-lexicon.txt         # vendored Life Lexicon plaintext (CC BY-SA 3.0)
test/conway/...            # one test file per module
```

> **Note on the default scaffold files:** leave `lib/conway.ex` and `test/conway_test.exs` (the `mix new` defaults) untouched in this phase; they still pass. Phase 2 repurposes `Conway`/adds the escript entry.

---

## Task 1: `Conway.Grid` — sparse live-cell set

**Files:**
- Create: `lib/conway/grid.ex`
- Test: `test/conway/grid_test.exs`

- [ ] **Step 1: Write the failing test**

Create `test/conway/grid_test.exs`:

```elixir
defmodule Conway.GridTest do
  use ExUnit.Case, async: true
  alias Conway.Grid

  test "new/0 is empty, new/1 seeds cells" do
    assert Grid.population(Grid.new()) == 0
    assert Grid.population(Grid.new([{0, 0}, {1, 1}])) == 2
  end

  test "put/delete/toggle/alive?" do
    g = Grid.new() |> Grid.put({3, 4})
    assert Grid.alive?(g, {3, 4})
    refute Grid.alive?(g, {0, 0})
    g = Grid.delete(g, {3, 4})
    refute Grid.alive?(g, {3, 4})
    g = g |> Grid.toggle({5, 5}) |> Grid.toggle({6, 6}) |> Grid.toggle({5, 5})
    refute Grid.alive?(g, {5, 5})
    assert Grid.alive?(g, {6, 6})
  end

  test "stamp places translated cells, erase removes them" do
    g = Grid.stamp(Grid.new(), [{0, 0}, {1, 0}], {10, 20})
    assert Grid.alive?(g, {10, 20})
    assert Grid.alive?(g, {11, 20})
    g = Grid.erase(g, [{0, 0}], {10, 20})
    refute Grid.alive?(g, {10, 20})
    assert Grid.alive?(g, {11, 20})
  end

  test "cells_in returns only cells inside the inclusive window" do
    g = Grid.new([{0, 0}, {5, 5}, {10, 10}, {-1, 0}])
    cells = Grid.cells_in(g, {0, 0, 5, 5}) |> MapSet.new()
    assert cells == MapSet.new([{0, 0}, {5, 5}])
  end

  test "bounds is nil when empty, else min/max corners" do
    assert Grid.bounds(Grid.new()) == nil
    assert Grid.bounds(Grid.new([{-2, 3}, {4, -1}])) == {-2, -1, 4, 3}
  end
end
```

- [ ] **Step 2: Run the test, verify it fails**

Run: `mix test test/conway/grid_test.exs`
Expected: FAIL (`Conway.Grid` is undefined).

- [ ] **Step 3: Write the implementation**

Create `lib/conway/grid.ex`:

```elixir
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
```

- [ ] **Step 4: Run the test, verify it passes**

Run: `mix test test/conway/grid_test.exs`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/conway/grid.ex test/conway/grid_test.exs
git commit -m "feat: sparse infinite Grid (MapSet of live cells)"
```

---

## Task 2: `Conway.Life` — the B3/S23 step

**Files:**
- Create: `lib/conway/life.ex`
- Test: `test/conway/life_test.exs`

- [ ] **Step 1: Write the failing test**

Create `test/conway/life_test.exs`:

```elixir
defmodule Conway.LifeTest do
  use ExUnit.Case, async: true
  alias Conway.{Grid, Life}

  defp translate(grid, dx, dy), do: MapSet.new(grid, fn {x, y} -> {x + dx, y + dy} end)

  test "empty grid stays empty" do
    assert Life.step(Grid.new()) == Grid.new()
  end

  test "a lone cell and a 2-cell pair both die (underpopulation)" do
    assert Life.step(Grid.new([{0, 0}])) == Grid.new()
    assert Life.step(Grid.new([{0, 0}, {1, 0}])) == Grid.new()
  end

  test "a 2x2 block is a still life" do
    block = Grid.new([{0, 0}, {1, 0}, {0, 1}, {1, 1}])
    assert Life.step(block) == block
  end

  test "a blinker has period 2" do
    horizontal = Grid.new([{0, 0}, {1, 0}, {2, 0}])
    vertical = Grid.new([{1, -1}, {1, 0}, {1, 1}])
    assert Life.step(horizontal) == vertical
    assert Life.step(vertical) == horizontal
    assert Life.step(horizontal, 2) == horizontal
  end

  test "a glider returns to itself translated by (1,1) after 4 generations" do
    glider = Grid.new([{1, 0}, {2, 1}, {0, 2}, {1, 2}, {2, 2}])
    assert Life.step(glider, 4) == translate(glider, 1, 1)
  end
end
```

- [ ] **Step 2: Run the test, verify it fails**

Run: `mix test test/conway/life_test.exs`
Expected: FAIL (`Conway.Life` is undefined).

- [ ] **Step 3: Write the implementation**

Create `lib/conway/life.ex`:

```elixir
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
```

- [ ] **Step 4: Run the test, verify it passes**

Run: `mix test test/conway/life_test.exs`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/conway/life.ex test/conway/life_test.exs
git commit -m "feat: Life.step/1,2 (sparse B3/S23 neighbor tally)"
```

---

## Task 3: `Conway.Pattern` — struct, ASCII parse, transforms

**Files:**
- Create: `lib/conway/pattern.ex`
- Test: `test/conway/pattern_test.exs`

- [ ] **Step 1: Write the failing test**

Create `test/conway/pattern_test.exs`:

```elixir
defmodule Conway.PatternTest do
  use ExUnit.Case, async: true
  alias Conway.Pattern

  test "from_ascii maps * and O to live, . to dead, normalized to origin" do
    p = Pattern.from_ascii("glider", "desc", [".*.", "..*", "***"])
    assert p.name == "glider"
    assert p.description == "desc"
    assert p.w == 3
    assert p.h == 3
    assert p.cells == MapSet.new([{1, 0}, {2, 1}, {0, 2}, {1, 2}, {2, 2}])
  end

  test "from_ascii shifts a non-origin diagram back to (0,0)" do
    p = Pattern.from_ascii("pair", "", ["...", ".**"])
    assert p.cells == MapSet.new([{0, 0}, {1, 0}])
    assert p.w == 2
    assert p.h == 1
  end

  test "dot is a single live cell" do
    d = Pattern.dot()
    assert d.cells == MapSet.new([{0, 0}])
    assert {d.w, d.h} == {1, 1}
  end

  test "rotate_cw four times is the identity" do
    p = Pattern.from_ascii("glider", "", [".*.", "..*", "***"])
    assert p |> Pattern.rotate_cw() |> Pattern.rotate_cw() |> Pattern.rotate_cw() |> Pattern.rotate_cw() == p
  end

  test "rotate_cw turns a 3x1 row into a 1x3 column" do
    row = Pattern.from_ascii("row", "", ["***"])
    rotated = Pattern.rotate_cw(row)
    assert {rotated.w, rotated.h} == {1, 3}
    assert rotated.cells == MapSet.new([{0, 0}, {0, 1}, {0, 2}])
  end

  test "mirror_h twice is the identity, and flips left-right once" do
    p = Pattern.from_ascii("L", "", ["*.", "*.", "**"])
    assert p |> Pattern.mirror_h() |> Pattern.mirror_h() == p
    assert Pattern.mirror_h(p).cells == MapSet.new([{1, 0}, {1, 1}, {0, 2}, {1, 2}])
  end
end
```

- [ ] **Step 2: Run the test, verify it fails**

Run: `mix test test/conway/pattern_test.exs`
Expected: FAIL (`Conway.Pattern` is undefined).

- [ ] **Step 3: Write the implementation**

Create `lib/conway/pattern.ex`:

```elixir
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
```

- [ ] **Step 4: Run the test, verify it passes**

Run: `mix test test/conway/pattern_test.exs`
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/conway/pattern.ex test/conway/pattern_test.exs
git commit -m "feat: Pattern struct with ASCII parse, rotate, mirror"
```

---

## Task 4: `Conway.Lexicon.parse/1` — the lexicon format parser

This task builds and tests the parser against small inline snippets only. The real
vendored file is wired up in Task 5.

**Files:**
- Create: `lib/conway/lexicon.ex`
- Test: `test/conway/lexicon_test.exs`

- [ ] **Step 1: Write the failing test**

Create `test/conway/lexicon_test.exs`:

```elixir
defmodule Conway.LexiconTest do
  use ExUnit.Case, async: true
  alias Conway.Lexicon

  @sample """
  This is preamble text before any entry. It must be ignored.

  :glider: (c/4 diagonal) The smallest spaceship.
          .*.
          ..*
          ***

  :p2 concept: A definition with no diagram, so it is skipped.

  :block: A still life.
          **
          **
  """

  test "parses entries that have a diagram and skips the rest" do
    patterns = Lexicon.parse(@sample)
    names = Enum.map(patterns, & &1.name)
    assert names == ["glider", "block"]
  end

  test "captures the description text from the header line" do
    [glider | _] = Lexicon.parse(@sample)
    assert glider.name == "glider"
    assert glider.description =~ "smallest spaceship"
    assert glider.cells == MapSet.new([{1, 0}, {2, 1}, {0, 2}, {1, 2}, {2, 2}])
  end

  test "preserves horizontal alignment by stripping only the common indent" do
    text = ":offset: desc\n          .*\n          *.\n"
    [p] = Lexicon.parse(text)
    assert p.cells == MapSet.new([{1, 0}, {0, 1}])
  end
end
```

- [ ] **Step 2: Run the test, verify it fails**

Run: `mix test test/conway/lexicon_test.exs`
Expected: FAIL (`Conway.Lexicon` is undefined).

- [ ] **Step 3: Write the implementation**

Create `lib/conway/lexicon.ex`:

```elixir
defmodule Conway.Lexicon do
  @moduledoc """
  Parser and loader for the Life Lexicon plaintext format (dvgrn/life-lexicon,
  CC BY-SA 3.0). Entries start at column 0 with `:Name:`; pattern diagrams are
  indented blocks of `.`/`*` lines terminated by a blank or unindented line.
  Entries with no diagram are skipped.
  """

  alias Conway.Pattern

  @header ~r/^:([^:]+):\s?(.*)$/
  @diagram_row ~r/^\s+[.*O]+$/

  @doc "Parse lexicon text into a list of `Conway.Pattern`."
  @spec parse(String.t()) :: [Pattern.t()]
  def parse(text) do
    text
    |> String.split(~r/\r\n|\r|\n/)
    |> chunk_entries()
    |> Enum.map(&entry_to_pattern/1)
    |> Enum.reject(&(is_nil(&1) or MapSet.size(&1.cells) == 0))
  end

  @doc "Read and parse the vendored lexicon file from `priv/`."
  @spec load() :: [Pattern.t()]
  def load do
    path = Path.join(to_string(:code.priv_dir(:conway)), "life-lexicon.txt")

    path
    |> File.read!()
    |> parse()
  end

  # Group lines into {name, body_lines}, one per `:Name:` header. Lines before
  # the first header (the license preamble) are dropped.
  defp chunk_entries(lines) do
    {entries, current} =
      Enum.reduce(lines, {[], nil}, fn line, {entries, current} ->
        case Regex.run(@header, line) do
          [_, name, rest] ->
            {push(entries, current), {name, [rest]}}

          nil ->
            case current do
              nil -> {entries, nil}
              {name, body} -> {entries, {name, [line | body]}}
            end
        end
      end)

    push(entries, current)
    |> Enum.reverse()
    |> Enum.map(fn {name, body} -> {name, Enum.reverse(body)} end)
  end

  defp push(entries, nil), do: entries
  defp push(entries, entry), do: [entry | entries]

  defp entry_to_pattern({name, body}) do
    {desc_lines, rest} = Enum.split_while(body, &(not diagram_row?(&1)))
    diagram = Enum.take_while(rest, &diagram_row?/1)

    case diagram do
      [] ->
        nil

      _ ->
        description =
          desc_lines
          |> Enum.map(&String.trim/1)
          |> Enum.reject(&(&1 == ""))
          |> Enum.join(" ")

        Pattern.from_ascii(name, description, strip_common_indent(diagram))
    end
  end

  defp diagram_row?(line), do: Regex.match?(@diagram_row, String.trim_trailing(line))

  defp strip_common_indent(lines) do
    min_indent =
      lines
      |> Enum.map(fn l -> String.length(l) - String.length(String.trim_leading(l)) end)
      |> Enum.min()

    Enum.map(lines, &String.slice(&1, min_indent..-1//1))
  end
end
```

- [ ] **Step 4: Run the test, verify it passes**

Run: `mix test test/conway/lexicon_test.exs`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/conway/lexicon.ex test/conway/lexicon_test.exs
git commit -m "feat: Lexicon.parse/1 for the Life Lexicon plaintext format"
```

---

## Task 5: Vendor the lexicon file + `Lexicon.load/0` + `Conway.Catalog`

**Files:**
- Create: `priv/life-lexicon.txt` (downloaded)
- Create: `lib/conway/catalog.ex`
- Test: `test/conway/catalog_test.exs`
- Test (integration): add to `test/conway/lexicon_test.exs`

- [ ] **Step 1: Download and vendor the lexicon file**

Run (downloads the no-wrap plaintext distribution, ~1 MB, license header intact):

```bash
mkdir -p priv
curl -fsSL -o priv/life-lexicon.txt \
  https://raw.githubusercontent.com/dvgrn/life-lexicon/master/life-lexicon-nowrap-plaintext.txt
head -5 priv/life-lexicon.txt
wc -l priv/life-lexicon.txt
```

Expected: the first lines show the lexicon title/copyright (CC BY-SA 3.0); the file is several thousand lines. If `curl` is unavailable, download the same URL by any means into `priv/life-lexicon.txt`.

- [ ] **Step 2: Write the failing load + catalog tests**

Append to `test/conway/lexicon_test.exs` (inside the module):

```elixir
  describe "load/0 against the vendored file" do
    test "parses a large catalog including well-known patterns" do
      patterns = Lexicon.load()
      assert length(patterns) > 500

      names = MapSet.new(patterns, &String.downcase(&1.name))
      assert MapSet.member?(names, "glider")
      assert Enum.any?(names, &String.contains?(&1, "gosper glider gun"))

      glider = Enum.find(patterns, &(String.downcase(&1.name) == "glider"))
      assert MapSet.size(glider.cells) == 5
    end
  end
```

Create `test/conway/catalog_test.exs`:

```elixir
defmodule Conway.CatalogTest do
  use ExUnit.Case, async: true
  alias Conway.{Catalog, Pattern}

  defp cat do
    Catalog.new([
      %Pattern{name: "glider"},
      %Pattern{name: "block"},
      %Pattern{name: "Gosper glider gun"}
    ])
  end

  test "current starts at the first pattern" do
    assert Catalog.current(cat()).name == "glider"
  end

  test "next and prev wrap around" do
    c = cat()
    assert c |> Catalog.next() |> Catalog.current() |> Map.get(:name) == "block"
    assert c |> Catalog.next() |> Catalog.next() |> Catalog.next() |> Catalog.current() |> Map.get(:name) == "glider"
    assert c |> Catalog.prev() |> Catalog.current() |> Map.get(:name) == "Gosper glider gun"
  end

  test "select jumps to an index" do
    assert cat() |> Catalog.select(1) |> Catalog.current() |> Map.get(:name) == "block"
  end

  test "search is case-insensitive substring match returning {index, pattern}" do
    results = Catalog.search(cat(), "gli")
    assert Enum.map(results, fn {i, p} -> {i, p.name} end) == [{0, "glider"}, {2, "Gosper glider gun"}]
  end

  test "an empty catalog is safe" do
    c = Catalog.new([])
    assert Catalog.current(c) == nil
    assert Catalog.next(c) == c
    assert Catalog.search(c, "x") == []
  end
end
```

- [ ] **Step 3: Run the tests, verify the Catalog tests fail**

Run: `mix test test/conway/lexicon_test.exs test/conway/catalog_test.exs`
Expected: the new `load/0` test PASSES (the file is now vendored and `Lexicon` exists from Task 4); the `Conway.CatalogTest` tests FAIL because `Conway.Catalog` is undefined. Implement `Catalog` next.

- [ ] **Step 4: Write the Catalog implementation**

Create `lib/conway/catalog.ex`:

```elixir
defmodule Conway.Catalog do
  @moduledoc """
  A navigable index over a list of `Conway.Pattern`: a current selection with
  next/prev wraparound and case-insensitive name search.
  """

  alias Conway.Pattern
  alias __MODULE__

  @type t :: %Catalog{patterns: tuple(), count: non_neg_integer(), index: non_neg_integer()}

  defstruct patterns: {}, count: 0, index: 0

  @spec new([Pattern.t()]) :: t()
  def new(patterns) when is_list(patterns) do
    %Catalog{patterns: List.to_tuple(patterns), count: length(patterns), index: 0}
  end

  @spec current(t()) :: Pattern.t() | nil
  def current(%Catalog{count: 0}), do: nil
  def current(%Catalog{patterns: p, index: i}), do: elem(p, i)

  @spec at(t(), non_neg_integer()) :: Pattern.t()
  def at(%Catalog{patterns: p}, i), do: elem(p, i)

  @spec next(t()) :: t()
  def next(%Catalog{count: 0} = c), do: c
  def next(%Catalog{index: i, count: n} = c), do: %{c | index: rem(i + 1, n)}

  @spec prev(t()) :: t()
  def prev(%Catalog{count: 0} = c), do: c
  def prev(%Catalog{index: i, count: n} = c), do: %{c | index: rem(i - 1 + n, n)}

  @spec select(t(), non_neg_integer()) :: t()
  def select(%Catalog{count: n} = c, i) when is_integer(i) and i >= 0 and i < n, do: %{c | index: i}

  @doc "All `{index, pattern}` whose name contains `query` (case-insensitive)."
  @spec search(t(), String.t()) :: [{non_neg_integer(), Pattern.t()}]
  def search(%Catalog{count: 0}, _query), do: []

  def search(%Catalog{patterns: p, count: n}, query) do
    q = String.downcase(query)

    for i <- 0..(n - 1)//1,
        pat = elem(p, i),
        String.contains?(String.downcase(pat.name), q),
        do: {i, pat}
  end
end
```

- [ ] **Step 5: Run the tests, verify they pass**

Run: `mix test test/conway/lexicon_test.exs test/conway/catalog_test.exs`
Expected: PASS (all lexicon + catalog tests, including `load/0` against the real file).

- [ ] **Step 6: Commit**

```bash
git add priv/life-lexicon.txt lib/conway/catalog.ex test/conway/lexicon_test.exs test/conway/catalog_test.exs
git commit -m "feat: vendor Life Lexicon (CC BY-SA 3.0) + load/0 + Catalog"
```

---

## Task 6: `Conway.Viewport` — camera and zoom math

**Files:**
- Create: `lib/conway/viewport.ex`
- Test: `test/conway/viewport_test.exs`

- [ ] **Step 1: Write the failing test**

Create `test/conway/viewport_test.exs`:

```elixir
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
```

- [ ] **Step 2: Run the test, verify it fails**

Run: `mix test test/conway/viewport_test.exs`
Expected: FAIL (`Conway.Viewport` is undefined).

- [ ] **Step 3: Write the implementation**

Create `lib/conway/viewport.ex`:

```elixir
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
```

- [ ] **Step 4: Run the test, verify it passes**

Run: `mix test test/conway/viewport_test.exs`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/conway/viewport.ex test/conway/viewport_test.exs
git commit -m "feat: Viewport camera + per-zoom cell math"
```

---

## Task 7: `Conway.Cursor` — position, stamp, visibility, footprint

**Files:**
- Create: `lib/conway/cursor.ex`
- Test: `test/conway/cursor_test.exs`

- [ ] **Step 1: Write the failing test**

Create `test/conway/cursor_test.exs`:

```elixir
defmodule Conway.CursorTest do
  use ExUnit.Case, async: true
  alias Conway.{Cursor, Pattern}

  test "new defaults to a visible single-cell stamp at the origin" do
    c = Cursor.new()
    assert {c.x, c.y} == {0, 0}
    assert c.visible?
    assert c.stamp.cells == MapSet.new([{0, 0}])
  end

  test "move offsets the position" do
    c = Cursor.new() |> Cursor.move(3, -2) |> Cursor.move(1, 1)
    assert {c.x, c.y} == {4, -1}
  end

  test "footprint translates the stamp cells to world coordinates" do
    stamp = Pattern.from_ascii("pair", "", ["**"])
    c = %Cursor{x: 10, y: 5, stamp: stamp, visible?: true}
    assert Cursor.footprint(c) == MapSet.new([{10, 5}, {11, 5}])
  end

  test "an invisible cursor has an empty footprint" do
    c = %Cursor{x: 10, y: 5, stamp: Pattern.dot(), visible?: false}
    assert Cursor.footprint(c) == MapSet.new()
  end

  test "toggle flips visibility; rotate and mirror transform the stamp" do
    c = Cursor.new()
    refute Cursor.toggle(c).visible?
    row = Pattern.from_ascii("row", "", ["***"])
    c = Cursor.set_stamp(c, row)
    assert Cursor.rotate(c).stamp.h == 3
    assert Cursor.mirror(c).stamp.cells == row.cells
  end
end
```

- [ ] **Step 2: Run the test, verify it fails**

Run: `mix test test/conway/cursor_test.exs`
Expected: FAIL (`Conway.Cursor` is undefined).

- [ ] **Step 3: Write the implementation**

Create `lib/conway/cursor.ex`:

```elixir
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
```

- [ ] **Step 4: Run the test, verify it passes**

Run: `mix test test/conway/cursor_test.exs`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/conway/cursor.ex test/conway/cursor_test.exs
git commit -m "feat: Cursor with stamp, visibility, and world footprint"
```

---

## Task 8: `Conway.Render.FullBlock` — the full-block renderer

**Files:**
- Create: `lib/conway/render/full_block.ex`
- Test: `test/conway/render/full_block_test.exs`

Golden tests pass `color: false` so the expected rows are plain text. Glyphs:
empty = `"  "`, live = `"██"`, cursor preview = `"░░"`.

- [ ] **Step 1: Write the failing test**

Create `test/conway/render/full_block_test.exs`:

```elixir
defmodule Conway.Render.FullBlockTest do
  use ExUnit.Case, async: true
  alias Conway.{Grid, Viewport, Cursor, Pattern}
  alias Conway.Render.FullBlock

  test "renders live cells as blocks and empties as spaces (plain mode)" do
    grid = Grid.new([{0, 0}, {1, 0}, {2, 0}])
    vp = %Viewport{cam_x: 0, cam_y: 0, zoom: :full, cols: 8, rows: 3}
    cursor = %Cursor{x: 0, y: 0, stamp: Pattern.dot(), visible?: false}

    assert FullBlock.render(grid, vp, cursor, color: false) == [
             "██████  ",
             "        ",
             "        "
           ]
  end

  test "a visible cursor draws its stamp footprint in the cursor glyph" do
    grid = Grid.new()
    vp = %Viewport{cam_x: 0, cam_y: 0, zoom: :full, cols: 8, rows: 2}
    cursor = %Cursor{x: 3, y: 1, stamp: Pattern.dot(), visible?: true}

    assert FullBlock.render(grid, vp, cursor, color: false) == [
             "        ",
             "      ░░"
           ]
  end

  test "the cursor preview takes color priority over a live cell underneath" do
    grid = Grid.new([{0, 0}])
    vp = %Viewport{cam_x: 0, cam_y: 0, zoom: :full, cols: 2, rows: 1}
    cursor = %Cursor{x: 0, y: 0, stamp: Pattern.dot(), visible?: true}

    assert FullBlock.render(grid, vp, cursor, color: false) == ["░░"]
  end

  test "color mode wraps glyphs in ANSI and stays the same character width" do
    grid = Grid.new([{0, 0}])
    vp = %Viewport{cam_x: 0, cam_y: 0, zoom: :full, cols: 2, rows: 1}
    cursor = %Cursor{x: 0, y: 0, stamp: Pattern.dot(), visible?: false}

    [row] = FullBlock.render(grid, vp, cursor, color: true)
    assert row =~ "██"
    assert String.contains?(row, IO.ANSI.reset())
  end
end
```

- [ ] **Step 2: Run the test, verify it fails**

Run: `mix test test/conway/render/full_block_test.exs`
Expected: FAIL (`Conway.Render.FullBlock` is undefined).

- [ ] **Step 3: Write the implementation**

Create `lib/conway/render/full_block.ex`:

```elixir
defmodule Conway.Render.FullBlock do
  @moduledoc """
  Full-block zoom renderer: each Life cell occupies one character row and two
  columns. Live cells render as `██`, the cursor stamp preview as `░░` (cursor
  color, taking priority over any live cell beneath it), empties as two spaces.
  Returns one binary per grid-area row.
  """

  alias Conway.{Grid, Viewport, Cursor}

  @spec render(Grid.t(), Viewport.t(), Cursor.t(), keyword()) :: [binary()]
  def render(grid, %Viewport{zoom: :full} = vp, cursor, opts \\ []) do
    color = Keyword.get(opts, :color, true)
    {wide, _tall} = Viewport.cells_visible(vp)
    footprint = Cursor.footprint(cursor)

    for r <- 0..(vp.rows - 1)//1 do
      row =
        for c <- 0..(wide - 1)//1 do
          cell = {vp.cam_x + c, vp.cam_y + r}

          cond do
            MapSet.member?(footprint, cell) -> glyph(:cursor, color)
            Grid.alive?(grid, cell) -> glyph(:live, color)
            true -> glyph(:empty, color)
          end
        end

      IO.iodata_to_binary(row)
    end
  end

  defp glyph(:empty, _), do: "  "
  defp glyph(:live, false), do: "██"
  defp glyph(:live, true), do: [IO.ANSI.green(), "██", IO.ANSI.reset()]
  defp glyph(:cursor, false), do: "░░"
  defp glyph(:cursor, true), do: [IO.ANSI.cyan(), "░░", IO.ANSI.reset()]
end
```

- [ ] **Step 4: Run the test, verify it passes**

Run: `mix test test/conway/render/full_block_test.exs`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/conway/render/full_block.ex test/conway/render/full_block_test.exs
git commit -m "feat: full-block zoom renderer with cursor preview"
```

---

## Task 9: `Conway.Render.Bars` — top and bottom bars

**Files:**
- Create: `lib/conway/render/bars.ex`
- Test: `test/conway/render/bars_test.exs`

> Width is measured with `String.length/1`. True display width for wide glyphs is
> deferred to Phase 4 polish; this is sufficient to see the bars now.

- [ ] **Step 1: Write the failing test**

Create `test/conway/render/bars_test.exs`:

```elixir
defmodule Conway.Render.BarsTest do
  use ExUnit.Case, async: true
  alias Conway.Render.Bars

  test "top is one line padded to exactly cols with key status fields" do
    line = Bars.top(cols: 100, generation: 7, population: 42, speed: 12, playing?: true, zoom: :full, cursor: {-3, 5})
    assert String.length(line) == 100
    assert line =~ "CONWAY"
    assert line =~ "gen 7"
    assert line =~ "pop 42"
    assert line =~ "12 gen/s"
    assert line =~ "(-3, 5)"
    assert line =~ "q quit"
  end

  test "bottom is two lines (name, description) padded to cols" do
    [l1, l2] = Bars.bottom(cols: 60, name: "glider", description: "small spaceship")
    assert String.length(l1) == 60
    assert String.length(l2) == 60
    assert l1 =~ "glider"
    assert l2 =~ "small spaceship"
  end

  test "long content is truncated to cols, not overflowed" do
    line = Bars.top(cols: 20, generation: 999_999, population: 999_999, speed: 60, playing?: false, zoom: :braille, cursor: {123, 456})
    assert String.length(line) == 20
  end
end
```

- [ ] **Step 2: Run the test, verify it fails**

Run: `mix test test/conway/render/bars_test.exs`
Expected: FAIL (`Conway.Render.Bars` is undefined).

- [ ] **Step 3: Write the implementation**

Create `lib/conway/render/bars.ex`:

```elixir
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
```

- [ ] **Step 4: Run the test, verify it passes**

Run: `mix test test/conway/render/bars_test.exs`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/conway/render/bars.ex test/conway/render/bars_test.exs
git commit -m "feat: top/bottom bar formatting"
```

---

## Task 10: `Conway.Render.frame/6` + a static demo

**Files:**
- Create: `lib/conway/render/render.ex`
- Create: `lib/conway/demo.ex`
- Test: `test/conway/render/render_test.exs`

- [ ] **Step 1: Write the failing test**

Create `test/conway/render/render_test.exs`:

```elixir
defmodule Conway.RenderTest do
  use ExUnit.Case, async: true
  alias Conway.{Grid, Viewport, Cursor, Pattern, Render}

  test "frame stacks the top bar, the grid rows, then the two bottom bar lines" do
    grid = Grid.new([{0, 0}])
    vp = %Viewport{cam_x: 0, cam_y: 0, zoom: :full, cols: 40, rows: 3}
    cursor = %Cursor{x: 0, y: 0, stamp: Pattern.dot(), visible?: false}

    lines =
      Render.frame(
        grid,
        vp,
        cursor,
        [generation: 0, population: 1, speed: 10, playing?: false, zoom: :full, cursor: {0, 0}],
        [name: "single cell", description: "A single live cell."],
        color: false
      )

    # 1 top bar + 3 grid rows + 2 bottom lines = 6 lines
    assert length(lines) == 6
    assert Enum.all?(lines, &(String.length(&1) == 40))
    assert hd(lines) =~ "CONWAY"
    assert Enum.at(lines, 1) == "██" <> String.duplicate(" ", 38)
    assert List.last(lines) =~ "single live cell"
  end
end
```

- [ ] **Step 2: Run the test, verify it fails**

Run: `mix test test/conway/render/render_test.exs`
Expected: FAIL (`Conway.Render` is undefined).

- [ ] **Step 3: Write the Render implementation**

Create `lib/conway/render/render.ex`:

```elixir
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
```

- [ ] **Step 4: Run the test, verify it passes**

Run: `mix test test/conway/render/render_test.exs`
Expected: PASS (1 test).

- [ ] **Step 5: Add the temporary static demo**

Create `lib/conway/demo.ex`:

```elixir
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
    vp = %Viewport{cam_x: -2, cam_y: -2, zoom: :full, cols: 60, rows: 16}
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
```

- [ ] **Step 6: Eyeball the demo**

Run: `mix run -e "Conway.Demo.run()"`
Expected: a cleared screen showing a top bar, a green glider near the upper-left, a cyan `░░` cursor a few cells to its right, and a two-line bottom bar naming "glider". Confirm it looks right.

- [ ] **Step 7: Commit**

```bash
git add lib/conway/render/render.ex lib/conway/demo.ex test/conway/render/render_test.exs
git commit -m "feat: Render.frame assembly + temporary static demo"
```

---

## Task 11: Phase wrap-up — full suite green + roadmap update

**Files:**
- Modify: `docs/superpowers/plans/README.md`

- [ ] **Step 1: Run the entire test suite**

Run: `mix test`
Expected: PASS — all Phase 1 modules plus the untouched `mix new` default test. No failures.

- [ ] **Step 2: Check formatting**

Run: `mix format --check-formatted`
Expected: no output (all files formatted). If it reports files, run `mix format` and re-run the suite.

- [ ] **Step 3: Mark Phase 1 complete in the roadmap**

In `docs/superpowers/plans/README.md`, change the Phase 1 row's **Status** column from `Not started` to `Done`.

- [ ] **Step 4: Commit**

```bash
git add docs/superpowers/plans/README.md
git commit -m "chore: Phase 1 (pure core) complete"
```

---

## Self-review notes (for the planner)

- **Spec coverage:** Milestone 1 → Tasks 1–2 (Grid, Life). Milestone 2 → Tasks 3–5 (Pattern, Lexicon, Catalog, vendored file). Milestone 3 → Tasks 6–10 (Viewport, Cursor, FullBlock, Bars, Render.frame, static demo). The §17 test cases called out for these modules (block/blinker/glider/lone-cell, rotate∘4/mirror∘2, lexicon format + known patterns, viewport mapping, full-block golden incl. cursor-priority) all have corresponding steps.
- **Deferred to later phases (intentionally, per the grouping):** half-block + braille renderers and `world_to_screen` for those zooms (Phase 3); the SGR-no-bleed `Diff`, ESC-timeout input decoding, `App.update/2` reducer, `Terminal`/`Input`/`Loop`, and escript packaging of `priv/` (Phase 2+). `Viewport.set_zoom/2` exists but only `:full` is rendered this phase.
- **Type/name consistency:** `Grid.t` = `MapSet`; `Pattern` fields `name/description/cells/w/h`; `Catalog` uses a tuple with `count`/`index`; `Viewport.cells_visible/1` drives `visible_window/1` and `FullBlock`; `Cursor.footprint/1` returns a `MapSet` consumed by `FullBlock`. `Render.frame/6` matches its caller in `Demo` and the render test.
- **No placeholders:** every step has runnable code/commands and expected output.
