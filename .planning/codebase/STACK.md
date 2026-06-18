# Technology Stack

**Analysis Date:** 2026-06-18

## Languages

**Primary:**
- Lua 5.1 (WoW-flavored) - All addon logic; `Duncedmaxxing/Core.lua`, `Duncedmaxxing/Options.lua`, `Duncedmaxxing/Modules/TipOfTheSpear.lua`

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
- **busted** - Lua unit test framework; configured in `.busted`
  - Pattern: `_spec.lua` files in `spec/` directory
  - Execution: Run via `busted` command
  - Supports full test isolation via per-test module reloading

**Linting:**
- **luacheck** - Static Lua linter for code quality checks
  - Configuration: `.luacheckrc` (Lua 5.1 std, WoW API globals, addon-specific configurations)
  - Excludes: `spec/**/*.lua` (test files use busted globals not in addon code)

**Build/Dev:**
- No build toolchain — Lua files are loaded directly by the WoW client in the order declared in `Duncedmaxxing/Duncedmaxxing.toc`
- No transpilation, minification, or bundling step

## Key Dependencies

**Critical:**
- WoW Widget API — all UI rendering relies on `CreateFrame`, `CreateTexture`, `CreateFontString`, and related Widget API calls; documented in `API_REFERENCES.md`
- `C_UnitAuras.GetPlayerAuraBySpellID` — used for aura verification of Tip of the Spear buff (`260286`); marked `RequiresNonSecretAura` on the wiki, so the addon uses it only as delayed sanity-check
- `C_Timer.After` / `C_Timer.NewTimer` — used for expiry scheduling and deferred aura reads; `Duncedmaxxing/Modules/TipOfTheSpear.lua` has fallback paths if `C_Timer` is absent
- `C_SpecializationInfo.GetSpecialization` (with fallback to `GetSpecialization`) — used in `Duncedmaxxing/Core.lua:DMX:IsSurvivalHunter()` to gate tracker activity to Survival spec (spec index 3)

**Infrastructure:**
- `DuncedmaxxingDB` SavedVariable — persisted by the WoW client across sessions; declared in `Duncedmaxxing/Duncedmaxxing.toc`; initialized and migrated in `Duncedmaxxing/Core.lua`

## Configuration

**Environment:**
- No environment variables or `.env` files — configuration is stored as WoW SavedVariables (`DuncedmaxxingDB`) written to `WTF/Account/.../SavedVariables/Duncedmaxxing.lua` by the game client
- Key configs: `tip.displayMode`, `tip.enabled`, `tip.showOnlyInCombat`, `tip.hideWhenEmpty`, position/scale, colors, border sizes — all with defaults in `Duncedmaxxing/Core.lua:DEFAULTS`

**Build:**
- `Duncedmaxxing/Duncedmaxxing.toc` — TOC file controls interface version, metadata, SavedVariables declaration, and Lua file load order

**Linting:**
- `.luacheckrc` — Static analysis configuration targeting Lua 5.1; defines WoW API globals, addon writable globals, and style rules

**Testing:**
- `.busted` — Test runner configuration; pattern `_spec`, no keep-going mode, utfTerminal output
- `spec/support/init.lua` — Addon loader with WoW vararg injection and ADDON_LOADED bootstrap for test isolation
- `spec/support/wow_stubs.lua` — Mock WoW API layer (timers, auras, frame stubs, spec detection)

## Platform Requirements

**Development:**
- A World of Warcraft: Midnight 12.0.5 installation; no external tooling required
- Files are dropped directly into the WoW `Interface/AddOns/Duncedmaxxing/` directory
- **Optional dev tools:** `luacheck` (linting) and `busted` (testing) installed via local system package manager

**Production:**
- WoW client on Windows or macOS; no server-side component
- Interface version target: `120005` (declared in `Duncedmaxxing/Duncedmaxxing.toc`)

---

*Stack analysis: 2026-06-18*
