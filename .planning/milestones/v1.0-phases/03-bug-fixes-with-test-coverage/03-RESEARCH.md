# Phase 3: Bug Fixes with Test Coverage - Research

**Researched:** 2026-06-18
**Domain:** WoW Lua addon — stack state machine bug fixes, talent API integration, test extension
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Use dual-path talent API: `C_SpellBook.IsSpellKnown(1272139)` with fallback to `IsPlayerSpell(1272139)` for detecting Twin Fangs talent.
- **D-02:** Twin Fangs spell ID is **1272139** (passive talent). Verified via warcraft.wiki.gg and wowhead.
- **D-03:** Cache talent state on `PLAYER_TALENT_UPDATE` and `PLAYER_SPECIALIZATION_CHANGED` events only. No per-cast API call.
- **D-04:** Twin Fangs + Takedown mechanic: grant fires FIRST (+3 stacks, capped at MAX_STACKS), THEN consumer effect fires (-1 stack). Net is clamp(stacks + 3, MAX_STACKS) - 1. Example: 1 stack → clamp(4, 3) = 3 → 3 - 1 = 2.
- **D-05:** `IsPlayerSpell` is deprecated in patch 11.2.0; `C_SpellBook.IsSpellKnown` is the replacement (added 11.2.0). Both available on Interface 120005. Dual-path ensures forward compatibility.
- **D-06:** Clear `auraVerifyPending` on every exit path of the timer callback, including the serial-mismatch early return. One-line fix.
- **D-07:** On display mode switch out of combat, trigger a fresh `SyncFromAura`. Claude decides exact scope and whether sync is conditional.
- **D-08:** Remove the dead post-migration fallback block (Core.lua lines 98-106 in current file). No migration version bump.
- **D-09:** `SETTINGS_MIGRATION` string stays at its current value.

### Claude's Discretion
- D-04 implementation structure: whether `ClassifySpellID` returns amounts directly, or a separate function maps kind + talent state to amounts.
- D-07 scope: whether aura refresh triggers on mode changes only or any settings change; whether sync is unconditional or conditional.

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| BUG-01 | `auraVerifyPending` flag cleared on every exit path of the timer callback, including early serial-mismatch return | One-line fix at `ScheduleAuraVerify` line 432; extend existing serial-mismatch test in `spec/tip_spec.lua` |
| BUG-02 | Switching display modes out of combat triggers a fresh aura read so stale stack counts are not shown | Fix in `RefreshTip` local function (Core.lua:173) or in `Tip:RefreshLayout`; new test scenario |
| BUG-03 | Kill Command stack prediction reads talent state dynamically instead of hard-coding +2 | Add `hasTwinFangs` cache field to `Tip`; update `ApplySpell` generator branch; register `PLAYER_TALENT_UPDATE` handler update |
| BUG-04 | Takedown grants 3 Tip of the Spear stacks when Twin Fangs talent is active | Implement existing `pending("adds 3 stacks for Takedown with Twin Fangs talent (BUG-04)")` test; fix consumer Takedown path in `ApplySpell` |
| QUAL-03 | Dead post-migration fallback block in NormalizeDB removed | Remove Core.lua lines 98-106; extend `spec/core_spec.lua` NormalizeDB idempotency tests |
</phase_requirements>

---

## Summary

Phase 3 delivers five targeted fixes and their corresponding tests against a codebase that already has 89 passing tests and one pending (BUG-04). The test infrastructure is fully operational — busted 2.3.0 with Lua 5.1, mock clock, mock aura dispatch, and per-test isolation via `loader.load()`. All Phase 1 structural work (Util.lua, Tip.* frame fields, ordered ForEachModule, ClassifySpellID pcall removed) has already shipped, so Phase 3 code can rely on those clean foundations.

The five deliverables divide into three categories: one one-line flag fix with a test extension (BUG-01), one out-of-combat refresh with a new test (BUG-02), one talent-aware prediction system with stubs and multiple tests (BUG-03/BUG-04 share infrastructure), and one dead-code removal with an idempotency test extension (QUAL-03). No new external libraries are needed. No environment dependencies beyond the already-installed busted runner.

