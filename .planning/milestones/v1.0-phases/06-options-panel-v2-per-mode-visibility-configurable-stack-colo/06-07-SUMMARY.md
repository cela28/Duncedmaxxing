---
phase: 06-options-panel-v2-per-mode-visibility-configurable-stack-colo
plan: 07
subsystem: infra
tags: [lua, wow-addon, savedvariables, migration, regression-test, fengari]

# Dependency graph
requires:
  - phase: 06-options-panel-v2-per-mode-visibility-configurable-stack-colo
    provides: "06-05's SETTINGS_MIGRATION token bump (0.3.3-stackcolorfmt) that activated the latent blanket-wipe bug"
provides:
  - "NormalizeDB migration branch that preserves every customized tip.* field across a SETTINGS_MIGRATION token bump"
  - "StackColorsAreLegacyFormat helper for detecting old positional-tuple stackColors shape"
  - "Regression test exercising the real migration branch with the shipped v1.0.0 token (0.3.2-fontfix)"
affects: [core, savedvariables, migration, settings]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Targeted field re-seed on migration instead of blanket CopyDefaults(DEFAULTS.tip) overwrite — only repair fields whose shape actually changed"

key-files:
  created: []
  modified:
    - Duncedmaxxing/Core.lua
    - spec/core_spec.lua

key-decisions:
  - "StackColorsAreLegacyFormat detects legacy shape by checking stackColors[0] is a table with no r key but a positional [1] value"
  - "Blanket CopyDefaults(DEFAULTS.tip) overwrite removed only from NormalizeDB's migration branch; DMX:ResetTipStyle's unrelated CopyDefaults(DEFAULTS.tip) call (the user-triggered Reset to Defaults button) was left untouched since it is a separate, intentional full-reset feature outside this plan's scope"

patterns-established:
  - "Migration-branch code should re-seed only the specific field(s) whose shape changed, never the whole config subtree, to avoid silently discarding user customizations"

requirements-completed: [DISP-06]

# Metrics
duration: 5min
completed: 2026-07-06
status: complete
---

# Phase 06 Plan 07: Fix SC-6 migration-branch settings wipe Summary

**Replaced NormalizeDB's blanket `CopyDefaults(DEFAULTS.tip)` migration overwrite with a targeted `stackColors`-only re-seed, closing a live data-loss regression that reset every customized tip.* field for users still on the shipped v1.0.0 SavedVariables token.**

## Performance

- **Duration:** ~5 min
- **Completed:** 2026-07-06T22:05:54Z
- **Tasks:** 2 completed
- **Files modified:** 2

## Accomplishments
- Added a regression test that genuinely exercises the migration branch by seeding the OLD shipped token (`"0.3.2-fontfix"`) with realistic non-position customizations plus legacy positional `stackColors`, and confirmed it fails (RED) against the pre-fix blanket-wipe code
- Added `StackColorsAreLegacyFormat` helper and rewrote `NormalizeDB`'s migration gate to re-seed only `stackColors` when it is provably in the old array-indexed shape, removing the `CopyDefaults(DEFAULTS.tip)` blanket overwrite and its five ad-hoc x/y/scale/optionsX/optionsY restore lines
- Confirmed the full fengari suite is green at 125/125 with all ten pre-existing "NormalizeDB — migration branch" tests still passing (deprecated-field clearing, `db.locked`, settingsMigration bump all preserved)

## Task Commits

Each task was committed atomically:

1. **Task 1: Add failing regression test for migration-branch settings preservation (RED)** - `69b15c4` (test)
2. **Task 2: Replace blanket migration wipe with targeted stackColors re-seed (GREEN)** - `2cfbae0` (fix)

_TDD gate sequence confirmed in git log: `test(06-07)` commit precedes `fix(06-07)` commit; RED state (124 passed, 1 failed) verified before the fix, GREEN state (125 passed, 0 failed) verified after._

## Files Created/Modified
- `Duncedmaxxing/Core.lua` - Added `StackColorsAreLegacyFormat` helper; `NormalizeDB` migration branch now re-seeds only `stackColors` (when legacy shape detected) instead of overwriting the entire `tip` table via `CopyDefaults(DEFAULTS.tip)`; deprecated-field clearing, `db.locked`, and `settingsMigration` bump all still occur inside the migration gate; `SETTINGS_MIGRATION` token unchanged
- `spec/core_spec.lua` - New describe block "NormalizeDB — migration branch preserves user customizations (SC-6 regression)" seeding the OLD `"0.3.2-fontfix"` token with non-position customizations and legacy positional stackColors

