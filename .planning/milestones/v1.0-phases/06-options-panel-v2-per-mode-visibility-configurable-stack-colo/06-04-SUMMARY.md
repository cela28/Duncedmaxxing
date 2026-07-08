---
phase: 06-options-panel-v2-per-mode-visibility-configurable-stack-colo
plan: 04
subsystem: ui
tags: [lua, wow-addon, options-panel, per-mode-visibility]

# Dependency graph
requires:
  - phase: 06-options-panel-v2-per-mode-visibility-configurable-stack-colo
    provides: Phase 6 UAT findings (widget-removal and per-mode-visibility gaps)
provides:
  - Scale and Border color widgets moved to bar-only visibility group
  - Enabled checkbox removed from options panel (DB field preserved)
  - Position Reset button and orphaned Tip:ResetPosition method removed
  - Verified /dmax has no mode subcommand (no-op confirmation)
affects: [06-options-panel-v2, 06-06 (final coordinate rebalancing)]

# Tech tracking
tech-stack:
  added: []
  patterns: []

key-files:
  created: []
  modified:
    - Duncedmaxxing/Options.lua
    - Duncedmaxxing/Modules/TipOfTheSpear.lua

key-decisions:
  - "Scale and Border color reassigned to the bar-only widget group rather than a new group; Refresh() show/hide engine was already correct and untouched"
  - "Enabled checkbox UI control removed but DEFAULTS.tip.enabled = true kept in Core.lua since shouldShow gate and two core_spec assertions depend on it"
  - "Position Reset button and its sole caller Tip:ResetPosition deleted together since no other reference existed (confirmed via spec grep)"

patterns-established: []

requirements-completed: [DISP-05, DISP-07]

# Metrics
duration: 5min
completed: 2026-07-06
status: complete
---

# Phase 06 Plan 04: Widget Removal and Per-Mode Visibility Gap Closure Summary

**Moved Scale/Border color to bar-only visibility, deleted the Enabled checkbox and position Reset button (plus its orphaned handler), confirmed no /dmax mode subcommand exists**

## Performance

- **Duration:** 5 min
- **Started:** 2026-07-06T20:50:37Z
- **Completed:** 2026-07-06T20:53:32Z
- **Tasks:** 3 completed
- **Files modified:** 2

## Accomplishments
- Number mode now correctly hides Scale and Border color inputs (text has no border, sizes via Text size) — closes UAT gap 1/2 (DISP-05)
- Enabled checkbox removed from the options panel while the underlying `tip.enabled` default and shouldShow gate remain intact (DISP-07)
- Position "Reset" button removed along with its now-dead `Tip:ResetPosition` handler; "Reset Style" button preserved
- Confirmed the `/dmax mode bar|number` slash subcommand gap was already closed in a prior commit — no code change needed

## Task Commits

Each task was committed atomically:

1. **Task 1: Move Scale and Border color to the bar-only visibility group** - `edf0628` (feat)
2. **Task 2: Remove the Enabled checkbox widget (keep the DB field)** - `0d448ef` (feat)
3. **Task 3: Remove the position Reset button and its orphaned handler** - `0072403` (feat)

_Note: All three tasks were straightforward deletions/reassignments; no TDD cycle was needed._

## Files Created/Modified
- `Duncedmaxxing/Options.lua` - Scale/Border color reassigned to bar-only group; Enabled checkbox deleted; position Reset button deleted
- `Duncedmaxxing/Modules/TipOfTheSpear.lua` - Orphaned `Tip:ResetPosition` method deleted

## Decisions Made
- Scale and Border color reassigned to the existing bar-only group (no new group needed) — the Refresh() show/hide engine was already correct
- Kept `DEFAULTS.tip.enabled = true` in Core.lua untouched; only the UI checkbox was removed, preserving the shouldShow gate and existing core_spec assertions
- Verified via grep that no spec file referenced `Tip:ResetPosition` before deleting it

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- All structural gates from the plan's `<verification>` section pass: `AddToGroup("both"` count = 4, Enabled setter absent, `Tip:ResetPosition` absent, "Reset Style" present exactly once, `enabled = true` still present in Core.lua
- Full fengari regression suite: 124 passed, 0 failed (matches pre-plan baseline; no regression from removing the untested ResetPosition method)
- Widget coordinates were intentionally left unrebalanced per plan instructions — final spacing rebalancing is deferred to plan 06-06
- Ready for the next plan in Phase 6 (per-mode visibility / configurable stack colors continuation)

---
*Phase: 06-options-panel-v2-per-mode-visibility-configurable-stack-colo*
*Completed: 2026-07-06*

## Self-Check: PASSED
