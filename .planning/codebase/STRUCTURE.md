# Codebase Structure

**Analysis Date:** 2026-06-17

## Directory Layout

```
Duncedmaxxing/              # WoW addon root — also the TOC directory name (must match)
├── Duncedmaxxing.toc       # WoW addon manifest: interface version, metadata, load order
├── Core.lua                # Bootstrap: namespace, DB init, module registry, slash commands
├── Options.lua             # Settings popup UI (non-combat only)
├── Modules/                # Feature modules — one file per tracked mechanic
│   └── TipOfTheSpear.lua   # Tip of the Spear stack tracker and renderer
├── Media/                  # Static assets referenced by the TOC IconTexture
│   └── duncedgers_pony.png # Addon icon (shown in addon list)
├── README.md               # User-facing feature and command documentation
├── DEVELOPMENT_NOTES.md    # Developer context: goals, tracking model, API rules, future ideas
├── API_REFERENCES.md       # WoW API call inventory with Warcraft Wiki references
└── .planning/              # GSD planning artifacts (not shipped with addon)
    └── codebase/           # Codebase map documents
```

## Directory Purposes

**Root (`/`):**
- Purpose: All shippable addon files live here. WoW requires the directory name to match the TOC filename stem.
- Contains: `Core.lua`, `Options.lua`, `Duncedmaxxing.toc`, documentation
- Key files: `Core.lua` (entry point), `Duncedmaxxing.toc` (load manifest)

**`Modules/`:**
- Purpose: Self-contained feature modules, each tracking one game mechanic
- Contains: One `.lua` file per tracked mechanic/aura; each file registers itself via `DMX:RegisterModule`
- Key files: `Modules/TipOfTheSpear.lua`

**`Media/`:**
- Purpose: Static texture/image assets referenced from Lua via `Interface\AddOns\Duncedmaxxing\Media\...` paths
- Contains: PNG images used as addon icon or in-game textures
- Key files: `Media/duncedgers_pony.png` (addon icon)

**`.planning/codebase/`:**
- Purpose: GSD codebase map documents for AI-assisted development
- Generated: Yes (by `/gsd:map-codebase`)
- Committed: Developer choice; not part of the WoW addon distribution

## Key File Locations

**Entry Points:**
- `Core.lua`: Addon bootstrap — initializes `DMX` namespace, registers `ADDON_LOADED`, wires everything together
- `Duncedmaxxing.toc`: WoW load manifest — defines interface version, metadata, and file load order

**Configuration:**
- `Duncedmaxxing.toc`: Interface version (`120005`), addon title, SavedVariables name (`DuncedmaxxingDB`)
- `Core.lua:11–34`: `DEFAULTS` table — all default values for `DuncedmaxxingDB`

**Core Logic:**
- `Modules/TipOfTheSpear.lua`: All stack tracking, predictive model, aura verification, and WoW frame rendering
- `Core.lua:140–164`: Module registry (`RegisterModule`, `GetModule`, `ForEachModule`)

**Settings UI:**
- `Options.lua`: Entire settings popup window — `DMX.Options` table with `BuildWindow`, `Refresh`, `Open`

**Documentation:**
- `README.md`: End-user command reference and feature overview
- `DEVELOPMENT_NOTES.md`: Developer context — tracking model, API rules, future plans
- `API_REFERENCES.md`: WoW API call inventory

## Naming Conventions

**Files:**
- `PascalCase.lua` for all Lua source files: `Core.lua`, `Options.lua`, `TipOfTheSpear.lua`
- `PascalCase.toc` for the manifest, matching the addon directory name: `Duncedmaxxing.toc`
- `lowercase_with_underscores.png` for media assets: `duncedgers_pony.png`
- `UPPER_SNAKE_CASE.md` for documentation: `README.md`, `API_REFERENCES.md`, `DEVELOPMENT_NOTES.md`

**Directories:**
- `PascalCase` for feature module subdirectories: `Modules/`, `Media/`

**Lua identifiers:**
- Module tables: `PascalCase` local (`Tip`, `Options`)
- Module methods: `PascalCase` (`Tip:Initialize`, `Tip:RefreshLayout`, `Options:BuildWindow`)
- Private/local functions: `PascalCase` (`ReadLiveState`, `ClassifySpellID`, `EnsureFrame`)
- Local constants: `UPPER_SNAKE_CASE` (`TIP_OF_THE_SPEAR`, `MAX_STACKS`, `BUFF_DURATION`)
- WoW spell ID constant tables: `UPPER_SNAKE_CASE` (`CONSUMERS`)
- DMX namespace methods: `PascalCase` (`DMX:RegisterModule`, `DMX:GetDB`, `DMX:IsSurvivalHunter`)

## Where to Add New Code

**New tracked mechanic (e.g., Pack Leader beast tracking):**
- Primary code: `Modules/<MechanicName>.lua` — create a new module table, implement `Initialize`, register with `DMX:RegisterModule("<key>", Module)`
- Add the new file to `Duncedmaxxing.toc` after existing module entries
- Add default settings under a new key in `DEFAULTS` in `Core.lua:11–34`
- Tests: Not applicable (no test framework; addon is verified in-game)

**New display option or setting:**
- Default value: `Core.lua:11–34` (`DEFAULTS.tip` or a new sibling key)
- Persistence migration: Update `SETTINGS_MIGRATION` constant and `NormalizeDB` in `Core.lua` if the field is not nil-safe with old DB data
- Options widget: `Options.lua` `BuildWindow` method — add `CreateInput`, `CreateCheckbox`, or `CreateButton` call
- Slash command: `Core.lua:226–353` slash handler block — add new `elseif command == "..."` branch

**New slash command:**
- Location: `Core.lua:226–353` inside `SlashCmdList.DUNCEDMAXXING`
- Update `PrintHelp` at `Core.lua:192–196` to document it
- Update `README.md` Commands section

**New media asset:**
- Location: `Media/<filename>.png`
- Reference from Lua as: `"Interface\\AddOns\\Duncedmaxxing\\Media\\<filename>.png"`

**New WoW API call:**
- Add entry to `API_REFERENCES.md` per the API Documentation Rule in `DEVELOPMENT_NOTES.md`

## Special Directories

**`Modules/`:**
- Purpose: Feature module Lua files, one per tracked game mechanic
- Generated: No
- Committed: Yes

**`Media/`:**
- Purpose: Static image assets bundled with the addon
- Generated: No
- Committed: Yes

**`.planning/`:**
- Purpose: GSD planning artifacts — not part of the WoW addon
- Generated: Yes (by GSD commands)
- Committed: Developer choice; WoW will not load files from dot-directories

---

*Structure analysis: 2026-06-17*
