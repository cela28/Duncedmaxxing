# Testing Patterns

**Analysis Date:** 2026-06-18

## Test Framework

**Runner:** busted (Lua unit test framework)
- Config: `.busted` — pattern `_spec`, utfTerminal output, no keep-going
- Location: Tests live in `spec/` directory with `_spec.lua` suffix
- Assertion Library: busted's built-in assertions (`assert.equals()`, `assert.is_nil()`, `assert.is_true()`, `assert.is_false()`, `assert.is_near()`, `assert.is_not_nil()`, `assert.is_table()`, `assert.are.equal()`)

**Run Commands:**
```bash
busted                              # Run all tests
busted spec/tip_spec.lua            # Run single suite
busted --verbose                    # Verbose output (utfTerminal)
```

## Test Infrastructure

**Test Loader:** `spec/support/init.lua`
- `loadAddon(path, addonName, dmxTable)` — Loads Lua files with proper WoW vararg injection
- Uses `loadfile()` not `dofile()` (RESEARCH Pitfall 2: dofile passes empty varargs, breaking `local _, DMX = ...`)
- `load()` function returns `(DMX, Tip, mockClock)`:
  1. Creates isolated `DMX = {}` namespace per test run (D-06: full isolation)
  2. Installs WoW API stubs via `stubs.install(DMX)`
  3. Loads addon files in TOC order: `Util.lua`, `Core.lua`, `Modules/TipOfTheSpear.lua` (skips Options.lua)
  4. Replicates `ADDON_LOADED` bootstrap: initializes DB, calls `MergeDefaults`, `NormalizeDB`, module dispatch via `DMX._test` escape hatch
  5. Returns `(DMX, Tip, mockClock)` for test access
- `resetTipState(Tip, clock)` — Zeros all mutable tracking fields (`stacks`, `expiresAt`, `lastPredictAt`, `castVerifySerial`, `auraVerifyPending`, `expireTimer`, `testMode`); sets `clock.now = 100` (non-zero base avoids grace-period collision)

**WoW API Stubs:** `spec/support/wow_stubs.lua`
- **Mock timers:** `C_Timer.After()`, `C_Timer.NewTimer()` with cancel/IsCancelled; timers tracked in `mockClock.timers` list
- **Mock auras:** `C_UnitAuras.GetPlayerAuraBySpellID()` wraps `mockAura.impl` (single-dispatch point for all tests)
- **Mock frames:** `CreateFrame()` returns `noopFrame()` with Show/Hide/SetShown/SetText/SetScript/CreateTexture/CreateFontString; tracks `_visible`, `_text`, `_scripts`
- **Mock globals:** `GetTime()`, `C_SpecializationInfo.GetSpecialization()`, `GetSpecialization()`, `C_Spell.GetSpellTexture()`, `GetSpellTexture()`, `UnitClass()`, `InCombatLockdown()`, `DEFAULT_CHAT_FRAME`, `STANDARD_TEXT_FONT`, `UIParent`, `SlashCmdList`
- **AuraData builder:** `makeAuraData(overrides)` — full `Struct_AuraData` contract fidelity (D-03); supports overrides like `{ applications = 2, expirationTime = clock.now + 8 }`
- **Mock clock:** `mockClock` object with:
  - `.now` — current simulated time (starts at 0, reset to 100 per test)
  - `:advance(dt)` — advances time by dt seconds; auto-fires all timers where `fireAt <= now`
  - `:reset()` — zeros clock and clears all pending timers

## Test File Organization

**Location:**
- `spec/util_spec.lua` — unit tests for `DMX.Util.Clamp`, `ParseHexColor`, `ParseOnOff`, `Trim`
- `spec/core_spec.lua` — unit tests for `DMX._test.MergeDefaults`, `DMX._test.NormalizeDB`
- `spec/tip_spec.lua` — unit tests for `Tip:ApplySpell`, `Tip:SyncFromAura`, `Tip:ScheduleCastVerify`
- `spec/support/init.lua` — test infrastructure (loader, bootstrap)
- `spec/support/wow_stubs.lua` — WoW API mocks and aura builders

**Naming:** Pattern `*_spec.lua` (matched by `.busted` pattern)

**Structure (per spec file):**
```lua
-- Top of each spec file:
local loader = require("spec.support.init")
local stubs  = require("spec.support.wow_stubs")  -- if using mocks

-- Per-suite setup:
describe("Feature Name", function()
    local DMX, Tip, clock
    
    before_each(function()
        DMX, Tip, clock = loader.load()  -- fresh load each test
        loader.resetTipState(Tip, clock)  -- zero mutable fields, set clock.now = 100
    end)
    
    -- Individual tests:
    it("description of expected behavior", function()
        -- arrange
        stubs.mockAura.impl = function(_) return stubs.makeAuraData({...}) end
        
        -- act
        local result = Tip:SomeMethod()
        
        -- assert
        assert.equals(expected, result)
    end)
    
    -- Pending tests:
    pending("not yet implemented feature")
end)
```

