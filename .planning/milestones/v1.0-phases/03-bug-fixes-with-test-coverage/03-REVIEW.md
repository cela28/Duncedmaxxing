---
phase: 03-bug-fixes-with-test-coverage
reviewed: 2026-06-18T14:45:00Z
depth: standard
files_reviewed: 6
files_reviewed_list:
  - Duncedmaxxing/Core.lua
  - Duncedmaxxing/Modules/TipOfTheSpear.lua
  - spec/tip_spec.lua
  - spec/core_spec.lua
  - spec/support/wow_stubs.lua
  - spec/support/init.lua
findings:
  critical: 1
  warning: 4
  info: 2
  total: 7
status: issues_found
---

# Phase 03: Code Review Report

**Reviewed:** 2026-06-18T14:45:00Z
**Depth:** standard
**Files Reviewed:** 6
**Status:** issues_found

## Summary

Reviewed all six files in scope: two production addon modules (Core.lua, TipOfTheSpear.lua), three test support files (wow_stubs.lua, init.lua), and two test spec files (tip_spec.lua, core_spec.lua). All 102 tests pass cleanly. No hardcoded secrets, debug artifacts, or injection vulnerabilities found.

The production addon code (Core.lua, TipOfTheSpear.lua) is well-structured with proper pcall guards, combat safety checks, and input validation. The primary concerns are in the test harness, where the mock timer clock has a correctness defect that fires callbacks in insertion order rather than temporal order, and where cascaded timers scheduled by callbacks are silently dropped within the same advance call. Both issues are latent: they do not cause failures in the current test suite, but they undermine the reliability of future tests that depend on timer ordering or cascaded scheduling.

## Critical Issues

### CR-01: Mock clock fires timers in insertion order, not fireAt order

**File:** `spec/support/wow_stubs.lua:26-40`
**Issue:** `mockClock:advance()` collects timer indices into a `fired` list and sorts them, but sorting array indices is equivalent to insertion order, not `fireAt` order. If two timers are scheduled such that the later-inserted one has an earlier `fireAt` (e.g., `After(5, cbA)` then `After(1, cbB)` at the same clock time), `cbA` fires before `cbB` even though `cbB` should fire first. The WoW engine guarantees temporal ordering of timer callbacks. This defect means any future test involving interleaved timer scheduling will silently produce wrong ordering.

The current test suite avoids this bug by accident: all timer-scheduling sequences happen to insert timers in ascending `fireAt` order. But the test for `ScheduleCastVerify serial-mismatch` (tip_spec.lua:337-396) relies on two `ApplySpell` calls that each schedule timers at `AURA_VERIFY_DELAY` and `FINAL_AURA_VERIFY_DELAY`. If the implementation ever changes to schedule timers in non-temporal order, the mock will silently fire them wrong.

**Fix:**
```lua
function mockClock:advance(dt)
    self.now = self.now + dt
    -- Repeatedly fire the earliest ready timer until none remain,
    -- so cascaded timers scheduled by callbacks are also handled.
    while true do
        local earliest_idx, earliest_at = nil, math.huge
        for i, t in ipairs(self.timers) do
            if not t.cancelled and t.fireAt <= self.now and t.fireAt < earliest_at then
                earliest_idx = i
                earliest_at  = t.fireAt
            end
        end
        if not earliest_idx then break end
        local t = self.timers[earliest_idx]
        table.remove(self.timers, earliest_idx)
        t.callback()
    end
end
```

This also fixes the secondary issue where cascaded timers (scheduled by a callback during advance) that are ready to fire are silently skipped until the next `advance` call.

## Warnings

### WR-01: Cascaded timers scheduled by callbacks are silently dropped during advance

**File:** `spec/support/wow_stubs.lua:24-41`
**Issue:** `mockClock:advance()` computes the `fired` list once before executing any callbacks. If a callback schedules a new timer whose `fireAt <= self.now` (which is already advanced), that new timer will not fire during the current `advance()` call. In real WoW, `C_Timer.After(0, fn)` fires on the next frame, which is essentially immediate. The mock silently defers it, requiring an additional `advance()` call to fire it. This is a correctness gap that could cause subtle test failures when testing code paths like `ScheduleExpiration`'s self-rescheduling branch (TipOfTheSpear.lua:393).

