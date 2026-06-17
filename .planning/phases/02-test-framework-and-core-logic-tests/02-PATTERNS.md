# Phase 2: Test Framework and Core Logic Tests - Pattern Map

**Mapped:** 2026-06-17
**Files analyzed:** 7 new files + 1 modified source file
**Analogs found:** 0 / 7 (no existing test infrastructure — all patterns sourced from production source code read directly)

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `spec/support/wow_stubs.lua` | test-support / mock layer | event-driven + request-response | None | no-analog |
| `spec/support/init.lua` | test-support / loader | request-response | None | no-analog |
| `spec/util_spec.lua` | test / unit | transform | None | no-analog |
| `spec/core_spec.lua` | test / unit | CRUD | None | no-analog |
| `spec/tip_spec.lua` | test / unit + timer | event-driven | None | no-analog |
| `.busted` | config | — | None | no-analog |
| `.luacheckrc` | config | — | None | no-analog |
| `Duncedmaxxing/Core.lua` (modify) | core / module registry | CRUD | Existing file | exact (read below) |

**Note:** The project has zero existing test files. All patterns below are extracted directly from the production source files that the tests will exercise. The RESEARCH.md contains authoritative example patterns from busted docs and WoW addon testing conventions — those are marked `[RESEARCH]`.

---

## Pattern Assignments

### `spec/support/wow_stubs.lua` (test-support, mock layer)

**Analog:** None — derived from `Duncedmaxxing/Modules/TipOfTheSpear.lua` (the consumer of all stubbed APIs) and RESEARCH.md patterns.

**WoW globals consumed by addon source** (extracted from source files):

From `Duncedmaxxing/Modules/TipOfTheSpear.lua` lines 30, 69–74, 108–110, 284–317, 356, 368, 404–405, 558, 752–764:
```lua
-- These globals are referenced in production code and must be stubbed:
C_UnitAuras.GetPlayerAuraBySpellID   -- line 30 (stored), 74 (called in ReadLiveState)
C_Timer.After                         -- lines 404, 405, 430, 558
C_Timer.NewTimer                      -- line 368 (returns handle with :Cancel(), :IsCancelled())
GetTime                               -- lines 95, 96, 330, 340, 362, 373, 374
CreateFrame                           -- lines 164, 284, 755
InCombatLockdown                      -- line 752
UIParent                              -- line 284
C_Spell.GetSpellTexture               -- line 124
```

From `Duncedmaxxing/Core.lua` lines 148, 158–164, 198–199, 201, 331–332, 338:
```lua
UnitClass                             -- line 148
C_SpecializationInfo.GetSpecialization -- line 159
GetSpecialization                     -- line 162 (fallback global)
SlashCmdList                          -- line 201
SLASH_DUNCEDMAXXING1                  -- line 198
SLASH_DUNCEDMAXXING2                  -- line 199
DEFAULT_CHAT_FRAME                    -- line 143
DuncedmaxxingDB                       -- line 338 (SavedVariables global)
CreateFrame                           -- line 331
```

**Mock clock pattern** `[RESEARCH — Pattern 3]`:
```lua
-- spec/support/wow_stubs.lua
local mockClock = {
    now    = 0,
    timers = {},  -- list of { fireAt, callback, cancelled }
}

function mockClock:advance(dt)
    self.now = self.now + dt
    local fired = {}
    for i, t in ipairs(self.timers) do
        if not t.cancelled and t.fireAt <= self.now then
            fired[#fired + 1] = i
        end
    end
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
```

**D-09 decision (from RESEARCH.md):** Auto-fire on `advance()` — no separate flush step needed. Rationale: most timer tests cross exactly one timer boundary; explicit flush is ceremony that obscures test intent for single-timer cases.

**C_Timer stub wired to mockClock** `[RESEARCH — Pattern 3]`:
```lua
_G.GetTime = function() return mockClock.now end

_G.C_Timer = {
    After = function(seconds, callback)
        table.insert(mockClock.timers, {
            fireAt   = mockClock.now + seconds,
            callback = callback,
            cancelled = false,
        })
    end,
    NewTimer = function(seconds, callback)
        local handle = { cancelled = false }
        handle.fireAt   = mockClock.now + seconds
        handle.callback = callback
        table.insert(mockClock.timers, handle)
        function handle:Cancel()      self.cancelled = true  end
        function handle:IsCancelled() return self.cancelled  end
        return handle
    end,
}
```

