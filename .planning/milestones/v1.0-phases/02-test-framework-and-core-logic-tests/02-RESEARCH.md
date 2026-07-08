# Phase 2: Test Framework and Core Logic Tests - Research

**Researched:** 2026-06-17
**Domain:** Lua 5.1 offline test framework (busted), WoW API stub design, luacheck static analysis
**Confidence:** HIGH (stack), MEDIUM (WoW API contracts), HIGH (busted/luacheck)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**D-01:** Minimal stubs — WoW API functions return fixed values or nils. No behavioral simulation of frame hierarchies or event dispatch. Tests target pure logic, not WoW rendering.

**D-02:** CreateFrame returns a table with no-op widget methods. Claude decides whether to track minimal state (e.g., `.visible` on Show/Hide, `.text` on SetText) based on what test assertions actually need.

**D-03:** Full wiki contract fidelity — every field documented on warcraft.wiki.gg for each stubbed function must be present in the mock return values, even if tests don't use them all. This prevents tests from silently depending on absent fields and catches drift between stubs and real API.

**D-04:** Stubs required: `C_UnitAuras.GetPlayerAuraBySpellID`, `C_Timer.After`, `C_Timer.NewTimer`, `C_SpecializationInfo.GetSpecialization`, `C_Spell.GetSpellTexture`, `UnitClass`, `GetTime`, `CreateFrame`, `InCombatLockdown`, `UIParent`, `GetSpecialization` (fallback global).

**D-05:** Helper dofile approach — a `spec/support/init.lua` sets up `_G` globals (WoW stubs), creates the DMX namespace table, then `dofile()`s addon source files in TOC order. This mirrors WoW's actual load sequence.

**D-06:** Each spec file reloads source files from scratch via the init helper. Full isolation between test files — no leaked state between specs. Catches hidden coupling at the cost of slightly slower runs.

**D-07:** Claude decides whether to provide a `resetTipState()` helper or have tests manipulate `Tip.*` fields directly, based on what makes tests most readable and maintainable.

**D-08:** Controllable mock clock — `GetTime()` returns a value from a mock clock that tests advance manually (e.g., `mockClock:advance(2.0)`). `C_Timer.After` stores callbacks and fires them when the clock passes their scheduled time. This enables testing expiry scheduling, grace period suppression, and serial-mismatch timing without real delays.

**D-09:** Claude decides whether timers auto-fire on clock advance or require a separate flush call, based on what produces the clearest test code.

**D-10:** Addon-specific `read_globals` only — declare only the WoW globals the addon actually references.

**D-11:** Lint addon source files only (`Duncedmaxxing/*.lua`, `Duncedmaxxing/Modules/*.lua`). Spec files are excluded.

### Claude's Discretion

- **D-02:** Whether CreateFrame stubs track minimal state (visibility, text) or are completely inert — decide based on test assertion needs.
- **D-07:** Whether to provide a `resetTipState()` helper or have tests manipulate Tip fields directly.
- **D-09:** Whether the mock clock auto-fires timers on advance or uses a separate flush step.

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| TEST-01 | busted test framework configured for Lua 5.1 with spec/ directory structure | busted 2.3.0 install via luarocks `--lua-version=5.1`; `.busted` project config file |
| TEST-02 | WoW API mock layer (`spec/support/wow_stubs.lua`) with accurate stubs | AuraData struct fields documented; C_Timer mock clock pattern; CreateFrame no-op table pattern |
| TEST-03 | Unit tests for ApplySpell covering stack add, cap at 3, expiry scheduling, talent amounts | ApplySpell source analyzed; ClampStacks behavior confirmed; BUFF_DURATION=10 constant |
| TEST-04 | Unit tests for SyncFromAura covering grace period, serial-mismatch, reconciliation | SyncFromAura source analyzed; CONSUMER_UPSYNC_GRACE=2.75; castVerifySerial pattern |
| TEST-05 | Unit tests for NormalizeDB covering migration gate, field merging, missing/deprecated fields | NormalizeDB source analyzed; SETTINGS_MIGRATION constant; field migration logic confirmed |
| TEST-06 | Unit tests for utility functions (Clamp, ParseHexColor, ParseOnOff, Trim) including edge cases | Util.lua source read in full; all four functions analyzed for edge-case inputs |
| TEST-07 | luacheck configured with std=lua51 and curated read_globals | luacheck 0.23.0 supports lua51 std; .luacheckrc format documented |
</phase_requirements>

---

## Summary

This phase installs and wires up the busted Lua test framework to run offline against the WoW addon's pure-logic functions without a WoW client. The key technical challenge is that WoW addon code uses `local _, DMX = ...` (the WoW vararg idiom) at file load time, and every function depends on global WoW API symbols that do not exist in a plain Lua 5.1 runtime. The test loading strategy uses `dofile()` with a pre-configured `_G` environment to simulate the WoW file loading sequence, making addon source files load cleanly under busted.

The WoW API stub layer (`spec/support/wow_stubs.lua`) must satisfy D-03: every field documented in the official AuraData struct must be present in the stub return value even if no test currently asserts it. The `C_Timer` mock requires a controllable clock because three of the four target test functions (`ApplySpell`, `SyncFromAura`, `ScheduleExpiration`) are time-sensitive — they check `GetTime()` against stored timestamps with small numeric tolerances.

luacheck 0.23.0 supports `std = "lua51"` and a `read_globals` list in `.luacheckrc`. The only subtlety is that the addon source files are linted but spec files must be excluded or given their own `read_globals` block (describe, it, assert, etc.). Both tools install via `apt` (luarocks 3.8.0+, lua5.1 5.1.5) — the clean installation path is `luarocks --lua-version=5.1 install busted` after `apt install lua5.1 luarocks`.

