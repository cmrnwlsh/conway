# Conway — Interactive Terminal Game of Life

- **Date:** 2026-05-31
- **Status:** Reviewed (independent technical review incorporated) — ready for implementation planning
- **Target:** Elixir 1.19.5, OTP 28, zero runtime dependencies

## 1. Overview

An interactive Conway's Game of Life simulation rendered directly in the
terminal. The world is an infinite grid viewed through a pannable, zoomable
viewport. The user moves a colored cursor, places named patterns drawn from the
full Life Lexicon, and plays, pauses, single-steps, and speed-controls the
simulation. The whole thing is a single full-screen TUI with our own renderer —
no TUI framework, no dependencies.

### Goals

- Infinite grid with a smoothly pannable viewport.
- Three zoom levels — full block, half block, braille — that trade detail for
  reach while keeping cells roughly square.
- A distinctly colored editing cursor whose "stamp" is a pattern the user can
  cycle, search, transform, or draw by hand.
- The complete Life Lexicon (~685 named patterns with descriptions, drawn from
  ~1000 lexicon entries) available to cycle and search.
- Top and bottom status bars; the bottom bar is focused on the current stamp's
  name and description. Bars can be hidden for a "terminal wallpaper" view.
- Play / pause / single-step with adjustable speed.
- Zero runtime dependencies; distributed and launched as an escript.

### Non-goals (for the first version)

- No alternative rule sets (B3/S23 only). The engine is structured so a rule
  parameter could be added later, but it is out of scope now.
- No hashlife / quadtree engine. A sparse set is sufficient for the intended
  "cozy sandbox" scale; the engine sits behind a clean interface so it can be
  swapped later without touching the UI.
- No RLE import in v1. The pattern layer normalizes to a `Pattern` struct, which
  keeps an RLE importer cheap to add later, but it is not built now.
- No persistence / save-load of worlds.

## 2. Environment & constraints

- **Raw terminal input** uses OTP 28's native support. Enter raw mode with
  `:shell.start_interactive({:noshell, :raw})` — an escript runs `-noshell` by
  default, which is the required context (this cannot be toggled from inside
  IEx). Read input with `:io.get_chars/2` / `IO.getn/2`, which in raw mode
  returns as soon as any data is available, keystroke-by-keystroke, with no echo.
  The app is launched as an escript (`./conway`).
- **Restoring the terminal does NOT use a second `start_interactive` call.** A
  second call returns `{:error, :already_started}`, and there is no documented
  raw→cooked toggle. Per the official "Creating a terminal application" guide, the
  app resets only *display* state on exit (leave the alternate screen, show the
  cursor, reset keypad/SGR) inside an `after` block, and the **runtime restores
  the underlying cooked/line-discipline terminal state automatically when the BEAM
  shuts down**. The escript must therefore always reach a clean halt (see §16) for
  restoration to occur.
- **Input encoding:** read input as raw bytes (treat the result as a binary; use a
  byte-wise/`latin1` read rather than Unicode-codepoint counting). Control keys
  and the lexicon file are ASCII, so byte-wise reading is correct and avoids
  codepoint-vs-byte ambiguity.
- In raw mode we are fully responsible for all output: cursor movement, clearing,
  and drawing are done by emitting ANSI escape sequences ourselves (via `IO.ANSI`
  plus a few raw sequences). Following the official guide we also enable keypad
  transmit mode for consistent arrow-key sequences, and reset it on exit.
- No external processes (`stty`, `tput`) are shelled out to; everything goes
  through OTP/ANSI.

## 3. Architecture

**Pure core + thin impure shell**, run from a single escript process. No
supervision tree: if anything goes wrong the app should crash, but it must
*always* restore the terminal and print the error first.

### Runtime model

- The escript's **main process runs the controller loop** (`Conway.Loop`). It
  holds the `%State{}` struct, `receive`s events, applies them, renders, and
  performs effects. This is architecture "A" minus the GenServer/Supervisor
  ceremony, which an escript does not need.