**noopFrame factory with minimal state tracking** `[RESEARCH — Pattern 4]` (D-02 decision: track `.visible` and `.text` because `Tip:Update()` calls `root:Hide()`/`root:Show()` and tests will assert visibility):
```lua
local function noopFrame()
    local frame = {}
    setmetatable(frame, {
        __index = function(t, k)
            return function(...) return t end   -- unknown method → no-op returning self
        end
    })
    frame._visible  = true
    frame._text     = ""
    frame._scripts  = {}
    frame.Show      = function(self) self._visible = true end
    frame.Hide      = function(self) self._visible = false end
    frame.SetShown  = function(self, v) self._visible = v end
    frame.IsShown   = function(self) return self._visible end
    frame.SetText   = function(self, t) self._text = tostring(t or "") end
    frame.GetText   = function(self) return self._text end
    frame.SetScript = function(self, event, fn) self._scripts[event] = fn end
    frame.GetCenter = function(self) return 0, 0 end
    frame.CreateTexture    = function(self) return noopFrame() end
    frame.CreateFontString = function(self) return noopFrame() end
    return frame
end

_G.CreateFrame = function(frameType, name, parent) return noopFrame() end
_G.UIParent    = noopFrame()
```

**AuraData full-contract stub** `[RESEARCH — Pattern 5]` (D-03: all wiki fields must be present):
```lua
local function makeAuraData(overrides)
    local defaults = {
        name              = "Tip of the Spear",
        spellId           = 260286,
        icon              = 132275,
        applications      = 1,
        count             = 1,
        duration          = 10.0,
        expirationTime    = 0,
        timeMod           = 1.0,
        dispelType        = nil,
        source            = "player",
        sourceUnit        = "player",
        isHelpful         = true,
        isHarmful         = false,
        isBossAura        = false,
        isFromPlayerOrPet = true,
        isRaid            = false,
        isStealable       = false,
        isNameplateOnly   = false,
        canApplyAura      = true,
        nameplateShowPersonal = false,
        nameplateShowAll      = false,
        auraInstanceID    = 1,
        points            = {},
    }
    if overrides then
        for k, v in pairs(overrides) do defaults[k] = v end
    end
    return defaults
end

_G.C_UnitAuras = {
    GetPlayerAuraBySpellID = function(spellID)
        return nil   -- default: buff not present; tests override per-test
    end,
}
```

**Remaining simple stubs** (all extracted from actual usage in source files):
```lua
_G.UnitClass = function(unit) return "Hunter", "HUNTER" end
_G.InCombatLockdown = function() return false end
_G.C_SpecializationInfo = { GetSpecialization = function() return 3 end }  -- Survival
_G.GetSpecialization    = function() return 3 end
_G.C_Spell = { GetSpellTexture = function(id) return 132275 end }
_G.GetSpellTexture      = function(id) return 132275 end
_G.STANDARD_TEXT_FONT   = "Fonts\\FRIZQT__.TTF"
_G.DEFAULT_CHAT_FRAME   = { AddMessage = function() end }
_G.SlashCmdList         = {}
_G.SLASH_DUNCEDMAXXING1 = nil
_G.SLASH_DUNCEDMAXXING2 = nil
_G.DuncedmaxxingDB      = nil
```

**Public interface for init.lua** — stubs module must expose `reset()` and `mockClock`:
```lua
return {
    mockClock     = mockClock,
    makeAuraData  = makeAuraData,
    install       = function(DMX)
        -- installs all _G stubs above; ties GetTime to mockClock
    end,
    reset         = function()
        mockClock:reset()
        -- reset any per-test overrides (e.g. C_UnitAuras.GetPlayerAuraBySpellID)
        _G.C_UnitAuras.GetPlayerAuraBySpellID = function() return nil end
    end,
}
```

---

### `spec/support/init.lua` (test-support, loader)

**Analog:** None — derived from RESEARCH.md Pattern 1 and Pattern 2, validated against actual source file load patterns.

**Critical: WoW vararg injection via loadfile** `[RESEARCH — Pattern 2]`:

The addon files use `local addonName, DMX = ...` (line 1 of every source file). Plain `dofile()` passes an empty vararg — both become `nil`. The correct approach for Lua 5.1:

