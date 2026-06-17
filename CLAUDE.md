<!-- GSD:project-start source:PROJECT.md -->
## Project

**Duncedmaxxing — Polish Pass**

A World of Warcraft addon that tracks Tip of the Spear stacks for Survival Hunters. It shows a real-time visual indicator (bar or icon mode) of the player's current stack count with predictive tracking that updates before the server confirms aura state. This milestone is a polish pass — fixing bugs, cleaning up internals, improving performance, and adding a test suite.

**Core Value:** Accurate, instant stack display during combat. If the stack count is wrong or laggy, nothing else matters.

### Constraints

- **Runtime**: WoW Lua 5.1 sandbox — no `require`, no filesystem, no threads
- **Combat lockdown**: UI mutations forbidden during `InCombatLockdown()`
- **API compatibility**: Must handle both old and new WoW API surfaces (dual-path calls)
- **No build toolchain**: Lua files loaded directly by WoW client via TOC order
<!-- GSD:project-end -->

<!-- GSD:stack-start source:codebase/STACK.md -->
## Technology Stack

## Languages
- Lua 5.1 (WoW-flavored) - All addon logic; `Core.lua`, `Options.lua`, `Modules/TipOfTheSpear.lua`
- None
## Runtime
- World of Warcraft client — Midnight 12.0.5 (Interface version `120005`)
- Lua executes inside the WoW sandboxed scripting environment; standard Lua libraries are partially available
- No standalone Lua interpreter; execution depends entirely on the WoW client loading the addon
- None — WoW addons have no external package manager
- Lockfile: Not applicable
## Frameworks
- WoW Addon Framework (Blizzard) — the TOC/Lua file loading system, SavedVariables persistence, event system, and Widget API (`CreateFrame`, `RegisterEvent`, etc.)
- No third-party addon framework (e.g., Ace3) is used; the addon is intentionally dependency-free
- None — no test framework detected
- No build toolchain — Lua files are loaded directly by the WoW client in the order declared in `Duncedmaxxing.toc`
- No transpilation, minification, or bundling step
## Key Dependencies
- WoW Widget API — all UI rendering relies on `CreateFrame`, `CreateTexture`, `CreateFontString`, and related Widget API calls; documented in `API_REFERENCES.md`
- `C_UnitAuras.GetPlayerAuraBySpellID` — used for aura verification of Tip of the Spear buff (`260286`); marked `RequiresNonSecretAura` on the wiki, so the addon uses it only as delayed sanity-check
- `C_Timer.After` / `C_Timer.NewTimer` — used for expiry scheduling and deferred aura reads; `Modules/TipOfTheSpear.lua` has fallback paths if `C_Timer` is absent
- `C_SpecializationInfo.GetSpecialization` (with fallback to `GetSpecialization`) — used in `Core.lua:DMX:IsSurvivalHunter()` to gate tracker activity to Survival spec (spec index 3)
- `DuncedmaxxingDB` SavedVariable — persisted by the WoW client across sessions; declared in `Duncedmaxxing.toc`; initialized and migrated in `Core.lua`
## Configuration
- No environment variables or `.env` files — configuration is stored as WoW SavedVariables (`DuncedmaxxingDB`) written to `WTF/Account/.../SavedVariables/Duncedmaxxing.lua` by the game client
- Key configs: `tip.displayMode`, `tip.enabled`, `tip.showOnlyInCombat`, `tip.hideWhenEmpty`, position/scale, colors, border sizes — all with defaults in `Core.lua:DEFAULTS`
- `Duncedmaxxing.toc` — TOC file controls interface version, metadata, SavedVariables declaration, and Lua file load order
## Platform Requirements
- A World of Warcraft: Midnight 12.0.5 installation; no external tooling required
- Files are dropped directly into the WoW `Interface/AddOns/Duncedmaxxing/` directory
- WoW client on Windows or macOS; no server-side component
- Interface version target: `120005` (declared in `Duncedmaxxing.toc`)
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

