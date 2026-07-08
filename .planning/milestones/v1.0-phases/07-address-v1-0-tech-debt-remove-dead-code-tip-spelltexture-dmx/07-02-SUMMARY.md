---
phase: 07-address-v1-0-tech-debt-remove-dead-code-tip-spelltexture-dmx
plan: 02
subsystem: testing
tags: [lua, wow-addon, dead-code-removal, fengari]

# Dependency graph
requires:
  - phase: 07-address-v1-0-tech-debt-remove-dead-code-tip-spelltexture-dmx (plan 01)
    provides: hasPrimalSurge/spellTexture removal, ClassifySpellID test export, generator-branch comment fix
provides:
  - DMX.Util.ParseOnOff fully removed (function, export, and 15-test describe block)
  - Documented intent comment on the db.locked = true migration line in NormalizeDB
affects: [v1.0-milestone-audit-closure]

# Tech tracking
tech-stack:
  added: []
  patterns: []

key-files:
  created: []
  modified:
    - Duncedmaxxing/Util.lua
    - spec/util_spec.lua
    - Duncedmaxxing/Core.lua

key-decisions:
  - "D-05: Removed DMX.Util.ParseOnOff (local function, export, and its 15-test describe block) with zero production callers remaining — slash interface has been settings-only since quick task 260624-0hx"
  - "D-07: No logic change to db.locked = true — added a two-line intent comment above it documenting the deliberate post-migration re-lock, matching the pre-existing passing test in spec/core_spec.lua"

patterns-established: []

requirements-completed: [D-05, D-07]

# Metrics
duration: 2min
completed: 2026-07-09
status: complete
---

# Phase 07 Plan 02: Remove ParseOnOff + Document db.locked Migration Summary

**Removed the dead DMX.Util.ParseOnOff slash-parser utility and its 15-test spec block, then documented the deliberate db.locked = true migration side effect with an intent comment (no logic change).**

## Performance

- **Duration:** 2min
- **Started:** 2026-07-08T21:30:57Z
- **Completed:** 2026-07-08T21:32:05Z
- **Tasks:** 2 completed
- **Files modified:** 3

## Accomplishments
- `DMX.Util.ParseOnOff` (local function + export) fully removed from `Duncedmaxxing/Util.lua`; `Trim`, `Clamp`, `ParseHexColor` untouched and still exported
- Entire `describe("DMX.Util.ParseOnOff", ...)` block (15 `it()` tests) deleted from `spec/util_spec.lua`, and the file-header comment updated to drop the removed symbol
- `db.locked = true` line in `Core.lua`'s `NormalizeDB` migration-gate block retained verbatim, with a new two-line comment documenting the deliberate re-lock-after-migration intent (D-07) — no other line in the migration block touched
- Full fengari suite green after each task commit (111 passed, 0 failed)

## Task Commits

Each task was committed atomically:

1. **Task 1: Remove DMX.Util.ParseOnOff fully (D-05)** - `de1317f` (refactor)
2. **Task 2: Document the db.locked migration intent (D-07)** - `b11a323` (docs)

**Plan metadata:** (pending — recorded after this summary is committed)

## Files Created/Modified
- `Duncedmaxxing/Util.lua` - Removed the `ParseOnOff` local function and its `Util.ParseOnOff` export; `Trim`/`Clamp`/`ParseHexColor` unchanged
- `spec/util_spec.lua` - Deleted the 15-test `DMX.Util.ParseOnOff` describe block and dropped "ParseOnOff" from the file-header comment
- `Duncedmaxxing/Core.lua` - Added a two-line intent comment above `db.locked = true` inside `NormalizeDB`'s migration-gate block; no logic change

## Decisions Made
- D-05: Confirmed via `grep -rn "ParseOnOff" Duncedmaxxing/ spec/` (both before and after) that zero production callers existed prior to deletion and zero references remain after — safe, fully isolated removal.
- D-07: Chose a two-line comment (over a single-line inline comment) to state both the "why" (prevent accidental drag after layout defaults change) and reference the decision ID (D-07) for future audit traceability, per CONTEXT.md's explicit discretion grant on comment length.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None. The suite count (111 passed after this plan) reflects the cumulative state after plan 07-01 (which had already reduced the total from the phase-start baseline of 125 via its own deletions) plus the 15 ParseOnOff tests removed in this plan's Task 1 — consistent with the plan's acceptance criterion of "total drops by exactly 15 ParseOnOff tests" relative to the pre-Task-1 count.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- D-05 and D-07 are both closed; the only remaining phase-07 tech-debt items (if any) are tracked in `07-01-SUMMARY.md` or the phase's remaining plan(s).
- No blockers. Full fengari suite green (111 passed, 0 failed) after both task commits.

---
*Phase: 07-address-v1-0-tech-debt-remove-dead-code-tip-spelltexture-dmx*
*Completed: 2026-07-09*

## Self-Check: PASSED

All created/modified files confirmed present on disk; both task commits (de1317f, b11a323) confirmed in git log.
