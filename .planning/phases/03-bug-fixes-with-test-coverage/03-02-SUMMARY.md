---
phase: 03-bug-fixes-with-test-coverage
plan: "02"
subsystem: tip-of-the-spear-tracking
tags: [bug-fix, talent-detection, twin-fangs, regression-test, dual-path-api]
dependency_graph:
  requires: [03-01]
  provides: [BUG-03-talent-aware-generator, BUG-04-takedown-grant-consume]
  affects:
    - Duncedmaxxing/Modules/TipOfTheSpear.lua
    - spec/tip_spec.lua
    - spec/support/wow_stubs.lua
    - spec/support/init.lua
    - .luacheckrc
tech_stack:
  added: []
  patterns:
    - dual-path talent API check (C_SpellBook.IsSpellKnown / IsPlayerSpell fallback)
    - event-driven talent cache on Tip.hasTwinFangs refreshed at PLAYER_TALENT_UPDATE, TRAIT_CONFIG_UPDATED, PLAYER_SPECIALIZATION_CHANGED, and Initialize
    - grant-then-consume order for Takedown with Twin Fangs active
key_files:
  created: []
  modified:
    - Duncedmaxxing/Modules/TipOfTheSpear.lua
    - spec/tip_spec.lua
    - spec/support/wow_stubs.lua
    - spec/support/init.lua
    - .luacheckrc
decisions:
  - HasTwinFangs reads C_SpellBook and IsPlayerSpell from _G at call time (no module-level capture) so test stubs can be swapped per-test without module reload
  - Takedown grant-then-consume fires grant first (ClampStacks(stacks + 3)) then subtracts 1 without second clamp — stacks guaranteed >= 2 after clamp(x + 3) where x >= 0
  - .luacheckrc updated to add C_SpellBook and IsPlayerSpell as read_globals alongside the production code change
metrics:
  duration: ~12min
  completed: "2026-06-18T12:00:00Z"
  tasks_completed: 2
  files_changed: 5
---

# Phase 03 Plan 02: BUG-03/BUG-04 Twin Fangs Talent-Aware Stack Prediction Summary

**One-liner:** Dual-path HasTwinFangs talent detection cached on Tip.hasTwinFangs with event-driven refresh; ApplySpell uses hasTwinFangs to grant 2 or 3 stacks on Kill Command and applies grant-then-consume order for Takedown, verified by 8 new regression tests replacing the pending BUG-04 placeholder.

## What Was Built

### Task 1: HasTwinFangs Detection, hasTwinFangs Cache, Talent-Aware ApplySpell, FindTrackedSpell spellID Return

**Production code changes in TipOfTheSpear.lua:**

- Added `local TAKEDOWN = 1250646` and `local TWIN_FANGS = 1272139` constants near the top of the file
- Added `local function HasTwinFangs()` with dual-path API check: tries `C_SpellBook.IsSpellKnown` first, falls back to `IsPlayerSpell`, returns `false` if neither is available. Reads from `_G` at call time to allow test stub swaps.
- Added `Tip.hasTwinFangs = false` to the Tip field declaration block
- Extended `FindTrackedSpell` to capture `local id = select(i, ...)` and return `kind, id` as two values
- Updated `Tip:ApplySpell(kind, spellID)`: generator branch uses `local grant = self.hasTwinFangs and 3 or 2`; consumer branch has a Takedown+Twin Fangs special case that applies grant-then-consume order (ClampStacks(stacks + 3) then stacks - 1)
- Updated `OnEvent UNIT_SPELLCAST_SUCCEEDED` to capture `local kind, spellID = FindTrackedSpell(...)` and pass spellID to `ApplySpell`
- Updated `OnEvent PLAYER_TALENT_UPDATE` and `TRAIT_CONFIG_UPDATED` to set `self.hasTwinFangs = HasTwinFangs()` before RefreshActive
- Updated `OnEvent PLAYER_SPECIALIZATION_CHANGED` to set `self.hasTwinFangs = HasTwinFangs()` after resetting stacks
- Updated `Initialize` to seed `self.hasTwinFangs = HasTwinFangs()` after InCombatLockdown check

**Test infrastructure changes:**

- Added `_G.C_SpellBook = { IsSpellKnown = function(spellID) return false end }` and `_G.IsPlayerSpell = function(spellID) return false end` to `wow_stubs.lua install()` (default: no talent known)
- Added `Tip.hasTwinFangs = false` to `resetTipState()` in `init.lua`
- Added `IsPlayerSpell` and `C_SpellBook` to `.luacheckrc` read_globals to suppress luacheck warnings