## Language
## Naming Patterns
- `ALL_CAPS_SNAKE_CASE` for numeric/string constants and color tables
- Examples: `TIP_OF_THE_SPEAR`, `MAX_STACKS`, `BUFF_DURATION`, `BORDER_SIZE`, `WHITE_TEX`, `TIP_COLOR`
- Defined at the top of each file with `local`
- `PascalCase` for all file-scoped `local function` declarations
- Examples: `Trim`, `Clamp`, `ParseHexColor`, `CopyDefaults`, `MergeDefaults`, `NormalizeDB`, `PrintHelp`, `RegisterSlashCommands`, `EnsureFrame`, `CreatePip`, `LayoutBorders`, `ColorTuple`
- `PascalCase` for methods defined on a module table
- Examples: `DMX:RegisterModule`, `DMX:GetDB`, `DMX:ForEachModule`, `Tip:Initialize`, `Tip:Update`, `Tip:RefreshLayout`, `Options:BuildWindow`, `Options:Refresh`
- `camelCase` for local variables within function bodies
- Examples: `addonName`, `borderSize`, `segmentWidths`, `iconSize`, `liveStacks`, `liveExpiresAt`, `requestedDelay`
- `PascalCase` for the module table itself: `Tip`, `Options`
- The addon namespace table: `DMX` (all-caps abbreviation)
- `camelCase`: `minValue`, `maxValue`, `getValue`, `setValue`, `segmentWidths`
- `ALL_CAPS_SNAKE_CASE` strings matching the WoW API convention: `"PLAYER_REGEN_DISABLED"`, `"UNIT_AURA"`, `"UNIT_SPELLCAST_SUCCEEDED"`
## File Organization
## Indentation and Formatting
## Constants and Magic Numbers
## Guard Clauses and Nil Safety
## Error Handling
- `Clamp` validates and constrains numeric inputs; returns `nil` for non-numeric strings
- `ParseHexColor` returns `nil` for invalid hex; callers check before using
- `ParseOnOff` returns `nil` for unrecognized tokens
## API Compatibility
## Module Registration Pattern
## Idempotency Guards
## Combat Safety
## Comments
## Logging
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

