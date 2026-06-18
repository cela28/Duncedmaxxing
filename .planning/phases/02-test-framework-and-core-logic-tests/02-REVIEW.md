---
phase: 02-test-framework-and-core-logic-tests
reviewed: 2026-06-18T09:47:59Z
depth: standard
files_reviewed: 8
files_reviewed_list:
  - .busted
  - .luacheckrc
  - Duncedmaxxing/Core.lua
  - spec/core_spec.lua
  - spec/support/init.lua
  - spec/support/wow_stubs.lua
  - spec/tip_spec.lua
  - spec/util_spec.lua
findings:
  critical: 1
  warning: 3
  info: 2
  total: 6
status: issues_found
---

# Phase 02: Code Review Report

**Reviewed:** 2026-06-18T09:47:59Z
**Depth:** standard
**Files Reviewed:** 8
**Status:** issues_found

## Summary

This change introduces a busted-based test suite (core_spec, tip_spec, util_spec), test infrastructure (init.lua loader, wow_stubs.lua mocks), luacheck configuration, and a `DMX._test` escape hatch in production Core.lua. All 89 tests pass. The test harness architecture is sound -- the `mockAura.impl` indirection pattern correctly handles TipOfTheSpear's module-level local capture, and `loadfile()` with vararg injection accurately simulates the WoW loader. However, there are issues with test scaffolding shipped to production, fragile hardcoded constants, and a mock clock edge case that could produce incorrect test results under certain timer callback patterns.

## Critical Issues

### CR-01: Production code ships test-only escape hatch unconditionally

**File:** `Duncedmaxxing/Core.lua:351-358`
**Issue:** `DMX._test` is set unconditionally at the module level, exposing internal local functions (`MergeDefaults`, `NormalizeDB`, `CopyDefaults`) and the `SETTINGS_MIGRATION` constant on the global `_G.Duncedmaxxing._test` table in production. While the WoW sandbox prevents remote exploitation, this exposes internal implementation details to all other addons running in the same client. Any addon can call `Duncedmaxxing._test.NormalizeDB()` or `Duncedmaxxing._test.MergeDefaults()` with arbitrary arguments, bypassing normal API boundaries and potentially corrupting `DuncedmaxxingDB` in ways the addon does not expect. This is compounded by the comment "Do not use in production addon code" -- indicating the author intended this to be test-only, but it is always present.
**Fix:** Gate the escape hatch behind a test-environment check. Since busted sets `_G.busted` at runtime, you can guard on that:
```lua
-- Only expose internals when running under busted (test runner).
if _G.busted then
    DMX._test = {
        MergeDefaults      = MergeDefaults,
        NormalizeDB        = NormalizeDB,
        CopyDefaults       = CopyDefaults,
        SETTINGS_MIGRATION = SETTINGS_MIGRATION,
    }
end
```
Alternatively, refactor the test loader to fire the real `ADDON_LOADED` event through the coreFrame's OnEvent handler (by making the frame or handler accessible) rather than duplicating the bootstrap logic.

## Warnings

### WR-01: Mock clock does not fire timers scheduled by callbacks during the same advance() call

**File:** `spec/support/wow_stubs.lua:24-41`
**Issue:** `mockClock:advance(dt)` collects all timers eligible to fire, then fires them in order. If a callback schedules a new timer with `fireAt <= self.now` (e.g., a zero-delay timer, or re-scheduling at the same time), that timer is NOT fired during the current `advance()` invocation. This means cascading timer chains require multiple `advance()` calls to fully resolve. In production, `C_Timer.After(0, fn)` fires on the next frame -- but the mock silently swallows it until the next `advance()`. Current tests happen to pass because they use generous time advances (10.1s for a 10.03s timer), but this is a latent correctness trap: a future test that expects a callback-scheduled timer to fire in the same `advance()` will silently produce wrong results. For example, `ScheduleExpiration` line 378 calls `self:ScheduleExpiration()` recursively from a timer callback, which schedules a new timer -- this new timer won't fire until a separate `advance()`.
**Fix:** Add a loop to re-scan for newly-eligible timers after firing callbacks:
```lua
function mockClock:advance(dt)
    self.now = self.now + dt
    local didFire = true
    while didFire do
        didFire = false
        local fired = {}
        for i, t in ipairs(self.timers) do
            if not t.cancelled and t.fireAt <= self.now then
                fired[#fired + 1] = i
            end
        end
        if #fired == 0 then break end
        didFire = true
        table.sort(fired)
        local offset = 0
        for _, idx in ipairs(fired) do
            local t = self.timers[idx - offset]
            table.remove(self.timers, idx - offset)
            offset = offset + 1
            t.callback()
        end
    end
end
```

