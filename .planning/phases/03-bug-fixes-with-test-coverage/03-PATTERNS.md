# Phase 3: Bug Fixes with Test Coverage - Pattern Map

**Mapped:** 2026-06-18
**Files analyzed:** 6 (2 source modifications, 4 test file modifications)
**Analogs found:** 6 / 6

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `Duncedmaxxing/Modules/TipOfTheSpear.lua` | module (state machine) | event-driven | Self (existing file — targeted patches) | exact |
| `Duncedmaxxing/Core.lua` | core / config | CRUD | Self (existing file — dead block removal) | exact |
| `spec/tip_spec.lua` | test | event-driven | Self (existing file — extend describe blocks) | exact |
| `spec/core_spec.lua` | test | CRUD | Self (existing file — extend describe block) | exact |
| `spec/support/wow_stubs.lua` | test-support / stub | request-response | Self (existing file — add C_SpellBook stub) | exact |
| `spec/support/init.lua` | test-support / loader | request-response | Self (existing file — extend resetTipState) | exact |

---

## Pattern Assignments

### `Duncedmaxxing/Modules/TipOfTheSpear.lua` — five targeted patches

**Analog:** Self. All patterns below are extracted from the live file.

---

#### BUG-01: ScheduleAuraVerify — verify flag placement (lines 408–440)

The live code already places `self.auraVerifyPending = false` at line 431, **before** the
serial-mismatch early return at line 432. The researcher confirmed this in RESEARCH.md Pitfall 5.
The BUG-01 task is therefore: **write the test first; if it passes without a code change, the fix
is already present.** No new code pattern is needed — the existing pattern is correct.

**Current correct implementation** (`TipOfTheSpear.lua` lines 428–439):
```lua
self.auraVerifyPending = true
local serial = self.castVerifySerial
C_Timer.After(requestedDelay, function()
    self.auraVerifyPending = false          -- clears on ALL paths (line 431)
    if self.inCombat and serial ~= self.castVerifySerial then
        return                              -- early return at line 433 — flag already cleared
    end
    if self:SyncFromAura() then
        self:Update()
    end
end)
```

---

#### BUG-03/BUG-04: Dual-path talent API detection — new local function

**Pattern source:** `Core.lua` lines 158–164 (existing `IsSurvivalHunter` dual-path call).

**Existing dual-path pattern to copy** (`Core.lua` lines 158–164):
```lua
local spec
if C_SpecializationInfo and C_SpecializationInfo.GetSpecialization then
    spec = C_SpecializationInfo.GetSpecialization()
elseif GetSpecialization then
    spec = GetSpecialization()
end
return spec == 3
```

**New `HasTwinFangs` function to add** (place near top of TipOfTheSpear.lua, after constants):
```lua
local function HasTwinFangs()
    local id = 1272139  -- Twin Fangs passive talent spell ID (D-02)
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        return C_SpellBook.IsSpellKnown(id) and true or false
    elseif IsPlayerSpell then
        return IsPlayerSpell(id) and true or false
    end
    return false
end
```

**Critical:** Do NOT capture `C_SpellBook.IsSpellKnown` as a module-level local (unlike the
`GetPlayerAuraBySpellID` capture at line 30). Let `HasTwinFangs()` read `_G.C_SpellBook` at
call time so test stubs can be set per-test without module reload tricks (RESEARCH Pitfall 2).

---

#### BUG-03/BUG-04: `hasTwinFangs` cache field — initialization

**Pattern source:** Existing Tip table field initializations at `TipOfTheSpear.lua` lines 32–41.

**Existing field init pattern** (lines 32–41):
```lua
Tip.stacks = 0
Tip.active = false
Tip.inCombat = false
Tip.testMode = false
Tip.testStacks = MAX_STACKS
Tip.expiresAt = 0
Tip.castVerifySerial = 0
Tip.auraVerifyPending = false
Tip.lastPredictAt = 0
Tip.lastPredictKind = nil
```

**New field to add** (append to this block):
```lua
Tip.hasTwinFangs = false
```

---

#### BUG-03/BUG-04: `PLAYER_TALENT_UPDATE` cache refresh — OnEvent handler

