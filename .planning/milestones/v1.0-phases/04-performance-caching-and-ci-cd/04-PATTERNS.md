# Phase 4: Performance Caching and CI/CD - Pattern Map

**Mapped:** 2026-06-18
**Files analyzed:** 5 (3 modified, 1 extended, 1 new)
**Analogs found:** 4 / 5

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `Duncedmaxxing/Modules/TipOfTheSpear.lua` (modify) | module | event-driven | `Duncedmaxxing/Modules/TipOfTheSpear.lua` itself — `Tip.hasTwinFangs` cache at line 55/778 | exact |
| `Duncedmaxxing/Core.lua` (no change needed) | core | — | — | reference only |
| `spec/tip_spec.lua` (extend) | test | — | `spec/tip_spec.lua` existing describe blocks (lines 21–170) | exact |
| `spec/support/init.lua` (extend) | test-support | — | `spec/support/init.lua` `resetTipState` function (lines 52–67) | exact |
| `.github/workflows/release.yml` (new) | ci-config | — | No analog in codebase — RESEARCH.md Pattern 3 is the reference | no analog |

---

## Pattern Assignments

### `Duncedmaxxing/Modules/TipOfTheSpear.lua` — PERF-01: Spec State Cache (`Tip.isSurvival`)

**Analog:** Same file — `Tip.hasTwinFangs` event-driven cache pattern.

**Field declaration pattern** (lines 45–55):
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
Tip.hasTwinFangs = false
```
Add `Tip.isSurvival = false` alongside these at the same top-of-module level.

**Initialize population pattern** (lines 768–794):
```lua
function Tip:Initialize(core)
    self.core = core

    if self.initialized then
        return
    end
    self.initialized = true

    EnsureFrame(self)
    self.inCombat = InCombatLockdown and InCombatLockdown() or false
    self.hasTwinFangs = HasTwinFangs()
    self:RefreshLayout()
    ...
end
```
Add `self.isSurvival = DMX:IsSurvivalHunter()` after `self.hasTwinFangs = HasTwinFangs()` on line 778.

**OnEvent invalidation pattern — spec change** (lines 735–744):
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
Replace `self:RefreshActive()` with `self.isSurvival = DMX:IsSurvivalHunter()`. Pattern: cache field is written directly on the Tip table, not through a method call.

**OnEvent invalidation pattern — talent update** (lines 745–749):
```lua
elseif event == "PLAYER_TALENT_UPDATE" or event == "TRAIT_CONFIG_UPDATED" then
    self.hasTwinFangs = HasTwinFangs()
    self:RefreshActive()
    self:Update()
    return
```
Add `self.isSurvival = DMX:IsSurvivalHunter()` after `self.hasTwinFangs = HasTwinFangs()`. Same pattern.

**PLAYER_LOGIN handler pattern** (lines 730–734):
```lua
elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
    self:RefreshActive()
    self:SyncFromAura()
    self:Update()
    return
```
Add `self.isSurvival = DMX:IsSurvivalHunter()` before `self:RefreshActive()` (or replace the call if RefreshActive is being repurposed).

**Update hot path — current bug** (lines 598–605):
```lua
self:RefreshActive()

local db = DMX:GetDB()
local cfg = db.tip
local stacks = self:GetStacks()
local unlocked = not db.locked

local shouldShow = unlocked or self.testMode or (cfg.enabled and self.active)
```
After PERF-01: remove `self:RefreshActive()` call entirely (line 598). Replace `self.active` with `self.isSurvival` on line 605.

**UNIT_SPELLCAST_SUCCEEDED guard pattern** (lines 753–758) — all `self.active` reads must become `self.isSurvival`:
```lua
elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
    if not self.active then
        self:RefreshActive()
    end
    if not self.active then
        return
    end
