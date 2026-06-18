# External Integrations

**Analysis Date:** 2026-06-18

## APIs & External Services

**World of Warcraft Game API (Blizzard):**
- All runtime integration is with the WoW client's built-in Lua API — no HTTP calls, no third-party web services
- Full API inventory is maintained in `API_REFERENCES.md`

Key API namespaces used:

- `C_UnitAuras` — aura data for the local player
  - `C_UnitAuras.GetPlayerAuraBySpellID(spellID)` — reads Tip of the Spear aura (`260286`) for delayed verification; `Duncedmaxxing/Modules/TipOfTheSpear.lua:30`
- `C_SpecializationInfo` — spec detection
  - `C_SpecializationInfo.GetSpecialization()` — returns current spec index; `Duncedmaxxing/Core.lua:183`
- `C_Spell` — spell texture lookups
  - `C_Spell.GetSpellTexture(spellID)` — resolves the Tip of the Spear icon for icon display mode; `Duncedmaxxing/Modules/TipOfTheSpear.lua:135`
- `C_Timer` — deferred execution
  - `C_Timer.After(seconds, fn)` — aura verification delays; `Duncedmaxxing/Modules/TipOfTheSpear.lua:413`
  - `C_Timer.NewTimer(seconds, fn)` — cancellable buff expiry timer; `Duncedmaxxing/Modules/TipOfTheSpear.lua:377`

**WoW Widget API (Blizzard Frame/Texture/FontString system):**
- All UI is built from first-party WoW frame widgets — `CreateFrame`, `CreateTexture`, `CreateFontString`
- Templates used: `UIPanelButtonTemplate`, `UICheckButtonTemplate`, `InputBoxTemplate`
- No external UI library (LibSharedMedia, Ace, etc.)

## Data Storage

**Databases:**
- None — no external database

**SavedVariables (WoW-native persistence):**
- Variable: `DuncedmaxxingDB` (declared in `Duncedmaxxing/Duncedmaxxing.toc`, line 7)
- Written to disk by the WoW client on logout/reload to `WTF/Account/.../SavedVariables/Duncedmaxxing.lua`
- Initialized with defaults in `Duncedmaxxing/Core.lua:MergeDefaults` / `NormalizeDB`
- Schema versioned via `SETTINGS_MIGRATION = "0.3.2-fontfix"` in `Duncedmaxxing/Core.lua:9`; a migration wipe resets all style keys while preserving position/scale

**File Storage:**
- `Duncedmaxxing/Media/duncedgers_pony.png` — addon icon bundled with the addon; referenced in `Duncedmaxxing/Duncedmaxxing.toc:8`
- No other file I/O; WoW's sandbox does not permit arbitrary filesystem access

**Caching:**
- None — no external cache layer
- In-memory state only (`Tip.stacks`, `Tip.expiresAt`, etc. in `Duncedmaxxing/Modules/TipOfTheSpear.lua`)

## Authentication & Identity

**Auth Provider:**
- Not applicable — the addon runs inside an already-authenticated WoW session; no addon-level authentication exists

## Monitoring & Observability

**Error Tracking:**
- None — no error tracking service
- Runtime errors surface as WoW in-game Lua error popups
- `pcall` is used defensively around aura reads in `Duncedmaxxing/Modules/TipOfTheSpear.lua:86` and `Duncedmaxxing/Modules/TipOfTheSpear.lua:95` to silently suppress API failures

**Logs:**
- `DEFAULT_CHAT_FRAME:AddMessage(...)` — used by `DMX:Print()` in `Duncedmaxxing/Core.lua:167` to write colored messages to the default chat frame
- No file logging; WoW sandbox does not allow it

## CI/CD & Deployment

**Hosting:**
- No hosting — distributed as a directory of files installed manually into the WoW `Interface/AddOns/` folder
- No package repository (CurseForge, Wago, etc.) detected in current codebase

**CI Pipeline:**
- None detected

## Environment Configuration

**Required env vars:**
- None — there are no environment variables; all configuration lives in WoW SavedVariables

**Secrets location:**
- Not applicable — no API keys, tokens, or secrets are used

## Webhooks & Callbacks

**Incoming:**
- Not applicable — no HTTP server

**Outgoing:**
- Not applicable — no HTTP calls

## WoW Events Subscribed

The addon reacts to the following WoW client events (no external message bus):