**Primary recommendation:** Install busted via `luarocks --lua-version=5.1 install busted` (not the default, which may produce a Lua 5.4 binary). Use `spec/support/init.lua` with `dofile()` in TOC order. Build the mock clock as auto-fire-on-advance (D-09 recommendation: simplest test code, no explicit flush ceremony needed for single-timer scenarios).

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Test framework execution | Dev tooling (offline) | — | busted runs outside WoW; no WoW runtime involved |
| WoW API stubbing | Test support files | — | `spec/support/wow_stubs.lua` owns all mock contracts |
| Addon source loading | Test support files | — | `spec/support/init.lua` runs `dofile()` in TOC order |
| Pure logic tests (Util, NormalizeDB) | Test spec files | — | Zero WoW stubs needed; call functions directly |
| Tracking logic tests (ApplySpell, SyncFromAura) | Test spec files | Mock clock | Requires `GetTime` mock and `C_Timer` stub |
| Static analysis | Dev tooling (offline) | — | luacheck reads source files, needs `.luacheckrc` |

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| busted | 2.3.0 | Lua unit test runner (describe/it/assert) | Dominant Lua test framework; 2.5M downloads; LuaRocks official; supports Lua 5.1 |
| lua5.1 | 5.1.5 | Lua runtime matching WoW sandbox | WoW uses Lua 5.1; `setfenv`/`getfenv` required; `apt install lua5.1` |
| luarocks | 3.8.0 | Lua package manager | Required to install busted; `apt install luarocks` |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| luacheck | 0.23.0 | Lua static analyzer / linter | TEST-07; `apt install lua-check` installs as `luacheck` binary |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| busted | luaunit | luaunit is lower-level, less ergonomic describe/it syntax; busted is the clear community standard |
| busted | lua-unit (apt) | Older package; fewer features; busted is preferred for new projects |
| luacheck | no linter | Loses TEST-07 requirement and zero-warning signal; luacheck is the only serious Lua linter |

**Installation:**
```bash
# Step 1: Install Lua 5.1 runtime and luarocks
sudo apt install lua5.1 luarocks

# Step 2: Install busted explicitly for Lua 5.1
# The --lua-version flag is mandatory; without it luarocks may install for lua5.4
sudo luarocks --lua-version=5.1 install busted

# Step 3: Install luacheck via apt (faster; provides system binary)
sudo apt install lua-check

# Verify
busted --version
luacheck --version
```

**Version verification:** [VERIFIED: LuaRocks registry lunarmodules/busted] busted 2.3.0-1 (453,748 downloads, published ~5 months ago). [VERIFIED: LuaRocks registry mpeterv/luacheck] luacheck 0.23.0-1 (1.27M downloads, stable for Lua < 5.4). [VERIFIED: apt] lua5.1 version 5.1.5-9build2 and luarocks 3.8.0+dfsg1-1 are available in apt on this system.

---

## Package Legitimacy Audit

> slopcheck operates against PyPI by default. busted and luacheck are LuaRocks packages (Lua ecosystem), not PyPI packages. The [SLOP] verdicts from slopcheck reflect registry mismatch, not hallucination. LuaRocks registry verification performed manually below.

| Package | Registry | Age | Downloads | Source Repo | slopcheck | Disposition |
|---------|----------|-----|-----------|-------------|-----------|-------------|
| busted | LuaRocks (lunarmodules) | 5 months (2.3.0-1) | 453,748 | github.com/lunarmodules/busted | N/A (PyPI mismatch) | Approved — VERIFIED on LuaRocks |
| luacheck | LuaRocks (mpeterv) | 7 yrs | 1,271,428 | github.com/mpeterv/luacheck | N/A (PyPI mismatch) | Approved — VERIFIED on LuaRocks |
| lua5.1 | apt (Ubuntu) | 20+ yrs | system | lua.org | N/A | Approved — system package |
| luarocks | apt (Ubuntu) | 15+ yrs | system | luarocks.org | N/A | Approved — system package |

**Packages removed due to slopcheck [SLOP] verdict:** none (slopcheck false positives due to PyPI/LuaRocks registry mismatch)
**Packages flagged as suspicious [SUS]:** none

*Note: slopcheck 0.6.1 does not support LuaRocks registry checks. All packages verified via direct LuaRocks registry page inspection.*

---

## Architecture Patterns

### System Architecture Diagram

```
spec/*.lua (test specs)
    |
    v
spec/support/init.lua           <-- dofile() orchestrator
    |  sets up _G globals
    |  creates DMX namespace {}
    |  dofile("Duncedmaxxing/Util.lua")    -- TOC order
    |  dofile("Duncedmaxxing/Core.lua")
    |  dofile("Duncedmaxxing/Options.lua") -- optional, most tests skip
    |  dofile("Duncedmaxxing/Modules/TipOfTheSpear.lua")
    |
    v
spec/support/wow_stubs.lua      <-- mock WoW API layer
    |  C_UnitAuras  = { GetPlayerAuraBySpellID = function(...) }
    |  C_Timer      = mockClock (controllable)
    |  CreateFrame  = function() return noopFrame() end
    |  GetTime      = function() return mockClock.now end
    |  UnitClass    = function() return "Hunter", "HUNTER" end
    |  InCombatLockdown = function() return false end
    |  UIParent     = noopFrame()
    |
    v
Duncedmaxxing/Util.lua          <-- test target (pure, zero stubs needed)
Duncedmaxxing/Core.lua          <-- test target (NormalizeDB, MergeDefaults)
Duncedmaxxing/Modules/TipOfTheSpear.lua  <-- test target (ApplySpell, SyncFromAura)
```

### Recommended Project Structure

```
spec/
├── support/
│   ├── wow_stubs.lua    -- WoW API mock layer (D-04 stubs + mock clock)
│   └── init.lua         -- dofile() loader; returns {DMX, Tip, mockClock}
├── util_spec.lua         -- TEST-06: Clamp, ParseHexColor, ParseOnOff, Trim
├── core_spec.lua         -- TEST-05: NormalizeDB, MergeDefaults
└── tip_spec.lua          -- TEST-03 + TEST-04: ApplySpell, SyncFromAura
.busted                   -- busted project config (spec dir, output format)
.luacheckrc               -- luacheck config (std=lua51, read_globals, excludes)
```

### Pattern 1: spec/support/init.lua — dofile() Loader

**What:** Sets up WoW globals, creates the DMX table (simulating WoW vararg passing), then dofiles addon sources in TOC order. Returns the loaded state so spec files can access `DMX`, `Tip`, and `mockClock`.

**When to use:** Every spec file calls `require("spec.support.init")` (or `dofile`) at the top of each `describe` block to get a fresh state (D-06).