### WR-02: Hardcoded migration version string in test helpers creates fragile coupling

**File:** `spec/core_spec.lua:153,202,253`
**Issue:** Three `migratedDB()` helper functions hardcode `settingsMigration = "0.3.2-fontfix"` to represent the "already migrated" state. When `SETTINGS_MIGRATION` in Core.lua is bumped for the next migration, all three helpers will produce DBs that trigger the migration branch instead of skipping it, causing 12+ tests to fail with misleading error messages. The test at line 85 correctly uses `DMX._test.SETTINGS_MIGRATION` for its assertion, demonstrating awareness of this coupling, but the helpers don't follow the same pattern.
**Fix:** Use the exposed constant in all helper functions:
```lua
local function migratedDB(tipOverrides)
    -- Requires DMX to be loaded first; call from within before_each
    local db = {
        settingsMigration = DMX._test.SETTINGS_MIGRATION,
        tip = { ... },
    }
    ...
end
```
Note: this requires `DMX` to be available when `migratedDB()` is called, which it is since all calls happen inside `it()` blocks after `before_each` loads DMX. The helper function definitions would need to move inside the `describe` block or accept DMX as a parameter.

### WR-03: Test bootstrap diverges from production bootstrap -- slash commands and Options.lua never tested

**File:** `spec/support/init.lua:35-43`
**Issue:** The test `load()` function manually replicates the `ADDON_LOADED` bootstrap but omits `RegisterSlashCommands()` and skips loading `Options.lua`. This means slash command registration (including `SLASH_DUNCEDMAXXING1/2` global assignment and `SlashCmdList.DUNCEDMAXXING` handler) is never exercised by any test. The slash handler contains branching logic with 15+ command paths, some of which directly mutate `db.tip` and could contain bugs. Additionally, if the real bootstrap sequence in Core.lua changes (e.g., new initialization steps are added), the test bootstrap will silently drift out of sync. The comment "coreFrame is a local inside Core.lua and cannot be reached from here" correctly identifies the constraint, but the mitigation (manual replication) introduces a maintenance hazard.
**Fix:** This is a known limitation of the test architecture. At minimum, add a comment documenting the divergence and keep a checklist of skipped steps. For a more robust solution, expose the bootstrap handler similarly to `_test`:
```lua
DMX._test.bootstrap = function()
    DuncedmaxxingDB = MergeDefaults(DEFAULTS, DuncedmaxxingDB)
    NormalizeDB(DuncedmaxxingDB)
    DMX.db = DuncedmaxxingDB
    DMX.ready = true
    RegisterSlashCommands()
    DMX:ForEachModule("Initialize", DMX)
end
```

## Info

### IN-01: Duplicate test cases in Tip:SyncFromAura error handling

**File:** `spec/tip_spec.lua:142-159`
**Issue:** The two tests "returns false when GetPlayerAuraBySpellID throws (ReadLiveState nil path)" and "returns false when ReadLiveState returns nil via pcall error" exercise the exact same code path. Both set `mockAura.impl` to a function that calls `error()`, and both assert `is_false(result)`. The second test's comment acknowledges it is "already covered above" but suggests it tests a different variant. In reality, both tests trigger the same `pcall` failure in `ReadLiveState` line 74, making the second test fully redundant.
**Fix:** Remove the second test or differentiate it by testing a genuinely different path (e.g., testing behavior when `GetPlayerAuraBySpellID` is nil, though this cannot be done without re-loading the module since it's captured as a local).

### IN-02: noopFrame __index returns frame table for property reads, masking potential type errors

**File:** `spec/support/wow_stubs.lua:98-100`
**Issue:** The `__index` metamethod on `noopFrame` returns a function for any unknown key access. Code that reads a property (not a method) from a noop frame -- e.g., `local w = frame.someNumericProperty` -- gets a function instead of nil or a number. If that value is later used in arithmetic, it would cause a "attempt to perform arithmetic on a function value" error in tests but silently work in production. Current addon code does not hit this path (all frame properties are either explicitly set or accessed via method calls), but it reduces the fidelity of the mock for future test development.
**Fix:** No immediate action required. If future tests need property reads from frames, consider adding explicit stubs for `GetWidth`, `GetHeight`, `GetEffectiveScale`, etc.:
```lua
frame.GetWidth  = function(self) return self._width or 0 end
frame.GetHeight = function(self) return self._height or 0 end
```

---

_Reviewed: 2026-06-18T09:47:59Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
