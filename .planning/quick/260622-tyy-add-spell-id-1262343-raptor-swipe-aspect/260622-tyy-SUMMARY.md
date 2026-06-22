---
phase: quick-260622-tyy
plan: "01"
subsystem: TipOfTheSpear
tags: [consumers, regression-test, raptor-swipe, aspect-of-the-eagle]
status: complete

dependency_graph:
  requires: []
  provides:
    - 1262343 classified as "consumer" via CONSUMERS table
    - Regression test verifying 1262343 decrements 1 stack
  affects:
    - Duncedmaxxing/Modules/TipOfTheSpear.lua
    - spec/tip_spec.lua

tech_stack:
  added: []
  patterns:
    - CONSUMERS table entry (boolean true) for plain consumer classification

key_files:
  created: []
  modified:
    - Duncedmaxxing/Modules/TipOfTheSpear.lua
    - spec/tip_spec.lua

decisions:
  - 1262343 is a plain consumer (no Twin Fangs / Takedown special case); only a CONSUMERS table entry was needed

metrics:
  duration: "~2min"
  completed: "2026-06-22"
  tasks_completed: 2
  files_modified: 2
---

# Quick Task 260622-tyy: Add Spell ID 1262343 (Raptor Swipe Aspect of the Eagle) Summary

**One-liner:** Added 1262343 to CONSUMERS table and mirrored the 265189 regression test for the AotE Raptor Swipe variant.

## Tasks Completed

| # | Name | Commit | Files |
|---|------|--------|-------|
| 1 | Register 1262343 as a consumer | f775876 | Duncedmaxxing/Modules/TipOfTheSpear.lua |
| 2 | Add regression test for 1262343 consumer behavior | 8b7ab8a | spec/tip_spec.lua |

## What Was Done

### Task 1 — Register 1262343 as a consumer

Added `[1262343] = true, -- Raptor Swipe (Aspect of the Eagle ranged variant)` to the CONSUMERS table in `TipOfTheSpear.lua`, immediately after the existing `[1262293] = true` Raptor Swipe base entry. This mirrors the 186270 (base) / 265189 (AotE variant) pair for Raptor Strike.

No changes to `ClassifySpellID` or `ApplySpell` were required — the existing table-lookup logic at line ~78 handles the new entry automatically.

### Task 2 — Add regression test for 1262343

Added an `it(...)` test to `spec/tip_spec.lua` in the existing `Tip:ApplySpell` describe block, directly after the 265189 test. The test:
- Sets `Tip.stacks = 2`
- Calls `Tip:ApplySpell("consumer", 1262343)`
- Asserts `Tip.stacks == 1`

Structure is identical to the 265189 test, adapted with an accurate comment for Raptor Swipe.

## Deviations from Plan

None — plan executed exactly as written.

## Test Execution

Tests were NOT run by this executor. There is no native Lua/busted toolchain in this environment. The fengari harness (Lua-VM-in-JS) will run the regression suite after this task returns and report the real result.

## Self-Check

- [x] `[1262343] = true` present in `Duncedmaxxing/Modules/TipOfTheSpear.lua` (line 27)
- [x] `1262343` present in `spec/tip_spec.lua` (lines 211-217)
- [x] Task 1 commit exists: f775876
- [x] Task 2 commit exists: 8b7ab8a

## Self-Check: PASSED