- A separate **input reader process** (`Conway.Input`) loops on `IO.getn`,
  decodes bytes (including escape sequences) into events with a pure
  `decode/1`, and sends `{:input, event}` to the loop. It is linked to the loop.
- **Ticks** are driven by `Process.send_after(self(), :tick, ms)`, rescheduled
  after each tick at the current speed while playing. Speed is clamped to 1–60
  gen/sec with `ms = round(1000 / speed)`; `+`/`-` adjust within those bounds. At
  most one `:tick` is outstanding — if a render overruns the interval the pending
  tick is coalesced rather than queued, so a slow frame can't pile up backlog.
- **Guaranteed teardown:** the loop is wrapped so that every exit path — clean
  quit (`q`), an exception in the loop, or a crash of the linked input reader —
  routes through a single `Terminal.restore/0` (display-state reset, §15), after
  which the error and stacktrace (if any) are printed, then the program halts so
  the runtime restores cooked mode (§2, §16). The loop traps exits so a
  linked-reader crash becomes a handled message rather than a silent kill, and a
  `try/after` guarantees restore even on an uncaught raise. Because the line
  discipline is still raw at print time, the error output uses CRLF (`\r\n`) line
  endings to avoid staircasing.

### The pure heart

`Conway.App.update(state, event) -> {state, [cmd]}` is a **pure, total
function**. Every keypress, tick, mode change, and edit is expressed as a
transition over `(state, event)`. Effects are returned as data
(`{:tick_after, ms}`, `:quit`) for the loop to perform. Rendering is derived
from state separately (`Render.frame/1`). This makes essentially all behavior
testable with no terminal involved.

## 4. Module map

```
lib/conway/
  # ── pure core (zero IO, fully unit-tested) ──
  grid.ex          # sparse live-cell set: MapSet of {x, y} (bignum ints → infinite)
                   #   new, put, delete, toggle, alive?, stamp, erase, cells_in, population, bounds
  life.ex          # step/1 :: Grid -> Grid (B3/S23, sparse neighbor tally); step/2 for n steps
  pattern.ex       # %Pattern{name, description, cells, w, h}
                   #   from_ascii/3, rotate_cw/1, mirror_h/1, normalize/1, dot/0 (default 1-cell stamp)
  lexicon.ex       # parse/1 (string -> [Pattern], pure); load/0 (reads vendored priv file)
  catalog.ex       # navigable index over [Pattern]: current/at/next/prev/search(query)
  viewport.ex      # %Viewport{cam_x, cam_y, zoom, cols, rows}
                   #   world<->screen per zoom, visible_window, pan, center_on, zoom_in/out, resize
  cursor.ex        # %Cursor{x, y, stamp, visible?}; move, set_stamp, rotate, mirror, toggle
  app.ex           # PURE reducer: update(state, event) -> {state, [cmd]}  ← the heart, total
  state.ex         # %State{} aggregating all mutable state (see §5)
  render/
    render.ex      # frame(state) -> iolist (assembles bars + grid area + active overlay)
    full_block.ex  # zoom renderer: ██ / spaces; crisp cursor
    half_block.ex  # zoom renderer: ▀ ▄ █ + space
    braille.ex     # zoom renderer: U+2800 base, 2×4 dots
    bars.ex        # top + bottom bar formatting
    overlay.ex     # picker / freehand / help overlays
    diff.ex        # row-level diff: rewrite only changed rows (\e[r;1H + row + clear-to-eol)
  # ── thin impure shell ──
  terminal.ex      # raw enter/exit, alt-screen, hide cursor, size query, restore/0
  input.ex         # reader process: IO.getn bytes -> decode/1 (pure) -> {:input, event}
  loop.ex          # escript main loop: state + receive + effects + guaranteed teardown
  cli.ex           # escript main/1: arg parse, lexicon load, Terminal.setup, spawn input, run
priv/
  life-lexicon.txt # vendored Life Lexicon plaintext (see §10)
```

## 5. State

