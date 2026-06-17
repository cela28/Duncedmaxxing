# External Integrations

**Analysis Date:** 2026-06-17

## APIs & External Services

**World of Warcraft Game API (Blizzard):**
- All runtime integration is with the WoW client's built-in Lua API — no HTTP calls, no third-party web services
- Full API inventory is maintained in `API_REFERENCES.md`

Key API namespaces used:

- `C_UnitAuras` — aura data for the local player
  - `C_UnitAuras.GetPlayerAuraBySpellID(spellID)` — reads Tip of the Spear aura (`260286`) for delayed verification; `Modules/TipOfTheSpear.lua:30`
- `C_SpecializationInfo` — spec detection
  - `C_SpecializationInfo.GetSpecialization()` — returns current spec index; `Core.lua:183`
- `C_Spell` — spell texture lookups
  - `C_Spell.GetSpellTexture(spellID)` — resolves the Tip of the Spear icon for icon display mode; `Modules/TipOfTheSpear.lua:135`
- `C_Timer` — deferred execution
  - `C_Timer.After(seconds, fn)` — aura verification delays; `Modules/TipOfTheSpear.lua:413`
  - `C_Timer.NewTimer(seconds, fn)` — cancellable buff expiry timer; `Modules/TipOfTheSpear.lua:377`

**WoW Widget API (Blizzard Frame/Texture/FontString system):**
- All UI is built from first-party WoW frame widgets — `CreateFrame`, `CreateTexture`, `CreateFontString`
- Templates used: `UIPanelButtonTemplate`, `UICheckButtonTemplate`, `InputBoxTemplate`
- No external UI library (LibSharedMedia, Ace, etc.)

## Data Storage

**Databases:**
- None — no external database

**SavedVariables (WoW-native persistence):**
- Variable: `DuncedmaxxingDB` (declared in `Duncedmaxxing.toc`, line 7)
- Written to disk by the WoW client on logout/reload to `WTF/Account/.../SavedVariables/Duncedmaxxing.lua`
- Initialized with defaults in `Core.lua:MergeDefaults` / `NormalizeDB`
- Schema versioned via `SETTINGS_MIGRATION = "0.3.2-fontfix"` in `Core.lua:9`; a migration wipe resets all style keys while preserving position/scale

**File Storage:**
- `Media/duncedgers_pony.png` — addon icon bundled with the addon; referenced in `Duncedmaxxing.toc:8`
- No other file I/O; WoW's sandbox does not permit arbitrary filesystem access

**Caching:**
- None — no external cache layer
- In-memory state only (`Tip.stacks`, `Tip.expiresAt`, etc. in `Modules/TipOfTheSpear.lua`)

## Authentication & Identity

**Auth Provider:**
- Not applicable — the addon runs inside an already-authenticated WoW session; no addon-level authentication exists

## Monitoring & Observability

**Error Tracking:**
- None — no error tracking service
- Runtime errors surface as WoW in-game Lua error popups
- `pcall` is used defensively around aura reads in `Modules/TipOfTheSpear.lua:86` and `Modules/TipOfTheSpear.lua:95` to silently suppress API failures

**Logs:**
- `DEFAULT_CHAT_FRAME:AddMessage(...)` — used by `DMX:Print()` in `Core.lua:167` to write colored messages to the default chat frame
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
| `ADDON_LOADED` | `Core.lua:357` | Initialize DB, slash commands, and modules |
| `PLAYER_LOGIN` | `Modules/TipOfTheSpear.lua:756` | Sync aura state on login |
| `PLAYER_ENTERING_WORLD` | `Modules/TipOfTheSpear.lua:757` | Sync aura state on zone change |
| `PLAYER_REGEN_DISABLED` | `Modules/TipOfTheSpear.lua:758` | Set `inCombat = true`, update display |
| `PLAYER_REGEN_ENABLED` | `Modules/TipOfTheSpear.lua:759` | Set `inCombat = false`, sync aura |
| `PLAYER_SPECIALIZATION_CHANGED` | `Modules/TipOfTheSpear.lua:760` | Reset stacks, re-check active spec |
| `PLAYER_TALENT_UPDATE` | `Modules/TipOfTheSpear.lua:761` | Re-check active spec |
| `TRAIT_CONFIG_UPDATED` | `Modules/TipOfTheSpear.lua:762` | Re-check active spec |
| `UNIT_AURA` (player) | `Modules/TipOfTheSpear.lua:763` | Schedule delayed aura verification |
| `UNIT_SPELLCAST_SUCCEEDED` (player) | `Modules/TipOfTheSpear.lua:764` | Predict stack change immediately |
| `PLAYER_REGEN_DISABLED` | `Options.lua:451` | Auto-close settings window on combat start |

---

*Integration audit: 2026-06-17*