## Decisions Made
- `StackColorsAreLegacyFormat(stackColors)` treats a `stackColors[0]` table with no `r` key but a truthy `[1]` value as legacy positional shape (per 06-REVIEW.md CR-01 sketch); any other shape (including missing `stackColors`) is treated as current/named-key and left untouched
- Left `DMX:ResetTipStyle`'s pre-existing `CopyDefaults(DEFAULTS.tip)` call unmodified — see Deviations below

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed a non-existent `assert.is_number` call in the new regression test**
- **Found during:** Task 2 (GREEN verification) — after the Core.lua fix, the suite still reported 1 failure
- **Issue:** The RED test (Task 1) used `assert.is_number(db.tip.stackColors[0].r)`, but the project's minimal assert shim (`spec/run.cjs`) does not implement `is_number`. This masked the true GREEN result behind a shim-API error.
- **Fix:** Replaced with `assert.is_table(db.tip.stackColors[0])` + `assert.near(1, db.tip.stackColors[0].r, 0.00001)`, matching the file's existing assertion style and the known DEFAULTS value.
- **Files modified:** `spec/core_spec.lua`
- **Verification:** Confirmed the RED failure (before this fix) was still due to the real bug — the first assertion (`displayMode == "number"`) already failed under the blanket-wipe code, so the `is_number` bug never masked the RED signal. After the fix, full suite is 125/125 green.
- **Committed in:** `2cfbae0` (part of Task 2 commit, since it was required to reach a verifiable GREEN state)

### Notable Non-Fixes (documented, not auto-fixed)

**2. [Acceptance-criteria discrepancy] `grep -c 'CopyDefaults(DEFAULTS.tip)' Duncedmaxxing/Core.lua` returns 1, not 0**
- **Found during:** Task 2 acceptance-criteria verification
- **Issue:** The plan's acceptance criteria and top-level `<verification>` both assert this grep returns 0 hits. One hit remains at `Duncedmaxxing/Core.lua:180`, inside `DMX:ResetTipStyle` — a pre-existing, unrelated "Reset to Defaults" feature invoked from the Options UI (`Options.lua:436`) that intentionally resets all tip styling except position. This occurrence predates this plan and is not part of `NormalizeDB` or the migration path.
- **Why not fixed:** Removing or altering `ResetTipStyle`'s blanket copy would silently break the explicit user-triggered "Reset to Defaults" button — a working, intentional feature with no connection to the SC-6 data-loss bug this plan targets. Rule 4 (architectural change) applies: changing or removing user-facing reset behavior requires a product decision, not an automatic fix bundled into a data-loss regression fix.
- **Actual objective status:** Fully satisfied — the blanket overwrite inside `NormalizeDB`'s migration branch (the actual data-loss source) is removed and verified via the new regression test plus all ten pre-existing migration-branch tests. `grep -c 'CopyDefaults(DEFAULTS.tip.stackColors)'` returns 1 (targeted re-seed present) and `grep -c 'StackColorsAreLegacyFormat'` returns 2 (helper + call site), matching the plan's other acceptance criteria.
- **Impact:** None on SC-6/DISP-06 — the literal grep in the plan's acceptance criteria did not anticipate this unrelated homonymous occurrence in the same file.

---

**Total deviations:** 1 auto-fixed (test-shim API bug), 1 documented non-fix (unrelated pre-existing code matching an over-broad grep pattern)
**Impact on plan:** No scope creep. The core objective — eliminating the migration-branch data-loss wipe — is fully achieved and regression-tested.

## Issues Encountered
None beyond the deviations documented above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- SC-6 BLOCKER closed: `NormalizeDB` no longer wipes customized settings on a `settingsMigration` token bump
- Full fengari suite green at 125/125
- Phase 06 gap-closure plan 06-08 (if any remaining items from 06-REVIEW.md/06-VERIFICATION.md) can now proceed independently

---
*Phase: 06-options-panel-v2-per-mode-visibility-configurable-stack-colo*
*Completed: 2026-07-06*

## Self-Check: PASSED