```elixir
%Conway.State{
  grid:          Grid.t,        # live cells
  viewport:      Viewport.t,    # cam + zoom (:full | :half | :braille) + cols/rows
  cursor:        Cursor.t,      # pos, stamp pattern, visible?
  playing?:      false,
  speed:         10,            # generations/sec → tick interval ms
  generation:    0,
  bars_visible?: true,
  mode:          :normal,       # :normal | :picker | :freehand | :help
  catalog:       Catalog.t,     # lexicon + current index
  picker:        nil,           # %{query, results, sel} when mode == :picker
  freehand:      nil,           # %{cells, cx, cy, w, h} when mode == :freehand
  cursor_pref:   true,          # remembered full-block cursor on/off across zoom changes
  last_frame:    []             # prior rows, for diff
}
```

## 6. Simulation engine

The grid is a sparse set of live cells: a `MapSet` of `{x, y}` integer tuples.
Elixir integers are arbitrary-precision, so the grid is genuinely infinite — no
bounds, no wraparound.

`Life.step/1` uses the standard sparse algorithm:

1. Build a neighbor-count map by, for every live cell, incrementing the count of
   each of its 8 neighbors.
2. A coordinate is live next generation iff its count is 3, or its count is 2 and
   it is currently live (B3/S23).
3. The next grid is the set of coordinates satisfying that rule.

The next generation is built **solely** from the neighbor-count map's keys; the
previous live set is never unioned in. That is precisely what makes isolated cells
die correctly — a live cell with 0 or 1 live neighbors is either absent from the
map (0 neighbors) or has count < 2 and is not re-added (1 neighbor).

Cost is `O(live × 8)`, which is comfortable at the intended scale. The rule is
isolated so a future variant could parameterize birth/survival sets.

## 7. Coordinates, viewport & zoom

World coordinates are integer `{x, y}`. The viewport is a camera over the world:
`cam_x/cam_y` (world coordinate at the top-left of the grid area), a `zoom`, and
the grid area's `cols`/`rows` in character cells.

Zoom maps Life cells to character cells, kept ~square (terminal cells are ~1 wide
: 2 tall):

| Zoom         | Glyphs            | Cell footprint        | Density        |
|--------------|-------------------|-----------------------|----------------|
| `:full`      | `██` / spaces     | 2 cols × 1 row / cell | 0.5 cells/char |
| `:half`      | `▀ ▄ █` + space   | 1 col × ½ row / cell  | 2 cells/char   |
| `:braille`   | `U+2800` + 2×4    | ½ col × ¼ row / cell  | 8 cells/char   |

Each step is a clean ~4× change in reach and preserves square cells. `Viewport`
provides world⇄screen mapping per zoom, the visible world rectangle
(`visible_window/1`, used to query only on-screen cells from the grid), panning,
recentering, and zoom that keeps a chosen focus point fixed (the cursor when it
is visible, otherwise the viewport center). On zoom-in back to full-block the
cursor is re-placed at (or clamped into) the viewport's focus point, never left at
a stale world coordinate that may now be off-screen.

**Braille dot mapping.** The 8 dots of a `U+2800`-based glyph are numbered
*column-first*, not row-major — a naive `row*2 + col` bitmask scrambles output.
For a 2-wide × 4-tall sub-cell block at `(col, row)`:

| (col,row) | dot | bit  |     | (col,row) | dot | bit  |
|-----------|-----|------|-----|-----------|-----|------|
| (0,0)     | 1   | 0x01 |     | (1,0)     | 4   | 0x08 |
| (0,1)     | 2   | 0x02 |     | (1,1)     | 5   | 0x10 |
| (0,2)     | 3   | 0x04 |     | (1,2)     | 6   | 0x20 |
| (0,3)     | 7   | 0x40 |     | (1,3)     | 8   | 0x80 |

The glyph codepoint is `0x2800 + Σ bits`. A golden test must assert a known
sub-bitmap (e.g. only the bottom-left dot lit → `U+2840`).

## 8. Rendering

`Render.frame/1` assembles the full screen as an iolist:

1. Top bar (if `bars_visible?`).
2. Grid area: `Grid.cells_in(visible_window)` handed to the renderer for the
   current zoom (`FullBlock` / `HalfBlock` / `Braille`), each producing rows of
   ANSI-styled glyphs.
