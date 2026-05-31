# Conway — Implementation Roadmap

Incremental, phase-by-phase build of the interactive terminal Game of Life.
The authoritative design is the spec; this index tracks which phase each plan
covers and its status. Progress within a phase lives in that plan's `- [ ]`
checkboxes (committed to git).

- **Spec:** [`../specs/2026-05-31-conway-tui-design.md`](../specs/2026-05-31-conway-tui-design.md) — see **§18 Build milestones** for the full arc.

| Phase | Milestones (spec §18) | Plan | Status |
|-------|-----------------------|------|--------|
| 1 | 1–3: Grid+Life engine · Pattern+Lexicon+Catalog · Viewport + static full-block render | [`2026-05-31-phase-1-pure-core.md`](2026-05-31-phase-1-pure-core.md) | Not started |
| 2 | 4–5: Terminal + Input · Interactive MVP (Loop + App reducer) | _to be written after Phase 1_ | Pending |
| 3 | 6–7: Half-block + Braille renderers · Stamp management (cycle/picker/transform/freehand) | _to be written after Phase 2_ | Pending |
| 4 | 8: Polish (wallpaper, help, recenter, resize, colors, diffing, CLI args, README) | _to be written after Phase 3_ | Pending |

**Workflow:** plan the current phase only (grounded in existing code) → execute via
superpowers TDD → check off steps → write the next phase's plan. Update the
Status column as phases complete.