```lua
-- spec/support/init.lua
local stubs = require("spec.support.wow_stubs")

local function loadAddon(path, addonName, dmxTable)
    local chunk, err = loadfile(path)
    if not chunk then
        error("Failed to load " .. path .. ": " .. tostring(err))
    end
    return chunk(addonName, dmxTable)   -- passes as vararg; local _, DMX = ... works
end
```

**TOC load order** (from `Duncedmaxxing/Duncedmaxxing.toc` lines 10–13):
```
Util.lua         → loadAddon("Duncedmaxxing/Util.lua", ...)
Core.lua         → loadAddon("Duncedmaxxing/Core.lua", ...)
Options.lua      → skip for most tests (no UI assertions needed)
Modules\TipOfTheSpear.lua → loadAddon("Duncedmaxxing/Modules/TipOfTheSpear.lua", ...)
```

**ADDON_LOADED bootstrap** — `coreFrame` is a local inside `Core.lua` (line 331), unreachable from test code. The init helper must replicate the ADDON_LOADED body directly (RESEARCH.md Open Question 2 resolution):

The ADDON_LOADED handler body from `Core.lua` lines 338–348:
```lua
DuncedmaxxingDB = MergeDefaults(DEFAULTS, DuncedmaxxingDB)
NormalizeDB(DuncedmaxxingDB)
DMX.db = DuncedmaxxingDB
DMX.ready = true
-- DMX:InitializeOptions() -- skip in tests
-- RegisterSlashCommands() -- skip in tests
DMX:ForEachModule("Initialize", DMX)
```

The init helper replicates this by calling `DMX._test.MergeDefaults`, `DMX._test.NormalizeDB`, and `DMX.defaults` (already exposed at `Core.lua` line 43):

```lua
local function load()
    local DMX = {}
    _G.DuncedmaxxingDB = nil
    stubs.install(DMX)           -- installs _G stubs, ties GetTime to mockClock

    loadAddon("Duncedmaxxing/Util.lua",    "Duncedmaxxing", DMX)
    loadAddon("Duncedmaxxing/Core.lua",    "Duncedmaxxing", DMX)
    loadAddon("Duncedmaxxing/Modules/TipOfTheSpear.lua", "Duncedmaxxing", DMX)

    -- Replicate ADDON_LOADED body (Core.lua lines 338–348):
    _G.DuncedmaxxingDB = {}
    _G.DuncedmaxxingDB = DMX._test.MergeDefaults(DMX.defaults, _G.DuncedmaxxingDB)
    DMX._test.NormalizeDB(_G.DuncedmaxxingDB)
    DMX.db    = _G.DuncedmaxxingDB
    DMX.ready = true
    DMX:ForEachModule("Initialize", DMX)

    local Tip = DMX:GetModule("tip")
    return DMX, Tip, stubs.mockClock
end

return { load = load }
```

**D-07 decision:** Provide a `resetTipState()` helper in the returned object — it is cleaner than having every test manually zero out all `Tip.*` fields. The helper resets only runtime tracking fields, not the module table itself:

```lua
-- resetTipState zeros the fields that ApplySpell and SyncFromAura mutate
local function resetTipState(Tip, clock)
    Tip.stacks           = 0
    Tip.expiresAt        = 0
    Tip.lastPredictAt    = 0
    Tip.lastPredictKind  = nil
    Tip.castVerifySerial = 0
    Tip.auraVerifyPending = false
    Tip.expireTimer      = nil
    Tip.testMode         = false
    clock:reset()
    clock.now = 100   -- non-zero base (avoids Pitfall 5 grace-period collision)
    _G.C_UnitAuras.GetPlayerAuraBySpellID = function() return nil end
end
```

---

### `spec/util_spec.lua` (test / unit, transform)

**Analog:** None (no existing tests) — patterns extracted from `Duncedmaxxing/Util.lua` directly.

**Target functions and their signatures** (from `Duncedmaxxing/Util.lua` lines 6–43):

```lua
-- Trim(text): strips leading/trailing whitespace; nil-safe (returns "" for nil)
-- line 7: (text or ""):match("^%s*(.-)%s*$")

-- Clamp(value, minValue, maxValue): tonumber coercion; returns nil for non-numeric string
-- lines 11–16

-- ParseOnOff(value): returns true/false/nil; recognizes on/off/true/false/1/0/yes/no
-- lines 18–25; calls Trim internally

-- ParseHexColor(value): returns {r,g,b,a} table or nil
-- lines 27–38; handles 6-char (no alpha) and 8-char (with alpha); strips leading #
```