```
Replace both `self.active` reads with `self.isSurvival`. The lazy-refresh call `self:RefreshActive()` is removed (cache is now always fresh from events).

**RefreshActive method** (lines 334–336) — retained but repurposed to write `isSurvival`:
```lua
function Tip:RefreshActive()
    self.active = DMX:IsSurvivalHunter()
end
```
Rename `self.active` to `self.isSurvival`. The method name `RefreshActive` can stay as a convenience wrapper for backward compat with any callers not yet migrated.

---

### `Duncedmaxxing/Modules/TipOfTheSpear.lua` — PERF-02: Spell Texture Cache (`Tip.spellTexture`)

**Analog:** Same file — `ResolveSpellTexture` local function (lines 137–147) is the existing dual-path API call to transform into a cache-populating function.

**Existing function to replace** (lines 137–147):
```lua
local function ResolveSpellTexture()
    if C_Spell and C_Spell.GetSpellTexture then
        return C_Spell.GetSpellTexture(TIP_OF_THE_SPEAR) or FALLBACK_ICON
    end

    if _G.GetSpellTexture then
        return _G.GetSpellTexture(TIP_OF_THE_SPEAR) or FALLBACK_ICON
    end

    return FALLBACK_ICON
end
```
Replace with a cache-populating local function `CacheSpellTexture(tip)` (see code below). The dual-path API call structure is preserved; only the return-vs-assign pattern changes.

**New cache-populating function — dual-path pattern preserved**:
```lua
-- Replaces ResolveSpellTexture. Called once at Initialize and on PLAYER_LOGIN.
-- C_Spell.GetSpellTexture returns two values (iconID, originalIconID);
-- only the first is captured — Lua discards the second implicitly.
local function CacheSpellTexture(tip)
    local tex
    if C_Spell and C_Spell.GetSpellTexture then
        tex = C_Spell.GetSpellTexture(TIP_OF_THE_SPEAR)
    end
    if not tex and _G.GetSpellTexture then
        tex = _G.GetSpellTexture(TIP_OF_THE_SPEAR)
    end
    tip.spellTexture = tex or FALLBACK_ICON
end
```

**Field declaration** — add alongside `Tip.hasTwinFangs` block (lines 45–55):
```lua
Tip.spellTexture = nil
```

**Initialize call site** (lines 768–794) — add `CacheSpellTexture(self)` after `self.hasTwinFangs = HasTwinFangs()`:
```lua
self.hasTwinFangs = HasTwinFangs()
self.isSurvival   = DMX:IsSurvivalHunter()   -- PERF-01
CacheSpellTexture(self)                        -- PERF-02
self:RefreshLayout()
```

**PLAYER_LOGIN re-check** (lines 730–734):
```lua
elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
    self:RefreshActive()
    self:SyncFromAura()
    self:Update()
    return
```
Add `CacheSpellTexture(self)` as the first line of this branch (before `self:RefreshActive()`).

**RefreshLayout call site fix** (line 493 — icons mode):
```lua
-- BEFORE:
pip.fill:SetTexture(ResolveSpellTexture())

-- AFTER:
pip.fill:SetTexture(self.spellTexture)
```

**Update call site fix** (line 651 — icons mode):
```lua
-- BEFORE:
pip.fill:SetTexture(ResolveSpellTexture())

-- AFTER:
pip.fill:SetTexture(self.spellTexture)
```

**D-08 local alias pattern** (lines 591–596 in `Update`, lines 457–462 in `RefreshLayout`) — existing pattern for frame locals that applies equally to `spellTexture` if accessed multiple times:
```lua
function Tip:Update()
    EnsureFrame(self)
    local root       = self.root       -- D-08 local alias
    local pips       = self.pips
    local label      = self.label
    local numberText = self.numberText
