---
phase: 06-options-panel-v2-per-mode-visibility-configurable-stack-colo
plan: 05
subsystem: ui
tags: [lua, wow-addon, savedvariables, options-panel, color-picker]

# Dependency graph
requires:
  - phase: 06-options-panel-v2-per-mode-visibility-configurable-stack-colo
    provides: Options.lua per-stack color picker widgets (ColorToHex, ParseHexColor) that read named-key r/g/b/a color tables
provides:
  - DEFAULTS.tip.stackColors in named-key { r=, g=, b=, a= } form for all four stack-color entries [0]..[3]
  - Bumped SETTINGS_MIGRATION token ("0.3.3-stackcolorfmt") that re-seeds any persisted positional-shape stackColors DB into named-key form on load
affects: [06-UAT re-run, any future phase touching stackColors defaults or the migration branch]

# Tech tracking
tech-stack:
  added: []
  patterns: ["Named-key {r,g,b,a} is now the canonical DEFAULTS color-table shape across the whole DEFAULTS.tip tree, including stackColors"]

key-files:
  created: []
  modified:
    - Duncedmaxxing/Core.lua
    - spec/core_spec.lua

key-decisions:
  - "Converted DEFAULTS.tip.stackColors[0..3] from positional {r,g,b,a} arrays to named-key {r=,g=,b=,a=} tables — the root cause of the Phase 6 UAT gap (all four stack color inputs rendering ffffff) was that Options.lua's ColorToHex reads color.r/.g/.b/.a while the old defaults were positional, so ToByte(nil) fell back to 1.0 for every channel"
  - "Bumped SETTINGS_MIGRATION from 0.3.2-fontfix to 0.3.3-stackcolorfmt so the NormalizeDB migration branch re-seeds any already-persisted positional stackColors into the new named-key form on next load"
  - "Left ColorTuple (TipOfTheSpear.lua) and STACK_COLORS untouched — the renderer already reads both positional and named shapes, so no renderer change was needed or made"
  - "Accepted the known migration-bump tradeoff: bumping SETTINGS_MIGRATION resets other persisted style fields (fill/border/text colors, sizes) to defaults on first load post-update, since the migration branch only special-cases x/y/scale/optionsX/optionsY — this matches the established behavior of the prior migration bump and is the sanctioned mechanism"

requirements-completed: [DISP-06]

# Metrics
duration: 4min
completed: 2026-07-06
status: complete
---

# Phase 6 Plan 05: Fix stack-color defaults format mismatch Summary

**Converted DEFAULTS.tip.stackColors from positional arrays to named-key {r,g,b,a} tables and bumped SETTINGS_MIGRATION so the four per-stack color inputs in Options.lua now display their real default colors (white/green/yellow/red) instead of all reading as ffffff.**

## Performance

- **Duration:** 4 min
- **Started:** 2026-07-06T20:54:00Z
- **Completed:** 2026-07-06T20:58:23Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Fixed the DISP-06 gap from 06-UAT.md test 3: all four stack-color inputs now expose their intended default colors to Options.lua's ColorToHex instead of falling back to white
- Bumped SETTINGS_MIGRATION so any DB already persisted with the old positional stackColors shape self-heals into named-key form on next load, with no user action required
- Updated core_spec.lua assertions to match the new named-key format and new migration token; full regression suite remains green (124/124)

## Task Commits

Each task was committed atomically:

1. **Task 1: Convert DEFAULTS.tip.stackColors to named-key form and bump the migration token** - `88dfe40` (fix)
2. **Task 2: Update core_spec.lua assertions for named-key stackColors and the new migration token** - `e215b41` (test)

**Plan metadata:** (this commit, following SUMMARY.md creation)

## Files Created/Modified
- `Duncedmaxxing/Core.lua` - DEFAULTS.tip.stackColors[0..3] converted to named-key {r=,g=,b=,a=} tables (numeric values unchanged); SETTINGS_MIGRATION bumped to "0.3.3-stackcolorfmt"
- `spec/core_spec.lua` - stackColors assertions switched from positional [1..4] indexing to named r/g/b/a key comparison in three describe blocks; all six hardcoded migration-token literals updated to the new token

## Decisions Made
- Named-key form was chosen over converting the renderer to positional, since ColorTuple in TipOfTheSpear.lua already reads both shapes and Options.lua's ColorToHex only reads named keys — named-key is the format both consumers need, and it matches every other color default in DEFAULTS.tip (fillColor, emptyColor, borderColor, textColor already use named keys)
- The migration-bump tradeoff (other persisted style fields reset to defaults) was accepted as-is per plan guidance, matching the established precedent of the prior migration bump (0.3.2-fontfix)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None - the fix was a direct format conversion as diagnosed in 06-UAT.md; the fengari suite passed on the first run after the assertion updates.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- DISP-06 gap closed; ready for 06-UAT re-run to confirm the four stack inputs visually read as ffffff (0), 2ecc71 (1), fff000 (2), and ff4c30 (3) in-game
- `spec/tip_spec.lua` still exercises stackColors via a positional array assignment (`db.tip.stackColors[2] = {0.5, 0.25, 0.75, 1}`) to prove the renderer is format-agnostic — this was intentionally left untouched as it is outside this plan's `files_modified` scope and continues to pass because ColorTuple reads both shapes
- No blockers

## Self-Check: PASSED

All claimed files and commits verified present.
</content>