**Test structure** `[RESEARCH — busted describe/it pattern]`:
```lua
-- spec/util_spec.lua
local loader = require("spec.support.init")

describe("DMX.Util.Clamp", function()
    local DMX

    before_each(function()
        DMX = loader.load()
    end)

    it("returns the value when within bounds", function()
        assert.are.equal(5, DMX.Util.Clamp(5, 0, 10))
    end)

    it("clamps to minValue when below", function()
        assert.are.equal(0, DMX.Util.Clamp(-1, 0, 10))
    end)

    it("clamps to maxValue when above", function()
        assert.are.equal(10, DMX.Util.Clamp(11, 0, 10))
    end)

    it("coerces numeric strings", function()
        assert.are.equal(5, DMX.Util.Clamp("5", 0, 10))
    end)

    it("returns nil for non-numeric strings", function()
        assert.is_nil(DMX.Util.Clamp("abc", 0, 10))
    end)
end)
```

**Key edge cases to cover** (derived from Util.lua source):
- `Clamp`: non-numeric string → nil (line 12–13), exact boundary values, negative range
- `ParseHexColor`: 6-char → alpha defaults to 1.0, 8-char → alpha from bytes, `#` prefix stripped (line 28), invalid chars → nil (line 29), wrong length → nil (line 29)
- `ParseOnOff`: all six truthy tokens (`on`/`true`/`1`/`yes`), all six falsy tokens (`off`/`false`/`0`/`no`), unrecognized → nil (no return)
- `Trim`: nil input → "" (line 7 uses `(text or "")`), whitespace-only → ""

---

### `spec/core_spec.lua` (test / unit, CRUD)

**Analog:** None — patterns extracted from `Duncedmaxxing/Core.lua` directly.

**Target functions** (from `Core.lua` lines 45–111):

`MergeDefaults(defaults, target)` — lines 57–72: recursive merge; only fills `nil` slots in target; does not overwrite existing values.

`NormalizeDB(db)` — lines 74–111: migration gate at line 77 (`db.settingsMigration ~= SETTINGS_MIGRATION`); on migration, preserves x/y/scale/optionsX/optionsY and resets all other fields to defaults; clears deprecated fields `barWidth`/`barHeight`/`spacing` (lines 91–93, 98–106); validates `displayMode` (lines 108–110).

**`SETTINGS_MIGRATION` constant** (Core.lua line 16): `"0.3.2-fontfix"` — test inputs must use a different value to trigger the migration branch (RESEARCH.md Pitfall 3).

**Access pattern:** These are `local function` in Core.lua — they must be exposed via `DMX._test` (added to Core.lua bottom per RESEARCH.md Open Question 1). Plan must include this Core.lua modification.

```lua
-- To be added at bottom of Duncedmaxxing/Core.lua (after all local function definitions):
DMX._test = {
    MergeDefaults = MergeDefaults,
    NormalizeDB   = NormalizeDB,
    CopyDefaults  = CopyDefaults,
    SETTINGS_MIGRATION = SETTINGS_MIGRATION,
    DEFAULTS      = DEFAULTS,
}
```

**Test structure for NormalizeDB** `[RESEARCH — Code Examples section]`:
```lua
-- spec/core_spec.lua
local loader = require("spec.support.init")

describe("NormalizeDB", function()
    local DMX

    before_each(function()
        DMX = loader.load()
    end)

    it("runs migration when settingsMigration does not match", function()
        local db = {
            settingsMigration = "old-version",   -- triggers migration (not "0.3.2-fontfix")
            tip = { x = 50, y = -100, scale = 1.5, displayMode = "icons",
                    optionsX = 360, optionsY = 170 }
        }
        DMX._test.NormalizeDB(db)
        assert.are.equal("0.3.2-fontfix", db.settingsMigration)
        assert.are.equal("bar", db.tip.displayMode)   -- reset to default
        assert.are.equal(50,    db.tip.x)             -- position preserved
        assert.are.equal(-100,  db.tip.y)
        assert.are.equal(1.5,   db.tip.scale)
    end)

    it("skips migration when already on current version", function()
        local db = {
            settingsMigration = "0.3.2-fontfix",
            tip = { x = 50, displayMode = "icons" }
        }
        DMX._test.NormalizeDB(db)
        assert.are.equal("icons", db.tip.displayMode)  -- NOT reset
    end)
end)
```