```
If `self.spellTexture` is read more than once in `Update`, apply the same local alias pattern: `local spellTexture = self.spellTexture` at function entry.

---

### `spec/tip_spec.lua` — New Caching Describe Block

**Analog:** Existing `describe("Tip:ApplySpell", ...)` block (lines 21–170). Copy structure exactly.

**Describe block structure pattern** (lines 21–28):
```lua
describe("Tip:ApplySpell", function()
    local DMX, Tip, clock

    before_each(function()
        DMX, Tip, clock = loader.load()
        loader.resetTipState(Tip, clock)
    end)
    ...
end)
```
New caching describe block follows the identical `before_each` isolation pattern.

**Spec-override pattern for PLAYER_SPECIALIZATION_CHANGED test** — stub override mid-test:
```lua
-- Pattern already in stubs: C_SpecializationInfo.GetSpecialization returns 3 by default
-- Override for non-Survival test:
_G.C_SpecializationInfo.GetSpecialization = function() return 1 end
Tip:OnEvent("PLAYER_SPECIALIZATION_CHANGED", "player")
assert.is_false(Tip.isSurvival)
```
This follows the same `mockAura.impl` override pattern used in SyncFromAura tests — swap the stub, fire the event, assert state.

**Assert pattern for non-nil cache fields** — from existing tests (e.g. line 112–113):
```lua
assert.is_not_nil(Tip.expireTimer)
assert.is_false(Tip.expireTimer:IsCancelled())
```
For caching tests: `assert.is_true(Tip.isSurvival)`, `assert.is_not_nil(Tip.spellTexture)`.

---

### `spec/support/init.lua` — Extend `resetTipState`

**Analog:** Existing `resetTipState` function (lines 52–67).

**Current reset list pattern** (lines 52–67):
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
    Tip.hasTwinFangs      = false
    clock:reset()
    clock.now = 100
    -- Reset aura dispatch via mockAura.impl (not _G.C_UnitAuras field, which the
    -- module-level local in TipOfTheSpear.lua has already captured).
    stubs.mockAura.impl = function(_spellID) return nil end
end
```
Add two new lines after `Tip.hasTwinFangs = false`:
```lua
    Tip.isSurvival        = false
    Tip.spellTexture      = nil
```

---

### `.github/workflows/release.yml` — New CI/CD Workflow

**Analog:** No analog in codebase. RESEARCH.md Pattern 3 (lines 341–384) is the reference.

**Two-job structure** — lint-and-test gates package-release via `needs`:
```yaml
jobs:
  lint-and-test:
    runs-on: ubuntu-latest
    steps: [...]

  package-release:
    needs: lint-and-test
    runs-on: ubuntu-latest
    steps: [...]
```

**Version injection pattern** — strip `v` prefix before sed:
```yaml
- name: Inject version into TOC
  run: |
    TAG="${{ github.ref_name }}"
    VERSION="${TAG#v}"
    sed -i "s/^## Version: .*/## Version: $VERSION/" Duncedmaxxing/Duncedmaxxing.toc
    echo "Injected version: $VERSION"
```
The `echo` line is a defensive diagnostic recommended by RESEARCH.md Pitfall 3.

**Zip packaging pattern** — top-level `Duncedmaxxing/` folder preserved:
```yaml
- name: Create zip
  run: |
    TAG="${{ github.ref_name }}"
    VERSION="${TAG#v}"
    zip -r "Duncedmaxxing-$VERSION.zip" Duncedmaxxing/
```

**Release asset upload pattern**:
```yaml
- name: Upload release asset
  uses: softprops/action-gh-release@v2
  with:
    files: Duncedmaxxing-*.zip
    prerelease: true
    generate_release_notes: true
```

**Trigger pattern** (release-created, not tag push):
```yaml
on:
  release:
    types: [created]
```

---

## Shared Patterns