## System Overview
```text
```
## Component Responsibilities
| Component | Responsibility | File |
|-----------|----------------|------|
| Core | Addon namespace `DMX`, module registry, DB init, settings migration, slash commands, spec-detection helpers | `Core.lua` |
| Options | Movable settings popup UI, all input widgets, combat guard | `Options.lua` |
| TipOfTheSpear | Stack state machine, predictive tracking, aura verification, WoW frame construction and rendering | `Modules/TipOfTheSpear.lua` |
| SavedVariables | Persistent user settings via WoW's `DuncedmaxxingDB` global | WoW engine |
## Pattern Overview
- All files share the addon-private namespace table via the `local addonName, DMX = ...` WoW vararg idiom
- `Core.lua` initializes the namespace and is the sole owner of `DuncedmaxxingDB`
- Modules self-register via `DMX:RegisterModule(key, table)` after load
- No external library dependencies — pure Lua + WoW API
## Layers
- Purpose: Owns addon identity, saved-variable DB, settings migration, module dispatch, and slash commands
- Location: `Core.lua`
- Contains: `DEFAULTS` table, `MergeDefaults`/`NormalizeDB` helpers, module registry methods, spec-detection helpers, `ADDON_LOADED` handler
- Depends on: WoW globals (`CreateFrame`, `UnitClass`, `C_SpecializationInfo`, `SlashCmdList`)
- Used by: `Options.lua`, `Modules/TipOfTheSpear.lua`
- Purpose: Provides a movable in-game configuration popup; reads and writes `db.tip` through `DMX:GetDB()`
- Location: `Options.lua`
- Contains: `DMX.Options` table with `BuildWindow`, `Refresh`, `Open`, `Initialize` methods, all widget factory functions
- Depends on: `Core.lua` (via `DMX`), WoW frame API (`CreateFrame`, `UIParent`, templates)
- Used by: Slash command handler in `Core.lua` calls `DMX:OpenOptions()`
- Purpose: All gameplay logic and rendering for a specific tracking feature
- Location: `Modules/TipOfTheSpear.lua`
- Contains: Stack state machine, predictive spellcast handling, aura verification with timers, full WoW frame tree construction
- Depends on: `Core.lua` (via `DMX`), WoW API (`C_UnitAuras`, `C_Timer`, `C_Spell`, frame events)
- Used by: `Core.lua` calls `DMX:ForEachModule("Initialize", DMX)` on `ADDON_LOADED`
## Data Flow
### Addon Initialization
### In-Combat Stack Tracking
### Settings Change Path
- All persistent state lives in `DuncedmaxxingDB` (WoW SavedVariables global), accessed via `DMX:GetDB()`
- Runtime stack state (`Tip.stacks`, `Tip.expiresAt`, `Tip.inCombat`, etc.) lives as fields on the `Tip` module table
## Key Abstractions
- Purpose: Shared addon object — acts as both the module registry and the public API surface
- Examples: `Core.lua:3` (`_G.Duncedmaxxing = DMX`), all files (`local _, DMX = ...`)
- Pattern: WoW addon private namespace passed via vararg; methods added with `function DMX:Method()`
- Purpose: Each feature is a self-contained Lua table with `Initialize`, `Update`, and lifecycle methods
- Examples: `Tip` in `Modules/TipOfTheSpear.lua:3`, `Options` in `Options.lua:3`
- Pattern: `local Foo = {}` → attach methods → `DMX:RegisterModule("key", Foo)` or assign to `DMX.Foo`
- Purpose: Centralized default values in `Core.lua:11–34`; every subsystem reads live config via a local `GetCfg()` that calls `DMX:GetDB().tip`
- Examples: `Core.lua:11`, `Options.lua:58–61`, `Modules/TipOfTheSpear.lua:120–122`
- Pattern: Defaults merged once on load via `MergeDefaults`; no runtime fallback logic needed in modules
## Entry Points
- Location: `Core.lua:356–374`
- Triggers: WoW fires `ADDON_LOADED` after all TOC files are parsed and loaded
- Responsibilities: DB initialization, settings migration, options initialization, module dispatch
- Location: `Core.lua:140–147`
- Triggers: Called at file parse time (bottom of each module file, outside any function)
- Responsibilities: Stores module reference; calls `Initialize` immediately if addon is already `ready`
- Location: `Core.lua:226–353`
- Triggers: Player types `/dmax` or `/duncedmaxxing`
- Responsibilities: Parses command string, directly mutates `db.tip`, calls `RefreshTip` or module methods
## Architectural Constraints
- **Threading:** Single-threaded Lua coroutine model (WoW standard). No worker threads. `C_Timer.After` and `C_Timer.NewTimer` are the only async primitives used.
- **Global state:** `DuncedmaxxingDB` is a WoW SavedVariables global. `_G.Duncedmaxxing = DMX` exposes the namespace globally. `Tip` module uses module-level locals for frame references (`root`, `pips`, `borders`, `label`, `numberText`).
- **Circular imports:** Not applicable — WoW addons do not use `require`; files share a namespace table and load sequentially per TOC order.
- **Combat protection:** Options window and all settings mutations are blocked during `InCombatLockdown()`. The tracking path (event handlers, `Tip:Update`) is explicitly kept off the combat-restricted path.
- **API compatibility:** Dual-path API calls for `GetSpecialization` / `C_SpecializationInfo` and `GetSpellTexture` / `C_Spell.GetSpellTexture` to handle WoW API surface changes across patches.
## Anti-Patterns
### Direct db.tip mutation in slash command handler
### Module-level frame locals in TipOfTheSpear
## Error Handling
- `ReadLiveState` wraps both `GetPlayerAuraBySpellID` and field access in `pcall` to avoid nil-indexing crashes on unexpected aura shapes (`Modules/TipOfTheSpear.lua:86–117`)
- `ClassifySpellID` wraps the lookup in `pcall` (`Modules/TipOfTheSpear.lua:57–69`)
- `Options:CanChange()` gate prevents all settings changes in combat (`Options.lua:161–168`)
- Nil-guard checks before every frame method call (e.g., `if tip and tip.RefreshLayout then`)
## Cross-Cutting Concerns
<!-- GSD:architecture-end -->

<!-- GSD:skills-start source:skills/ -->
## Project Skills

No project skills found. Add skills to any of: `.claude/skills/`, `.agents/skills/`, `.cursor/skills/`, `.github/skills/`, or `.codex/skills/` with a `SKILL.md` index file.
<!-- GSD:skills-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd-quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd-debug` for investigation and bug fixing
- `/gsd-execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->



<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd-profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