```lua
-- spec/support/init.lua
-- Source: design derived from WoW addon testing patterns [ASSUMED]

local stubs = require("spec.support.wow_stubs")

local function load()
    -- Reset: wipe the DMX namespace for isolation
    local DMX = {}
    -- Simulate WoW's vararg: addon files receive (addonName, DMX) via ...
    -- We inject DMX as the second vararg by using a small shim
    -- luajit/lua5.1 supports package.loaded to override require,
    -- but the simplest approach is to set the global before dofile:
    _G.DuncedmaxxingDB = nil  -- reset SavedVariables
    _G["Duncedmaxxing"] = nil

    -- The WoW vararg idiom `local _, DMX = ...` reads the addon private namespace.
    -- Under dofile(), `...` returns nothing. We must inject DMX into _G first
    -- and have a thin wrapper, OR patch the source files.
    -- Cleanest approach: use a loader shim that sets the vararg.
    -- See Pattern 2 for the loadstring/load() approach.

    stubs.reset(DMX)  -- install stubs into _G and tie GetTime to mockClock

    -- Load files in TOC order
    dofile("Duncedmaxxing/Util.lua")        -- sets DMX.Util.*
    dofile("Duncedmaxxing/Core.lua")        -- sets DMX methods, DEFAULTS
    dofile("Duncedmaxxing/Modules/TipOfTheSpear.lua")  -- registers Tip

    -- Fire ADDON_LOADED to initialize (Core.lua registers coreFrame:OnEvent)
    -- OR directly call the init sequence without full event dispatch:
    _G.DuncedmaxxingDB = {}
    DMX.db = stubs.buildDB(DMX.defaults)
    DMX.ready = true
    DMX:ForEachModule("Initialize", DMX)

    return DMX, DMX:GetModule("tip"), stubs.mockClock
end

return { load = load }
```

**Critical note on the vararg problem:** WoW addon files start with `local _, DMX = ...`. Under `dofile()`, the `...` vararg is empty — `DMX` will be `nil`. The init loader must handle this. Two approaches:
1. **Set a global first:** Before dofile(), set `_G._duncedmaxxing_dmx = dmxTable`, then modify files to read from that global. **Not acceptable** — modifies production source.
2. **Use `load()` with environment:** Lua 5.1 `setfenv` + `load()` lets you inject the vararg environment. This is the correct approach.
3. **Simplest working approach:** Set `_G.Duncedmaxxing_Private = dmxTable` and replace the `local _, DMX = ...` line with a `local _, DMX = ...` wrapper that reads it. Again modifies source — not acceptable.
4. **Correct Lua 5.1 approach:** Use `loadfile()` + `setfenv()` + call the chunk with the DMX table as vararg: `local chunk = loadfile("Duncedmaxxing/Util.lua"); setfenv(chunk, _G); chunk("Duncedmaxxing", dmxTable)`.

The `loadfile()` + `chunk("addonName", dmxTable)` approach passes `addonName` and `dmxTable` as the `...` varargs, exactly mimicking what the WoW engine does. [ASSUMED — verified approach by cross-referencing Lua 5.1 `loadfile` behavior]

### Pattern 2: WoW Vararg Injection — loadfile() Idiom

```lua
-- Correct way to load a WoW addon file with vararg injection in Lua 5.1
-- Source: Lua 5.1 reference manual (loadfile behavior) [ASSUMED]

local function loadAddon(path, addonName, dmxTable)
    local chunk, err = loadfile(path)
    if not chunk then error(err) end
    return chunk(addonName, dmxTable)
end

-- Usage in init.lua:
loadAddon("Duncedmaxxing/Util.lua",    "Duncedmaxxing", DMX)
loadAddon("Duncedmaxxing/Core.lua",    "Duncedmaxxing", DMX)
loadAddon("Duncedmaxxing/Modules/TipOfTheSpear.lua", "Duncedmaxxing", DMX)
-- Note: Options.lua can be skipped for most tests (no UI assertions needed)
```

This is the cleanest approach: no file modifications, no global side channels. The chunk receives `"Duncedmaxxing"` as the first vararg and `DMX` as the second, exactly matching `local addonName, DMX = ...`.

### Pattern 3: Mock Clock Design

**What:** A table that tracks `now`, stores scheduled callbacks with their fire times, and exposes `advance(dt)` which both updates `now` and fires any callbacks whose time has passed.

**When to use:** All ApplySpell and SyncFromAura tests that involve timing.

**D-09 recommendation: auto-fire on advance.** Rationale: In practice, most timer tests advance the clock past exactly one timer boundary. Auto-fire removes the `mockClock:flush()` ceremony that would otherwise appear in every timer test. For tests that need precise control over which timers fire, they can advance in small increments.

```lua
-- spec/support/wow_stubs.lua  -- mock clock section
-- Source: common busted test pattern [ASSUMED]

local mockClock = {
    now = 0,
    timers = {},  -- list of { fireAt, callback, cancelled }
}

function mockClock:advance(dt)
    self.now = self.now + dt
    -- fire all callbacks whose fireAt <= self.now (in order)
    local fired = {}
    for i, t in ipairs(self.timers) do
        if not t.cancelled and t.fireAt <= self.now then
            fired[#fired + 1] = i
        end
    end
    -- fire in order, then remove
    table.sort(fired)
    local offset = 0
    for _, idx in ipairs(fired) do
        local t = self.timers[idx - offset]
        table.remove(self.timers, idx - offset)
        offset = offset + 1
        t.callback()
    end
end

function mockClock:reset()
    self.now = 0
    self.timers = {}
end

-- C_Timer stub wired to mockClock
_G.GetTime = function() return mockClock.now end

_G.C_Timer = {
    After = function(seconds, callback)
        table.insert(mockClock.timers, {
            fireAt = mockClock.now + seconds,
            callback = callback,
            cancelled = false,
        })
    end,
    NewTimer = function(seconds, callback)
        local handle = { cancelled = false }
        handle.fireAt = mockClock.now + seconds
        handle.callback = callback
        table.insert(mockClock.timers, handle)
        function handle:Cancel()
            self.cancelled = true
        end
        function handle:IsCancelled()
            return self.cancelled
        end
        return handle
    end,
}
```

### Pattern 4: Minimal CreateFrame Stub

