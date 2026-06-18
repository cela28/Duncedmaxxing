---
phase: 02-test-framework-and-core-logic-tests
plan: "03"
subsystem: testing
tags: [testing, busted, lua5.1, luacheck, tip-of-the-spear, applyspell, syncfromaura, timer, static-analysis]

requires:
  - phase: 02-02
    provides: "spec/support/init.lua loader with DMX._test bootstrap"
provides:
  - TEST-03
  - TEST-04
  - TEST-07
affects: [spec/tip_spec.lua, spec/support/wow_stubs.lua, spec/support/init.lua, .luacheckrc]

tech-stack:
  added: [luacheck 1.2.0]
  patterns: [mockAura-indirection, per-test-aura-dispatch, luacheck-wow-globals]

key-files:
  created:
    - spec/tip_spec.lua
    - .luacheckrc
  modified:
    - spec/support/wow_stubs.lua
    - spec/support/init.lua

key-decisions:
  - "mockAura indirection added to wow_stubs.lua: C_UnitAuras.GetPlayerAuraBySpellID wrapper delegates to mockAura.impl, allowing per-test overrides despite TipOfTheSpear.lua module-level local capture"
  - "luacheck 1.2.0 installed via luarocks (sudo apt unavailable); W432 shadowing suppressed for WoW SetScript self pattern; max_line_length disabled for layout code"
  - "SlashCmdList added to globals (not read_globals) because addon mutates a field on it"

patterns-established:
  - "mockAura.impl swap pattern: tests override stubs.mockAura.impl per-it() to control ReadLiveState output without reloading the module"
  - "resetTipState resets mockAura.impl to nil-returning lambda in addition to Tip runtime fields"
  - "Serial-mismatch test pattern: call ApplySpell twice to advance serial, spy on SyncFromAura, advance clock past AURA_VERIFY_DELAY, assert exactly one call (stale serial fires but returns early)"

requirements-completed: [TEST-03, TEST-04, TEST-07]

duration: ~15min
completed: 2026-06-18
---

# Phase 02 Plan 03: TipOfTheSpear Logic Tests and luacheck Summary

**24 passing tip spec tests covering ApplySpell, SyncFromAura, ScheduleExpiration, and ScheduleCastVerify serial-mismatch, plus luacheck 1.2.0 configured for zero-warning static analysis of all addon Lua files**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-06-18T09:22:00Z
- **Completed:** 2026-06-18T09:37:16Z
- **Tasks:** 2
- **Files modified:** 4 (spec/tip_spec.lua, .luacheckrc, spec/support/wow_stubs.lua, spec/support/init.lua)

## Accomplishments
- 24 unit tests for ApplySpell (stack add/cap, consumer decrement/floor, expiresAt, lastPredictAt/Kind, unknown kind, timer scheduling, timer fire), SyncFromAura (nil ReadLiveState, stack/expiresAt sync, zero on absent aura, consumer grace suppression within/past window, generator bypass, out-of-combat bypass), and ScheduleCastVerify serial-mismatch (stale serial early-returns, matching serial calls SyncFromAura)
- Twin Fangs `pending()` test documents BUG-04 placeholder for Phase 3
- luacheck 1.2.0 configured with zero warnings across all 4 addon source files
- Full suite: 89 successes / 0 failures / 0 errors / 1 pending

## Task Commits

Each task was committed atomically:

1. **Task 1: Write ApplySpell, SyncFromAura, and timer tests** - `80762b7` (feat)
2. **Task 2: Configure luacheck and achieve zero warnings** - `808593b` (feat)

**Plan metadata:** (committed after SUMMARY.md)

## Files Created/Modified
- `spec/tip_spec.lua` — 335-line test file: 24 it() blocks + 1 pending() across 3 describe blocks
- `.luacheckrc` — luacheck config: std=lua51, 5 writeable globals, 13 read globals, W432 suppressed
- `spec/support/wow_stubs.lua` — Added mockAura dispatch table with indirection wrapper
- `spec/support/init.lua` — Updated resetTipState to reset mockAura.impl instead of _G field

## Decisions Made
- **mockAura indirection (Rule 2 auto-fix):** TipOfTheSpear.lua captures `C_UnitAuras.GetPlayerAuraBySpellID` as a module-level local at file-load time. Direct replacement of `_G.C_UnitAuras.GetPlayerAuraBySpellID` per-test would have no effect. Added `mockAura.impl` dispatch table so tests swap the implementation without needing to reload the module.
- **luacheck via luarocks:** `sudo apt install lua-check` requires interactive sudo password. luacheck 1.2.0 installed via `~/.local/bin/luarocks install luacheck` without root.
- **SlashCmdList in globals:** Lua semantics treat `SlashCmdList.X = fn` as a field write on a non-standard global; luacheck emits W112 unless `SlashCmdList` is in `globals` (not `read_globals`).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Added mockAura indirection to wow_stubs.lua**
- **Found during:** Task 1 (Write ApplySpell, SyncFromAura, and timer tests)
- **Issue:** SyncFromAura tests require per-test control of what `ReadLiveState` returns. TipOfTheSpear.lua line 30 captures `C_UnitAuras.GetPlayerAuraBySpellID` as a `local` at module-load time. Post-load replacement of `_G.C_UnitAuras.GetPlayerAuraBySpellID` does not affect the captured local, so all `SyncFromAura` tests would use the stub's original nil-returning function regardless of override.
- **Fix:** Added `mockAura = { impl = function() return nil end }` to wow_stubs.lua. The `install()` wrapper now uses `function(spellID) return mockAura.impl(spellID) end` — this wrapper is captured by TipOfTheSpear.lua and delegates to the replaceable `mockAura.impl`. resetTipState updated to reset `stubs.mockAura.impl` instead of `_G.C_UnitAuras.GetPlayerAuraBySpellID`.
- **Files modified:** spec/support/wow_stubs.lua, spec/support/init.lua
- **Verification:** Existing 65 tests still pass after change; new SyncFromAura tests correctly observe aura data injected via mockAura.impl
- **Committed in:** 80762b7 (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (Rule 2 — missing critical test infrastructure)
**Impact on plan:** Fix was necessary for SyncFromAura tests to function at all. No scope creep — the change is strictly test infrastructure.

## Issues Encountered
None during task execution beyond the mockAura indirection deviation above.

## User Setup Required
None — luacheck installed automatically via luarocks. No external services or credentials required.

## Next Phase Readiness
- Phase 2 is complete: TEST-01 through TEST-07 all delivered
- 89 tests passing across util_spec.lua, core_spec.lua, tip_spec.lua
- luacheck zero-warning baseline established; any future regression is immediately visible
- Phase 3 (bug fixes) has a full regression test suite to validate fixes against
- BUG-04 (Twin Fangs) has a pending() placeholder that will become an it() assertion in Phase 3

---
*Phase: 02-test-framework-and-core-logic-tests*
*Completed: 2026-06-18*

## Self-Check: PASSED

- spec/tip_spec.lua exists: FOUND
- .luacheckrc exists: FOUND
- 02-03-SUMMARY.md exists: FOUND
- Task 1 commit 80762b7: FOUND
- Task 2 commit 808593b: FOUND
- busted spec/ → 89 successes / 0 failures / 0 errors / 1 pending: VERIFIED
- luacheck Duncedmaxxing/ --no-unused-args → 0 warnings / 0 errors: VERIFIED
