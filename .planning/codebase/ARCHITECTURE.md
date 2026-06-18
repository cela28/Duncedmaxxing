<!-- refreshed: 2026-06-18 -->
# Architecture

**Analysis Date:** 2026-06-18

## System Overview

```text
┌─────────────────────────────────────────────────────────────┐
│                  WoW Addon Load Sequence                     │
│  `Duncedmaxxing/Duncedmaxxing.toc` — declares load order     │
└───────────────┬────────────────────────────┬────────────────┘
                │                            │
                ▼                            ▼
┌──────────────────────┐      ┌──────────────────────────────┐
│     Util.lua         │      │     Core.lua                  │
│  Utility functions   │      │  Addon namespace              │
│  (Clamp, Parse*)     │      │  Module registry              │
└──────────────┬───────┘      │  DB init & migration          │
               │               │  Slash commands               │
               │               │  `_G.Duncedmaxxing`           │
               │               └──────────────┬────────────────┘
               │                              │
               │                              │ DMX:RegisterModule
               │                              ▼
               │              ┌──────────────────────────────┐
               │              │     Options.lua               │
               │              │  Settings UI (popup window)   │
               │              │  `DMX.Options`                │
               │              └──────────────┬───────────────┘
               │                             │
               │                             │ calls DMX API
               │                             │
               │                             ▼
               └──────────────┬──────────────────────────────┐
                              │                              │
                              ▼                              │
┌──────────────────────────────────────────────────────────────┐
│              Duncedmaxxing/Modules/TipOfTheSpear.lua          │
│  Stack tracking + WoW frame rendering                        │
│  `Tip` table, registered as module "tip"                     │
└──────────────────────────────────────────────────────────────┘
         │ reads/writes
         ▼
┌──────────────────────────────────────────────────────────────┐
│  `DuncedmaxxingDB` (SavedVariables — WoW persistent storage) │
│  Keyed under `db.tip` for all tracker and display settings   │
└──────────────────────────────────────────────────────────────┘
```

**Test Infrastructure (offline, `busted`):**
```text
                  Test Runner: busted
                       │
                       ▼
        ┌────────────────────────────────┐
        │  .busted (configuration)       │
        │  .luacheckrc (linting config)  │
        └────────────────────────────────┘
                       │
                       ▼
        ┌────────────────────────────────┐
        │  spec/support/                 │
        │  - init.lua (loader)           │
        │  - wow_stubs.lua (mocks)       │
        └────────────────────────────────┘
                       │
         ┌─────────────┼─────────────┐
         ▼             ▼             ▼
    core_spec.lua  util_spec.lua  tip_spec.lua
    (DB, settings) (validators)   (tracking)
```

## Component Responsibilities

| Component | Responsibility | File |
|-----------|----------------|------|
| Util | String/color parsing, numeric clamping helpers | `Duncedmaxxing/Util.lua` |
| Core | Addon namespace `DMX`, module registry, DB init, settings migration, slash commands, spec-detection helpers | `Duncedmaxxing/Core.lua` |
| Options | Movable settings popup UI, all input widgets, combat guard | `Duncedmaxxing/Options.lua` |
| TipOfTheSpear | Stack state machine, predictive tracking, aura verification, WoW frame construction and rendering | `Duncedmaxxing/Modules/TipOfTheSpear.lua` |
| Test Loader | Load addon files with WoW vararg injection for offline testing | `spec/support/init.lua` |
| WoW Mocks | Mock implementations of WoW API globals (timers, auras, frames, etc.) | `spec/support/wow_stubs.lua` |
| SavedVariables | Persistent user settings via WoW's `DuncedmaxxingDB` global | WoW engine |

## Pattern Overview

**Overall:** Event-driven module system with a shared namespace table (`DMX`)

**Key Characteristics:**
- All files share the addon-private namespace table via the `local addonName, DMX = ...` WoW vararg idiom
- `Duncedmaxxing/Core.lua` initializes the namespace and is the sole owner of `DuncedmaxxingDB`
- Modules self-register via `DMX:RegisterModule(key, table)` after load
- No external library dependencies — pure Lua + WoW API
- Test harness uses `loadfile()` to inject WoW varargs and full WoW API mock layer for offline validation

## Layers

**Util Layer:**
- Purpose: Shared validation and parsing helpers for the rest of the codebase
- Location: `Duncedmaxxing/Util.lua`
- Contains: `Clamp`, `Trim`, `ParseOnOff`, `ParseHexColor` functions exposed via `DMX.Util` namespace
- Depends on: Lua standard library only (`string`, `tonumber`)
- Used by: `Duncedmaxxing/Core.lua`, `Duncedmaxxing/Options.lua` (both call `DMX.Util.*`)
- Tested by: `spec/util_spec.lua` (all functions fully unit-tested)