3. Bottom bar (if `bars_visible?`).
4. Active overlay (picker / freehand / help), drawn over the grid area when
   `mode != :normal`.

**Diffing:** frames are compared to `last_frame` at row granularity. Only changed
rows are rewritten (`\e[{row};1H` + new row + clear-to-end-of-line), which keeps
output small and avoids flicker. Each rewritten row is **self-contained** — it
starts with explicit attributes and ends with an SGR reset (`\e[0m`) so colors
never bleed into adjacent rows that weren't rewritten. A full repaint is forced on
zoom change, resize, and overlay open/close.

**Clipping:** the stamp preview, and any lexicon pattern larger than the viewport,
is clipped to the visible window for *display*; placement still unions the full
pattern into the infinite grid.

**Color rules:**

- Live cells render in the "life" color; the cursor stamp preview renders in a
  distinct "cursor" color; background is the terminal default.
- A glyph in half/braille zoom can contain both live and cursor cells but has a
  single foreground color. The cursor is therefore **only shown at full-block
  zoom**, where each cell is its own glyph and the cursor stays pixel-crisp. At
  half/braille zoom the cursor is hidden entirely (see §9), so this ambiguity
  never arises.

## 9. Cursor & editing

- The cursor has a position, a current **stamp** (`Pattern`), and a `visible?`
  flag. While visible at full-block zoom, the stamp is previewed at the cursor in
  the cursor color.
- **Editing — placing and erasing — is allowed only at full-block zoom with the
  cursor visible.** Zooming out to half/braille auto-hides the cursor and
  disables editing; those zooms are view-only. Zooming back to full restores the
  cursor to the user's remembered on/off preference (`cursor_pref`).
- `c` toggles the cursor on/off at full-block zoom (and updates `cursor_pref`).
- The default stamp is a single cell (`Pattern.dot/0`), so `⏎` / `x` double as
  single-cell paint / erase; no separate brush tool is needed.
- Place unions the stamp's cells into the grid at the cursor; erase removes the
  stamp's footprint at the cursor.

## 10. Lexicon

### Source & format

The corpus is the **Life Lexicon** (Stephen Silver; maintained by Dave Greene at
`dvgrn/life-lexicon`), vendored as its plaintext distribution into
`priv/life-lexicon.txt`. Format:

- Each entry begins at column 0 with `:Name:` followed by description text. The
  description may include `{cross-references}` in braces and parenthetical
  metadata such as `(p30)`.
- Pattern diagrams are indented blocks whose lines contain only `.` (dead) and
  `*` (alive). A diagram block ends at a blank line or an unindented line.
- Many entries are pure concept definitions with no diagram; some entries contain
  multiple diagrams.

### Parsing

`Lexicon.parse/1` (pure) walks the file into entries and produces a
`[%Pattern{name, description, cells, w, h}]`:

- Capture the name from the `:Name:` header and the following description text.
- Map an indented `.`/`*` block to cell coordinates (origin-normalized).
- Skip entries that contain no diagram. For entries with multiple diagrams, take
  the first as the representative stamp (a future enhancement could expose the
  others).

`Lexicon.load/0` reads the vendored file and returns the parsed list; it is the
only impure function in the lexicon layer. `Catalog` wraps the list with a
current index plus `next/prev`, and `search(query)` for the picker.

### Attribution & licensing

The Life Lexicon is released under **Creative Commons Attribution-ShareAlike 3.0
(CC BY-SA 3.0)** — "copyright (C) Stephen Silver, 1997-2018" (updated by Dave
Greene and David Bell). Vendoring is therefore permitted with attribution. Keep
`priv/life-lexicon.txt` with its original copyright/license header intact, credit
Stephen Silver and Dave Greene in the README, and note that the bundled lexicon
**data** remains under CC BY-SA 3.0 (copyleft) while the application **code** may
carry its own separate license.

## 11. Stamp management

- **Cycle:** `]` / `[` move to the next / previous pattern in the catalog; the
  bottom bar shows the current name and description.
- **Picker:** `/` opens a searchable overlay listing patterns with type-to-filter
  search; `↑`/`↓` move the selection, `⏎` selects, `esc` cancels.