The highest complexity item is BUG-03/BUG-04: adding a `hasTwinFangs` talent cache to the Tip table, dual-path API detection, event-driven refresh on `PLAYER_TALENT_UPDATE`, and reworking `ApplySpell` so the generator path uses the dynamic grant amount and the Takedown consumer path applies the grant-then-consume sequence when Twin Fangs is active. The order-of-operations constraint (grant fires BEFORE consume, D-04) is critical and must be implemented and tested precisely.

**Primary recommendation:** Implement BUG-01 and QUAL-03 first (trivial, low-risk, test coverage immediately verified), then tackle the BUG-03/BUG-04 talent system as a unit, and close with BUG-02 (requires judgement call on D-07 scope).

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Stack prediction (ApplySpell) | Module: TipOfTheSpear | — | All game-state prediction lives in the tracking module |
| Talent detection (Twin Fangs) | Module: TipOfTheSpear | Core (event dispatch) | Talent affects only this module's prediction logic; cache on Tip table |
| Aura verification flag (BUG-01) | Module: TipOfTheSpear | — | `auraVerifyPending` is a Tip-internal scheduling guard |
| Out-of-combat aura refresh (BUG-02) | Core (RefreshTip) | Module: TipOfTheSpear | Mode-switch originates in Core slash handler and Options callbacks |
| Dead code removal (QUAL-03) | Core (NormalizeDB) | — | NormalizeDB is Core-owned; no module impact |
| Test coverage | spec/ layer | — | No production code layer; busted runner only |

---

## Standard Stack

### Core (no new packages needed)
| Component | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| busted | 2.3.0 (installed) | Test runner | Already in use; configured in `.busted` |
| Lua 5.1 | 5.1 (PUC-Rio, installed) | Runtime for tests | Matches WoW sandbox; busted installed with `--lua-version=5.1` flag |
| luacheck | 1.2.0 (installed) | Static linter | Already configured in `.luacheckrc` |

**No new packages.** All tooling is already installed and verified. [VERIFIED: bash `busted --version`, `lua -v`, `luacheck --version`]

### Supporting WoW APIs (runtime, no install)
| API | Purpose | Dual-path |
|-----|---------|-----------|
| `C_SpellBook.IsSpellKnown(spellID)` | Detect Twin Fangs talent (primary, 11.2.0+) | Yes — fallback to `IsPlayerSpell` |
| `IsPlayerSpell(spellID)` | Detect Twin Fangs talent (fallback, deprecated 11.2.0) | Yes — only if C_SpellBook absent |

[ASSUMED] — API availability at runtime is not testable offline; confirmed available on Interface 120005 per CONTEXT.md D-05 and warcraft.wiki.gg references in the discussion log.

---

## Package Legitimacy Audit

No external packages are installed by this phase. All tooling (busted, luacheck) is already present and was audited in Phase 2.