**Core / Bootstrap Layer:**
- Purpose: Owns addon identity, saved-variable DB, settings migration, module dispatch, and slash commands
- Location: `Duncedmaxxing/Core.lua`
- Contains: `DEFAULTS` table, `MergeDefaults`/`NormalizeDB` helpers, module registry methods, spec-detection helpers, `ADDON_LOADED` handler, `DMX._test` escape hatch
- Depends on: WoW globals (`CreateFrame`, `UnitClass`, `C_SpecializationInfo`, `SlashCmdList`), `Duncedmaxxing/Util.lua`
- Used by: `Duncedmaxxing/Options.lua`, `Duncedmaxxing/Modules/TipOfTheSpear.lua`
- Tested by: `spec/core_spec.lua` (DB migration, defaults merging via `DMX._test` escape hatch)

**Options Layer:**
- Purpose: Provides a movable in-game configuration popup; reads and writes `db.tip` through `DMX:GetDB()`
- Location: `Duncedmaxxing/Options.lua`
- Contains: `DMX.Options` table with `BuildWindow`, `Refresh`, `Open`, `Initialize` methods, all widget factory functions
- Depends on: `Duncedmaxxing/Core.lua` (via `DMX`), `Duncedmaxxing/Util.lua` (validators), WoW frame API (`CreateFrame`, `UIParent`, templates)
- Used by: Slash command handler in `Duncedmaxxing/Core.lua` calls `DMX:OpenOptions()`
- Tested by: Integration testing only (no unit tests; UI code is complex to mock)

**Module / Feature Layer:**
- Purpose: All gameplay logic and rendering for a specific tracking feature
- Location: `Duncedmaxxing/Modules/TipOfTheSpear.lua`
- Contains: Stack state machine, predictive spellcast handling, aura verification with timers, full WoW frame tree construction
- Depends on: `Duncedmaxxing/Core.lua` (via `DMX`), WoW API (`C_UnitAuras`, `C_Timer`, `C_Spell`, frame events)
- Used by: `Duncedmaxxing/Core.lua` calls `DMX:ForEachModule("Initialize", DMX)` on `ADDON_LOADED`
- Tested by: `spec/tip_spec.lua` (pure-logic methods `ApplySpell`, `SyncFromAura`, timer scheduling with mock clock)

## Data Flow

### Addon Initialization

1. WoW loads files in TOC order: `Util.lua` → `Core.lua` → `Options.lua` → `Modules/TipOfTheSpear.lua` (`Duncedmaxxing/Duncedmaxxing.toc` lines 10–13)
2. Each file captures the shared namespace via `local _, DMX = ...`
3. `Util.lua` exports validators via `DMX.Util` table
4. `Core.lua` initializes `DMX` namespace with defaults, module registry, slash handlers, and `DMX._test` escape hatch for testing
5. `TipOfTheSpear.lua` self-registers: `DMX:RegisterModule("tip", Tip)` (`Duncedmaxxing/Modules/TipOfTheSpear.lua:770`)
6. `ADDON_LOADED` fires → `Core.lua` merges defaults into `DuncedmaxxingDB`, runs `NormalizeDB`, assigns `DMX.db`, calls `DMX:InitializeOptions()` then `DMX:ForEachModule("Initialize", DMX)` (`Duncedmaxxing/Core.lua:358–374`)
7. `Tip:Initialize` builds the WoW frame tree and registers all game events (`Duncedmaxxing/Modules/TipOfTheSpear.lua:743–768`)

### In-Combat Stack Tracking

1. `UNIT_SPELLCAST_SUCCEEDED` fires for the player (`Duncedmaxxing/Modules/TipOfTheSpear.lua:728`)
2. `FindTrackedSpell` classifies the spell ID as `"generator"` (Kill Command) or `"consumer"` (`Duncedmaxxing/Modules/TipOfTheSpear.lua:72–79`)
3. `Tip:ApplySpell` immediately updates `self.stacks` and `self.expiresAt`, schedules an expiry timer, calls `Tip:Update`, then schedules a delayed `SyncFromAura` sanity check (`Duncedmaxxing/Modules/TipOfTheSpear.lua:675–695`)
4. `UNIT_AURA` fires → `Tip:ScheduleAuraVerify` defers a short-delay aura read to avoid lag artifacts (`Duncedmaxxing/Modules/TipOfTheSpear.lua:725–727`)
5. `Tip:SyncFromAura` calls `C_UnitAuras.GetPlayerAuraBySpellID(260286)` and reconciles live aura state, with a consumer-upsync suppression window (`Duncedmaxxing/Modules/TipOfTheSpear.lua:332–357`)