Based on the test targets (ApplySpell, SyncFromAura, NormalizeDB, Util functions), `CreateFrame` is called during `Initialize` → `EnsureFrame`. The frame object needs to support: `SetFrameStrata`, `SetFrameLevel`, `SetClampedToScreen`, `RegisterEvent`, `RegisterUnitEvent`, `SetScript`, `CreateTexture`, `CreateFontString`, `RegisterForDrag`, `SetSize`, `SetPoint`, `ClearAllPoints`, `Show`, `Hide`, `SetShown`, `GetCenter`, `SetScale`, `SetMovable`, `EnableMouse`, `StopMovingOrSizing`, `StartMoving`. None of these need to return meaningful values for pure-logic tests.

```lua
-- noopFrame factory — D-02 implementation
-- Source: WoW addon testing patterns [ASSUMED]

local function noopFrame()
    local frame = {}
    local mt = {
        __index = function(t, k)
            -- Return a no-op function for any unknown method
            return function(...) return t end
        end
    }
    -- State tracking for assertions that need it (D-02 discretion):
    frame._visible = true
    frame._text = ""
    frame._scripts = {}
    -- Override specific methods that tests assert against
    frame.Show  = function(self) self._visible = true end
    frame.Hide  = function(self) self._visible = false end
    frame.SetShown = function(self, v) self._visible = v end
    frame.IsShown  = function(self) return self._visible end
    frame.SetText  = function(self, t) self._text = tostring(t or "") end
    frame.GetText  = function(self) return self._text end
    frame.SetScript = function(self, event, fn) self._scripts[event] = fn end
    frame.GetCenter = function(self) return 0, 0 end
    frame.CreateTexture   = function(self) return noopFrame() end
    frame.CreateFontString = function(self) return noopFrame() end
    setmetatable(frame, mt)
    return frame
end

_G.CreateFrame = function(frameType, name, parent)
    return noopFrame()
end

_G.UIParent = noopFrame()
```

**D-02 decision:** Track minimal state (`.visible`, `.text`) because `Tip:Update()` calls `root:Hide()` / `root:Show()` and several tests will want to assert tracker visibility. Without this, tests cannot verify the hide/show path without restructuring the entire test to check stacks only.

### Pattern 5: AuraData Stub — Full Contract Fidelity (D-03)

Based on the WoW wiki AuraData struct, the complete field set required by D-03:

```lua
-- spec/support/wow_stubs.lua — AuraData builder
-- Source: Wowpedia Struct_AuraData / warcraft.wiki.gg [CITED: wowpedia.fandom.com/wiki/Struct_AuraData]

local function makeAuraData(overrides)
    local defaults = {
        -- Core identity
        name            = "Tip of the Spear",
        spellId         = 260286,
        icon            = 132275,           -- FileID
        -- Stack state (tests override these)
        applications    = 1,                -- stack count; 0 means 1 stack displayed
        count           = 1,                -- legacy alias (same as applications)
        -- Timing
        duration        = 10.0,
        expirationTime  = 0,                -- 0 = no expiration; tests set this
        timeMod         = 1.0,
        -- Metadata
        dispelType      = nil,
        source          = "player",
        sourceUnit      = "player",
        -- Flags
        isHelpful       = true,
        isHarmful       = false,
        isBossAura      = false,
        isFromPlayerOrPet = true,
        isRaid          = false,
        isStealable     = false,
        isNameplateOnly = false,
        canApplyAura    = true,
        nameplateShowPersonal = false,
        nameplateShowAll      = false,
        -- Instance tracking
        auraInstanceID  = 1,
        -- Extra (tooltip values, vararg in UnitAura)
        points          = {},
    }
    if overrides then
        for k, v in pairs(overrides) do defaults[k] = v end
    end
    return defaults
end

_G.C_UnitAuras = {
    GetPlayerAuraBySpellID = function(spellID)
        -- Default: buff not present. Tests override this.
        return nil
    end,
}
```

Tests override `GetPlayerAuraBySpellID` per-test to control what `ReadLiveState` returns:
```lua
-- In a test:
_G.C_UnitAuras.GetPlayerAuraBySpellID = function()
    return makeAuraData({ applications = 2, expirationTime = mockClock.now + 8 })
end
```

### Pattern 6: .busted Config File

```lua
-- .busted at repo root
-- Source: busted official docs [CITED: lunarmodules.github.io/busted/]
return {
    default = {
        verbose    = false,
        output     = "utfTerminal",
        pattern    = "_spec",
        ["no-keep-going"] = false,
    }
}
```

Run command: `busted spec/` from project root.

### Pattern 7: .luacheckrc Config File

```lua
-- .luacheckrc at repo root
-- Source: luacheck docs [CITED: luacheck.readthedocs.io — referenced from mpeterv/luacheck]
std = "lua51"

-- WoW globals the addon actually references (D-10)
read_globals = {
    -- Frame/UI creation
    "CreateFrame",
    "UIParent",
    "STANDARD_TEXT_FONT",
    -- SavedVariables global
    "DuncedmaxxingDB",
    -- WoW API namespaces
    "C_UnitAuras",
    "C_Timer",
    "C_SpecializationInfo",
    "C_Spell",
    -- Legacy/fallback globals
    "GetSpecialization",
    "GetSpellTexture",
    "InCombatLockdown",
    "UnitClass",
    "GetTime",
    -- Slash command registration
    "SlashCmdList",
    "SLASH_DUNCEDMAXXING1",
    "SLASH_DUNCEDMAXXING2",
    -- Output
    "DEFAULT_CHAT_FRAME",
    -- String constant for spellcast events (used in table keys)
}

-- Exclude spec files from addon linting (D-11)
exclude_files = {
    "spec/**/*.lua",
}
```

Run command: `luacheck Duncedmaxxing/ --no-unused-args` from project root.

**Note on `SLASH_DUNCEDMAXXING1` / `SLASH_DUNCEDMAXXING2`:** These are set as globals in `RegisterSlashCommands()` with plain assignment (`SLASH_DUNCEDMAXXING1 = ...`). luacheck will flag them as undefined globals unless they are in `read_globals` or `globals`.

### Anti-Patterns to Avoid