## Test Coverage

**Utility functions** (`spec/util_spec.lua` — 44 tests):
- `DMX.Util.Clamp(value, minValue, maxValue)` — 12 tests covering:
  - In-bounds return, min/max bounds, boundary values
  - Coerces numeric strings, returns nil for non-numeric
  - Negative ranges, above/below negative bounds
- `DMX.Util.ParseHexColor(hexStr)` — 10 tests covering:
  - 6-char hex parsing with correct r,g,b,a values
  - 8-char hex with alpha channel
  - Leading `#` stripping
  - Invalid hex characters, wrong lengths (3, 5, 7 chars), empty string
  - Pure white/black edge cases
- `DMX.Util.ParseOnOff(str)` — 9 tests covering:
  - Returns true for "on", "true", "1", "yes" (case-insensitive)
  - Returns false for "off", "false", "0", "no" (case-insensitive)
  - Whitespace trimming before parsing
  - Returns nil for unrecognized tokens
- `DMX.Util.Trim(str)` — 5 tests covering:
  - Leading/trailing whitespace removal
  - nil input returns ""
  - Whitespace-only input returns ""
  - Internal whitespace preservation

**Core DB functions** (`spec/core_spec.lua` — 25 tests):
- `MergeDefaults(defaults, target)` — 6 tests covering:
  - Does not overwrite existing non-nil values in target
  - Fills nil slots from defaults
  - Deep-merges nested tables, preserving existing nested values
  - Creates missing nested table when target has nil
  - Returns same target table reference
  - Handles nil target by returning copy of defaults
- `NormalizeDB(db)` — 19 tests covering:
  - **Migration branch (settingsMigration mismatch):** 8 tests for running migration, preserving position/scale/options, resetting displayMode, clearing deprecated fields
  - **Already-migrated branch (settingsMigration matches):** 2 tests for skipping migration, preserving displayMode
  - **Deprecated field migration (always runs post-gate):** 4 tests for `barWidth→width`, `barHeight→height`, `spacing→borderSize`, respecting existing borderSize
  - **displayMode validation (always runs):** 5 tests for resetting invalid modes to "bar", preserving all valid modes ("bar"/"icons"/"number"), resetting nil to "bar"

**Tracking logic** (`spec/tip_spec.lua` — 24+ tests):
- `Tip:ApplySpell(kind)` — 13 tests covering:
  - Generator: adds 2 stacks from 0, caps at 3, sets expiresAt to now + BUFF_DURATION, schedules non-cancelled expireTimer, sets lastPredictAt/lastPredictKind
  - Consumer: decrements by 1, floors at 0, clears expiresAt only when hitting 0 (preserves expiresAt when stacks remain > 0)
  - Timer fires after BUFF_DURATION and zeroes stacks
  - Unknown kind: no change, early return
  - Pending: Twin Fangs (BUG-04) implementation
- `Tip:SyncFromAura()` — 8 tests covering:
  - Returns false when GetPlayerAuraBySpellID throws (pcall error path)
  - Returns false when ReadLiveState returns nil via pcall error
  - Syncs stacks from live aura (applications field)
  - Syncs expiresAt from live aura (expirationTime field)
  - Zeroes stacks and expiresAt when aura is absent
  - **Consumer grace suppression:** within 2.75s window (CONSUMER_UPSYNC_GRACE) suppresses up-sync when `lastPredictKind == "consumer"` and `inCombat == true`
  - **Consumer grace suppression expiry:** past window (3+ seconds) allows sync
  - Does NOT suppress when `lastPredictKind == "generator"`
  - Does NOT suppress when `inCombat == false`
- `Tip:ScheduleCastVerify` serial-mismatch guard — 2 tests covering:
  - Does NOT call SyncFromAura when castVerifySerial has changed (stale serial)
  - DOES call SyncFromAura when castVerifySerial matches (valid serial)

**Total: 93+ unit tests** covering pure logic, DB migrations, stack tracking, timer mechanics, aura sync, consumer grace suppression.

## Mocking Strategy

**What is mocked:**
- `C_Timer.After()`, `C_Timer.NewTimer()` — full implementation with callback queueing
- `C_UnitAuras.GetPlayerAuraBySpellID()` — wrapped to call `mockAura.impl` per-test
- Frame API — no-op frames tracking visibility/text/scripts
- `GetTime()` — returns `mockClock.now`
- Spec detection — always returns Survival Hunter (spec 3)
- `UnitClass()` — always returns Hunter
- `InCombatLockdown()` — always returns false

**What is NOT mocked:**
- Pure Lua table operations (`table.insert`, `table.remove`, ipairs, etc.)
- Module loading and registration
- Utility functions like `Clamp`, `ParseHexColor` — test actual logic