**Pattern source:** `TipOfTheSpear.lua` lines 721–723 (existing `PLAYER_TALENT_UPDATE` branch)
and lines 712–720 (`PLAYER_SPECIALIZATION_CHANGED` branch).

**Existing `PLAYER_SPECIALIZATION_CHANGED` pattern** (lines 712–720):
```lua
elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
    local unit = ...
    if unit == "player" then
        self.stacks = 0
        self:RefreshActive()
        self:SyncFromAura()
        self:Update()
    end
    return
```

**Existing `PLAYER_TALENT_UPDATE` branch** (lines 721–723) — currently does NOT refresh talent:
```lua
elseif event == "PLAYER_TALENT_UPDATE" or event == "TRAIT_CONFIG_UPDATED" then
    self:RefreshActive()
    self:Update()
    return
```

**Updated `PLAYER_TALENT_UPDATE` branch** — add `hasTwinFangs` refresh:
```lua
elseif event == "PLAYER_TALENT_UPDATE" or event == "TRAIT_CONFIG_UPDATED" then
    self.hasTwinFangs = HasTwinFangs()
    self:RefreshActive()
    self:Update()
    return
```

**Updated `PLAYER_SPECIALIZATION_CHANGED` branch** — also refresh talent on spec change:
```lua
elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
    local unit = ...
    if unit == "player" then
        self.stacks = 0
        self.hasTwinFangs = HasTwinFangs()
        self:RefreshActive()
        self:SyncFromAura()
        self:Update()
    end
    return
```

**Also add in `Initialize`** (after `self.inCombat` init, before `EnsureFrame`) to seed the
initial talent state after `ADDON_LOADED`:
```lua
self.hasTwinFangs = HasTwinFangs()
```

---

#### BUG-03/BUG-04: `FindTrackedSpell` — extend to return spell ID

**Pattern source:** `TipOfTheSpear.lua` lines 60–67 (current `FindTrackedSpell`).

**Current implementation** (lines 60–67):
```lua
local function FindTrackedSpell(...)
    for i = 1, select("#", ...) do
        local kind = ClassifySpellID(select(i, ...))
        if kind then
            return kind
        end
    end
end
```

**Updated to also return matching spell ID** (two return values):
```lua
local function FindTrackedSpell(...)
    for i = 1, select("#", ...) do
        local id = select(i, ...)
        local kind = ClassifySpellID(id)
        if kind then
            return kind, id
        end
    end
end
```

**Call site in OnEvent** (line 736) must be updated:
```lua
-- Before:
local kind = FindTrackedSpell(...)
if kind then
    self:ApplySpell(kind)
end

-- After:
local kind, spellID = FindTrackedSpell(...)
if kind then
    self:ApplySpell(kind, spellID)
end
```

---

#### BUG-03/BUG-04: `ApplySpell` — talent-aware grant amounts

**Pattern source:** `TipOfTheSpear.lua` lines 675–695 (current `ApplySpell`).

**Current implementation** (lines 675–695):
```lua
function Tip:ApplySpell(kind)
    local now = GetTime()

    if kind == "generator" then
        self.stacks = ClampStacks(self.stacks + 2)
        self.expiresAt = now + BUFF_DURATION
    elseif kind == "consumer" then
        self.stacks = ClampStacks(self.stacks - 1)
        if self.stacks == 0 then
            self.expiresAt = 0
        end
    else
        return
    end

    self.lastPredictAt = now
    self.lastPredictKind = kind
    self:ScheduleExpiration()
    self:Update()
    self:ScheduleCastVerify()
end
```

**New constant to add** (with other constants at top of file, near `KILL_COMMAND`):
```lua
local TAKEDOWN = 1250646
```

