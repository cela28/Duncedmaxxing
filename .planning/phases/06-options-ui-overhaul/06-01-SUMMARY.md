---
phase: 06-options-ui-overhaul
plan: "01"
subsystem: core-data-layer
status: complete
tags:
  - stackColors
  - defaults-schema
  - settings-migration
  - shouldShow
dependency_graph:
  requires: []
  provides:
    - DEFAULTS.tip.stackColors
    - SETTINGS_MIGRATION=0.3.2-stackcolors
    - config-driven stack color read in Tip:Update()
  affects:
    - Duncedmaxxing/Core.lua
    - Duncedmaxxing/Modules/TipOfTheSpear.lua
    - spec/core_spec.lua
    - spec/tip_spec.lua
tech_stack:
  added: []
  patterns:
    - Config-driven color read with STACK_COLORS constant as nil-safety fallback
    - ColorTuple() normalization from named-key {r,g,b,a} config to positional call
key_files:
  created: []
  modified:
    - Duncedmaxxing/Core.lua
    - Duncedmaxxing/Modules/TipOfTheSpear.lua
    - spec/core_spec.lua
    - spec/tip_spec.lua
decisions:
  - "stackColors added to DEFAULTS.tip with keys [0]-[3] matching STACK_COLORS constant values"
  - "enabled removed from DEFAULTS.tip — tracker always active for Survival spec"
  - "SETTINGS_MIGRATION bumped from 0.3.2-fontfix to 0.3.2-stackcolors"
  - "shouldShow simplified to drop cfg.enabled gate"
  - "ColorTuple() reused to normalize named-key config colors to positional SetTextColor args"
metrics:
  duration: "3min"
  completed_date: "2026-06-29"
  tasks_completed: 2
  files_modified: 4
---

# Phase 06 Plan 01: DB Schema and Config-Driven Stack Colors Summary

Per-stack color configuration added to the DB schema, `Tip:Update()` switched from hardcoded `STACK_COLORS` to config-driven colors with a fallback, `enabled` removed from `DEFAULTS` and `shouldShow`, and settings migration version bumped to propagate schema changes to existing saves.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| RED | Failing tests for stackColors and config-driven colors | 98f0e25 | spec/core_spec.lua, spec/tip_spec.lua |
| 1 (GREEN) | Add stackColors to DEFAULTS, remove enabled, simplify shouldShow, config-driven color read | 4307e6c | Core.lua, TipOfTheSpear.lua, spec/core_spec.lua |

## What Was Built

**Core.lua:**
- `DEFAULTS.tip.stackColors` — table with keys [0]-[3], each `{r, g, b, a}` named-key entry matching the existing `STACK_COLORS` constant values in TipOfTheSpear.lua
- `SETTINGS_MIGRATION` changed from `"0.3.2-fontfix"` to `"0.3.2-stackcolors"` — triggers migration for existing users, resetting tip fields to new defaults (which include `stackColors` and exclude `enabled`)
- `enabled` removed from `DEFAULTS.tip`

**TipOfTheSpear.lua:**
- `shouldShow` simplified from `cfg.enabled and self.isSurvival` to `self.isSurvival` — tracker visibility no longer gated on an `enabled` toggle
- Number mode color read changed from hardcoded `STACK_COLORS[stacks]` to config-driven: reads `GetCfg().stackColors[stacks]` first, falls back to `STACK_COLORS[stacks]` if nil. `ColorTuple()` normalizes the named-key `{r,g,b,a}` config format for `SetTextColor()`

**spec/core_spec.lua:**
- All `migratedDB` fixtures updated from `"0.3.2-fontfix"` to `"0.3.2-stackcolors"`
- `enabled = true` removed from all fixture helpers
- `assert.equals(true, db.tip.enabled)` removed from idempotency test
- New test: MergeDefaults on fresh `{tip = {}}` populates `stackColors[0..3]`
- New test: NormalizeDB migration branch populates `stackColors` from fresh defaults

**spec/tip_spec.lua:**
- `db.tip.enabled = true` removed from number-mode test `before_each` setup
- New test: custom `db.tip.stackColors[0] = {r=1,g=0,b=0,a=1}` overrides default white at 0 stacks
- New test: `db.tip.stackColors = nil` falls back to hardcoded `STACK_COLORS[1]` green at 1 stack

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixture version strings needed updating inline with Task 1 GREEN**
- **Found during:** Task 1 GREEN implementation
- **Issue:** Changing `SETTINGS_MIGRATION` to `"0.3.2-stackcolors"` caused existing `migratedDB` fixtures (which hardcoded `"0.3.2-fontfix"`) to trigger the migration branch on NormalizeDB calls — breaking 6 pre-existing tests
- **Fix:** Updated all four `migratedDB` fixture helpers in `core_spec.lua` to use `"0.3.2-stackcolors"` and removed `enabled` fields inline with the Task 1 GREEN commit, rather than splitting into a separate Task 2 commit
- **Files modified:** spec/core_spec.lua
- **Commit:** 4307e6c

Note: All Task 2 test fixture changes were necessarily completed inline with Task 1's GREEN phase, because the implementation change (bumping SETTINGS_MIGRATION) immediately broke existing tests. The changes are logically complete: all fixtures updated, all new assertions added, all `enabled` references removed.

## Verification Results

```
busted spec/ → 121 successes / 0 failures / 0 errors / 0 pending
```

All plan verification checks pass:
- `grep -c "enabled" Duncedmaxxing/Core.lua` → 0 (no enabled in DEFAULTS.tip)
- `grep "stackColors" Duncedmaxxing/Core.lua` → line 28 in DEFAULTS.tip
- `grep "cfg.enabled" Duncedmaxxing/Modules/TipOfTheSpear.lua` → 0 hits
- `grep "ColorTuple" Duncedmaxxing/Modules/TipOfTheSpear.lua` → hit at line 626 (number mode)

## Known Stubs

None — all data paths are fully wired. `stackColors` defaults in `DEFAULTS.tip` match the existing `STACK_COLORS` constant exactly; Plan 02 will add UI widgets to let users customize these values.

## Self-Check: PASSED

All created/modified files verified present on disk. Both task commits (98f0e25, 4307e6c) confirmed in git log. Test suite exits 0 with 121 passing tests.
