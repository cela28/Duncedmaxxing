# Testing Patterns

**Analysis Date:** 2026-06-18

## Test Framework

**Runner:**
- **busted** - Lua unit test framework (5.1-compatible)
- Config: `.busted` — pattern `_spec`, utfTerminal output, no keep-going
- Location: Tests live in `spec/` directory with `_spec.lua` suffix

**Assertion Library:**
- busted's built-in assertions (included with busted)
- Common patterns: `assert.equals()`, `assert.is_nil()`, `assert.is_true()`, `assert.is_false()`, `assert.is_near()`, `assert.is_not_nil()`, `assert.is_table()`

**Run Commands:**
```bash
busted                # Run all tests
busted spec/tip_spec.lua  # Run single suite
busted --luas spec/util_spec.lua  # Verbose mode (implied by utfTerminal)
```

## Test Infrastructure

**Test Loader:** `spec/support/init.lua`
- Implements `loadAddon(path, addonName, dmxTable)` to load Lua files with proper WoW vararg injection
- Uses `loadfile()` not `dofile()` (RESEARCH Pitfall 2: dofile passes empty varargs, breaking `local _, DMX = ...`)
- Implements `load()` that:
  1. Creates isolated `DMX = {}` namespace per test run (D-06: full isolation)
  2. Installs WoW API stubs via `stubs.install(DMX)`
  3. Loads addon files in TOC order: `Util.lua`, `Core.lua`, `Modules/TipOfTheSpear.lua` (skips Options.lua)
  4. Replicates `ADDON_LOADED` bootstrap: initializes DB, calls `MergeDefaults`, `NormalizeDB`, module dispatch
  5. Returns `(DMX, Tip, mockClock)` for test access
- Implements `resetTipState(Tip, clock)` to zero all mutable fields before each test

**WoW API Stubs:** `spec/support/wow_stubs.lua`
- Mock timers: `C_Timer.After()`, `C_Timer.NewTimer()` with cancel/IsCancelled
- Mock auras: `C_UnitAuras.GetPlayerAuraBySpellID()` wraps `mockAura.impl` (single-dispatch point for all tests)
- Mock frame API: `CreateFrame()` returns `noopFrame()` with Show/Hide/SetShown/SetText/SetScript/CreateTexture/CreateFontString
- Mock globals: `GetTime()`, `C_SpecializationInfo.GetSpecialization()`, `C_Spell.GetSpellTexture()`, `UnitClass()`, `InCombatLockdown()`, `GetSpecialization()`
- **Aura data builder:** `makeAuraData(overrides)` — full `Struct_AuraData` contract fidelity (D-03)
- **Mock clock:** `mockClock` object with `.now`, `:advance(dt)`, `:reset()` — auto-fires timers when `.now` increases

## Test File Organization

**Location:**
- `spec/util_spec.lua` — unit tests for `DMX.Util.*` pure functions
- `spec/core_spec.lua` — unit tests for `DMX._test.MergeDefaults`, `DMX._test.NormalizeDB`
- `spec/tip_spec.lua` — unit tests for `Tip:ApplySpell`, `Tip:SyncFromAura`, `Tip:ScheduleCastVerify`
- `spec/support/init.lua` — test infrastructure (loader, bootstrap)
- `spec/support/wow_stubs.lua` — WoW API mocks

**Naming:**
- Pattern: `*_spec.lua` (matched by `.busted` pattern)
- Suite-to-file mapping: one module per file for clarity

**Structure:**
```lua
-- Top of each spec file:
local loader = require("spec.support.init")
local stubs  = require("spec.support.wow_stubs")  -- if using mocks

-- Per-suite setup:
describe("Feature Name", function()
    local DMX, Tip, clock
    
    before_each(function()
        DMX, Tip, clock = loader.load()  -- fresh load each test
        if Tip then
            loader.resetTipState(Tip, clock)  -- zero mutable fields
        end
    end)
    
    -- Individual tests:
    it("description of expected behavior", function()
        -- arrange
        stubs.mockAura.impl = function(_) return stubs.makeAuraData(...) end
        
        -- act
        local result = Tip:SomeMethod()
        
        -- assert
        assert.equals(expected, result)
    end)
end)
```

## Test Coverage

**Currently tested:**

