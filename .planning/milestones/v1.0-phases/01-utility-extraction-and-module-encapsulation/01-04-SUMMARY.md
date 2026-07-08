---
phase: "01"
plan: "04"
subsystem: TipOfTheSpear stack prediction
tags: [bug-fix, tdd, consumers-table, aspect-of-the-eagle, raptor-strike, stack-lag]
dependency_graph:
  requires: ["03"]
  provides: [265189-consumer-classification, aspect-eagle-raptor-strike-instant-decrement]
  affects:
    - Duncedmaxxing/Modules/TipOfTheSpear.lua
    - spec/tip_spec.lua
tech_stack:
  added: []
  patterns: [exact-match CONSUMERS table lookup, plain -1 consumer branch reuse]
key_files:
  created: []
  modified:
    - Duncedmaxxing/Modules/TipOfTheSpear.lua
    - spec/tip_spec.lua
decisions:
  - "265189 is a verified literal captured via in-game /etrace; added directly to CONSUMERS without a named constant (single-use, comment-documented)"
  - "No code changes outside the CONSUMERS table entry — ApplySpell plain -1 branch already handles any non-Takedown consumer correctly"
metrics:
  duration: "2min"
  completed: "2026-06-22"
  tasks_completed: 1
  files_modified: 2
status: complete
---

# Phase 01 Plan 04: Aspect-of-the-Eagle Raptor Strike Stack-Lag Fix Summary

**One-liner:** Added spell ID 265189 to CONSUMERS so the ranged Raptor Strike variant triggers the instant predictive decrement instead of the slow UNIT_AURA path.

## What Was Built

### Task 1: Register Aspect-of-the-Eagle Raptor Strike (265189) as a consumer and add regression test

**Root cause:** With Aspect of the Eagle (186289) active, Raptor Strike fires `UNIT_SPELLCAST_SUCCEEDED` under spell ID 265189 — the ranged variant. This ID was absent from the `CONSUMERS` table, so `ClassifySpellID` returned `nil`, `FindTrackedSpell` found nothing, and `ApplySpell` (the instant predictive decrement) never ran. The stack was corrected only by the slow `UNIT_AURA → ScheduleAuraVerify → SyncFromAura` path (deferred ≥ 0.05s, up to AURA_VERIFY_DELAY = 1.25s in combat) — the user-observed lag.

**RED phase (commit ae38ccc):** Added regression test to `spec/tip_spec.lua`:
- "Aspect-of-the-Eagle Raptor Strike (265189) decrements 1 stack instantly" — sets `Tip.stacks = 2`, calls `Tip:ApplySpell("consumer", 265189)`, asserts result is 1.
- Modeled exactly on the existing `186270` Raptor Strike consumer test at lines 188-193.
- `hasTwinFangs` left at reset default (false) to exercise the plain -1 path, not the Takedown special case.

**GREEN phase (commit 304d591):** Added one line to `Duncedmaxxing/Modules/TipOfTheSpear.lua` CONSUMERS table:
```lua
[265189] = true,  -- Raptor Strike (Aspect of the Eagle ranged variant)
```
`ClassifySpellID` now returns `"consumer"` for 265189 via the existing `CONSUMERS[value]` lookup. `ApplySpell` routes it through the plain -1 consumer branch (lines 704-709). No other logic changed.

## Verification Results

All structural gates passed (busted and luacheck absent from PATH):

- `OK_265189_WIRED` — 265189 present in both TipOfTheSpear.lua and spec/tip_spec.lua.
- `OK_265189_IN_CONSUMERS_TABLE` — node table-scope grep confirms 265189 is inside the `local CONSUMERS = { ... }` block.
- `BUSTED_ABSENT` — busted not on PATH; in-game UAT Test 6 re-test is the primary functional gate.
- `LUACHECK_ABSENT` — luacheck not on PATH; skipped without failing the plan.

**In-game UAT re-test required:** Phase 01 UAT Test 6 must be re-tested in-game: with Aspect of the Eagle active, casting Raptor Strike should decrement the stack display instantly, identical to the melee Raptor Strike (no lag).

## Deviations from Plan

None — plan executed exactly as written. TDD RED/GREEN cycle followed; only CONSUMERS table entry added.

## Known Stubs

None.

## Threat Flags

No new security-relevant surface introduced. Single-player addon, no network endpoints, no auth paths, no schema changes. The 265189 spell ID is an engine-assigned constant in an exact-match read-only lookup.

## Self-Check: PASSED

- `Duncedmaxxing/Modules/TipOfTheSpear.lua` — modified, exists.
- `spec/tip_spec.lua` — modified, exists.
- Commits: ae38ccc (RED test phase), 304d591 (GREEN implementation).
