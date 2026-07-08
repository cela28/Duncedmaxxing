---
phase: 03-bug-fixes-with-test-coverage
plan: "01"
subsystem: core-logic
tags: [bug-fix, dead-code-removal, regression-test, aura-verification, display-sync]
dependency_graph:
  requires: []
  provides: [BUG-01-regression-test, BUG-02-refresh-sync, QUAL-03-dead-block-removed]
  affects: [Duncedmaxxing/Core.lua, spec/tip_spec.lua, spec/core_spec.lua]
tech_stack:
  added: []
  patterns:
    - out-of-combat SyncFromAura gate before RefreshLayout in RefreshTip
    - serial-mismatch regression test using mock clock advance
key_files:
  created: []
  modified:
    - Duncedmaxxing/Core.lua
    - spec/tip_spec.lua
    - spec/core_spec.lua
decisions:
  - BUG-02 fix applied to all RefreshTip callers (mode switch, size, color, border) rather than mode-change-only — simpler and covers all stale-display paths
  - BUG-01 regression test uses inCombat=true to exercise the serial-mismatch guard path explicitly
  - QUAL-03 dead block removed entirely — migration gate (lines 77-96) already clears barWidth/barHeight/spacing so the fallback block was unreachable for any user who had loaded the addon at least once
metrics:
  duration: ~10min
  completed: "2026-06-18T11:24:05Z"
  tasks_completed: 2
  files_changed: 3
---

# Phase 03 Plan 01: BUG-01/BUG-02/QUAL-03 Bug Fixes and Regression Tests Summary

**One-liner:** auraVerifyPending flag regression test, out-of-combat SyncFromAura in RefreshTip to eliminate stale displays, and dead barWidth/barHeight/spacing migration fallback block removed from NormalizeDB.

## What Was Built

### Task 1: BUG-01 Regression Test and QUAL-03 Dead Block Removal

**BUG-01 regression test (spec/tip_spec.lua):**
Added `describe("Tip:ScheduleAuraVerify — auraVerifyPending flag (BUG-01)")` block with one test that confirms the timer closure clears `auraVerifyPending = false` before the serial-mismatch early return check. The test sets `inCombat=true`, calls `ApplySpell` twice to make the first timer's serial stale, advances the mock clock past `AURA_VERIFY_DELAY`, and asserts `Tip.auraVerifyPending == false`. No change to TipOfTheSpear.lua was needed — the fix was already in place at line 431.

**QUAL-03 dead block removal (Duncedmaxxing/Core.lua):**
Deleted the 9-line unreachable fallback block in `NormalizeDB` that mapped `tip.barWidth → tip.width`, `tip.barHeight → tip.height`, and `tip.spacing → tip.borderSize`. The migration gate (lines 77-96) already sets these deprecated fields to nil for any DB that has been migrated, so the fallback block was never reached for any user running a version >= 0.3.2-fontfix.

**QUAL-03 test updates (spec/core_spec.lua):**
- Renamed describe to `"NormalizeDB — deprecated fields ignored post-migration (QUAL-03)"`
- Updated 3 of 4 it() descriptions to confirm no mapping occurs (not "migrates X to Y")
- Assertions flipped from `assert.equals(value, ...)` to `assert.is_nil(...)` for barWidth, barHeight, spacing fields
- 4th test ("does not overwrite existing borderSize with spacing") kept as-is — borderSize=2 is still 2 regardless
- Added 5th test: NormalizeDB idempotency — double call preserves enabled, displayMode, x, y, scale

### Task 2: BUG-02 Out-of-Combat SyncFromAura in RefreshTip

**BUG-02 code fix (Duncedmaxxing/Core.lua):**
Modified the `RefreshTip` local function to call `tip:SyncFromAura()` as its first action when `not tip.inCombat`. This fires on every non-combat RefreshTip call (mode switch, scale, color, border) and ensures the displayed stack count matches the live aura state before refreshing layout.

**BUG-02 regression tests (spec/tip_spec.lua):**
Added `describe("RefreshTip — out-of-combat aura sync (BUG-02)")` with 3 tests:
1. Absent aura zeros stale stacks (stacks=2 → 0, expiresAt → 0)
2. Present aura syncs to live stack count (stacks=0 → 2 from mockAura returning applications=2)
3. Combat mode blocks SyncFromAura call — spy confirms it is never invoked, stacks remain at 2

## Verification Results

| Check | Result |
|-------|--------|
| `busted` full suite | 94 successes / 0 failures / 0 errors / 1 pending |
| `luacheck Duncedmaxxing/ --no-unused-args` | 0 warnings / 0 errors in 4 files |
| `grep -c "tip.barWidth" Core.lua` | 1 (only nil-clearing line inside migration gate) |
| `grep -c "SyncFromAura" Core.lua` | 1 (BUG-02 fix in RefreshTip) |

The 1 pending test is BUG-04 (Twin Fangs Takedown — deferred to Plan 2).

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| Task 1 | bc23fbc | fix(03-01): QUAL-03 dead migration block removed, BUG-01 regression test added |
| Task 2 | 2a92282 | fix(03-01): BUG-02 out-of-combat SyncFromAura in RefreshTip with regression tests |

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None — all changes are wired to real logic paths. No placeholder data.

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes introduced. All changes are within the existing NormalizeDB and RefreshTip functions. No new threat surface beyond what the plan's threat model already covers (T-03-01, T-03-02, T-03-03).

## Self-Check: PASSED

- [x] `Duncedmaxxing/Core.lua` modified (barWidth dead block removed, SyncFromAura added to RefreshTip)
- [x] `spec/tip_spec.lua` modified (BUG-01 + BUG-02 test blocks added)
- [x] `spec/core_spec.lua` modified (QUAL-03 deprecated-field tests updated, idempotency test added)
- [x] Commit bc23fbc exists (Task 1)
- [x] Commit 2a92282 exists (Task 2)
- [x] `busted` full suite: 94 successes / 0 failures
- [x] `luacheck`: 0 warnings / 0 errors