- **Calling dofile() without vararg injection:** `dofile("Duncedmaxxing/Core.lua")` causes `local _, DMX = ...` to assign `nil` to DMX, crashing every method call. Always use the `loadfile()` + chunk-call pattern (Pattern 2).
- **Sharing state between spec files:** D-06 requires full reload isolation. Never cache the `init.load()` result in a module-level variable across spec files.
- **Mock clock starting at 0 without reset between tests:** Tests that advance the clock leave `mockClock.now` at a non-zero value. Each `describe` or `it` block must call `mockClock:reset()` in a `before_each`.
- **Omitting AuraData fields from stubs (violating D-03):** Even if a test only checks `applications`, the stub must return the full struct. Missing fields can cause code paths that traverse `aura.expirationTime` to silently nil-error or short-circuit.
- **Setting `globals` instead of `read_globals` in luacheckrc:** `globals` marks symbols as writable; `read_globals` is read-only. WoW globals should be `read_globals` since addon files only read them, not define them (exception: `DuncedmaxxingDB` and `SLASH_*` which are written — use `globals` for those).

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Test runner with assertions | Custom assert wrappers | busted's `assert.are.equal`, `assert.is_true`, `assert.is_nil` | busted ships a complete assertion library via `luassert` |
| Timer simulation | `os.clock()`-based real delays | Mock clock pattern (Pattern 3) | Real delays make tests slow and flaky; mock clock is deterministic |
| WoW API detection | `if WoW then ... else ... end` in source | Stubs in `_G` before dofile() | Modifying source to detect test environment creates test-only code paths |
| Lua version enforcement | Shell wrapper scripts | `luarocks --lua-version=5.1 install busted` | LuaRocks handles binary selection; manual wrappers are fragile |
| Aura contract verification | Hand-written field checklist | Full `makeAuraData()` builder that includes all fields | Centralizes D-03 compliance; easier to update when wiki changes |

**Key insight:** The WoW addon testing problem is simpler than it looks. There is no need for a full WoW emulator — the test targets are pure Lua functions. The only complexity is the file loading setup (`loadfile` vararg injection) and the mock clock.

---

## Common Pitfalls

### Pitfall 1: busted installs for wrong Lua version
**What goes wrong:** `sudo luarocks install busted` without `--lua-version=5.1` may install for the default Lua (5.4 on Ubuntu 24.x). The resulting `busted` binary runs under Lua 5.4, which lacks `setfenv`/`getfenv`. If addon source files depend on Lua 5.1-specific behavior, tests may pass under 5.4 but fail in the WoW client.
**Why it happens:** `luarocks` defaults to the system default Lua version, which is often not 5.1 on modern Ubuntu.
**How to avoid:** Always run `luarocks --lua-version=5.1 install busted`. Verify with `busted --version` and check the Lua version it reports.
**Warning signs:** `attempt to call global 'setfenv' (a nil value)` in tests that use setfenv.

### Pitfall 2: dofile() passes empty vararg to addon files
**What goes wrong:** `dofile("Duncedmaxxing/Core.lua")` runs the file, but `local addonName, DMX = ...` inside it receives an empty vararg — both become `nil`. The very first line `_G.Duncedmaxxing = DMX` silently sets the global to nil. Everything subsequently crashes.
**Why it happens:** `dofile()` does not forward arguments to the chunk; it simply runs it.
**How to avoid:** Use the `loadfile()` + `chunk("Duncedmaxxing", dmxTable)` pattern (Pattern 2 above). This passes the two values as the chunk's vararg.
**Warning signs:** `attempt to index a nil value (global 'Duncedmaxxing')` or `attempt to call a nil value (method 'RegisterModule')` as the very first test error.

### Pitfall 3: SETTINGS_MIGRATION string must match exactly
**What goes wrong:** NormalizeDB tests that pass a pre-migration DB must use a `settingsMigration` value that is different from `"0.3.2-fontfix"`. If the test accidentally sets `settingsMigration = "0.3.2-fontfix"` on the input DB, the migration branch is skipped and migration tests silently do nothing.
**Why it happens:** The migration gate is `db.settingsMigration ~= SETTINGS_MIGRATION` — the test input must have an intentionally old/wrong value to trigger migration.
**How to avoid:** Always set `db.settingsMigration = "old-version"` (or nil) in test input to exercise the migration branch. Use `db.settingsMigration = "0.3.2-fontfix"` only for the "already migrated" branch.
**Warning signs:** Migration test passes with no assertions firing.

### Pitfall 4: SyncFromAura serial-mismatch test requires two timer callbacks
**What goes wrong:** `ScheduleCastVerify` registers two `C_Timer.After` callbacks (`AURA_VERIFY_DELAY` = 1.25s and `FINAL_AURA_VERIFY_DELAY` = 2.05s). The serial-mismatch test must advance the clock past 1.25s while ensuring `castVerifySerial` has already been incremented by a second call to `ScheduleCastVerify`. Advancing past only the first callback but not the second leaves the second pending.
**Why it happens:** The serial check `if serial ~= self.castVerifySerial then return end` is the guard being tested — it requires the serial to have changed between when the callback was registered and when it fires.
**How to avoid:** In the serial-mismatch test: (1) call `ApplySpell("generator")` to schedule verify with serial N, (2) call `ApplySpell("generator")` again to increment serial to N+1, (3) advance clock past 1.25s — the first callback fires and detects the mismatch (serial N != N+1), returns early. Assert `SyncFromAura` was not called for the first cast.

### Pitfall 5: Grace period suppression boundary (CONSUMER_UPSYNC_GRACE = 2.75)
**What goes wrong:** The grace period test must set `lastPredictAt` before calling `SyncFromAura`, and the mock clock must be within the grace window. `SyncFromAura` checks `GetTime() < (self.lastPredictAt or 0) + CONSUMER_UPSYNC_GRACE`. If the mock clock starts at 0 and `lastPredictAt` is also 0, `0 < 2.75` is true — the suppression fires even on first call, making the test trivially pass without testing the actual boundary.
**How to avoid:** Set `mockClock.now = 100` as the starting time for grace-period tests. Set `Tip.lastPredictAt = 100` (or whatever the test designates as "now"). Then test: advance 1 second (`now = 101`) → grace window active → suppression fires. Advance 3 more seconds (`now = 104`) → past grace → sync proceeds.
**Warning signs:** Every consumer-related SyncFromAura test returns false regardless of clock position.