**Key constraint:** TipOfTheSpear.lua captures `C_UnitAuras.GetPlayerAuraBySpellID` as a module-level local on load. Tests cannot swap the captured function directly; instead, tests override `mockAura.impl` and reload the module via `loader.load()` on each `before_each()`.

## Test Patterns

**Per-test isolation (D-06):**
```lua
before_each(function()
    DMX, Tip, clock = loader.load()  -- fresh namespace, reloads all modules
    loader.resetTipState(Tip, clock)  -- zeros all mutable Tip fields, clock.now = 100
end)
```

**Mock clock timer simulation (D-08, D-09):**
```lua
Tip:ApplySpell("generator")
-- Timer scheduled at fireAt = clock.now + BUFF_DURATION (100 + 10 = 110)
clock:advance(10.1)  -- auto-fires timers where fireAt <= clock.now (101.1 > 110? No... wait)
-- Actually: advance(10.1) makes clock.now = 100 + 10.1 = 110.1; fires timers at fireAt <= 110.1
assert.equals(0, Tip.stacks)  -- expireTimer fired and zeroed stacks
```

**Aura mocking:**
```lua
stubs.mockAura.impl = function(_spellID)
    return stubs.makeAuraData({ applications = 2, expirationTime = clock.now + 8 })
end
local result = Tip:SyncFromAura()
assert.is_true(result)
assert.equals(2, Tip.stacks)
```

**Spy on method calls (serial-mismatch test):**
```lua
local syncCallCount = 0
local originalSync = Tip.SyncFromAura
Tip.SyncFromAura = function(self)
    syncCallCount = syncCallCount + 1
    return originalSync(self)
end
-- ... do operations ...
assert.equals(1, syncCallCount)  -- called exactly once
Tip.SyncFromAura = originalSync  -- restore
```

**Assertion patterns:**
```lua
assert.equals(expected, actual)  -- numeric/string equality (alias: assert.are.equal)
assert.is_nil(value)            -- nil check
assert.is_not_nil(value)        -- not-nil check
assert.is_true(bool)            -- boolean true
assert.is_false(bool)           -- boolean false
assert.is_table(value)          -- table type check
assert.is_near(expected, actual, tolerance)  -- floating-point with epsilon
```

## Adding New Tests

**To add tests for a new pure-logic function:**

1. Create a describe block in the appropriate spec file (util_spec.lua, core_spec.lua, tip_spec.lua)
2. Load modules in `before_each()` via `loader.load()`
3. Reset state if needed via `loader.resetTipState()`
4. Use `stubs.mockAura.impl` to control aura returns
5. Use `clock:advance()` to trigger timers
6. Use busted assertions

**Example:**
```lua
describe("NewFunction", function()
    local DMX
    
    before_each(function()
        DMX = loader.load()
    end)
    
    it("returns expected value", function()
        local result = DMX.Util.NewFunction(arg1, arg2)
        assert.equals(expected, result)
    end)
    
    pending("handles edge case not yet implemented")
end)
```

## Coverage Status

**Automatically tested in Phase 02-02:**
- ✓ `Clamp` — all paths (bounds, coercion, nil return)
- ✓ `ParseHexColor` — all paths (valid hex, invalid chars, wrong lengths)
- ✓ `ParseOnOff` — all paths (on/off tokens, case-insensitivity, whitespace)
- ✓ `Trim` — all paths (leading/trailing, nil, internal spaces)
- ✓ `MergeDefaults` — all paths (existing values, nil slots, nested, nil target)
- ✓ `NormalizeDB` — all paths (migration, validation, deprecated field cleanup)
- ✓ `Tip:ApplySpell` — all paths (generator, consumer, capping, timers)
- ✓ `Tip:SyncFromAura` — all paths (API errors, sync, grace suppression, gates)
- ✓ `Tip:ScheduleCastVerify` — all paths (stale serial, matching serial)

**Still untested (manual in-game verification required):**
- **ReadLiveState full paths** — all three pcall branches with real WoW API unavailability
- **ClassifySpellID pcall path** — whether inner code can actually throw
- **UI frame construction** — `CreateFrame`, `CreateTexture`, `CreateFontString` rendering and layout
- **Slash command handler** — `/dmax` parsing and direct db mutation
- **Options window** — combat lockdown guard, widget event handlers, interaction flows
- **Event integration** — real WoW events (PLAYER_REGEN_DISABLED, UNIT_AURA, etc.)

## Verification in Phase 02

Test infrastructure implemented to satisfy:
- D-02: Pure function unit testing (Util, Core, Tip tracking)
- D-03: Full AuraData contract fidelity
- D-04: WoW API stubs for timers, auras, frames, globals
- D-05: Mock clock with auto-fire on time advance
- D-06: Per-test isolation (fresh load each test)
- D-08, D-09: Timer simulation for expiry and verify delays
- D-10: Addon escape hatch `DMX._test` for test-only exports

Tests pass and serve as regression safety net for core tracking logic and DB migrations.

---

*Testing analysis: 2026-06-18*