- **Transforms:** `r` rotates the stamp 90° CW; `f` mirrors it. Combined they
  reach all 8 orientations. Transforms operate on the current `Pattern`.
- **Freehand editor:** `e` toggles a small bounded canvas; arrows move the editor
  cursor, `space` toggles a cell, `⏎`/`e` saves the drawn cells as the new stamp,
  `c` clears, `esc` cancels.

## 12. Bars & wallpaper mode

- **Top bar:** title, play/pause state, generation count, population, speed, zoom
  level, cursor coordinates, and brief global hints (`? help`, `q quit`).
- **Bottom bar:** focused on the stamp — `stamp ▸ <name>`, a dim truncated
  description line, and the stamp/cycle/transform/edit key hints.
- `b` toggles both bars off. With the bars hidden the grid area reclaims those
  rows (the viewport grows to the full terminal height). Combined with the cursor
  off and the simulation playing, this is the "terminal wallpaper" view.

## 13. Input handling

`Conway.Input` reads raw bytes via `:io.get_chars`/`IO.getn` (as a binary; see §2
on encoding) and feeds them to a pure `decode/1` that maps byte sequences to
events and returns any unconsumed remainder so partial escape sequences are
buffered across reads:

- Single printable bytes → character events.
- `ESC [ A/B/C/D` → arrow up/down/right/left.
- `ESC [ 1;2 A/B/C/D` (and equivalents) → shifted arrows (viewport pan,
  best-effort; `HJKL` is the portable fallback, §14).
- `ESC [ {n} ; {m} R` → a cursor-position report (terminal size, §15), not a key.
- `\r` → enter; `\x7f`/`\b` → backspace; `\x03` → quit (Ctrl-C, in-band in raw
  mode).
- A bare trailing `ESC` with nothing after it → `decode/1` returns
  `{:incomplete, buffer}` rather than guessing.

**ESC disambiguation.** Because raw-mode reads can split an arrow sequence (`ESC`
in one read, `[ A` in the next), a pure `decode/1` cannot by itself tell a real
Escape key from the start of a CSI sequence. So `decode/1` stays pure and returns
`{:incomplete, buffer}` on a bare trailing `ESC`; the **impure reader** applies a
short timeout (~30–50 ms) — if no more bytes arrive, the buffered `ESC` is emitted
as the Escape key (close overlay); otherwise the bytes are decoded together. The
decoder is unit-tested independently of the timeout.

## 14. Keymap

| Keys                | Action                                                     |
|---------------------|------------------------------------------------------------|
| `␣` space           | play / pause                                               |
| `s`                 | step one generation (when paused)                          |
| `+` / `-`           | speed up / down                                            |
| `z` / `Z`           | zoom out / in; `1`/`2`/`3` = full / half / braille direct  |
| Arrows / `hjkl`     | move cursor 1 cell *(full-block only)*                     |
| `⇧`+Arrows / `HJKL` | pan viewport (any zoom); `HJKL` is the portable path       |
| `⏎`                 | place current stamp at cursor *(full-block, cursor on)*    |
| `x` / `⌫`           | erase stamp footprint at cursor *(full-block, cursor on)*  |
| `]` / `[`           | next / prev pattern in lexicon                             |
| `/`                 | open searchable pattern picker                             |
| `r` / `f`           | rotate 90° / mirror the stamp                              |
| `e`                 | toggle freehand stamp editor                               |
| `c`                 | toggle cursor on/off *(full-block)*                        |
| `b`                 | toggle bars (wallpaper mode)                               |
| `o` / `0`           | recenter on cursor / jump to origin                        |
| `?`                 | help overlay                                               |
| `q` / `Ctrl-C`      | quit (restores terminal)                                   |

Mode-specific keys (picker: type-to-filter, `↑↓`, `⏎`, `esc`; freehand: arrows,
`space`, `⏎`/`e`, `c`, `esc`; help: any key / `esc` closes) are handled within
those modes.

## 15. Terminal lifecycle