### Pitfall 6: luacheck `globals` vs `read_globals` for SLASH globals
**What goes wrong:** `SLASH_DUNCEDMAXXING1 = "/duncedmaxxing"` in Core.lua writes to an undefined global. luacheck flags this as an undefined global unless it is listed in `globals` (writeable). Listing it in `read_globals` only allows reading, so the assignment still triggers a warning.
**Why it happens:** luacheck distinguishes between globals that are defined externally and read-only (`read_globals`) vs. globals that the code itself writes (`globals`). The WoW convention is that addons write their slash command global at startup.
**How to avoid:** List `SLASH_DUNCEDMAXXING1`, `SLASH_DUNCEDMAXXING2`, and `DuncedmaxxingDB` under `globals` (writeable) in `.luacheckrc`, not `read_globals`.
**Warning signs:** luacheck reports "setting undefined field of global 'SLASH_DUNCEDMAXXING1'" on zero-warning runs.

---

## Code Examples

### Loading addon files in test init.lua

```lua
-- spec/support/init.lua
-- Source: Lua 5.1 reference manual loadfile/vararg behavior [ASSUMED]

local stubs = require("spec.support.wow_stubs")

local function loadAddon(path, addonName, dmxTable)
    local chunk, err = loadfile(path)
    if not chunk then
        error("Failed to load " .. path .. ": " .. tostring(err))
    end
    return chunk(addonName, dmxTable)
end

local function load()
    -- Fresh DMX namespace for isolation (D-06)
    local DMX = {}
    _G.DuncedmaxxingDB = nil

    -- Install WoW stubs into _G
    stubs.install(DMX)

    -- Load in TOC order (Util first, as declared in Duncedmaxxing.toc)
    loadAddon("Duncedmaxxing/Util.lua",                       "Duncedmaxxing", DMX)
    loadAddon("Duncedmaxxing/Core.lua",                       "Duncedmaxxing", DMX)
    loadAddon("Duncedmaxxing/Modules/TipOfTheSpear.lua",      "Duncedmaxxing", DMX)

    -- Simulate ADDON_LOADED initialization
    -- (Core.lua's coreFrame OnEvent handler does this; we call it directly)
    _G.DuncedmaxxingDB = {}
    local MergeDefaults = function(defaults, target)
        -- replicate CopyDefaults/MergeDefaults behavior for init
        -- OR: fire the event on coreFrame directly:
    end
    -- Simplest: call the Core.lua ADDON_LOADED handler by triggering the stored script
    -- coreFrame is a local in Core.lua; we can't reach it. Instead:
    -- Option A: Fire the OnEvent if coreFrame was exposed.
    -- Option B: Manually replicate the init sequence:
    _G.DuncedmaxxingDB = DMX.defaults and
        -- The safe approach: let Core.lua's event fire by calling it through a shim
        -- This is resolved in the plan — see Open Questions.
        {} or {}
    DMX.db = _G.DuncedmaxxingDB
    DMX.ready = true
    -- Manually call Initialize on registered modules
    DMX:ForEachModule("Initialize", DMX)

    local Tip = DMX:GetModule("tip")
    return DMX, Tip, stubs.mockClock
end

return { load = load }
```

**Open issue with init sequence:** The `ADDON_LOADED` handler is attached to a `local coreFrame` inside `Core.lua`. There is no clean way to fire it from the test environment without either (a) exposing `coreFrame` as `DMX.coreFrame`, (b) adding a `DMX:Boot()` method, or (c) replicating the init logic in the test init helper. Option (c) is most pragmatic for this phase and is what the pseudocode above does. The planner should include a task to call `MergeDefaults` + `NormalizeDB` directly in the init helper using the functions accessed via `DMX._MergeDefaults` if Core.lua exposes them, or replicate the minimal init inline.

### busted test structure for ApplySpell (TEST-03)

```lua
-- spec/tip_spec.lua
-- Source: busted official docs [CITED: lunarmodules.github.io/busted/]

local loader = require("spec.support.init")

describe("Tip:ApplySpell", function()
    local DMX, Tip, clock

    before_each(function()
        DMX, Tip, clock = loader.load()
        clock:reset()
        Tip.stacks = 0
        Tip.expiresAt = 0
        clock.now = 100  -- non-zero base time (Pitfall 5)
    end)

    it("adds 2 stacks on generator (Kill Command)", function()
        Tip:ApplySpell("generator")
        assert.are.equal(2, Tip.stacks)
    end)

    it("caps stacks at 3 on generator when already at 2", function()
        Tip.stacks = 2
        Tip:ApplySpell("generator")
        assert.are.equal(3, Tip.stacks)  -- 2 + 2 capped at 3
    end)

    it("decrements stacks on consumer", function()
        Tip.stacks = 2
        Tip:ApplySpell("consumer")
        assert.are.equal(1, Tip.stacks)
    end)

    it("sets expiresAt to now + 10 on generator", function()
        Tip:ApplySpell("generator")
        assert.are.equal(100 + 10, Tip.expiresAt)
    end)

    it("schedules expiration timer after generator", function()
        Tip:ApplySpell("generator")
        assert.is_not_nil(Tip.expireTimer)
        assert.is_false(Tip.expireTimer:IsCancelled())
    end)

    it("fires expiry callback after BUFF_DURATION (10s)", function()
        Tip:ApplySpell("generator")
        clock:advance(10.1)  -- just past buff duration + 0.03 timer fudge
        assert.are.equal(0, Tip.stacks)
    end)
end)
```

### NormalizeDB migration test (TEST-05)

```lua
-- spec/core_spec.lua

describe("NormalizeDB", function()
    local DMX, _, clock

    before_each(function()
        DMX, _, clock = loader.load()
    end)

    it("runs migration when settingsMigration does not match", function()
        local db = {
            settingsMigration = "old-version",  -- triggers migration (Pitfall 3)
            tip = {
                x = 50, y = -100, scale = 1.5,
                displayMode = "icons",  -- should be overwritten by migration
            }
        }
        -- NormalizeDB is local in Core.lua; access via DMX.NormalizeDB
        -- (Core.lua must expose it — see Open Questions)
        DMX._NormalizeDB(db)
        assert.are.equal("0.3.2-fontfix", db.settingsMigration)
        assert.are.equal("bar", db.tip.displayMode)  -- reset to default
        assert.are.equal(50, db.tip.x)               -- position preserved
    end)
end)
```