**Updated `ApplySpell`** with `spellID` parameter and talent-aware branches (D-04 order of
operations: grant fires FIRST, then consume — see RESEARCH.md Pattern 3):
```lua
function Tip:ApplySpell(kind, spellID)
    local now = GetTime()

    if kind == "generator" then
        local grant = self.hasTwinFangs and 3 or 2
        self.stacks = ClampStacks(self.stacks + grant)
        self.expiresAt = now + BUFF_DURATION
    elseif kind == "consumer" then
        if spellID == TAKEDOWN and self.hasTwinFangs then
            -- D-04: grant fires FIRST (+3 capped at MAX_STACKS), THEN consume (-1).
            -- clamp(stacks + 3) - 1 is NOT the same as clamp(stacks - 1 + 3)
            -- when clamp truncates. Example: stacks=1 → clamp(4)=3 → 3-1=2.
            self.stacks = ClampStacks(self.stacks + 3)
            self.expiresAt = now + BUFF_DURATION
            self.stacks = self.stacks - 1  -- no second clamp: guaranteed >= 2
        else
            self.stacks = ClampStacks(self.stacks - 1)
            if self.stacks == 0 then
                self.expiresAt = 0
            end
        end
    else
        return
    end

    self.lastPredictAt = now
    self.lastPredictKind = kind
    self:ScheduleExpiration()
    self:Update()
    self:ScheduleCastVerify()
end
```

---

#### BUG-02: `RefreshTip` in Core.lua — add out-of-combat SyncFromAura

**Pattern source:** `Core.lua` lines 173–179 (current `RefreshTip` local function) and
`TipOfTheSpear.lua` lines 702–706 (existing out-of-combat SyncFromAura call in
`PLAYER_REGEN_ENABLED` handler).

**Current `RefreshTip`** (`Core.lua` lines 173–179):
```lua
local function RefreshTip(tip)
    if tip and tip.RefreshLayout then
        tip:RefreshLayout()
    elseif tip and tip.Update then
        tip:Update()
    end
end
```

**Updated `RefreshTip`** — add unconditional out-of-combat SyncFromAura before layout:
```lua
local function RefreshTip(tip)
    if tip and not tip.inCombat then
        tip:SyncFromAura()
    end
    if tip and tip.RefreshLayout then
        tip:RefreshLayout()
    elseif tip and tip.Update then
        tip:Update()
    end
end
```