---

### `spec/tip_spec.lua` (test / unit + timer, event-driven)

**Analog:** None — patterns extracted from `Duncedmaxxing/Modules/TipOfTheSpear.lua` directly.

**Target functions and key constants** (from TipOfTheSpear.lua):

| Symbol | Line | Value | Relevance |
|--------|------|-------|-----------|
| `BUFF_DURATION` | 10 | 10 | expiresAt = now + 10 after generator |
| `MAX_STACKS` | 7 | 3 | ClampStacks caps at 3 |
| `CONSUMER_UPSYNC_GRACE` | 11 | 2.75 | SyncFromAura suppression window |
| `AURA_VERIFY_DELAY` | 9 | 1.25 | First castVerify timer delay |
| `FINAL_AURA_VERIFY_DELAY` | 10 | 2.05 | Second castVerify timer delay |
| `KILL_COMMAND` | 6 | 259489 | Generator spell ID |
| `CONSUMERS` | 17–23 | table | Consumer spell IDs |

**ApplySpell (TEST-03)** — lines 675–695:
- Generator (`kind == "generator"`): `stacks = ClampStacks(stacks + 2)`, `expiresAt = now + BUFF_DURATION`
- Consumer (`kind == "consumer"`): `stacks = ClampStacks(stacks - 1)`, clears `expiresAt` if stacks → 0
- Both: sets `lastPredictAt = now`, `lastPredictKind = kind`, calls `ScheduleExpiration()` and `ScheduleCastVerify()`

**SyncFromAura (TEST-04)** — lines 323–348:
- Returns `false` when `ReadLiveState()` returns nil (GetPlayerAuraBySpellID unavailable)
- Consumer grace suppression (lines 329–332): `lastPredictKind == "consumer"` AND `liveStacks > stacks` AND `GetTime() < lastPredictAt + CONSUMER_UPSYNC_GRACE` → return false
- On accept: syncs `stacks` and `expiresAt` from live aura, calls `ScheduleExpiration()`, returns true

**Test structure for ApplySpell** `[RESEARCH — Code Examples section]`:
```lua
-- spec/tip_spec.lua
local loader = require("spec.support.init")

describe("Tip:ApplySpell", function()
    local DMX, Tip, clock

    before_each(function()
        DMX, Tip, clock = loader.load()
        loader.resetTipState(Tip, clock)   -- clock.now = 100, stacks = 0
    end)

    it("adds 2 stacks on generator", function()
        Tip:ApplySpell("generator")
        assert.are.equal(2, Tip.stacks)
    end)

    it("caps stacks at 3 when already at 2", function()
        Tip.stacks = 2
        Tip:ApplySpell("generator")
        assert.are.equal(3, Tip.stacks)
    end)

    it("decrements stacks on consumer", function()
        Tip.stacks = 2
        Tip:ApplySpell("consumer")
        assert.are.equal(1, Tip.stacks)
    end)

    it("sets expiresAt to now + BUFF_DURATION on generator", function()
        Tip:ApplySpell("generator")
        assert.are.equal(110, Tip.expiresAt)   -- clock.now(100) + BUFF_DURATION(10)
    end)

    it("clears expiresAt when consumer drains last stack", function()
        Tip.stacks = 1
        Tip:ApplySpell("consumer")
        assert.are.equal(0, Tip.expiresAt)
    end)

    it("fires expiry callback after BUFF_DURATION", function()
        Tip:ApplySpell("generator")
        clock:advance(10.1)   -- past BUFF_DURATION(10) + NewTimer fudge(0.03)
        assert.are.equal(0, Tip.stacks)
    end)

    it("schedules a non-cancelled expireTimer", function()
        Tip:ApplySpell("generator")
        assert.is_not_nil(Tip.expireTimer)
        assert.is_false(Tip.expireTimer:IsCancelled())
    end)

    pending("adds 3 stacks for Twin Fangs/Takedown (BUG-04, Phase 3)", function()
        -- Takedown (1250646) should grant 3 stacks; not yet implemented
        Tip:ApplySpell("generator")   -- placeholder
    end)
end)
```