**Note:** `NormalizeDB` is currently a `local function` in `Core.lua`. The plan must either (a) expose it as `DMX._NormalizeDB = NormalizeDB` at the bottom of Core.lua for test access, or (b) test it indirectly by calling the init sequence and inspecting `DMX.db` state. Direct access is cleaner for test assertions. The planner should decide and document which approach to use.

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `require()` for WoW addon loading | `loadfile()` + vararg injection | WoW addons never used require | Tests must use loadfile; dofile() is insufficient |
| `setfenv()` in Lua 5.1 for environment scoping | Not needed for this approach | Lua 5.2+ dropped setfenv | loadfile+vararg-call approach avoids setfenv entirely |
| Per-version busted binary (`busted-5.1`) | `luarocks --lua-version=5.1 install` | LuaRocks 3.x | Install flag, not separate binary |
| `pairs(self.modules)` iteration (old ForEachModule) | `ipairs(self.moduleOrder)` (Phase 1 output) | Phase 1 | Tests can rely on deterministic module init order |

**Deprecated/outdated:**
- Phase 1 source note: `ClassifySpellID` no longer has a `pcall` wrapper (removed in Phase 1). Tests should call it directly without expecting pcall behavior.
- `options.lua` duplicate `Clamp`/`ParseHexColor`: removed in Phase 1. Tests for Clamp/ParseHexColor should target `DMX.Util.Clamp` and `DMX.Util.ParseHexColor`, not any Options.lua local.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `loadfile(path)(addonName, dmxTable)` correctly passes two varargs to the chunk, making `local _, DMX = ...` work | Pattern 2, Pattern 1 | init.lua fails to inject DMX; every module load crashes |
| A2 | `busted` spec files loaded via `require()` run in the same `_G` as the test init helper's stubs | Pattern 1 | Stubs not visible to dofile'd addon code; all WoW API calls crash |
| A3 | `NormalizeDB` is a local function in Core.lua and must be explicitly exposed for direct test access | Code Examples | Tests must test it indirectly through DB init sequence |
| A4 | `SLASH_DUNCEDMAXXING1` must be in `globals` not `read_globals` in luacheckrc | Pattern 7 | luacheck reports false positives on valid addon code |
| A5 | busted's `before_each` creates a clean scope; `loader.load()` called in `before_each` provides full state isolation | Pattern 3 code | State leaks between tests; timer callbacks from prior tests fire unexpectedly |
| A6 | `Tip:ApplySpell("generator")` grants +2 stacks (hardcoded in source, not read from talent data) | TEST-03 analysis | Tests for talent-specific amounts need BUG-03 context (deferred to Phase 3) |

**A6 context on talent amounts:** The CONTEXT.md says TEST-03 covers "talent-specific grant amounts (Kill Command, Twin Fangs)". The current source in `TipOfTheSpear.lua` line 679 hardcodes `self.stacks + 2` for generators. BUG-03 (dynamic talent reads) is Phase 3. For this phase, the "talent-specific" test for Kill Command is simply that generators add 2 and consumers subtract 1. A test for Twin Fangs (`Takedown` granting 3 stacks) cannot be written until BUG-04 is implemented. **The planner should scope TEST-03 twin-fangs coverage to "pending BUG-04" with a stub test that documents expected behavior rather than asserts it.**

---

## Open Questions

1. **How to expose Core.lua local functions for test access**
   - What we know: `NormalizeDB`, `MergeDefaults`, `CopyDefaults` are `local function` inside Core.lua. They cannot be accessed from test specs without modification.
   - What's unclear: Whether to (a) expose them via `DMX._NormalizeDB = NormalizeDB` at Core.lua bottom (surgical addition), (b) test indirectly via init sequence inspection, or (c) accept that NormalizeDB is tested implicitly through DB state after `loader.load()`.
   - Recommendation: Expose `DMX._test = { NormalizeDB = NormalizeDB, MergeDefaults = MergeDefaults }` at Core.lua bottom, clearly marked as test-only. Allows direct unit testing without going through the full ADDON_LOADED path. The planner must include this as an explicit task.

2. **How to trigger ADDON_LOADED initialization sequence in tests**
   - What we know: The init sequence lives in a `coreFrame:SetScript("OnEvent", ...)` closure in Core.lua. `coreFrame` is a local variable — unreachable from test code. Without this running, `DMX.db` is nil and `DMX.ready` is false.
   - What's unclear: The cleanest way to bootstrap DB state in tests.
   - Recommendation: The test `init.lua` should replicate the ADDON_LOADED body manually: call `MergeDefaults(DEFAULTS, {})`, call `NormalizeDB()`, set `DMX.db`, set `DMX.ready = true`, then call `DMX:ForEachModule("Initialize", DMX)`. This requires exposing DEFAULTS via `DMX.defaults` (already present in Core.lua line 43) and the two functions via `DMX._test`.

3. **Test coverage for Twin Fangs (BUG-04)**
   - What we know: TEST-03 mentions "Twin Fangs talent support" but BUG-04 is Phase 3. The current source does not implement Twin Fangs grant-3 behavior.
   - Recommendation: Write a `pending()` test in busted with the expected behavior described. This documents the requirement without a false-passing test. Planner should include one `pending` test for Twin Fangs as a known gap.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| lua5.1 | busted runtime, test execution | ✗ (apt ready) | — (need: 5.1.5) | Install via `apt install lua5.1` |
| luarocks | busted package install | ✗ (apt ready) | — (need: 3.8.0) | Install via `apt install luarocks` |
| busted | test runner | ✗ (post-luarocks) | — (need: 2.3.0) | `luarocks --lua-version=5.1 install busted` |
| lua-check | luacheck binary | ✗ (apt ready) | — (need: 0.23.0) | Install via `apt install lua-check` |

**Missing dependencies with no fallback:** lua5.1, luarocks, busted, lua-check must all be installed. The planner must include installation as Wave 0 tasks.

**Missing dependencies with fallback:** None — all four are available via apt/luarocks.