Scope rationale (D-07, Claude's discretion): unconditional for all non-combat `RefreshTip` calls
(mode switch, size change, color change, border change) rather than mode-change-only. This is
simpler, covers all stale-display paths, and `ReadLiveState` already handles API absence
gracefully (RESEARCH.md Pattern 5 and Pitfall 4).

---

#### QUAL-03: `NormalizeDB` dead block removal in Core.lua

**Pattern source:** `Core.lua` lines 98–106 (block to delete).

**Lines to remove** (`Core.lua` lines 98–106):
```lua
if tip.barWidth then
    tip.width = tip.barWidth
end
if tip.barHeight then
    tip.height = tip.barHeight
end
if tip.spacing and not tip.borderSize then
    tip.borderSize = tip.spacing
end
```

After removal, `NormalizeDB` ends at the `displayMode` validation block (line 108 in current
numbering). No replacement code — the migration gate at lines 77–96 already clears these fields
for any migrated DB, making the fallback unreachable.

---

### `spec/tip_spec.lua` — four new describe blocks / extensions

**Analog:** Self. Copy the `before_each` and `it()` structure verbatim from the existing file.

**`before_each` pattern to copy** (lines 24–27 — used in every describe block):
```lua
before_each(function()
    DMX, Tip, clock = loader.load()
    loader.resetTipState(Tip, clock)
end)
```

**Spy/override pattern for SyncFromAura** (lines 279–285 — copy for BUG-01 flag test):
```lua
local syncCallCount = 0
local originalSync  = Tip.SyncFromAura
Tip.SyncFromAura    = function(self)
    syncCallCount = syncCallCount + 1
    return originalSync(self)
end
-- ... test body ...
Tip.SyncFromAura = originalSync  -- restore at end
```

**mockAura override pattern** (lines 163–168 — copy for BUG-02 aura-absent scenario):
```lua
stubs.mockAura.impl = function(_spellID)
    return stubs.makeAuraData({ applications = 2, expirationTime = clock.now + 8 })
end
```

**clock:advance pattern for timer tests** (lines 121–123 — copy for BUG-01 flag check):
```lua
clock:advance(AURA_VERIFY_DELAY + 0.1)
assert.equals(0, Tip.stacks)
```

**Talent state setup pattern** — set `Tip.hasTwinFangs` directly in test body before call:
```lua
-- Control talent state per test via direct field assignment (no stub needed for the
-- field itself; the stub for C_SpellBook.IsSpellKnown controls Initialize/OnEvent paths)
Tip.hasTwinFangs = true
Tip:ApplySpell("generator")
assert.equals(3, Tip.stacks)
```

**BUG-04 Takedown grant-then-consume test pattern** (implements the pending at line 127):
```lua
it("adds 3 stacks for Takedown with Twin Fangs talent (BUG-04)", function()
    Tip.hasTwinFangs = true
    Tip.stacks = 1
    Tip:ApplySpell("consumer", 1250646)   -- Takedown spell ID
    -- D-04: clamp(1 + 3, MAX_STACKS=3) = 3, then 3 - 1 = 2
    assert.equals(2, Tip.stacks)
    assert.not_equals(0, Tip.expiresAt)   -- expiresAt set (stacks > 0)
end)
```

**BUG-02 mode-switch test pattern** — reach RefreshTip via `DMX:RefreshTip()`:
```lua
it("syncs stacks to 0 on RefreshTip when out of combat and aura is absent", function()
    Tip.stacks    = 2
    Tip.expiresAt = clock.now + 5
    Tip.inCombat  = false
    -- mockAura.impl already returns nil from resetTipState
    DMX:RefreshTip()
    assert.equals(0, Tip.stacks)
end)
```

---

### `spec/core_spec.lua` — update 4 deprecated-field tests

**Analog:** Self. The 4 tests in the `"NormalizeDB — deprecated field migration (always runs
post-gate)"` describe block (lines 218–242) currently assert that the dead block maps
`barWidth→width`, `barHeight→height`, and `spacing→borderSize`. After QUAL-03 removes that block,
these tests must flip: they should assert the fields are NOT mapped.

**Current test pattern to update** (lines 218–221 — one of four):
```lua
it("migrates barWidth to width", function()
    local db = migratedDB({barWidth = 300})
    DMX._test.NormalizeDB(db)
    assert.equals(300, db.tip.width)   -- FAILS after dead block removal
end)
```

**Updated test pattern** — assert no mapping occurs when already migrated:
```lua
it("does not map barWidth to width when already migrated (dead block removed)", function()
    local db = migratedDB({barWidth = 300})
    -- migratedDB provides settingsMigration = "0.3.2-fontfix" so gate is skipped.
    -- Dead block (lines 98-106) is gone; barWidth should not affect width.
    DMX._test.NormalizeDB(db)
    assert.is_nil(db.tip.width)   -- not mapped; default width comes from MergeDefaults
end)
```

All four tests follow this same inversion: assert that `width`, `height`, and `borderSize` are
NOT written from the deprecated field names.

---

### `spec/support/wow_stubs.lua` — add C_SpellBook and IsPlayerSpell stubs

**Analog:** Self. Copy the existing stub installation pattern in `install()` (lines 120–182).

**Existing stub installation pattern** (lines 154–158 — dual-path spec API):
```lua
_G.C_SpecializationInfo = {
    GetSpecialization = function() return 3 end,
}

_G.GetSpecialization = function() return 3 end
```

**New stubs to add** in `install()`, after the existing dual-path spec stubs (default: no talent):
```lua
_G.C_SpellBook = {
    IsSpellKnown = function(spellID) return false end,
}
_G.IsPlayerSpell = function(spellID) return false end
```

**Per-test override pattern** — tests that need `hasTwinFangs = true` set `Tip.hasTwinFangs`
directly (simpler) OR override `_G.C_SpellBook.IsSpellKnown` before `loader.load()` if testing
the Initialize/OnEvent refresh path. The direct field approach is preferred for `ApplySpell` tests.

---

### `spec/support/init.lua` — extend `resetTipState`

**Analog:** Self. Add `hasTwinFangs` to the existing field reset block (lines 53–65).

**Current `resetTipState`** (lines 52–66):
```lua
local function resetTipState(Tip, clock)
    Tip.stacks            = 0
    Tip.expiresAt         = 0
    Tip.lastPredictAt     = 0
    Tip.lastPredictKind   = nil
    Tip.castVerifySerial  = 0
    Tip.auraVerifyPending = false
    Tip.expireTimer       = nil
    Tip.testMode          = false
    clock:reset()
    clock.now = 100
    stubs.mockAura.impl = function(_spellID) return nil end
end
```

**Add one line** after `Tip.testMode = false`:
```lua
Tip.hasTwinFangs      = false
```

---

## Shared Patterns

### Dual-path WoW API calls
**Source:** `Core.lua` lines 158–164 (`IsSurvivalHunter`), `TipOfTheSpear.lua` lines 122–132
(`ResolveSpellTexture`)
**Apply to:** New `HasTwinFangs` local function in TipOfTheSpear.lua

```lua
-- Pattern: check modern namespaced API first, fall back to global deprecated name
if C_SpellBook and C_SpellBook.IsSpellKnown then
    return C_SpellBook.IsSpellKnown(id) and true or false
elseif IsPlayerSpell then
    return IsPlayerSpell(id) and true or false
end
return false
```

### Event-driven state cache on Tip table
**Source:** `TipOfTheSpear.lua` lines 32–41 (Tip field declarations) and lines 697–741
(OnEvent handler — `inCombat`, `active` patterns)
**Apply to:** `hasTwinFangs` field — init, OnEvent branch, resetTipState

### Per-test isolation via `loader.load()` in `before_each`
**Source:** `spec/tip_spec.lua` lines 24–27
**Apply to:** All new describe blocks in tip_spec.lua

```lua
before_each(function()
    DMX, Tip, clock = loader.load()
    loader.resetTipState(Tip, clock)
end)
```

### mockAura dispatch override for aura-state tests
**Source:** `spec/tip_spec.lua` lines 143–145 and `spec/support/wow_stubs.lua` lines 18–21
**Apply to:** BUG-02 mode-switch test (nil aura = absent stacks)

```lua
stubs.mockAura.impl = function(_spellID) return nil end  -- absent (default from resetTipState)
-- or for present aura:
stubs.mockAura.impl = function(_spellID)
    return stubs.makeAuraData({ applications = 2, expirationTime = clock.now + 8 })
end
```

### DMX._test escape hatch for testing local functions
**Source:** `Core.lua` lines 351–358
**Apply to:** No new test-escape additions needed for Phase 3 — existing `_test.NormalizeDB` is
sufficient for QUAL-03; no new Core locals need exposure.

---

## No Analog Found

No files in this phase lack a close analog. All six files being modified are well-established in
the codebase, and all patterns are drawn directly from those files.

---

## Key Notes for Planner

1. **BUG-01 is likely a no-op code change.** Live code already clears `auraVerifyPending` before
   the serial-mismatch early return (line 431 precedes line 432). The plan should instruct the
   executor to write and run the test first; proceed to fix only if the test fails.

2. **QUAL-03 requires updating 4 existing tests**, not just adding new ones. The 4 tests in the
   `"deprecated field migration (always runs post-gate)"` describe block in `core_spec.lua` assert
   the behavior of the block being deleted. They will fail after deletion and must be inverted.

3. **Talent stub must be installed before `loader.load()`** only if testing the Initialize or
   OnEvent talent refresh path. For `ApplySpell` tests, setting `Tip.hasTwinFangs = true` directly
   after `loader.load()` is simpler and avoids the capture-timing issue (RESEARCH Pitfall 2).

4. **BUG-04 order of operations:** `clamp(stacks + 3) - 1` is not the same as
   `clamp(stacks - 1 + 3)` when the clamp truncates. Always apply grant first. The test at
   `stacks=1` with `MAX_STACKS=3` is the distinguishing case: correct result is 2, wrong-order
   result is 3.

5. **BUG-02 scope:** The `RefreshTip` SyncFromAura gate is on `not tip.inCombat` only, making it
   unconditional across all non-combat settings changes. `ReadLiveState` handles API absence
   gracefully, so no additional guard is needed.

---

## Metadata

**Analog search scope:** `Duncedmaxxing/`, `spec/` directories
**Files read:** TipOfTheSpear.lua (771 lines), Core.lua (359 lines), tip_spec.lua (336 lines),
core_spec.lua (293 lines), wow_stubs.lua (197 lines), init.lua (72 lines)
**Pattern extraction date:** 2026-06-18