| Event | Handler location | Purpose |
|-------|-----------------|---------|
| `ADDON_LOADED` | `Duncedmaxxing/Core.lua:357` | Initialize DB, slash commands, and modules |
| `PLAYER_LOGIN` | `Duncedmaxxing/Modules/TipOfTheSpear.lua:756` | Sync aura state on login |
| `PLAYER_ENTERING_WORLD` | `Duncedmaxxing/Modules/TipOfTheSpear.lua:757` | Sync aura state on zone change |
| `PLAYER_REGEN_DISABLED` | `Duncedmaxxing/Modules/TipOfTheSpear.lua:758` | Set `inCombat = true`, update display |
| `PLAYER_REGEN_ENABLED` | `Duncedmaxxing/Modules/TipOfTheSpear.lua:759` | Set `inCombat = false`, sync aura |
| `PLAYER_SPECIALIZATION_CHANGED` | `Duncedmaxxing/Modules/TipOfTheSpear.lua:760` | Reset stacks, re-check active spec |
| `PLAYER_TALENT_UPDATE` | `Duncedmaxxing/Modules/TipOfTheSpear.lua:761` | Re-check active spec |
| `TRAIT_CONFIG_UPDATED` | `Duncedmaxxing/Modules/TipOfTheSpear.lua:762` | Re-check active spec |
| `UNIT_AURA` (player) | `Duncedmaxxing/Modules/TipOfTheSpear.lua:763` | Schedule delayed aura verification |
| `UNIT_SPELLCAST_SUCCEEDED` (player) | `Duncedmaxxing/Modules/TipOfTheSpear.lua:764` | Predict stack change immediately |
| `PLAYER_REGEN_DISABLED` | `Duncedmaxxing/Options.lua:451` | Auto-close settings window on combat start |

## Test Infrastructure (Development)

**Busted Test Runner:**
- Configuration: `.busted` — pattern `_spec`, utfTerminal output, no early-stop on failure
- Test discovery: Scans `spec/` directory for `*_spec.lua` files
- Execution: `busted` command runs all tests with full per-test isolation

**Mock Layer (spec/support/):**
- `spec/support/wow_stubs.lua` — Comprehensive WoW API mocking layer:
  - Mock clock: `mockClock` with `advance(dt)` for timer simulation; used by `C_Timer.After` and `C_Timer.NewTimer` stubs
  - Mock aura: `mockAura.impl` function (swappable per-test) that feeds into captured `C_UnitAuras.GetPlayerAuraBySpellID`
  - Frame stubs: `noopFrame()` minimal state with `_visible`, `_text`, `_scripts` tracking for assertions
  - Full `Struct_AuraData` builder: `makeAuraData(overrides)` for precise aura contract testing
  - API stubs: `C_Timer`, `C_UnitAuras`, `C_SpecializationInfo`, `C_Spell`, `CreateFrame`, `UIParent`, etc.

- `spec/support/init.lua` — Test loader with full addon isolation:
  - `load()` function: Fresh namespace per-test, loads addon files in TOC order via `loadfile()` with vararg injection, replicates `ADDON_LOADED` bootstrap
  - `resetTipState(Tip, clock)` function: Zeros `Tip.stacks`, `Tip.expiresAt`, `Tip.lastPredictAt`, `Tip.castVerifySerial`, `Tip.expireTimer`, `Tip.auraVerifyPending` and resets clock

**Test Files:**
- `spec/util_spec.lua` — Unit tests for `DMX.Util` functions: `Clamp`, `ParseHexColor`, `ParseOnOff`, `Trim`
- `spec/core_spec.lua` — Unit tests for `Core.lua` pure-logic: `MergeDefaults` (via `DMX._test`), `NormalizeDB` (via `DMX._test`), settings migration
- `spec/tip_spec.lua` — Unit tests for `TipOfTheSpear.lua` pure-logic: `Tip:ApplySpell`, `Tip:SyncFromAura`, `Tip:ScheduleExpiration`, `Tip:ScheduleCastVerify`

**Luacheck Static Analyzer:**
- Configuration: `.luacheckrc` — targets Lua 5.1, defines writeable globals (SavedVariable, slash commands), read-only WoW API globals
- Addon globals defined: `DuncedmaxxingDB`, `SLASH_DUNCEDMAXXING1`, `SLASH_DUNCEDMAXXING2`, `Duncedmaxxing`, `SlashCmdList`
- WoW API read-globals: `CreateFrame`, `UIParent`, `C_UnitAuras`, `C_Timer`, `C_SpecializationInfo`, `C_Spell`, `GetSpecialization`, `GetSpellTexture`, `InCombatLockdown`, `UnitClass`, `GetTime`, `DEFAULT_CHAT_FRAME`
- Test exclusion: `spec/**/*.lua` excluded (tests use busted globals not part of addon)
- Line-length limit: Disabled (addon UI code naturally has long lines)
- Ignore rule W432: Shadowing upvalue arguments (WoW SetScript closures intentionally shadow `self`)

---

*Integration audit: 2026-06-18*
