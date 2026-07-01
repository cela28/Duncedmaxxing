---
phase: 06-options-panel-v2-per-mode-visibility-configurable-stack-colo
plan: 03
subsystem: testing
tags: [lua, fengari, busted-style-spec, regression, config-defaults, rendering]

# Dependency graph
requires:
  - phase: 06-options-panel-v2-per-mode-visibility-configurable-stack-colo
    provides: "colorByStack toggle + stackColors defaults (Core.lua) and the config-driven number-mode render read (TipOfTheSpear.lua) from plan 01"
provides:
  - "Regression coverage proving colorByStack ON reads config-driven per-stack colors (including an edited-color case, not just hardcoded defaults)"
  - "Regression coverage proving colorByStack OFF applies the flat textColor fallback regardless of stack count"
  - "Regression coverage proving MergeDefaults fills missing colorByStack/stackColors, preserves user edits, and NormalizeDB does not wipe a legacy DB or bump settingsMigration when merging the new fields"
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "New spec cases extend existing describe blocks in place (no new spec files) to keep related assertions co-located, matching the existing spec organization convention"
    - "pcall used in place of unsupported assert.has_no.errors (the project's minimal assert shim in spec/support does not implement busted's full assert library)"

key-files:
  created: []
  modified:
    - spec/tip_spec.lua
    - spec/core_spec.lua

key-decisions:
  - "Used pcall(...) + assert.is_true(ok, ...) instead of assert.has_no.errors(...) since the fengari-based assert shim only implements a subset of busted's assertion API"
  - "Added a legacy-DB describe block (MergeDefaults + NormalizeDB — legacy DB gains colorByStack/stackColors with no wipe) rather than inserting into the existing 'already migrated' describe block, to isolate the full MergeDefaults->NormalizeDB pipeline assertion from the narrower single-function NormalizeDB cases already there"

patterns-established: []

requirements-completed: [DISP-06]

# Metrics
duration: 5min
completed: 2026-07-02
status: complete
---

# Phase 06 Plan 03: Regression Coverage for Configurable Stack Colors Summary

**Extended the fengari spec suite with 7 new assertions locking DISP-06's colorByStack toggle (config-driven ON, flat-fallback OFF) and the no-wipe default-merge of the new fields onto fresh and legacy DBs; full suite green at 124/124.**

## Performance

- **Duration:** 5 min
- **Started:** 2026-07-01T21:18:33Z
- **Completed:** 2026-07-01T21:21:35Z
- **Tasks:** 2 completed
- **Files modified:** 2

## Accomplishments
- `spec/tip_spec.lua` now proves colorByStack ON is genuinely config-driven: mutating `db.tip.stackColors[2]` to an arbitrary color and re-rendering shows the edited value, not a hardcoded constant — closing the gap the plan-01 summary flagged (only the default values were previously asserted).
- `spec/tip_spec.lua` now proves colorByStack OFF applies the flat `db.tip.textColor` fallback at both stack 1 and stack 3, confirming the OFF branch ignores stack count entirely.
- `spec/core_spec.lua` now proves `MergeDefaults` fills `colorByStack`/`stackColors` byte-for-byte when absent, preserves a user-set `colorByStack = false`, and preserves an edited `stackColors[1]` entry (fill-missing-only semantics, no clobbering).
- `spec/core_spec.lua` now proves the full `MergeDefaults` -> `NormalizeDB` pipeline on a legacy already-migrated DB (fields set, but `colorByStack`/`stackColors` absent) populates the new fields with no wipe of existing settings (`displayMode`, `x`, `y`, `scale`, `enabled`), no `settingsMigration` bump, and no runtime error.
- Full suite: 117 -> 124 tests, 0 failures.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add colorByStack ON/OFF number-color assertions to spec/tip_spec.lua** - `1aee7f6` (test)
2. **Task 2: Add colorByStack/stackColors default-merge + no-wipe assertions to spec/core_spec.lua** - `cd6ad2d` (test)

**Plan metadata:** (recorded below after this commit)

## Files Created/Modified
- `spec/tip_spec.lua` - Added 3 new `it(...)` cases to the existing "Tip:Update number mode color coding" describe block: one colorByStack-ON edited-color case, two colorByStack-OFF flat-textColor-fallback cases (stacks 1 and 3)
- `spec/core_spec.lua` - Added 3 new `it(...)` cases to the existing "MergeDefaults" describe block (fill-missing, preserve-false, preserve-edit) and 1 new describe block with a legacy-DB `MergeDefaults`->`NormalizeDB` no-wipe/no-error/no-bump case

## Decisions Made
- The project's spec assert shim (`spec/support`) does not implement `assert.has_no.errors`; used `pcall` + `assert.is_true(ok, ...)` instead to assert the merge/normalize pipeline does not raise on a legacy DB.
- Placed the legacy-DB pipeline case in its own new describe block rather than extending "NormalizeDB — already migrated branch" because it exercises both `MergeDefaults` and `NormalizeDB` together (the existing block only calls `NormalizeDB` directly on a fully-populated tip table), keeping the assertion's scope explicit.

## Deviations from Plan

None - plan executed exactly as written. (One test-shim compatibility adjustment: `assert.has_no.errors` is not available in this project's minimal assert implementation, so the equivalent `pcall`-based assertion was used instead — same behavior verified, no scope change.)

## Issues Encountered

- First run of the legacy-DB case failed with `attempt to index a nil value (field 'has_no')` because `spec/support`'s assert shim doesn't implement busted's `has_no.errors` matcher chain. Rewrote the assertion using `pcall` (Rule 1 — bug in test code, fixed inline, re-verified green before continuing).

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- DISP-06 (configurable stack colors) is now fully covered end-to-end: data layer (plan 01), UI widgets (plan 02), and regression coverage locking both the render toggle and the no-wipe default-merge (plan 03).
- Full fengari suite passes at 124/124 with zero regressions across the whole phase's three plans.
- No blockers. Phase 06 plans are all complete; ready for phase-level verification/UAT.

---
*Phase: 06-options-panel-v2-per-mode-visibility-configurable-stack-colo*
*Completed: 2026-07-02*