- **Setup:** enter raw mode, switch to the alternate screen buffer (`\e[?1049h`),
  enable keypad transmit mode, hide the terminal's own cursor (`\e[?25l`), clear.
- **Restore (display state only):** reset SGR, show cursor (`\e[?25h`), disable
  keypad transmit mode, and leave the alternate screen (`\e[?1049l`). This runs on
  every exit path (§3, §16) and is idempotent. The cooked/line-discipline state is
  **not** reset here — the runtime restores it on VM shutdown (§2), so the program
  must reach a clean halt.
- **Size:** the cursor-position-report (CPR) probe is the primary mechanism, since
  `:io.rows/0` / `:io.columns/0` have historically returned `{:error, :enotsup}`
  from a noshell/escript context (verify on the target build; use them only if
  confirmed working there). The probe writes `\e[999;999H\e[6n` (move far, then
  request position) and reads back `\e[{rows};{cols}R`. **The CPR reply must be
  consumed by the input decoder** (which recognizes the `\e[{n};{m}R` form, §13) so
  it is not mis-decoded as keystrokes or raced against early input. If a terminal
  does not clamp the far-move and returns literal `999`s, fall back to a sane
  default plus the manual refresh key.
- **Resize:** re-query size once per frame (compare the latest CPR/`:io.rows`
  result); on change, recompute the viewport's `cols`/`rows`, **re-layout any open
  overlay, re-clamp the cursor/camera**, and force a full repaint. Do **not**
  install a custom `SIGWINCH` handler — the runtime manages it. `Ctrl-L` forces a
  manual refresh + full repaint.

## 16. Error handling & teardown

The design is "let it crash" — but never leave the terminal wedged.

- The loop traps exits and wraps its body in `try/after`. Any of: clean quit, an
  uncaught exception in the loop, or an `{:EXIT, _, reason}` from the linked input
  reader, runs `Terminal.restore/0` (display-state reset, §15) in the `after`
  clause, then prints the error and stacktrace (if abnormal) and halts with a
  nonzero status. Reaching halt lets the runtime restore cooked mode (§2).
- **Ctrl-C:** in raw mode the terminal's signal generation (ISIG) is disabled, so
  Ctrl-C arrives in-band as the byte `\x03`, which the decoder maps to quit — the
  normal quit path, running the full teardown.
- **Out-of-band signals:** to cover the window *before* raw mode is active and any
  external `SIGINT`/`SIGTERM`, install an OS signal handler
  (`:os.set_signal(:sigint, :handle)` + a handler) that performs the same display
  restore and halts. `SIGKILL` cannot be intercepted; a wedged terminal after
  `kill -9` is the one accepted gap.
- There is no auto-restart.

## 17. Testing strategy

The impure surface is tiny by construction; almost all behavior is pure and
tested directly.

- **Engine** (`Grid`/`Life`): block stable, blinker period 2, glider returns to
  itself translated by `(1,1)` after 4 generations, population counts, and a lone
  live cell (and a cell with a single neighbor) both die. TDD.
- **`Pattern`:** `from_ascii` maps `*`→cell / `.`→empty; `rotate_cw` ∘4 ==
  identity; `mirror` ∘2 == identity; normalization to origin.
- **`Lexicon.parse/1`:** `:Name:` headers, description capture, multi-diagram
  entries, blank-line termination, diagram-less entries skipped. Plus `load/0`
  against the real vendored file: count over a threshold and known patterns
  (`glider`, `Gosper glider gun`) present and correct.
- **`Catalog`:** next/prev wraparound, search filtering.
- **`Viewport`:** world⇄screen round-trips per zoom, `visible_window`
  correctness, zoom-about-focus math.
- **Renderers:** golden tests — a small known grid + viewport + cursor → exact
  expected output per zoom; off-screen cells excluded; cursor shown only at
  full-block; the braille dot→bit mapping (§7) via a known sub-bitmap; large
  patterns clipped to the visible window.
- **`Diff`:** only changed rows rewritten; identical frames → no-op; rewritten
  rows are self-contained (no SGR color bleed into un-rewritten rows).