### Settings Change Path

1. Player interacts with `Options` window or issues a `/dmax` command
2. Handler reads `DMX:GetDB().tip` directly and writes updated values
3. `DMX:RefreshTip()` → `Tip:RefreshLayout()` → rebuilds frame geometry and calls `Tip:Update()` (`Duncedmaxxing/Core.lua:206–208`, `Duncedmaxxing/Modules/TipOfTheSpear.lua:451–538`)

**State Management:**
- All persistent state lives in `DuncedmaxxingDB` (WoW SavedVariables global), accessed via `DMX:GetDB()`
- Runtime stack state (`Tip.stacks`, `Tip.expiresAt`, `Tip.inCombat`, etc.) lives as fields on the `Tip` module table

### Test Initialization Flow

1. Test calls `loader.load()` from `spec/support/init.lua`
2. Loader installs WoW API mocks via `stubs.install(DMX)` from `spec/support/wow_stubs.lua`
3. Loader calls `loadfile()` (not `dofile()`) to inject WoW varargs `(addonName, DMX)` into each source file
4. Files load in addon order: `Util.lua` → `Core.lua` → `TipOfTheSpear.lua` (Options.lua skipped in tests)
5. Loader manually simulates `ADDON_LOADED` bootstrap: merges defaults, runs `NormalizeDB`, calls `DMX:ForEachModule("Initialize", DMX)`
6. Test receives `DMX`, `Tip` module reference, and `mockClock` for timer-based assertions
7. Each test calls `loader.resetTipState(Tip, clock)` in `before_each()` for full isolation

## Key Abstractions

**DMX Namespace Table:**
- Purpose: Shared addon object — acts as both the module registry and the public API surface
- Examples: `Duncedmaxxing/Core.lua:3` (`_G.Duncedmaxxing = DMX`), all files (`local _, DMX = ...`)
- Pattern: WoW addon private namespace passed via vararg; methods added with `function DMX:Method()`
- Test escape hatch: `DMX._test` exposes `SETTINGS_MIGRATION`, `MergeDefaults`, `NormalizeDB` for offline validation

**Module Table Pattern:**
- Purpose: Each feature is a self-contained Lua table with `Initialize`, `Update`, and lifecycle methods
- Examples: `Tip` in `Duncedmaxxing/Modules/TipOfTheSpear.lua:3`, `Options` in `Duncedmaxxing/Options.lua:3`
- Pattern: `local Foo = {}` → attach methods → `DMX:RegisterModule("key", Foo)` or assign to `DMX.Foo`

**DEFAULTS / GetCfg Pattern:**
- Purpose: Centralized default values in `Duncedmaxxing/Core.lua:11–34`; every subsystem reads live config via a local `GetCfg()` that calls `DMX:GetDB().tip`
- Examples: `Duncedmaxxing/Core.lua:11`, `Duncedmaxxing/Options.lua:58–61`, `Duncedmaxxing/Modules/TipOfTheSpear.lua:120–122`
- Pattern: Defaults merged once on load via `MergeDefaults`; no runtime fallback logic needed in modules

**Mock Clock Pattern (Testing):**
- Purpose: Controllable time source for deterministic timer-based testing without real delays
- Location: `spec/support/wow_stubs.lua:6–46` (MockClock implementation)
- Pattern: Tests call `clock:advance(seconds)` to move time forward; all scheduled callbacks auto-fire when `fireAt <= now`
- Used by: `spec/tip_spec.lua` to test expiry timers and aura-verify delays without blocking

## Entry Points

**ADDON_LOADED event:**
- Location: `Duncedmaxxing/Core.lua:356–374`
- Triggers: WoW fires `ADDON_LOADED` after all TOC files are parsed and loaded
- Responsibilities: DB initialization, settings migration, options initialization, module dispatch

**DMX:RegisterModule:**
- Location: `Duncedmaxxing/Core.lua:140–147`
- Triggers: Called at file parse time (bottom of each module file, outside any function)
- Responsibilities: Stores module reference; calls `Initialize` immediately if addon is already `ready`

**SlashCmdList.DUNCEDMAXXING:**
- Location: `Duncedmaxxing/Core.lua:226–353`
- Triggers: Player types `/dmax` or `/duncedmaxxing`
- Responsibilities: Parses command string, directly mutates `db.tip`, calls `RefreshTip` or module methods

