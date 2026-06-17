# Technology Stack

**Analysis Date:** 2026-06-17

## Languages

**Primary:**
- Lua 5.1 (WoW-flavored) - All addon logic; `Core.lua`, `Options.lua`, `Modules/TipOfTheSpear.lua`

**Secondary:**
- None

## Runtime

**Environment:**
- World of Warcraft client — Midnight 12.0.5 (Interface version `120005`)
- Lua executes inside the WoW sandboxed scripting environment; standard Lua libraries are partially available
- No standalone Lua interpreter; execution depends entirely on the WoW client loading the addon

**Package Manager:**
- None — WoW addons have no external package manager
- Lockfile: Not applicable

## Frameworks

**Core:**
- WoW Addon Framework (Blizzard) — the TOC/Lua file loading system, SavedVariables persistence, event system, and Widget API (`CreateFrame`, `RegisterEvent`, etc.)
- No third-party addon framework (e.g., Ace3) is used; the addon is intentionally dependency-free

**Testing:**
- None — no test framework detected

**Build/Dev:**
- No build toolchain — Lua files are loaded directly by the WoW client in the order declared in `Duncedmaxxing.toc`
- No transpilation, minification, or bundling step

## Key Dependencies

**Critical:**
- WoW Widget API — all UI rendering relies on `CreateFrame`, `CreateTexture`, `CreateFontString`, and related Widget API calls; documented in `API_REFERENCES.md`
- `C_UnitAuras.GetPlayerAuraBySpellID` — used for aura verification of Tip of the Spear buff (`260286`); marked `RequiresNonSecretAura` on the wiki, so the addon uses it only as delayed sanity-check
- `C_Timer.After` / `C_Timer.NewTimer` — used for expiry scheduling and deferred aura reads; `Modules/TipOfTheSpear.lua` has fallback paths if `C_Timer` is absent
- `C_SpecializationInfo.GetSpecialization` (with fallback to `GetSpecialization`) — used in `Core.lua:DMX:IsSurvivalHunter()` to gate tracker activity to Survival spec (spec index 3)

**Infrastructure:**
- `DuncedmaxxingDB` SavedVariable — persisted by the WoW client across sessions; declared in `Duncedmaxxing.toc`; initialized and migrated in `Core.lua`

## Configuration

**Environment:**
- No environment variables or `.env` files — configuration is stored as WoW SavedVariables (`DuncedmaxxingDB`) written to `WTF/Account/.../SavedVariables/Duncedmaxxing.lua` by the game client
- Key configs: `tip.displayMode`, `tip.enabled`, `tip.showOnlyInCombat`, `tip.hideWhenEmpty`, position/scale, colors, border sizes — all with defaults in `Core.lua:DEFAULTS`

**Build:**
- `Duncedmaxxing.toc` — TOC file controls interface version, metadata, SavedVariables declaration, and Lua file load order

## Platform Requirements

**Development:**
- A World of Warcraft: Midnight 12.0.5 installation; no external tooling required
- Files are dropped directly into the WoW `Interface/AddOns/Duncedmaxxing/` directory

**Production:**
- WoW client on Windows or macOS; no server-side component
- Interface version target: `120005` (declared in `Duncedmaxxing.toc`)

---

*Stack analysis: 2026-06-17*
