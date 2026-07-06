---
phase: 06-options-panel-v2-per-mode-visibility-configurable-stack-colo
plan: 06
subsystem: ui
tags: [lua, wow-addon, options-panel, layout]

# Dependency graph
requires:
  - phase: 06-options-panel-v2-per-mode-visibility-configurable-stack-colo
    provides: "06-04 freed grid slots by deleting the Enabled checkbox and position Reset button and moving Scale/Border color into the bar-only group; 06-05 standardized stackColors to named-key form"
provides:
  - "Rebalanced two-column absolute layout in Options.lua with no large dead region in either Bar or Number mode"
  - "Window height reduced from 484 to 400 (width unchanged at 386)"
  - "LEFT_X/RIGHT_X column constants for future layout maintenance"
affects: [options-panel, ui-polish]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Mutually-exclusive mode-specific widgets (bar-only vs number-only) intentionally share identical SetPoint row coordinates since they are never shown at the same time — this collapses the layout to the height of whichever mode is active instead of reserving separate vertical space for both"

key-files:
  created: []
  modified:
    - Duncedmaxxing/Options.lua

key-decisions:
  - "Overlapped Bar-section and Number-section widgets (and their headers) at the same left-column row coordinates, and overlapped bar color fields with number text/stack color fields at the same right-column row coordinates, since each pair is mutually exclusive by displayMode"
  - "Moved Hide Empty checkbox from an isolated (260,-80) offset to the right column's top row (204,-80), reclaiming a coherent slot instead of leaving it floating between columns"
  - "Moved Number/TextSize/ColorByStack widgets from the right column to the left column (same x as Bar's equivalents) so each column's content length depends on which single section is active, not on the union of both"
  - "Shrunk window height 484 -> 400 now that overlap removed the need for two full-height mode-specific columns"

patterns-established:
  - "Row-sharing for mutually-exclusive display-mode widgets: same (x,y) SetPoint reused across bar-only and number-only widget pairs in Options.lua BuildWindow"

requirements-completed: [DISP-07]

# Metrics
duration: 10min
completed: 2026-07-06
status: complete
---

# Phase 06 Plan 06: Options Panel Layout Rebalance Summary

**Rebalanced the options-panel two-column grid by overlapping mutually-exclusive Bar/Number section rows, closing the large dead regions UAT flagged in both display modes and shrinking the window from 386x484 to 386x400.**

## Performance

- **Duration:** 10min
- **Started:** 2026-07-06T20:57:00Z
- **Completed:** 2026-07-06T21:07:10Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments
- Eliminated the Bar-mode upper-right dead block (previously y=-120..-238 in the right column) by moving the Colors section header up to y=-108, directly under the Hide Empty toggle
- Eliminated the Number-mode left-column dead block (previously y=-178..-414) by relocating the Number header, Text size input, and Color by stack checkbox into the left column, sharing row coordinates with the equivalent Bar-only widgets (Bar header, Scale, Width)
- Reclaimed the vacated ~y=-80 row (former Enabled checkbox) for the repositioned Hide Empty checkbox, and tightened all remaining rows to a consistent 28px grid
- Reduced window height from 484 to 400 (12% shorter) while keeping width at 386 and all widget behavior, closures, and group memberships unchanged

## Task Commits

Each task was committed atomically:

1. **Task 1: Rebalance the options-panel layout and tighten empty space** - `ca2f8ea` (fix)

**Plan metadata:** (this commit, following)

## Files Created/Modified
- `Duncedmaxxing/Options.lua` - Repositioned all Position/Bar/Number/Colors section widgets onto a shared 28px row grid with mutually-exclusive widgets overlapping coordinates; reduced window height from 484 to 400; added LEFT_X/RIGHT_X constants

## Decisions Made
- Bar-only and Number-only widgets never render simultaneously (gated by `displayMode` in `Options:Refresh`'s `SetWidgetShown` calls), so giving them identical `SetPoint` coordinates is safe and collapses unused vertical space automatically per active mode, without needing runtime-conditional positioning logic
- Kept the "Colors" header in both the `bar` and `number` widget groups (unchanged from before) since it is effectively always shown once a mode is active; only repositioned it earlier in the flow, directly below Hide Empty, so it isn't stranded below an invisible Number section in Bar mode
- Extracted `LEFT_X = 16` / `RIGHT_X = 204` constants (minimal footprint) per the project's `ALL_CAPS_SNAKE_CASE` constant convention, without introducing a full row-offset constant table that would have ballooned the diff for a one-task cosmetic plan

## Deviations from Plan

None - plan executed exactly as written. The plan explicitly suggested "lift the right-column Colors section up" and "pull the Number section up so Number mode is compact" as example approaches; the row-sharing technique implements both suggestions simultaneously by collapsing Bar/Number (and their Colors sub-fields) onto identical coordinates rather than merely shifting them to new distinct positions.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Options panel layout work for Phase 06 is now complete (this was the final gap-closure plan, wave 2, depending on 06-04)
- Visual confirmation (opening the panel in-game in both Bar and Number modes, dragging the window) is out of automated scope and should be done at the Phase 06 UAT re-run
- No blockers for closing out Phase 06

---
*Phase: 06-options-panel-v2-per-mode-visibility-configurable-stack-colo*
*Completed: 2026-07-06*

## Self-Check: PASSED

- FOUND: Duncedmaxxing/Options.lua
- FOUND: .planning/phases/06-options-panel-v2-per-mode-visibility-configurable-stack-colo/06-06-SUMMARY.md
- FOUND commit: ca2f8ea