**Packages removed due to slopcheck [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

---

## Architecture Patterns

### System Architecture Diagram

```
PLAYER_TALENT_UPDATE event
         │
         ▼
  Tip:OnEvent  ──► RefreshTalentCache() ──► Tip.hasTwinFangs = true/false
                                                      │
                                                      ▼
UNIT_SPELLCAST_SUCCEEDED ──► ClassifySpellID(spellID)
                                      │
                             "generator" (Kill Command)
                                      │
                             ApplySpell("generator")
                                      │
                        Tip.hasTwinFangs? → +3 : +2
                              + ClampStacks()
                                      │
                                      ▼
                           Takedown (1250646) → "consumer_takedown"
                                      │
                           Tip.hasTwinFangs?
                               YES: grant 3 first → clamp → consume 1
                               NO:  consume 1 only
                                      │
                                      ▼
                              Tip.stacks updated
                                      │
                         ScheduleAuraVerify ──► ScheduleAuraVerify guard:
                                                  auraVerifyPending==true? skip
                                                  NO: set true, schedule timer
                                                         │
                                              timer fires:
                                              ALWAYS: auraVerifyPending = false
                                              serial mismatch? return (BUG-01 fix)
                                              else: SyncFromAura()

Mode switch (slash cmd / Options)
         │
         ▼
  RefreshTip(tip)  ──► inCombat==false? SyncFromAura() (BUG-02 fix)
                   ──► tip:RefreshLayout()
```

### Recommended Project Structure
```
Duncedmaxxing/
├── Util.lua                      # [Phase 1] DMX.Util.* utilities
├── Core.lua                      # NormalizeDB dead block removed (QUAL-03)
├── Options.lua                   # Unchanged
└── Modules/
    └── TipOfTheSpear.lua         # Bug fixes: BUG-01, BUG-02, BUG-03, BUG-04

spec/
├── core_spec.lua                 # NormalizeDB idempotency test extended (QUAL-03)
├── tip_spec.lua                  # BUG-01, BUG-02, BUG-03, BUG-04 tests added
├── util_spec.lua                 # Unchanged
└── support/
    ├── init.lua                  # resetTipState extended with hasTwinFangs = false
    └── wow_stubs.lua             # C_SpellBook.IsSpellKnown + IsPlayerSpell stubs added
```

### Pattern 1: Dual-Path Talent API Detection
**What:** Check `C_SpellBook.IsSpellKnown` first (modern API, 11.2.0+), fall back to `IsPlayerSpell` (deprecated 11.2.0). Same pattern as `C_SpecializationInfo.GetSpecialization` / `GetSpecialization` already in Core.lua.
**When to use:** Any WoW API that was renamed/namespaced in a patch update while the old name was deprecated.

```lua
-- Source: CONTEXT.md D-01, mirroring Core.lua:158-162 pattern
local function HasTwinFangs()
    local id = 1272139  -- Twin Fangs passive talent spell ID
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        return C_SpellBook.IsSpellKnown(id)
    elseif IsPlayerSpell then
        return IsPlayerSpell(id)
    end
    return false
end
```

### Pattern 2: Event-Driven Talent Cache
**What:** Cache talent state as a boolean field on the Tip table. Refresh only on `PLAYER_TALENT_UPDATE` and `PLAYER_SPECIALIZATION_CHANGED` events (D-03). Do not call talent API on every cast.
**When to use:** Any spec/talent state that does not change during combat.

```lua
-- Tip table field (initialize in Initialize or as default):
Tip.hasTwinFangs = false

-- In OnEvent:
elseif event == "PLAYER_TALENT_UPDATE" or event == "TRAIT_CONFIG_UPDATED" then
    self.hasTwinFangs = HasTwinFangs()  -- refresh cache
    self:RefreshActive()
    self:Update()
    return
elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
    -- also refresh talent cache on spec change
    self.hasTwinFangs = HasTwinFangs()
    ...
```

### Pattern 3: Talent-Aware ApplySpell Routing
**What:** `ApplySpell` receives the kind string. For Kill Command ("generator"), use `hasTwinFangs` to determine grant amount (+3 vs +2). For Takedown ("consumer"), if `hasTwinFangs`, apply the grant-then-consume sequence (D-04 order).

Two valid structures for D-04 (Claude's discretion):

**Option A — separate Takedown classification:** Classify spell 1250646 as `"consumer_takedown"` instead of plain `"consumer"` when Twin Fangs context is needed. `ApplySpell` switches on the kind to apply special logic.

**Option B — talent-aware inside ApplySpell only:** Keep classification as-is (`"consumer"` for all consumers). Add a special-case check inside `ApplySpell`'s consumer branch: if `lastSpellID == 1250646 and self.hasTwinFangs`, do the grant-then-consume sequence. Requires passing the spell ID to `ApplySpell`, or detecting it via a separate field set before `ApplySpell` is called.

**Recommendation:** Option A is cleaner and more testable. `ClassifySpellID` returns `"consumer_takedown"` only when Twin Fangs is active AND the spell is Takedown. This keeps `ApplySpell` clean and each kind maps to one code path. It also allows the existing "consumer" tests to continue passing unchanged.

However, `ClassifySpellID` is a pure local function that currently has no access to `Tip.hasTwinFangs`. Options:
- Make `ClassifySpellID` a method on Tip: `Tip:ClassifySpellID(spellID)`
- Keep it a local but pass `hasTwinFangs` as a parameter

**Simpler alternative (recommended):** Keep `ClassifySpellID` as a pure static lookup returning `"generator"` or `"consumer"`. Add a `spellID` parameter to `ApplySpell` (or call site passes it through `FindTrackedSpell`) so the Takedown branch can be detected inside `ApplySpell` via an explicit `spellID == TAKEDOWN` check. This avoids spreading talent state into the classification function.

```lua
-- FindTrackedSpell already returns kind; extend to also return spellID:
local function FindTrackedSpell(...)
    for i = 1, select("#", ...) do
        local id = select(i, ...)
        local kind = ClassifySpellID(id)
        if kind then
            return kind, id   -- return both kind and the matching spell ID
        end
    end
end

-- ApplySpell extended signature:
function Tip:ApplySpell(kind, spellID)
    local now = GetTime()
    if kind == "generator" then
        local grant = self.hasTwinFangs and 3 or 2
        self.stacks = ClampStacks(self.stacks + grant)
        self.expiresAt = now + BUFF_DURATION
    elseif kind == "consumer" then
        if spellID == TAKEDOWN and self.hasTwinFangs then
            -- D-04: grant fires FIRST, then consume
            self.stacks = ClampStacks(self.stacks + 3)
            self.expiresAt = now + BUFF_DURATION
            self.stacks = ClampStacks(self.stacks - 1)
            -- expiresAt stays set (stacks are guaranteed >= 2 after clamp(x+3)-1 >= 2)
        else
            self.stacks = ClampStacks(self.stacks - 1)
            if self.stacks == 0 then
                self.expiresAt = 0
            end
        end
    else
        return
    end
    ...
end
```

### Pattern 4: BUG-01 One-Line Fix
**What:** Add `self.auraVerifyPending = false` before the early return at the serial-mismatch check in `ScheduleAuraVerify`.
**Current code (lines 430-439):**

```lua
C_Timer.After(requestedDelay, function()
    self.auraVerifyPending = false          -- already clears on normal path
    if self.inCombat and serial ~= self.castVerifySerial then
        return                              -- BUG: flag is NOT cleared here
    end
    ...
end)
```

**Fixed code:**

```lua
C_Timer.After(requestedDelay, function()
    self.auraVerifyPending = false          -- clears on ALL paths (must be first)
    if self.inCombat and serial ~= self.castVerifySerial then
        return
    end
    ...
end)
```

Wait — re-reading the current code: `self.auraVerifyPending = false` IS already on line 431, BEFORE the serial-mismatch check on line 432. The CONCERNS.md description says the flag is NOT cleared on the early return path. Let me reconcile:

The current code at lines 430-439 in the live file shows:
```lua
C_Timer.After(requestedDelay, function()
    self.auraVerifyPending = false      -- line 431
    if self.inCombat and serial ~= self.castVerifySerial then
        return                          -- line 433 — flag IS cleared before this return
    end
```

This means the BUG-01 fix may **already be present** in the current code. The `auraVerifyPending = false` at line 431 is unconditional and precedes the early return. This needs verification against the CONCERNS.md description (which says the flag is only cleared if the serial check does NOT trigger).

**Important note for planner:** The researcher read the actual live file and found `auraVerifyPending = false` at line 431 (before the serial check at line 432). This contradicts the CONCERNS.md bug description. The planner MUST verify whether BUG-01 is already fixed or whether the description refers to an earlier file state. The test must still be written to confirm the flag-cleared-on-mismatch-path behavior.

### Pattern 5: BUG-02 — Out-of-Combat SyncFromAura on Mode Switch
**What:** When a display mode switch occurs out of combat, `Tip.stacks` may be stale from a prior fight. Adding a `SyncFromAura()` call before `RefreshLayout` when out of combat ensures the display is accurate.

**Scope decision (D-07, Claude's discretion):**

Recommendation: Trigger `SyncFromAura` inside `RefreshTip` (Core.lua line 173) when `tip.inCombat == false`. This is unconditional (no check on current stack state) and covers all non-combat refresh paths: mode switch, size change, color change, border change — all call `RefreshTip`. This is simpler than a mode-change-only hook and avoids stale displays after any setting change.

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

**Test approach:** Set `Tip.stacks = 2` (stale from prior fight), `Tip.inCombat = false`, configure stubs to return nil aura, then call `DMX:RefreshTip()` and assert `Tip.stacks == 0`. Note: `RefreshTip` is a local function in Core.lua; the test must reach it via `DMX:RefreshTip()` public method or via slash command handler.

### Pattern 6: QUAL-03 Dead Block Removal
**What:** Remove Core.lua lines 98-106 (the three `if tip.barWidth/barHeight/spacing` checks that execute unconditionally after the migration gate). The migration gate (lines 77-96) already clears these fields and sets `settingsMigration`, making the post-gate block unreachable for any migrated DB.

**Verify removal is safe:** The existing `NormalizeDB` tests in `spec/core_spec.lua` include 4 tests for "deprecated field migration" — these tests pass deprecated field inputs to `NormalizeDB`. After removing lines 98-106, these tests SHOULD FAIL because the dead block was doing the mapping. This means either:
1. The tests test the migration gate path (where the block IS reachable on first migration), or
2. The tests test the always-runs path (which is the block being removed)

Re-reading TESTING.md: "**Deprecated field migration (always runs post-gate):** 4 tests for `barWidth→width`, `barHeight→height`, `spacing→borderSize`, respecting existing borderSize"

This means those 4 tests exercise the block being removed. After removal, those tests must be updated to confirm the fields are NOT mapped (because the migration gate already cleared them). The planner must budget for updating those 4 tests, not just adding new ones.

### Anti-Patterns to Avoid
- **Calling talent API per cast:** `C_SpellBook.IsSpellKnown` or `IsPlayerSpell` called inside `UNIT_SPELLCAST_SUCCEEDED` handler — expensive, unnecessary. Cache on `PLAYER_TALENT_UPDATE` only.
- **Blocking SyncFromAura in combat for BUG-02 fix:** The BUG-02 fix must be gated on `not inCombat`. Calling SyncFromAura during combat from RefreshTip would fight with the combat prediction system.
- **Wrong order for Twin Fangs:** `stacks - 1 + 3` is NOT the same as `clamp(stacks + 3) - 1` when at low stacks. The grant fires first (D-04).
- **Module reload to update hasTwinFangs stub:** Tests cannot swap the captured `C_SpellBook` local after module load. The stub must be set up before `loader.load()` is called, or the talent detection function must be structured to read from `_G` dynamically (not capture at load time).

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Talent detection | Custom spell ID list | `C_SpellBook.IsSpellKnown` / `IsPlayerSpell` | WoW provides this; list would need manual maintenance per patch |
| Timer scheduling | Manual polling with OnUpdate | `C_Timer.After` (already used) | Frame rate polling wastes CPU; C_Timer is the standard |
| Test isolation | Module-level globals between tests | `loader.load()` per `before_each` (already used) | Global state leaks cause false positives |

---

## Runtime State Inventory

> This is not a rename/refactor/migration phase. Skipped.

---

## Common Pitfalls

### Pitfall 1: hasTwinFangs capture timing
**What goes wrong:** If `HasTwinFangs()` is called at module-load time (top of TipOfTheSpear.lua) and captured as a module-level local, the initial talent state from before the player is fully loaded will be cached and never refreshed.
**Why it happens:** Module loads happen at addon init before `PLAYER_LOGIN` fires.
**How to avoid:** Initialize `Tip.hasTwinFangs = false` as a Tip table field default. Call `HasTwinFangs()` only from within `Initialize` (after `ADDON_LOADED`) and from the `PLAYER_TALENT_UPDATE` / `PLAYER_SPECIALIZATION_CHANGED` handlers.
**Warning signs:** Twin Fangs always reads as `false` even when the talent is talented.

### Pitfall 2: Test stubs for C_SpellBook.IsSpellKnown must be installed before module load
**What goes wrong:** `TipOfTheSpear.lua` may capture `C_SpellBook.IsSpellKnown` as a local at the top of the file (like it does for `C_UnitAuras.GetPlayerAuraBySpellID` at line 30). If so, `wow_stubs.lua` must install `_G.C_SpellBook = { IsSpellKnown = ... }` before `loader.load()` calls `loadAddon`. If the talent detection function reads `_G.C_SpellBook` at runtime (not captured at load), the stub can be set per-test.
**Why it happens:** Lua captures variable bindings at file parse time for module-level locals.
**How to avoid:** Check whether the implementation captures `C_SpellBook.IsSpellKnown` as a module-level local. If yes, install the stub in `stubs.install()`. If the function reads `_G.C_SpellBook` at call time, per-test override is possible.
**Warning signs:** `Tip.hasTwinFangs` is always `false` in tests even when stub is configured.

Recommendation: Do NOT capture `HasTwinFangs` or `C_SpellBook.IsSpellKnown` as a module-level local. Let `HasTwinFangs()` read `_G.C_SpellBook` and `_G.IsPlayerSpell` at call time. This keeps the stub pattern simple (set stub, call function, assert result) without module reload tricks.

### Pitfall 3: QUAL-03 — four existing "deprecated field" tests will break after removal
**What goes wrong:** The 4 tests for `barWidth→width`, `barHeight→height`, `spacing→borderSize` in `spec/core_spec.lua` exercise the block being deleted. After deletion they will fail because the mapping no longer happens.
**Why it happens:** The tests were written to document existing behavior, not to enforce the future state.
**How to avoid:** In the same plan as the QUAL-03 fix, update these 4 tests to confirm the deprecated fields are NOT mapped after migration gate has already cleared them. New test structure: provide a DB with `barWidth` set but `settingsMigration` already at the current value → confirm `width` is unchanged (field not mapped by dead block).
**Warning signs:** `busted` shows exactly 4 failures in `core_spec.lua` after the dead block is removed.

### Pitfall 4: BUG-02 SyncFromAura during initial addon load
**What goes wrong:** `RefreshTip` is called from `DMX:ResetTipStyle()` and from slash command handlers during `ADDON_LOADED`. If `SyncFromAura` is unconditionally called from `RefreshTip` before the aura API is ready, it may return stale data or throw.
**Why it happens:** `ReadLiveState` already guards against API absence (`if not GetPlayerAuraBySpellID then return nil, nil end`), so this is not a crash risk — but an unnecessary call.
**How to avoid:** Gate on `not tip.inCombat` only — correct. At addon load time, `tip.inCombat` is initialized from `InCombatLockdown()` (false by default in tests and most load scenarios), so the SyncFromAura call will happen, but it's safe because `ReadLiveState` handles API absence gracefully.

### Pitfall 5: BUG-01 may already be fixed in current file
**What goes wrong:** CONCERNS.md describes the bug as the flag not being cleared on the serial-mismatch early return. The live file (as read) shows `self.auraVerifyPending = false` on line 431, which is BEFORE the early return on line 433.
**Why it happens:** Documentation written at analysis time may not reflect edits made between analysis and Phase 3.
**How to avoid:** Planner must read the live `ScheduleAuraVerify` function before writing the fix task. If the flag is already cleared, the task becomes "add test for the serial-mismatch path" only (no code change needed).
**Warning signs:** The test passes without a code change.

### Pitfall 6: Twin Fangs order of operations
**What goes wrong:** `clamp(stacks - 1 + 3)` is NOT `clamp(stacks + 3) - 1`. Example: stacks = 0.
- Wrong order: clamp(-1 + 3) = clamp(2) = 2
- Correct order (D-04): clamp(0 + 3) - 1 = 3 - 1 = 2 (same in this case)
- Different case: stacks = 1, grant = 3, MAX = 3: correct = clamp(4) - 1 = 3 - 1 = 2; wrong = clamp(1 - 1 + 3) = clamp(3) = 3
**Why it happens:** Flipping grant/consume order gives different results when clamp truncates.
**How to avoid:** Always apply grant first (ClampStacks(stacks + 3)), then apply consume (-1, no second clamp needed since stacks >= 1 after grant).

---

## Code Examples

Verified patterns from reading live source files:

### BUG-01: ScheduleAuraVerify flag placement verification
```lua
-- Current live code (TipOfTheSpear.lua:428-439) — read from source:
self.auraVerifyPending = true
local serial = self.castVerifySerial
C_Timer.After(requestedDelay, function()
    self.auraVerifyPending = false          -- line 431: flag cleared BEFORE serial check
    if self.inCombat and serial ~= self.castVerifySerial then
        return                              -- early return on line 433
    end
    if self:SyncFromAura() then
        self:Update()
    end
end)
```
Flag IS cleared before early return in current code. BUG-01 fix may be a no-op code change; test extension is still required.

### BUG-03/BUG-04: ApplySpell with talent context
```lua
-- Source: researcher recommendation based on CONTEXT.md D-04 and current ApplySpell (line 675)
local TAKEDOWN = 1250646

function Tip:ApplySpell(kind, spellID)
    local now = GetTime()
    if kind == "generator" then
        local grant = self.hasTwinFangs and 3 or 2
        self.stacks = ClampStacks(self.stacks + grant)
        self.expiresAt = now + BUFF_DURATION
    elseif kind == "consumer" then
        if spellID == TAKEDOWN and self.hasTwinFangs then
            -- D-04: grant fires FIRST (+3 capped), then consume (-1)
            self.stacks = ClampStacks(self.stacks + 3)
            self.expiresAt = now + BUFF_DURATION
            self.stacks = self.stacks - 1  -- no clamp needed: stacks >= 1 after +3
            -- expiresAt preserved (stacks always >= 2 after this sequence from any start)
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

### QUAL-03: Dead block to remove (Core.lua lines 98-106)
```lua
-- REMOVE these lines:
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

### Wow stubs additions for talent detection
```lua
-- Add to stubs.install() in spec/support/wow_stubs.lua:
_G.C_SpellBook = {
    IsSpellKnown = function(spellID) return false end,  -- default: no talent
}
_G.IsPlayerSpell = function(spellID) return false end
```

### resetTipState extension for hasTwinFangs
```lua
-- Add to spec/support/init.lua resetTipState():
Tip.hasTwinFangs = false
```

---

## State of the Art

| Old Approach | Current Approach | Notes |
|--------------|-----------------|-------|
| `IsPlayerSpell(id)` | `C_SpellBook.IsSpellKnown(id)` | Deprecated in 11.2.0; both available on 12.0.5 [ASSUMED per CONTEXT.md D-05] |
| `pairs()` ForEachModule | `ipairs(moduleOrder)` | Phase 1 delivered ordered iteration |
| pcall in ClassifySpellID | Direct return (pure lookup) | Phase 1 removed the pcall |
| Module-level frame locals | `Tip.root`, `Tip.pips`, etc. | Phase 1 moved all frame refs to Tip table |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `C_SpellBook.IsSpellKnown` and `IsPlayerSpell` are both available on Interface 120005 (12.0.5) | Standard Stack, Pattern 1 | Talent detection would fail silently; fallback chain still provides `false` so no crash |
| A2 | Twin Fangs spell ID is 1272139 | Standard Stack | Wrong ID means talent always reads as absent; no crash, just wrong prediction |
| A3 | BUG-01 may already be fixed in live code (flag cleared before early return) | Pattern 4, Pitfall 5 | If not already fixed, the one-line fix is correct as described in CONTEXT.md D-06 |
| A4 | The 4 existing "deprecated field" tests in core_spec.lua test the block being removed | Pitfall 3 | If tests are on the migration gate path (not the dead block), they may continue passing; verify before updating tests |

---

## Open Questions (RESOLVED)

1. **Is BUG-01 already fixed in the live file?**
   - RESOLVED: Yes. Live code at line 431 places `self.auraVerifyPending = false` BEFORE the serial-mismatch early return at line 433. CONCERNS.md described an older file state. Plan 03-01 writes the regression test to confirm the fix is present — no code change needed.

2. **Does `FindTrackedSpell` need to return the spell ID for the Takedown branch?**
   - RESOLVED: Yes. Extend `FindTrackedSpell` to `return kind, id` (two return values). Call site in `OnEvent` becomes `local kind, spellID = FindTrackedSpell(...)`. Pass `spellID` to `ApplySpell`. Implemented in Plan 03-02 Task 1 step 5.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| busted | All tests | ✓ | 2.3.0 | — |
| Lua 5.1 (PUC-Rio) | All tests | ✓ | 5.1 | — |
| luacheck | Linting | ✓ | 1.2.0 | — |

All dependencies present. No missing dependencies. [VERIFIED: bash `busted --version`, `lua -v`, `luacheck --version`]

**Baseline test suite:** 89 passing / 0 failing / 1 pending before any Phase 3 changes. [VERIFIED: bash `busted` run]

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | busted 2.3.0 |
| Config file | `.busted` |
| Quick run command | `busted spec/tip_spec.lua` |
| Full suite command | `busted` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| BUG-01 | `auraVerifyPending` cleared on serial-mismatch exit | unit | `busted spec/tip_spec.lua` | ✅ (extend existing serial-mismatch describe block) |
| BUG-02 | Mode switch out of combat shows correct stack count | unit | `busted spec/tip_spec.lua` | ✅ (new describe block or extend SyncFromAura) |
| BUG-03 | Kill Command +2 without Twin Fangs, +3 with Twin Fangs | unit | `busted spec/tip_spec.lua` | ✅ (extend ApplySpell describe block) |
| BUG-04 | Takedown grants 3 stacks when Twin Fangs active (grant-then-consume) | unit | `busted spec/tip_spec.lua` | ✅ (implement pending test at tip_spec.lua:127) |
| QUAL-03 | NormalizeDB idempotent after dead block removal; deprecated fields not mapped post-migration | unit | `busted spec/core_spec.lua` | ✅ (update 4 existing deprecated-field tests) |

### Sampling Rate
- **Per task commit:** `busted spec/tip_spec.lua` or `busted spec/core_spec.lua` (relevant suite)
- **Per wave merge:** `busted` (full suite)
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
None — existing test infrastructure covers all phase requirements. No new spec files, no new conftest, no framework install needed.

---

## Security Domain

This phase does not introduce authentication, session management, access control, cryptographic operations, or user-facing input validation. No ASVS categories apply. Security enforcement is not relevant to this WoW addon bug-fix phase.

---

## Sources

### Primary (HIGH confidence)
- Live source file read: `Duncedmaxxing/Modules/TipOfTheSpear.lua` — ScheduleAuraVerify, ApplySpell, ClassifySpellID, OnEvent, CONSUMERS table
- Live source file read: `Duncedmaxxing/Core.lua` — NormalizeDB, RefreshTip, RegisterSlashCommands
- Live source file read: `spec/tip_spec.lua` — existing test coverage, pending BUG-04 marker
- Live source file read: `spec/support/wow_stubs.lua` — stub installation pattern, mockAura dispatch
- Live source file read: `spec/support/init.lua` — loader, resetTipState
- `.planning/phases/03-bug-fixes-with-test-coverage/03-CONTEXT.md` — all locked decisions (D-01 through D-09)
- `.planning/codebase/TESTING.md` — test infrastructure, coverage map, mock patterns
- `.planning/codebase/CONCERNS.md` — detailed bug descriptions with line numbers

### Secondary (MEDIUM confidence)
- `.planning/phases/01-utility-extraction-and-module-encapsulation/01-CONTEXT.md` — Phase 1 structural changes confirmed as shipped
- `.planning/REQUIREMENTS.md` — requirement IDs and acceptance criteria

### Tertiary (LOW confidence / ASSUMED)
- WoW API availability for `C_SpellBook.IsSpellKnown` and `IsPlayerSpell` on Interface 120005: taken from CONTEXT.md discussion references to warcraft.wiki.gg — not independently verified by researcher in this session [ASSUMED per A1, A2]

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — busted/Lua/luacheck all verified installed and running
- Architecture: HIGH — all patterns derived from reading live source files
- Pitfalls: HIGH — BUG-01 analysis, QUAL-03 test-update requirement, and talent stub timing are based on direct code inspection
- Talent API claims: ASSUMED — taken from prior research/discussion, not independently verified via warcraft.wiki.gg in this session

**Research date:** 2026-06-18
**Valid until:** 2026-07-18 (stable — WoW API surface, busted version, all unlikely to change within month)