**Serial-mismatch test pattern** (RESEARCH.md Pitfall 4):
```lua
it("castVerify callback returns early on serial mismatch", function()
    -- Step 1: first cast schedules verify with serial N
    Tip:ApplySpell("generator")          -- serial becomes 1
    -- Step 2: second cast increments serial to N+1 before first timer fires
    Tip:ApplySpell("generator")          -- serial becomes 2; stacks now 3 (capped)
    -- Step 3: advance past AURA_VERIFY_DELAY (1.25s)
    -- First callback fires, checks serial 1 != 2 → early return (no SyncFromAura)
    local syncCalled = false
    local origSync = Tip.SyncFromAura
    Tip.SyncFromAura = function(self, ...)
        syncCalled = true
        return origSync(self, ...)
    end
    clock:advance(1.3)   -- fires first C_Timer.After(1.25) callback
    assert.is_false(syncCalled)  -- serial mismatch → suppressed
end)
```

**Grace period boundary test** (RESEARCH.md Pitfall 5 — start clock at 100, not 0):
```lua
it("suppresses SyncFromAura within CONSUMER_UPSYNC_GRACE window", function()
    Tip.stacks          = 2
    Tip.lastPredictKind = "consumer"
    Tip.lastPredictAt   = clock.now   -- = 100
    Tip.inCombat        = true

    -- Mock aura returning 3 stacks (higher than predicted 1 after consumer)
    _G.C_UnitAuras.GetPlayerAuraBySpellID = function()
        return stubs.makeAuraData({ applications = 3, expirationTime = clock.now + 8 })
    end

    -- Within grace window (100 + 1 = 101; grace ends at 100 + 2.75 = 102.75)
    clock:advance(1)
    local result = Tip:SyncFromAura()
    assert.is_false(result)   -- suppressed
    assert.are.equal(2, Tip.stacks)  -- unchanged
end)
```

---

### `.busted` (config)

**Analog:** None — new config file. Pattern from RESEARCH.md Pattern 6.

```lua
-- .busted at repo root
return {
    default = {
        verbose          = false,
        output           = "utfTerminal",
        pattern          = "_spec",
        ["no-keep-going"] = false,
    }
}
```

Run command: `busted spec/` from project root.

---

### `.luacheckrc` (config)

**Analog:** None — new config file. Pattern from RESEARCH.md Pattern 7.

**Critical distinction (RESEARCH.md Pitfall 6):** `SLASH_DUNCEDMAXXING1`, `SLASH_DUNCEDMAXXING2`, and `DuncedmaxxingDB` must be in `globals` (writeable), not `read_globals` — they are written by addon code.

Confirmed by Core.lua lines 198–199 (`SLASH_DUNCEDMAXXING1 = "..."` plain assignment) and line 338 (`DuncedmaxxingDB = MergeDefaults(...)`).

```lua
-- .luacheckrc at repo root
std = "lua51"

-- Globals written by the addon (NOT read_globals — they are assigned)
globals = {
    "DuncedmaxxingDB",
    "SLASH_DUNCEDMAXXING1",
    "SLASH_DUNCEDMAXXING2",
}

-- WoW globals the addon reads but does not define
read_globals = {
    "CreateFrame",
    "UIParent",
    "STANDARD_TEXT_FONT",
    "C_UnitAuras",
    "C_Timer",
    "C_SpecializationInfo",
    "C_Spell",
    "GetSpecialization",
    "GetSpellTexture",
    "InCombatLockdown",
    "UnitClass",
    "GetTime",
    "SlashCmdList",
    "DEFAULT_CHAT_FRAME",
    "Duncedmaxxing",
}

-- Exclude spec files from addon linting (D-11)
exclude_files = {
    "spec/**/*.lua",
}
```

Run command: `luacheck Duncedmaxxing/ --no-unused-args` from project root.

---

### `Duncedmaxxing/Core.lua` (modify — expose test helpers)

**Analog:** Existing file — exact match.

**Change:** Add `DMX._test` block at the bottom of `Core.lua`, after the `coreFrame` event registration block (after line 349, before EOF). This exposes local functions for direct unit testing without going through the ADDON_LOADED event.

The local functions to expose (all defined before line 74–111):
- `NormalizeDB` (line 74)
- `MergeDefaults` (line 57)
- `CopyDefaults` (line 45)
- `SETTINGS_MIGRATION` constant (line 16)
- `DEFAULTS` table (already at `DMX.defaults`, line 43)