- **`Input.decode/1`:** arrows, shifted arrows, letters, enter, backspace, Ctrl-C,
  a bare trailing `ESC` → `{:incomplete, _}`, partial-escape buffering across
  reads, the cursor-position-report form `\e[{n};{m}R`, and a multi-byte UTF-8
  input under the chosen encoding.
- **`App.update/2`:** the centerpiece — synthetic event streams asserting
  transitions: play/pause flips `playing?` and emits `{:tick_after, ms}`; `s`
  advances generation only while paused; zoom-out hides cursor and rejects edits;
  place works only at full-block with cursor on; `/` opens and `esc` closes the
  picker; typing filters; rotate/mirror/cycle mutate the stamp; `b` toggles bars;
  `+`/`-` clamp speed to 1–60. Exhaustive, zero IO.
- **Shell** (`Terminal`/`Input`/`Loop`/`CLI`): deliberately thin; test the
  escape-string builders (setup/restore) rather than a live TTY; verify display
  restore runs even when the loop raises, and that the out-of-band SIGINT handler
  restores display state and halts.

## 18. Build milestones

Each is independently verifiable. The first two are pure; #3 is first on screen;
#5 is the first playable build.

1. **Engine core** — `Grid` + `Life`, TDD. ✅ blinker/glider tests pass.
2. **Patterns + lexicon** — `Pattern` + transforms; `Lexicon.parse`; vendor the
   plaintext file; `Catalog`. ✅ real file parses to ~685 patterns with
   glider/Gosper present.
3. **Viewport + full-block (static)** — `Viewport` + `FullBlock` + `Bars` +
   `Render.frame`; a throwaway `mix run` prints one static frame of a seeded
   glider. ✅ looks right + golden tests pass.
4. **Terminal + input** — raw setup/restore + `Input`/`decode`; a harness that
   enters raw mode and echoes decoded events until `q`. ✅ keys decode and the
   terminal always restores cleanly (including on a forced crash).
5. **Interactive MVP** — `Loop` + `App.update` wiring: cursor move, pan,
   place/erase (single-cell), play/pause/step/speed, quit, teardown. escript
   builds. ✅ hand-place a glider and watch it fly.
6. **Half-block + braille** — two renderers + zoom switching, cursor auto-hide on
   zoom-out, zoom-about-focus. ✅ all three zooms render and edit-locking holds.
7. **Stamp management** — `[`/`]` cycle + bottom bar; `r`/`f` transforms; `/`
   picker (search/select); `e` freehand editor. ✅ stamp a Gosper gun from the
   lexicon, search the picker, draw a custom stamp.
8. **Polish** — wallpaper toggle, help overlay, recenter/jump, size query + resize
   handling, colors, frame diffing, CLI args (e.g. `--speed`, a starting
   pattern), README + run instructions.

## 19. Future extensions (out of scope now)

- RLE importer (load Golly/`.rle` files and paste custom patterns), enabled by
  the normalized `Pattern` struct.
- Alternative rules (parameterized birth/survival).
- A faster engine (hashlife/quadtree) behind the same engine interface for very
  large patterns and big generation jumps.
- World save/load.
- Exposing multiple diagrams per lexicon entry.

## 20. References

- Life Lexicon source (CC BY-SA 3.0): https://github.com/dvgrn/life-lexicon
- Life Lexicon home: https://conwaylife.com/ref/lexicon/lex_home.htm
- OTP 28 raw terminal mode (forum): https://elixirforum.com/t/raw-terminal-mode-coming-to-otp-28/67491
- OTP "Creating a terminal application" guide: https://www.erlang.org/doc/apps/stdlib/terminal_interface.html
- `shell:start_interactive/1`: https://www.erlang.org/doc/apps/stdlib/shell.html
- Raw mode PR (erlang/otp #8962): https://github.com/erlang/otp/pull/8962
- `IO.ANSI`: https://elixir.hexdocs.pm/elixir/IO.ANSI.html
- Unicode Braille Patterns (dot numbering): https://en.wikipedia.org/wiki/Braille_Patterns
- Parser inspiration (Rust): https://github.com/scastiel/lexicon-rs