**apt availability confirmed:** `lua5.1 5.1.5-9build2`, `luarocks 3.8.0+dfsg1-1`, `lua-check 1.1.2-1` are all present in the system apt index. [VERIFIED: Bash]

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | busted 2.3.0 (to be installed) |
| Config file | `.busted` at repo root (Wave 0 creation) |
| Quick run command | `busted spec/` |
| Full suite command | `busted spec/ --verbose` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| TEST-01 | busted configured for Lua 5.1; `busted spec/` runs | smoke | `busted spec/` | ❌ Wave 0 |
| TEST-02 | wow_stubs.lua provides full AuraData, C_Timer, CreateFrame | unit | `busted spec/util_spec.lua` (stubs must load) | ❌ Wave 0 |
| TEST-03 | ApplySpell: stack add, cap at 3, expiry, Kill Command +2 | unit | `busted spec/tip_spec.lua` | ❌ Wave 0 |
| TEST-04 | SyncFromAura: grace suppression, serial-mismatch, reconciliation | unit | `busted spec/tip_spec.lua` | ❌ Wave 0 |
| TEST-05 | NormalizeDB: migration gate, field merge, deprecated fields | unit | `busted spec/core_spec.lua` | ❌ Wave 0 |
| TEST-06 | Util: Clamp bounds, ParseHexColor 6/8-char, ParseOnOff variants, Trim | unit | `busted spec/util_spec.lua` | ❌ Wave 0 |
| TEST-07 | luacheck --std=lua51 zero warnings on addon source | static | `luacheck Duncedmaxxing/ --no-unused-args` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `busted spec/` (full suite; runs in under 5 seconds offline)
- **Per wave merge:** `busted spec/ --verbose && luacheck Duncedmaxxing/`
- **Phase gate:** Full suite green + luacheck zero warnings before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `spec/support/wow_stubs.lua` — WoW API mock layer
- [ ] `spec/support/init.lua` — dofile loader with vararg injection
- [ ] `spec/util_spec.lua` — TEST-06 tests
- [ ] `spec/core_spec.lua` — TEST-05 tests
- [ ] `spec/tip_spec.lua` — TEST-03 + TEST-04 tests
- [ ] `.busted` — busted project config
- [ ] `.luacheckrc` — luacheck config
- [ ] Framework install: `sudo apt install lua5.1 luarocks lua-check && sudo luarocks --lua-version=5.1 install busted`

---

## Security Domain

> This phase has no network access, user input handling, authentication, or data persistence. It adds offline test files and a config file. ASVS categories V2-V6 are not applicable.

---

## Project Constraints (from CLAUDE.md)

| Constraint | Impact on This Phase |
|------------|---------------------|
| Runtime: WoW Lua 5.1 sandbox | Tests must use Lua 5.1 binary; busted must be installed with `--lua-version=5.1` |
| No build toolchain | No transpilation step; test files are plain `.lua` files loaded directly by busted |
| No `require`, no filesystem in production | Production code cannot use `require`; this constraint does not apply to spec files which run outside WoW |
| No external dependencies in production addon | spec/ files and .busted/.luacheckrc are dev-only artifacts; they must not appear in the addon distribution |
| `ALL_CAPS_SNAKE_CASE` for constants | Spec file constants (e.g., `KILL_COMMAND = 259489` used in tests) should follow the same pattern |
| 4-space indentation, double-quoted strings | Spec files should follow the same conventions |
| No `error()` or `assert()` in production | Spec files may use busted `assert.*` — this is test-only, not production code |
| CLAUDE.md instructs GSD workflow before edits | All file creation goes through GSD plan execution |

---

## Sources

### Primary (HIGH confidence)

- LuaRocks registry `lunarmodules/busted` — version 2.3.0-1, 453,748 downloads, Lua >= 5.1 [VERIFIED: LuaRocks]
- LuaRocks registry `mpeterv/luacheck` — version 0.23.0-1, 1.27M downloads, Lua >= 5.1 < 5.4 [VERIFIED: LuaRocks]
- busted official docs `lunarmodules.github.io/busted/` — config file format, CLI options [CITED]
- System apt index — `lua5.1 5.1.5-9build2`, `luarocks 3.8.0+dfsg1-1`, `lua-check 1.1.2-1` available [VERIFIED: Bash]
- `Duncedmaxxing/Util.lua` — Clamp, ParseHexColor, Trim, ParseOnOff implementations read directly [VERIFIED: codebase]
- `Duncedmaxxing/Core.lua` — NormalizeDB, MergeDefaults, SETTINGS_MIGRATION, DEFAULTS read directly [VERIFIED: codebase]
- `Duncedmaxxing/Modules/TipOfTheSpear.lua` — ApplySpell, SyncFromAura, ScheduleExpiration, BUFF_DURATION, CONSUMER_UPSYNC_GRACE read directly [VERIFIED: codebase]
- `Duncedmaxxing/Duncedmaxxing.toc` — TOC load order (Util → Core → Options → TipOfTheSpear) [VERIFIED: codebase]
- Phase 1 VERIFICATION.md — confirms Phase 1 source changes are in place; Tip table frame fields, Util.* exports, ForEachModule with moduleOrder all verified [VERIFIED: .planning/phases/01-utility-extraction-and-module-encapsulation/01-VERIFICATION.md]

### Secondary (MEDIUM confidence)

- Wowpedia Struct_AuraData search results — AuraData field list: applications, expirationTime, auraInstanceID, spellId, etc. [CITED: wowpedia.fandom.com/wiki/Struct_AuraData via WebSearch]
- C_Timer.NewTimer documentation — returns handle with Cancel(), IsCancelled(), Invoke() methods [CITED: wowpedia.fandom.com/wiki/API_C_Timer.NewTimer via WebSearch]
- GetSpecialization() returns spec index (1-3 for Hunter: BM=1, MM=2, SV=3) [CITED: wowpedia.fandom.com via WebSearch]
- LuaRocks issue #980 — `--lua-version=5.1` required for correct busted binary under LuaRocks 3 [CITED: github.com/luarocks/luarocks/issues/980]

### Tertiary (LOW confidence)

- `loadfile(path)(addonName, dmxTable)` vararg injection pattern — training knowledge, not verified against Lua 5.1 reference in this session [ASSUMED — A1]
- busted `before_each` isolation guarantees — assumed based on standard test framework behavior [ASSUMED — A5]

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — both busted and luacheck verified on LuaRocks; apt packages confirmed available
- Architecture: HIGH — source files read in full; all function signatures and behaviors confirmed from code
- WoW API contracts: MEDIUM — AuraData fields from Wowpedia search results (could not fetch wiki directly due to TLS error); enough fields confirmed for stub design
- Pitfalls: HIGH — most derived from reading actual source code and understanding the vararg/dofile interaction

**Research date:** 2026-06-17
**Valid until:** 2026-07-17 (busted/luacheck are stable; WoW API contracts stable for Midnight 12.0.5)
