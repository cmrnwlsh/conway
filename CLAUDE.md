# CLAUDE.md

Conway — an interactive Conway's Game of Life simulation rendered in the terminal
with a hand-rolled, dependency-free TUI. Elixir 1.19.5 / OTP 28.

## Hard constraints
- **Zero RUNTIME dependencies.** The shipped artifact is an escript; nothing goes
  into `deps` without `runtime: false` (dev/test-only tooling like Credo is fine).
  The renderer and input layer are hand-written (ANSI + OTP 28 raw mode) — no TUI
  framework.
- **OTP 28 raw mode** via `:shell.start_interactive({:noshell, :raw})`. The
  terminal's cooked state is restored by the runtime on VM halt (NOT by a second
  `start_interactive` call); the app only resets display state in an `after`
  block. See spec §2 / §15 / §16.
- Infinite grid = a sparse `MapSet` of `{x, y}` (arbitrary-precision ints). No
  fixed bounds, no wraparound.

## Commands — the quality gate (all must pass before commit/merge)
- `mix test` — full suite.
- `mix lint` — Credo strict (`credo --strict`); keep at **0 issues**.
- `mix format --check-formatted` — formatting clean.
- `mix run -e "Conway.Demo.run()"` — prints the temporary static-render demo
  (replaced by `Conway.Loop` in Phase 2).

## How this project is built — read this to resume
Built incrementally, one **phase** at a time. Durable source of truth (in git):
- **Spec:** `docs/superpowers/specs/2026-05-31-conway-tui-design.md` — §18 is the
  phase roadmap; §3–§16 are the design.
- **Plans:** `docs/superpowers/plans/` — one per phase, bite-sized TDD tasks with
  `- [ ]` checkboxes (ticked = done). Index + status:
  `docs/superpowers/plans/README.md`.
- **To re-orient a fresh session:** recall project memory → read spec §18 → the
  roadmap index → the in-progress plan's checkboxes → skim new modules → run the
  quality gate.

Per-phase workflow: write the phase plan (grounded in existing code) → execute
(TDD, fresh subagent per task + spec/quality review) → keep the gate green →
merge to `main` → mark the roadmap Done.

## Architecture
Pure core + thin impure shell (spec §3–§4). Pure modules — `Grid`, `Life`,
`Pattern`, `Lexicon`, `Catalog`, `Viewport`, `Cursor`, `Render.*` — have zero IO
and are unit-tested directly. The impure shell (`Terminal`, `Input`, `Loop`, and
the `App` reducer — Phase 2+) stays thin. `Conway.App.update/2` is the pure,
total reducer over `(state, event)`; effects are returned as data.

## Conventions
- **TDD**: test first; verify behavior by running, never by claim.
- **Credo-clean code**: alias groups alphabetical; max nesting depth 2 (extract
  private helpers); no over-long lines (`mix format`).
- **Git**: a short feature branch per phase (`phase-N-*` / `chore/*`); merge to
  `main` only when the gate is green; do not commit straight to `main`.
  Commit-message trailer: `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.
- Cross-phase carry-forward notes live in project memory (e.g. Phase 3 half/braille
  renderers should render via `Grid.cells_in(Viewport.visible_window(vp))`).

## Licensing
- `priv/life-lexicon.txt` is the Life Lexicon, **CC BY-SA 3.0** (© Stephen Silver,
  updated by Dave Greene & David Bell). Keep its header intact and attribute them;
  the data is copyleft.
- The **code** license is not yet chosen (the repo will be public / open source).
  Choose one before publishing and note the BY-SA-data vs code-license interaction.
  README attribution is a Phase 4 (Polish) item.
