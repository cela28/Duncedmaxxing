---
status: complete
phase: quick
plan: 260622-hmo
subsystem: tip-of-the-spear
tags: [ui, color-coding, number-mode, tdd]
dependency_graph:
  requires: []
  provides: [per-stack-color-coding]
  affects: [Duncedmaxxing/Modules/TipOfTheSpear.lua]
tech_stack:
  added: []
  patterns: [STACK_COLORS lookup table, per-stack SetTextColor in Update]
key_files:
  created: []
  modified:
    - Duncedmaxxing/Modules/TipOfTheSpear.lua
    - spec/support/wow_stubs.lua
    - spec/tip_spec.lua
decisions:
  - "Hardcoded STACK_COLORS table (no user config) -- colors are fixed constants for instant visual recognition"
  - "SetTextColor applied after SetText in Update() number mode block, before Show()"
metrics:
  duration: 196s
  completed: 2026-06-22
---

# Quick Task 260622-hmo: Add Per-Stack Color Coding for Number Display Mode Summary

**One-liner:** STACK_COLORS lookup table with white/green/yellow/red per stack count, applied via SetTextColor in Update() number mode block

## What Changed

Added per-stack color coding for the number display mode in TipOfTheSpear. When `displayMode` is `"number"`, the text color changes based on current stack count:

| Stacks | Color | RGBA |
|--------|-------|------|
| 0 | White | (1, 1, 1, 1) |
| 1 | Green (#2ECC71) | (0.18039, 0.80000, 0.44314, 1) |
| 2 | Yellow (#FFF000) | (1, 0.94118, 0, 1) |
| 3 | Red/Orange (#FF4C30) | (1, 0.29804, 0.18824, 1) |

Bar and icon display modes are completely unaffected.

## Task Completion

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add SetTextColor tracking to wow_stubs and write color-coding tests (RED) | 18bffa7 | spec/support/wow_stubs.lua, spec/tip_spec.lua |
| 2 | Implement STACK_COLORS table and apply in Update() (GREEN) | 329a69d | Duncedmaxxing/Modules/TipOfTheSpear.lua, spec/tip_spec.lua |

## TDD Gate Compliance

- RED gate: `test(260622-hmo)` commit `18bffa7` -- 3 tests failed as expected (stacks 1/2/3 colors not implemented)
- GREEN gate: `feat(260622-hmo)` commit `329a69d` -- all 47 tests pass (42 existing + 5 new)
- REFACTOR gate: not needed -- implementation is minimal (6 lines of new code)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed test setup missing showOnlyInCombat=false**
- **Found during:** Task 2 (GREEN phase)
- **Issue:** Tests failed because `showOnlyInCombat` defaulted to `true`, causing `Update()` to hide the frame and return early before reaching the STACK_COLORS color path
- **Fix:** Added `db.tip.showOnlyInCombat = false` in the test `before_each` block
- **Files modified:** spec/tip_spec.lua
- **Commit:** 329a69d

## Verification

- `busted spec/tip_spec.lua`: 47 successes / 0 failures / 0 errors
- `luacheck Duncedmaxxing/Modules/TipOfTheSpear.lua --config .luacheckrc`: 0 warnings / 0 errors
- `grep -c "STACK_COLORS" Duncedmaxxing/Modules/TipOfTheSpear.lua`: 2 (definition + usage)
- `grep -c "_textColor" spec/tip_spec.lua`: 8 (assertions across all 5 color tests)

## Known Stubs

None -- all colors are hardcoded constants with no placeholder values.

## Self-Check: PASSED
