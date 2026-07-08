---
phase: 01-utility-extraction-and-module-encapsulation
plan: "03"
subsystem: TipOfTheSpear stack prediction
tags: [bug-fix, tdd, generator-grant, twin-fangs, primal-surge, kill-command]
dependency_graph:
  requires: []
  provides: [correct-generator-grant, hasPrimalSurge-field, twin-fangs-decoupled]
  affects: [Duncedmaxxing/Modules/TipOfTheSpear.lua, spec/tip_spec.lua, spec/support/init.lua]
tech_stack:
  added: []
  patterns: [flat-2 fallback for unverifiable spell ID, field reserved for future resolution]
key_files:
  created: []
  modified:
    - Duncedmaxxing/Modules/TipOfTheSpear.lua
    - spec/tip_spec.lua
    - spec/support/init.lua
decisions:
  - "Primal Surge spell ID unverifiable offline; flat-2 fallback used (grant = 2 always)"
  - "hasPrimalSurge field added to Tip for future HasPrimalSurge() wiring without breaking changes"
  - "Generator grant decoupled from hasTwinFangs entirely; Twin Fangs scoped to Takedown consumer path"
metrics:
  duration: "3min"
  completed: "2026-06-22"
  tasks_completed: 2
  files_modified: 3
status: complete
---

# Phase 01 Plan 03: Kill Command Stack-Overshoot Fix Summary

**One-liner:** Decoupled Kill Command generator grant from hasTwinFangs; flat-2 fallback closes the 3-then-2 flicker for Primal Surge users.

## What Was Built

### Task 1: Resolve and record the Primal Surge spell ID

Attempted to verify the Survival Hunter "Primal Surge" talent spell ID from canonical sources (warcraft.wiki.gg, wowhead). The debug file (`.planning/debug/kill-command-stack-overshoot.md`) confirmed the mechanic via web sources during diagnosis: base Kill Command grants 1 stack, Primal Surge talent adds +1 (Kill Command grants 2). However, the numeric spell ID was not surfaced in any project file or available offline reference.

**Outcome:** Flat-2 fallback path selected. No PRIMAL_SURGE constant added (plan requirement: do not invent or commit an unverified ID). Task 2 uses `local grant = 2` unconditionally.

No code changes in Task 1.

### Task 2: Decouple generator grant from Twin Fangs; add Primal Surge detection

**RED phase (commit f406a9d):** Added failing regression tests to `spec/tip_spec.lua` before implementing the fix:
- New test: "generator grant is independent of Twin Fangs: hasTwinFangs=true yields BASE (not 3) from 0 stacks" — this test would fail against the old formula `self.hasTwinFangs and 3 or 2`.
- New test: "generator grant with Primal Surge yields 2 stacks from 0"
- New test: "generator grant without Primal Surge yields BASE stacks from 0"
- Removed "grants 3 stacks on generator with Twin Fangs active (BUG-03)" — premise is the bug being fixed.
- Removed "caps at MAX_STACKS on generator with Twin Fangs from 1 stack (BUG-03)" — premise is the bug being fixed.
- Renamed "adds 2 stacks on generator from zero" to "adds BASE stacks on generator from zero (flat-2 fallback: BASE=2)" with `hasPrimalSurge = false` explicit.
- Annotated expiry timer test with BASE comment.

**GREEN phase (commit 975cb6e):** Implemented the fix in `Duncedmaxxing/Modules/TipOfTheSpear.lua` and `spec/support/init.lua`:
- Replaced `local grant = self.hasTwinFangs and 3 or 2` with `local grant = 2` (flat-2 fallback).
- Added `Tip.hasPrimalSurge = false` field initializer next to `Tip.hasTwinFangs = false`.
- Consumer branch (Takedown + Twin Fangs special case, lines 703-707) left completely untouched.
- Added `Tip.hasPrimalSurge = false` to `resetTipState` in `spec/support/init.lua` for per-test isolation.
- No HasPrimalSurge() helper added (flat-2 fallback — no spell ID to check).

## Verification Results

All structural checks passed (busted and luacheck absent from PATH):

- `OK_FALLBACK_PATH` — no PRIMAL_SURGE constant (correct, ID unverifiable).
- `OK_STALE_GENERATOR_TESTS_REMOVED` — stale "with Twin Fangs" generator tests removed.
- `OK_OLD_FORMULA_GONE` — `hasTwinFangs and 3 or 2` no longer present in TipOfTheSpear.lua.
- `OK_PRIMAL_SURGE_WIRED` — `hasPrimalSurge` present in both TipOfTheSpear.lua and spec/tip_spec.lua.

**In-game UAT re-test required:** Since busted is unavailable, Phase 01 UAT Test 3 must be re-tested in-game: casting Kill Command should raise stacks to 2 with no transient 3.

## Deviations from Plan

None — plan executed exactly as written. Flat-2 fallback path was the intended outcome when Primal Surge spell ID is unverifiable offline.

## Known Stubs

None — `hasPrimalSurge` is initialized to `false` and the comment in TipOfTheSpear.lua line 699 notes it is reserved for future ID resolution. This is intentional and documented, not a data stub.

## Threat Flags

No new security-relevant surface introduced. This is a pure arithmetic fix in single-player addon prediction logic with no network endpoints, auth paths, file access, or schema changes.

## Self-Check: PASSED

- `Duncedmaxxing/Modules/TipOfTheSpear.lua` — modified, exists.
- `spec/tip_spec.lua` — modified, exists.
- `spec/support/init.lua` — modified, exists.
- Commits: f406a9d (RED test phase), 975cb6e (GREEN implementation).