**Insertion point:** After line 349 (end of `coreFrame:SetScript` closure), before EOF.

**Pattern to follow** (matches existing Core.lua style — PascalCase table keys, no trailing newlines):
```lua
-- Test-only escape hatch: exposes local functions for spec/core_spec.lua
-- Do not use in production addon code.
DMX._test = {
    MergeDefaults      = MergeDefaults,
    NormalizeDB        = NormalizeDB,
    CopyDefaults       = CopyDefaults,
    SETTINGS_MIGRATION = SETTINGS_MIGRATION,
}
```

---

## Shared Patterns

### WoW vararg injection (applies to all spec files that load addon source)
**Source:** RESEARCH.md Pattern 2 (derived from Lua 5.1 reference manual)
**Apply to:** `spec/support/init.lua`
```lua
local function loadAddon(path, addonName, dmxTable)
    local chunk, err = loadfile(path)
    if not chunk then error("Failed to load " .. path .. ": " .. tostring(err)) end
    return chunk(addonName, dmxTable)
end
```
**Critical:** `dofile()` MUST NOT be used for addon source files — it passes an empty vararg, making `local _, DMX = ...` assign nil to DMX, crashing everything on first method call.

### Per-spec isolation via before_each reload (applies to all spec files)
**Source:** RESEARCH.md D-06 decision
**Apply to:** `spec/util_spec.lua`, `spec/core_spec.lua`, `spec/tip_spec.lua`
```lua
local loader = require("spec.support.init")
describe("...", function()
    local DMX, Tip, clock
    before_each(function()
        DMX, Tip, clock = loader.load()   -- fresh reload every test
        loader.resetTipState(Tip, clock)  -- zero runtime state + clock.now = 100
    end)
```

### Non-zero clock base time (applies to all timer-sensitive tests)
**Source:** RESEARCH.md Pitfall 5
**Apply to:** All `before_each` blocks in `spec/tip_spec.lua`

Always set `clock.now = 100` (or any non-zero base) before timer tests. If `clock.now = 0` and `lastPredictAt = 0`, then `0 < 0 + 2.75` is true — grace suppression fires even on first call, making grace-period boundary tests false-positive.

### DMX.Util.* namespace for utility functions (applies to util_spec.lua)
**Source:** `Duncedmaxxing/Util.lua` lines 40–43
```lua
Util.Trim         = Trim
Util.Clamp        = Clamp
Util.ParseOnOff   = ParseOnOff
Util.ParseHexColor = ParseHexColor
```
Test access via: `DMX.Util.Clamp(...)`, `DMX.Util.ParseHexColor(...)`, etc.

### Module access via DMX:GetModule (applies to tip_spec.lua)
**Source:** `Duncedmaxxing/Core.lua` lines 123–125
```lua
function DMX:GetModule(key)
    return self.modules[key]
end
```
In tests: `local Tip = DMX:GetModule("tip")`. Module registers itself at TipOfTheSpear.lua line 770: `DMX:RegisterModule("tip", Tip)`.

---

## No Analog Found

All 7 new files have no analog in the existing codebase. The project has no existing test infrastructure.

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `spec/support/wow_stubs.lua` | test-support | event-driven | No existing mock files; WoW addon with zero prior test setup |
| `spec/support/init.lua` | test-support | request-response | No existing test loader; novel loadfile+vararg injection pattern |
| `spec/util_spec.lua` | test | transform | No existing specs |
| `spec/core_spec.lua` | test | CRUD | No existing specs |
| `spec/tip_spec.lua` | test | event-driven + timer | No existing specs |
| `.busted` | config | — | No busted config exists |
| `.luacheckrc` | config | — | No luacheck config exists |

For all these files, the planner should use the RESEARCH.md patterns (Patterns 1–7) as the primary reference, supplemented by the source-code excerpts above.

---

## Metadata

**Analog search scope:** `Duncedmaxxing/` (all 4 Lua source files), repo root (no config files found)
**Files scanned:** 4 source files (Core.lua, Util.lua, Options.lua, TipOfTheSpear.lua), Duncedmaxxing.toc
**Pattern extraction date:** 2026-06-17
**Source confidence:** HIGH — all key constants, function signatures, and field names extracted directly from production source files with line numbers.