### Task 2: BUG-03 and BUG-04 Regression Tests

Replaced the `pending("adds 3 stacks for Takedown with Twin Fangs talent (BUG-04)")` placeholder in `spec/tip_spec.lua` with 8 new tests inside the existing `Tip:ApplySpell` describe block:

**BUG-03 tests (talent-aware generator grants):**
1. "grants 2 stacks on generator without Twin Fangs (BUG-03 baseline)" — hasTwinFangs=false → stacks == 2
2. "grants 3 stacks on generator with Twin Fangs active (BUG-03)" — hasTwinFangs=true → stacks == 3
3. "caps at MAX_STACKS on generator with Twin Fangs from 1 stack (BUG-03)" — hasTwinFangs=true, stacks=1 → stacks == 3 (capped)

**BUG-04 tests (Takedown with Twin Fangs grant-then-consume):**
4. Takedown from 0 stacks with Twin Fangs → stacks == 2, expiresAt != 0
5. Takedown from 1 stack with Twin Fangs → stacks == 2 (the D-04 distinguishing case: wrong order would give 3)
6. Takedown from 2 stacks with Twin Fangs → stacks == 2
7. Takedown without Twin Fangs consumes 1 normally → stacks == 1
8. Non-Takedown consumer with Twin Fangs consumes 1 normally (Raptor Strike) → stacks == 1

## Verification Results

| Check | Result |
|-------|--------|
| `busted` full suite | 102 successes / 0 failures / 0 errors / 0 pending |
| `luacheck Duncedmaxxing/ --no-unused-args` | 0 warnings / 0 errors in 4 files |
| `grep -c "hasTwinFangs" TipOfTheSpear.lua` | 6 (>= 5 required) |
| `grep -c "HasTwinFangs" TipOfTheSpear.lua` | 4 (>= 4 required) |
| `grep -c "TAKEDOWN" TipOfTheSpear.lua` | 2 (>= 2 required) |
| `grep -c "pending(" tip_spec.lua` | 0 (no pending tests) |

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| Task 1 | 0cf4776 | feat(03-02): HasTwinFangs dual-path detection, hasTwinFangs cache, talent-aware ApplySpell |
| Task 2 | dde547d | test(03-02): BUG-03 and BUG-04 regression tests for Twin Fangs talent-aware stacks |

## Deviations from Plan

**[Rule 2 - Missing Critical Functionality] Added C_SpellBook and IsPlayerSpell to .luacheckrc read_globals**
- **Found during:** Task 1 verification (luacheck run)
- **Issue:** luacheck reported 5 warnings for undefined globals C_SpellBook and IsPlayerSpell — new WoW API globals referenced by HasTwinFangs were not in the .luacheckrc read_globals list
- **Fix:** Added both globals to read_globals in .luacheckrc; committed as part of Task 1
- **Files modified:** .luacheckrc
- **Commit:** 0cf4776

## Known Stubs

None — all changes wire to real logic paths. No placeholder data.

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes introduced. HasTwinFangs accesses WoW talent API as read-only; the result is bounded by `and true or false` boolean coercion and stored only on the local Tip table. No new threat surface beyond T-03-04, T-03-05, T-03-06 already documented in the plan's threat model.

## Self-Check: PASSED

- [x] `Duncedmaxxing/Modules/TipOfTheSpear.lua` modified (TAKEDOWN, TWIN_FANGS, HasTwinFangs, hasTwinFangs, talent-aware ApplySpell, FindTrackedSpell spellID return, OnEvent updates, Initialize update)
- [x] `spec/tip_spec.lua` modified (pending placeholder removed, 8 new tests added)
- [x] `spec/support/wow_stubs.lua` modified (C_SpellBook and IsPlayerSpell stubs added)
- [x] `spec/support/init.lua` modified (hasTwinFangs = false in resetTipState)
- [x] `.luacheckrc` modified (C_SpellBook and IsPlayerSpell in read_globals)
- [x] Commit 0cf4776 exists (Task 1)
- [x] Commit dde547d exists (Task 2)
- [x] `busted` full suite: 102 successes / 0 failures / 0 pending
- [x] `luacheck`: 0 warnings / 0 errors