**Utility functions** (`spec/util_spec.lua`):
- `DMX.Util.Clamp` — numeric range clamping with string coercion; 9 test cases covering bounds, negatives, non-numeric strings
- `DMX.Util.ParseHexColor` — hex color parsing (6-char, 8-char, with # prefix); 8 cases covering valid inputs, invalid chars, wrong lengths
- `DMX.Util.ParseOnOff` — parse boolean tokens ("on"/"off"/"yes"/"no"/"true"/"false"/"1"/"0"); 10 cases with case-insensitivity and whitespace handling
- `DMX.Util.Trim` — strip leading/trailing whitespace; 4 cases covering nil, empty, and internal spaces

**Core DB functions** (`spec/core_spec.lua`):
- `MergeDefaults` — merge user DB with defaults; 6 cases covering existing values, nil slots, nested tables, nil target
- `NormalizeDB` (migration branch) — settings migration on version mismatch; 8 cases covering version bump, field preservation, defaults, deprecated field cleanup
- `NormalizeDB` (already migrated) — skip migration when version matches; 2 cases checking displayMode preservation and version stability
- `NormalizeDB` (deprecated field migration) — always-run post-migration cleanup; 4 cases covering barWidth→width, barHeight→height, spacing→borderSize
- `NormalizeDB` (displayMode validation) — always-run validation; 5 cases covering invalid mode reset, all valid modes, nil reset

**Tracking logic** (`spec/tip_spec.lua`):
- `Tip:ApplySpell` — predictive stack state updates; 10 cases covering generator (+2 stacks), consumer (-1 stack), capping, expireTimer scheduling, prediction tracking
- `Tip:SyncFromAura` — live aura sync with consumer grace suppression; 7 cases covering:
  - API errors (GetPlayerAuraBySpellID throws)
  - Stack sync from live aura
  - expiresAt sync
  - Zero on absent aura
  - Consumer grace suppression within 2.75s window
  - Consumer grace suppression expiry past window
  - Generator (no suppression)
  - Out-of-combat (no suppression)
- `Tip:ScheduleCastVerify` — serial-mismatch guard for stale timers; 2 cases covering stale serial rejection and valid serial execution

**Total: 61 test cases** covering pure logic paths, DB migrations, stack tracking, and timer mechanics.

## Mocking Strategy

**What is mocked:**
- `C_Timer` — full implementation with callback queueing and serial numbers
- `C_UnitAuras.GetPlayerAuraBySpellID` — wrapped to call `mockAura.impl` per-test
- Frame API — no-op frames tracking visibility/text/scripts
- `GetTime` — returns `mockClock.now`
- Spec detection — always returns Survival Hunter (spec 3)
- `UnitClass` — always returns Hunter

**What is NOT mocked:**
- Pure Lua table operations (`table.insert`, `table.remove`, ipairs, etc.)
- Module loading and registration
- The `local` capture pattern used by TipOfTheSpear.lua (tests must reload module to change stubs)

**Key constraint:** TipOfTheSpear.lua captures `C_UnitAuras.GetPlayerAuraBySpellID` as a module-level local on load (`local GetPlayerAuraBySpellID = C_UnitAuras and ...`). Tests cannot swap out the captured function directly; instead, tests override `mockAura.impl` and tests reload the module via `loader.load()` on each `before_each()`.

## Test Patterns

**Per-test isolation (D-06):**
```lua
before_each(function()
    DMX, Tip, clock = loader.load()  -- fresh namespace, reloads all modules
    loader.resetTipState(Tip, clock)  -- zeros all mutable Tip fields
end)
```

**Mock clock timer simulation (D-08, D-09):**
```lua
Tip:ApplySpell("generator")
-- Timer scheduled at fireAt = clock.now + BUFF_DURATION
clock:advance(10.1)  -- auto-fires timers where fireAt <= clock.now
assert.equals(0, Tip.stacks)  -- expireTimer fired and zeroed stacks
```

**Aura mocking:**
```lua
stubs.mockAura.impl = function(_spellID)
    return stubs.makeAuraData({ applications = 2, expirationTime = clock.now + 8 })
end
local result = Tip:SyncFromAura()
assert.is_true(result)
```

**Assertion patterns:**
```lua
assert.equals(expected, actual)  -- numeric/string equality
assert.is_nil(value)            -- nil check
assert.is_true/is_false(bool)   -- boolean
assert.is_near(expected, actual, tolerance)  -- float with epsilon
```

## Adding New Tests

**To add tests for a new function:**

1. Create a new `describe("Feature Name", function() ... end)` block
2. Load the module in `before_each()` via `loader.load()`
3. Use `stubs.mockAura.impl` to control aura returns
4. Use `clock:advance()` to trigger timers
5. Use standard busted assertions

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
end)
```

## Coverage Gaps (from 2026-06-17 analysis)

Automatically tested in this build:
- ✓ `Clamp` — all paths
- ✓ `ParseHexColor` — all paths
- ✓ `ParseOnOff` — all paths
- ✓ `Trim` — all paths
- ✓ `MergeDefaults` — all paths
- ✓ `NormalizeDB` — migration, validation, deprecated field cleanup paths
- ✓ `Tip:ApplySpell` — generator, consumer, capping, timer scheduling
- ✓ `Tip:SyncFromAura` — all sync paths, consumer grace suppression, out-of-combat paths
- ✓ `Tip:ScheduleCastVerify` — serial mismatch guard

Still untested (manual in-game verification required):
- **ReadLiveState pcall branches** — full error handling paths (frame rendering still untested)
- **ClassifySpellID pcall** — whether inner code can actually throw
- **UI frame construction** — `CreateFrame`, `CreateTexture`, `CreateFontString` rendering (not tested, no mock visibility assertions)
- **Slash command handler** — `/dmax` parsing and direct db mutation (integration test, not unit tested)
- **Options window** — combat lockdown guard, widget updates (frame API not fully mocked)

## Verification in Phase 02

Test framework was implemented to satisfy:
- D-02: Pure function unit testing (Util, Core, Tip tracking logic)
- D-03: Full AuraData contract fidelity in mocks
- D-04: WoW API stubs for timers, auras, frames, globals
- D-05: Mock clock with auto-fire on time advance
- D-06: Per-test isolation (fresh load each test)
- D-08, D-09: Timer simulation for expiry and verify delays

Tests pass and serve as regression safety net for core tracking logic and DB migrations.

---

*Testing analysis: 2026-06-18*
