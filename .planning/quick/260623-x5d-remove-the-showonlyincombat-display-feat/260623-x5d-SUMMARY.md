---
phase: quick-260623-x5d
plan: "01"
subsystem: display-visibility
tags: [quick-task, cleanup, showOnlyInCombat, visibility]
status: complete

dependency_graph:
  requires: []
  provides: [tracker-always-visible-in-and-out-of-combat]
  affects:
    - Duncedmaxxing/Core.lua
    - Duncedmaxxing/Options.lua
    - Duncedmaxxing/Modules/TipOfTheSpear.lua
    - spec/core_spec.lua
    - spec/tip_spec.lua

tech_stack:
  added: []
  patterns:
    - Removed showOnlyInCombat combat-gated visibility; tracker now always shows when enabled

key_files:
  modified:
    - Duncedmaxxing/Core.lua
    - Duncedmaxxing/Options.lua
    - Duncedmaxxing/Modules/TipOfTheSpear.lua
    - spec/core_spec.lua
    - spec/tip_spec.lua

decisions:
  - ParseOnOff import retained in Core.lua as a harmless unused local (removing it is out of scope)
  - showOnlyInCombat key left as inert field on persisted DuncedmaxxingDB (NormalizeDB does not strip unknown keys in already-migrated branch)

metrics:
  duration: "5 min"
  completed: "2026-06-23"
  tasks_completed: 3
  files_modified: 5
---

# Phase quick-260623-x5d Plan 01: Remove showOnlyInCombat Display Feature Summary

**One-liner:** Removed `showOnlyInCombat` combat-gated visibility entirely — tracker now always shows regardless of combat state.

## What Was Built

The `showOnlyInCombat` display feature was fully removed from all addon source files and test fixtures:

- **Core.lua:** Deleted `showOnlyInCombat = true` from `DEFAULTS.tip`, removed the `combat`/`combatonly` slash command branch, and dropped `, combat on|off` from `PrintHelp` text.
- **Options.lua:** Deleted the `CreateCheckbox(window, "Combat only", ...)` call (getter and setter).
- **TipOfTheSpear.lua:** Removed the three-line visibility-gate block (`if shouldShow and cfg.showOnlyInCombat and not self.inCombat ...`) from `Tip:Update`. The `hideWhenEmpty` block and all `self.inCombat` references were left completely intact.
- **spec/core_spec.lua:** Removed `showOnlyInCombat = true` from the `migrationDB` and `migratedDB` fixture builders. Added a new assertion documenting that NormalizeDB preserves a persisted `showOnlyInCombat` key harmlessly (inert leftover field, not stripped by the already-migrated branch).
- **spec/tip_spec.lua:** Removed the now-inert `db.tip.showOnlyInCombat = false` line from the number-mode color-coding `before_each`.

## Verification Results

### Negative grep (addon source clean)

```
grep -rn showOnlyInCombat Duncedmaxxing/
```
**Result: no matches** (as expected)

### Spec suite

```
npx -y -p fengari@0.1.5 node spec/run.cjs
```
**Result: 117 passed, 0 failed, 117 total**

### Retained invariants confirmed

- `hideWhenEmpty` default, checkbox, and branch: all present and untouched.
- `self.inCombat` still referenced in `SyncFromAura` (grace-suppression), `ScheduleAuraVerify` (timing), and event handlers — only its use inside the removed visibility gate was deleted.

## Commits

| Task | Commit | Message |
|------|--------|---------|
| 1 — Core.lua | 1267e30 | refactor(quick-260623-x5d-01): remove showOnlyInCombat from Core.lua |
| 2 — Options + TipOfTheSpear | 35b222d | refactor(quick-260623-x5d-01): remove Combat only checkbox and visibility gate |
| 3 — Specs | 7243c0c | test(quick-260623-x5d-01): strip showOnlyInCombat from specs; add inert-key assertion |

## Deviations from Plan

None — plan executed exactly as written. The `ParseOnOff` import was intentionally left in place as confirmed by the plan's own guidance.

## Known Stubs

None.

## Threat Flags

None — no new network endpoints, auth paths, or schema changes introduced. This is a pure removal of a display-logic feature.

## Self-Check

- [x] All five modified files confirmed present on disk
- [x] All three task commits verified via `git log`
- [x] `grep -rn showOnlyInCombat Duncedmaxxing/` returns no matches
- [x] Spec suite: 117 passed, 0 failed
