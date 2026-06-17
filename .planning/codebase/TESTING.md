# Testing Patterns

**Analysis Date:** 2026-06-17

## Test Framework

**Runner:** None — no automated test framework is present.

No `.spec.lua`, `_test.lua`, `busted`, `luaunit`, or equivalent test files exist anywhere in the repository.

**Run Commands:**
```bash
# No test commands available
```

## Testing Approach

This project uses **manual in-game testing** as its sole verification mechanism. The addon targets the WoW client runtime (Lua 5.1 embedded in the game), which makes standard Lua test frameworks (busted, luaunit) impractical without a WoW environment mock layer.

## Built-In Test/Preview Mode

The addon provides a built-in preview mechanism as a substitute for automated tests:

**`Tip:SetTestStacks(stacks)`** — `Duncedmaxxing/Modules/TipOfTheSpear.lua:557`

Sets `testMode = true` and overrides the displayed stack count for 8 seconds, then restores live state. This allows visual verification of all display modes and stack counts without triggering actual spells.

```lua
-- Invoked via slash commands:
-- /dmax test        → SetTestStacks(3)
-- /dmax 0-3         → SetTestStacks(n)
-- Options "Preview" button → SetTestStacks(3)
```

**Test mode characteristics:**
- Bypasses aura expiry timer logic
- Does not suppress aura up-sync guards (returns to live after 8 seconds)
- Tests all three display modes (bar, icons, number) by changing `cfg.displayMode` then previewing

## Manual Test Scenarios

The following behaviors require manual in-game verification:

**Stack tracking:**
- Cast Kill Command — expect stacks +2, capped at 3
- Cast a consumer (Wildfire Bomb, Raptor Strike, etc.) — expect stacks -1
- Wait 10 seconds after last Kill Command — expect stacks drop to 0
- Rapidly cast consumer after Kill Command — verify aura up-sync suppression holds for `CONSUMER_UPSYNC_GRACE` (2.75s) window

**Visibility rules:**
- Combat-only mode: tracker hidden out of combat, shown on `PLAYER_REGEN_DISABLED`
- Hide-when-empty: tracker hides at 0 stacks, shows when stacks > 0
- Unlocked: tracker always visible regardless of stacks or combat state

**API fallback paths:**
- `C_UnitAuras.GetPlayerAuraBySpellID` missing → `ReadLiveState` returns `nil, nil` gracefully
- `C_Spell.GetSpellTexture` missing → falls back to `_G.GetSpellTexture`, then `FALLBACK_ICON`
- `C_SpecializationInfo` missing → falls back to global `GetSpecialization`

**Settings persistence:**
- Settings saved to `DuncedmaxxingDB` (WoW SavedVariables)
- Migration on load: `SETTINGS_MIGRATION = "0.3.2-fontfix"` resets style settings while preserving position/scale

## Coverage Gaps

**All logic paths are untested automatically.** Specific high-risk areas:

**`ReadLiveState()` — `Duncedmaxxing/Modules/TipOfTheSpear.lua:81`**
- What's not tested: All three pcall branches (API missing, pcall throws, valid aura)
- Risk: Silent return of nil could mask stale display state

**`MergeDefaults` / `NormalizeDB` — `Duncedmaxxing/Core.lua:84, 101`**
- What's not tested: Settings migration path (`settingsMigration` mismatch branch)
- Risk: A bad migration could corrupt saved settings across sessions

**`ParseHexColor` — `Duncedmaxxing/Core.lua:59`, `Duncedmaxxing/Options.lua:25`**
- What's not tested: Edge cases (5-char hex, empty string, unicode input)
- Risk: Invalid color input silently returns nil and leaves previous color unchanged

**Consumer up-sync suppression — `Tip:SyncFromAura()` line 338-341**
- What's not tested: The timing window (`CONSUMER_UPSYNC_GRACE = 2.75`) boundary
- Risk: Suppression fires too early or too late, causing display flicker

**`ClassifySpellID` pcall — `Duncedmaxxing/Modules/TipOfTheSpear.lua:56`**
- What's not tested: The pcall wrapper path (what could throw here is unclear)
- Risk: pcall overhead is unnecessary if the inner code cannot actually throw

## Adding Automated Tests

If automated testing were introduced, the recommended approach for a WoW addon of this type:

1. Use **busted** (Lua test framework) with a WoW API stub layer
2. Stub the minimal WoW globals: `CreateFrame`, `C_UnitAuras`, `C_Timer`, `GetTime`, `InCombatLockdown`, `UnitClass`, `GetSpecialization`
3. Pure logic functions (`Clamp`, `ParseHexColor`, `MergeDefaults`, `CopyDefaults`, `NormalizeDB`, `ClampStacks`, `ColorTuple`) are already fully isolated and could be unit tested without WoW stubs
4. Tracking logic in `Tip:ApplySpell`, `Tip:SyncFromAura`, `Tip:ScheduleExpiration` would need `C_Timer` and `GetTime` stubs

**No test infrastructure exists today.** Priority for adding tests: pure utility functions first (zero stubs needed), then tracking logic (timer stubs needed), then UI/frame code (full WoW frame mock needed, high cost).

---

*Testing analysis: 2026-06-17*