**Fix:** The fix in CR-01 (while-loop approach) addresses this issue simultaneously by re-scanning the timer list after each callback fires.

### WR-02: FindTrackedSpell iterates over all event args including non-spell-ID values

**File:** `Duncedmaxxing/Modules/TipOfTheSpear.lua:761`
**Issue:** `UNIT_SPELLCAST_SUCCEEDED` event handler passes all varargs (`unit`, `castGUID`, `spellID`) to `FindTrackedSpell(...)`. The function then calls `ClassifySpellID` on each arg, including the string `unit` ("player") and string `castGUID`, before reaching the numeric `spellID`. While `ClassifySpellID` safely returns nil for non-numbers (the `type(value) == "number"` guard at line 69), this is wasteful and fragile: if WoW ever adds a numeric arg before `spellID`, it could false-match. The intent is clearly to check only the spellID.

**Fix:**
```lua
elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
    if not self.active then
        self:RefreshActive()
    end
    if not self.active then
        return
    end

    local unit, castGUID, spellID = ...
    local kind = ClassifySpellID(spellID)
    if kind then
        self:ApplySpell(kind, spellID)
    end
```

### WR-03: Test loader skips Options.lua, leaving Options integration untested

**File:** `spec/support/init.lua:29-33`
**Issue:** The test loader loads Util.lua, Core.lua, and TipOfTheSpear.lua but skips Options.lua entirely. While the comment at line 30 acknowledges this, it means that `DMX:InitializeOptions()` is never called during test bootstrap, and the Options module's interaction with the tracker (via `RefreshTracker` -> `DMX:RefreshTip()`) and its combat safety guards are completely untested. If Options.lua introduces a regression that corrupts `db.tip` settings, no test will catch it.

**Fix:** Add Options.lua to the loader sequence and include at least basic integration tests for `Options:CanChange()`, `Options:SetMode()`, and the combat-guard flow.

### WR-04: Test spec monkey-patches Tip.SyncFromAura without cleanup on assertion failure

**File:** `spec/tip_spec.lua:338-376`
**Issue:** Multiple test cases (lines 338-376, 380-395, 438-449) override `Tip.SyncFromAura` with a spy wrapper and restore the original at the end of the test body. If an assertion fails before the restore line (e.g., `assert.equals(1, syncCallCount)` at line 372), the monkey-patch persists into subsequent tests. This violates test isolation and can cause cascading failures that are hard to diagnose. The `before_each` calls `loader.load()` which creates a fresh module, so this is mitigated by the test structure. However, within a single `describe` block where `before_each` calls `loader.load()`, the fresh load prevents leakage across tests. The risk is low given current structure but the pattern is fragile.

**Fix:** Use `finally` or `teardown` blocks to ensure cleanup:
```lua
it("does not call SyncFromAura when serial is stale", function()
    local syncCallCount = 0
    local originalSync  = Tip.SyncFromAura
    Tip.SyncFromAura    = function(self)
        syncCallCount = syncCallCount + 1
        return originalSync(self)
    end
    finally(function() Tip.SyncFromAura = originalSync end)

    -- ... test body ...
end)
```

## Info

### IN-01: Dead parameter in stubs.install()

**File:** `spec/support/wow_stubs.lua:120`
**Issue:** The `install(DMX)` function accepts a `DMX` parameter but never references it. Callers pass the DMX table (init.lua:27) but it serves no purpose.

**Fix:** Remove the parameter:
```lua
local function install()
```
and update the call site in init.lua:27 to `stubs.install()`.

### IN-02: Dead export stubs.reset() is never called by any test

**File:** `spec/support/wow_stubs.lua:191-194`
**Issue:** The `reset()` function is exported in the return table but never called anywhere. Test reset is handled by `loader.resetTipState()` which calls `clock:reset()` and resets `mockAura.impl` directly. The unused export adds confusion about which reset path to use.

**Fix:** Either remove the export from the return table, or document it as the canonical external reset and have `resetTipState` call it internally.

---

_Reviewed: 2026-06-18T14:45:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