### Dual-Path API Calls
**Source:** `Duncedmaxxing/Modules/TipOfTheSpear.lua` lines 137–147 (`ResolveSpellTexture`), `Duncedmaxxing/Core.lua` lines 143–154 (`IsSurvivalHunter`)
**Apply to:** `CacheSpellTexture` function (PERF-02)
```lua
-- Pattern: new API first, legacy global fallback, hardcoded fallback last
if C_Spell and C_Spell.GetSpellTexture then
    tex = C_Spell.GetSpellTexture(TIP_OF_THE_SPEAR)
end
if not tex and _G.GetSpellTexture then
    tex = _G.GetSpellTexture(TIP_OF_THE_SPEAR)
end
tip.spellTexture = tex or FALLBACK_ICON
```

### Event-Driven Cache Invalidation
**Source:** `Duncedmaxxing/Modules/TipOfTheSpear.lua` lines 745–749 (`hasTwinFangs` on PLAYER_TALENT_UPDATE)
**Apply to:** Both `isSurvival` and `spellTexture` refresh paths in `OnEvent`
```lua
-- Pattern: write directly to self.field in the event handler; never call the API from Update
elseif event == "PLAYER_TALENT_UPDATE" or event == "TRAIT_CONFIG_UPDATED" then
    self.hasTwinFangs = HasTwinFangs()
    -- PERF-01: add here:
    self.isSurvival = DMX:IsSurvivalHunter()
    self:Update()
    return
```

### Idempotency Guard at Initialize
**Source:** `Duncedmaxxing/Modules/TipOfTheSpear.lua` lines 769–774
**Apply to:** `Initialize` method when adding cache population calls
```lua
function Tip:Initialize(core)
    self.core = core

    if self.initialized then
        return   -- guard: only run once
    end
    self.initialized = true
    ...
```
Cache-populating calls (`CacheSpellTexture`, `self.isSurvival = ...`) go inside the guard, after `self.initialized = true`.

### Test Isolation Pattern
**Source:** `spec/support/init.lua` lines 21–47 (`load()`), lines 52–67 (`resetTipState`)
**Apply to:** All new `describe` blocks in `spec/tip_spec.lua`
```lua
before_each(function()
    DMX, Tip, clock = loader.load()
    loader.resetTipState(Tip, clock)
end)
```

### Stub Override in Mid-Test
**Source:** `spec/support/wow_stubs.lua` lines 147–152 (`mockAura.impl` swap pattern)
**Apply to:** `PLAYER_SPECIALIZATION_CHANGED` test that needs non-Survival spec
```lua
-- Swap stub before firing event; stubs.install already set the default return
_G.C_SpecializationInfo.GetSpecialization = function() return 1 end
```

---

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `.github/workflows/release.yml` | ci-config | — | No GitHub Actions workflow exists in the repo; RESEARCH.md Pattern 3 (lines 341–384) is the reference |

---

## Metadata

**Analog search scope:** `Duncedmaxxing/` (all Lua source), `spec/` (test files)
**Files scanned:** 4 (TipOfTheSpear.lua, Core.lua, spec/support/init.lua, spec/support/wow_stubs.lua, spec/tip_spec.lua)
**Pattern extraction date:** 2026-06-18

**Key observations for planner:**
- The `Tip.hasTwinFangs` cache (lines 55, 778, 739, 746) is the canonical template for both PERF-01 and PERF-02. The planner should reference this as the "copy exactly" analog.
- `self.active` appears at 4 locations in TipOfTheSpear.lua: line 46 (declaration), line 335 (write in RefreshActive), line 605 (read in Update), lines 754/757 (read in OnEvent UNIT_SPELLCAST_SUCCEEDED). All 4 must be updated atomically when renaming to `self.isSurvival`.
- `ResolveSpellTexture()` call sites are at lines 493 and 651. Both must be replaced with `self.spellTexture`. After replacement the local function definition (lines 137–147) can be removed.
- The `luacheck` pre-existing 6 warnings (unused `self` argument) will fail CI if not addressed. The planner should include a Wave 0 task to either fix them or add `-- luacheck: ignore 212` suppressions at the affected lines in Core.lua (lines 131, 137) and Options.lua (lines 142, 172, 452, 456).
