---
phase: 06-options-panel-v2-per-mode-visibility-configurable-stack-colo
plan: 01
subsystem: ui
tags: [lua, wow-addon, config-defaults, rendering]

# Dependency graph
requires:
  - phase: 05-refactor-display-modes-remove-icon-mode-and-add-a-bar-text-m
    provides: bar/number displayMode set, no-migration default-merge philosophy
provides:
  - DEFAULTS.tip.colorByStack boolean (default true) in Core.lua
  - DEFAULTS.tip.stackColors nested sub-table (keys 0-3) in Core.lua, byte-for-byte the prior hardcoded STACK_COLORS values
  - Config-driven per-stack number-mode color read in TipOfTheSpear.lua replacing the hardcoded STACK_COLORS read
affects: [06-02-options-panel-v2-plan (widgets), 06-03-options-panel-v2-plan (spec coverage)]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Nested DEFAULTS sub-table merged recursively via existing MergeDefaults — no migration bump needed for new fields"
    - "ColorTuple(color, fallback) used defensively on both branches so a missing/malformed config value falls back to a hardcoded constant instead of nil-indexing"

key-files:
  created: []
  modified:
    - Duncedmaxxing/Core.lua
    - Duncedmaxxing/Modules/TipOfTheSpear.lua

key-decisions:
  - "stackColors stored as array-indexed RGBA tuples (matching source STACK_COLORS shape) rather than r/g/b/a keys — ColorTuple reads both shapes so Options.lua hex inputs (plan 02) can still write r/g/b/a"
  - "cfg.colorByStack treated as ON when nil (only explicit false disables it), matching D-01's default-true intent without requiring MergeDefaults to have already run"

patterns-established:
  - "Config-driven render branch reuses the exact ColorTuple(cfg.field, DMX.defaults.tip.field) fallback idiom already established in RefreshLayout's textColor read"

requirements-completed: [DISP-06]

# Metrics
duration: 3min
completed: 2026-07-02
status: complete
---

# Phase 06 Plan 01: Data-Layer Foundation for Configurable Stack Colors Summary

**Added `colorByStack` toggle + `stackColors` defaults to Core.lua and wired the number-mode render path in TipOfTheSpear.lua to read them, with hardcoded-fallback safety on both branches.**

## Performance

- **Duration:** 3 min
- **Started:** 2026-07-01T21:06:10Z
- **Completed:** 2026-07-01T21:08:33Z
- **Tasks:** 2 completed
- **Files modified:** 2

## Accomplishments
- `DEFAULTS.tip` now has `colorByStack = true` and a nested `stackColors` sub-table (keys 0-3) whose four RGBA tuples are byte-for-byte the prior hardcoded `STACK_COLORS` values — no visual change for existing users, no `SETTINGS_MIGRATION` bump.
- Number-mode render in `Tip:Update` now branches on `cfg.colorByStack`: ON (default/nil) resolves the per-stack color from `cfg.stackColors` via `ColorTuple` with a `STACK_COLORS` fallback; OFF applies the flat `cfg.textColor` through the same `ColorTuple` fallback idiom already used in `RefreshLayout`.
- Bar-mode rendering and the module-local `STACK_COLORS` fallback table are untouched.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add colorByStack + stackColors defaults to DEFAULTS.tip in Core.lua** - `21b531a` (feat)
2. **Task 2: Replace hardcoded STACK_COLORS read with config read in number-mode render path** - `8d1206f` (feat)

**Plan metadata:** (recorded below after this commit)

_Note: both tasks were marked `tdd="true"` in the plan; existing regression coverage (`spec/tip_spec.lua` "Tip:Update number mode color coding") already asserts the four default per-stack colors byte-for-byte, so no new RED test was required to prove this plan's `must_haves` — the existing suite serves as the GREEN gate. Plan 03 adds the new OFF-fallback and merge-idempotency assertions._

## Files Created/Modified
- `Duncedmaxxing/Core.lua` - Added `colorByStack` boolean and nested `stackColors` sub-table to `DEFAULTS.tip`
- `Duncedmaxxing/Modules/TipOfTheSpear.lua` - Number-mode render branch in `Tip:Update` now reads `cfg.colorByStack`/`cfg.stackColors` instead of the hardcoded `STACK_COLORS` table unconditionally

## Decisions Made
- Used array-indexed RGBA tuples for `stackColors` entries (matching the existing `STACK_COLORS` shape) rather than `r/g/b/a`-keyed tables, per the plan's Task 1 action and the Context doc's "Claude's Discretion" note — `ColorTuple` already reads both shapes, so plan 02's hex-input widgets (which write `r/g/b/a`) will resolve correctly too.
- Treated `cfg.colorByStack == nil` as ON (only explicit `false` disables per-stack coloring), matching D-01's "toggle defaults ON" intent and keeping behavior correct even before `MergeDefaults` has populated the field on a very old DB snapshot.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 02 (Options.lua widgets) can now read/write `db.tip.colorByStack` and `db.tip.stackColors[0..3]` — both fields are populated by `MergeDefaults` on load with no migration required.
- Plan 03 (spec coverage) can add merge-idempotency and colorByStack-OFF-fallback assertions against the now-existing config fields and render branch.
- No blockers.

---
*Phase: 06-options-panel-v2-per-mode-visibility-configurable-stack-colo*
*Completed: 2026-07-02*