**Test Entry Point (spec/support/init.lua):**
- Location: `spec/support/init.lua:19–46` (`load()` function)
- Triggers: Each test suite calls `loader.load()` in its `before_each()` block
- Responsibilities: Installs WoW mocks, loads addon files with vararg injection, simulates ADDON_LOADED bootstrap, returns DMX/Tip/clock for assertion use

## Architectural Constraints

- **Threading:** Single-threaded Lua coroutine model (WoW standard). No worker threads. `C_Timer.After` and `C_Timer.NewTimer` are the only async primitives used. Tests use mock clock for deterministic timer testing.
- **Global state:** `DuncedmaxxingDB` is a WoW SavedVariables global. `_G.Duncedmaxxing = DMX` exposes the namespace globally. `Tip` module uses module-level locals for frame references (`root`, `pips`, `borders`, `label`, `numberText`). Tests isolate global state by resetting `_G.DuncedmaxxingDB` and installing fresh stubs per test.
- **Circular imports:** Not applicable — WoW addons do not use `require`; files share a namespace table and load sequentially per TOC order. Tests use standard Lua `require()` for test infrastructure only (support modules, not addon code).
- **Combat protection:** Options window and all settings mutations are blocked during `InCombatLockdown()`. The tracking path (event handlers, `Tip:Update`) is explicitly kept off the combat-restricted path.
- **API compatibility:** Dual-path API calls for `GetSpecialization` / `C_SpecializationInfo` and `GetSpellTexture` / `C_Spell.GetSpellTexture` to handle WoW API surface changes across patches.
- **Test isolation (D-06):** Each test calls `loader.load()` in `before_each()`, reloading all addon source files fresh. This prevents test pollution from timer-state, stack-state, and DB-state mutations. Clock is reset to `now = 100` (non-zero to avoid grace-period collision pitfalls).

## Anti-Patterns

### Direct db.tip mutation in slash command handler

**What happens:** `Duncedmaxxing/Core.lua`'s slash command handler directly writes fields like `db.tip.scale = scale` instead of routing through a setter on the module or options object.
**Why it's wrong:** The same mutation logic is partially duplicated between the slash handler and `Duncedmaxxing/Options.lua`; future fields need to be updated in both places.
**Do this instead:** Add a thin setter method on `DMX` or `Options` (e.g., `DMX:SetTipConfig(key, value)`) and call it from both paths.

### Module-level frame locals in TipOfTheSpear

**What happens:** `root`, `pips`, `borders`, `label`, `numberText` are declared as module-level upvalue locals in `Duncedmaxxing/Modules/TipOfTheSpear.lua:32–36`, not as fields on the `Tip` table.
**Why it's wrong:** Makes it impossible to fully reset or replace the frame from outside without reimplementing the locals; breaks the encapsulation of the `Tip` module table.
**Do this instead:** Store all frame references as `Tip.root`, `Tip.pips`, etc., consistent with how `Tip.stacks`, `Tip.expiresAt`, etc. are stored.

## Error Handling

**Strategy:** Defensive `pcall` wrapping around WoW API calls that could fail silently on API version mismatches.

**Patterns:**
- `ReadLiveState` wraps both `GetPlayerAuraBySpellID` and field access in `pcall` to avoid nil-indexing crashes on unexpected aura shapes (`Duncedmaxxing/Modules/TipOfTheSpear.lua:86–117`)
- `ClassifySpellID` wraps the lookup in `pcall` (`Duncedmaxxing/Modules/TipOfTheSpear.lua:57–69`)
- `Options:CanChange()` gate prevents all settings changes in combat (`Duncedmaxxing/Options.lua:161–168`)
- Nil-guard checks before every frame method call (e.g., `if tip and tip.RefreshLayout then`)
- Tests use `stubs.mockAura.impl` to inject error-path testing (e.g., simulated API failures in `spec/tip_spec.lua:143–159`)

## Cross-Cutting Concerns

**Logging:** `DMX:Print(message)` writes prefixed messages to `DEFAULT_CHAT_FRAME`. Used for user-facing feedback only; no debug logging infrastructure. (`Duncedmaxxing/Core.lua:166–170`)
**Validation:** Input parsing helpers (`Clamp`, `ParseOnOff`, `ParseHexColor`, `Trim`) defined in `Duncedmaxxing/Util.lua` and exposed via `DMX.Util` for consistent validation across `Core`, `Options`, and test suites.
**Authentication:** Not applicable (WoW addon context; no network auth).

---

*Architecture analysis: 2026-06-18*
