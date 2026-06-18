# Codebase Structure

**Analysis Date:** 2026-06-18

## Directory Layout

```
repo-root/
├── Duncedmaxxing/              # WoW addon directory (drop into Interface/AddOns/)
│   ├── Duncedmaxxing.toc       # WoW addon manifest: interface version, metadata, load order
│   ├── Util.lua                # Utility functions: Clamp, Trim, ParseOnOff, ParseHexColor
│   ├── Core.lua                # Bootstrap: namespace, DB init, module registry, slash commands
│   ├── Options.lua             # Settings popup UI (non-combat only)
│   ├── Modules/                # Feature modules — one file per tracked mechanic
│   │   └── TipOfTheSpear.lua   # Tip of the Spear stack tracker and renderer
│   └── Media/                  # Static assets referenced by the TOC IconTexture
│       └── duncedgers_pony.png # Addon icon (shown in addon list)
├── spec/                       # Offline test suite (busted + luacheck)
│   ├── core_spec.lua           # Unit tests: MergeDefaults, NormalizeDB, settings migration
│   ├── util_spec.lua           # Unit tests: Clamp, ParseHexColor, ParseOnOff, Trim
│   ├── tip_spec.lua            # Unit tests: ApplySpell, SyncFromAura, timer scheduling
│   └── support/                # Test infrastructure
│       ├── init.lua            # Test loader: loadfile vararg injection, ADDON_LOADED bootstrap
│       └── wow_stubs.lua       # WoW API mocks: C_Timer, C_UnitAuras, frames, globals
├── .busted                     # Busted test runner configuration
├── .luacheckrc                 # Luacheck linting configuration (targets Lua 5.1, excludes spec/)
├── README.md                   # User-facing feature and command documentation
├── CLAUDE.md                   # AI-assisted development instructions
├── .gitignore                  # Git ignore rules
└── .planning/                  # GSD planning artifacts (not shipped with addon)
    └── codebase/               # Codebase map documents
```

## Directory Purposes

**Root (`/`):**
- Purpose: Repository root. Dev-only files (README, CLAUDE.md, .gitignore, .planning/, test config) live here. Addon files live in the `Duncedmaxxing/` subdirectory.
- Contains: `README.md`, `CLAUDE.md`, `.gitignore`, `.planning/`, `.busted`, `.luacheckrc`, `Duncedmaxxing/`, `spec/`
- Key files: `Duncedmaxxing/Core.lua` (entry point), `Duncedmaxxing/Duncedmaxxing.toc` (load manifest)

**`Duncedmaxxing/`:**
- Purpose: WoW addon directory. All shippable addon files live here. WoW requires the directory name to match the TOC filename stem. Users clone/extract directly into `Interface/AddOns/`.
- Contains: `Core.lua`, `Options.lua`, `Util.lua`, `Duncedmaxxing.toc`, `Modules/`, `Media/`

**`Duncedmaxxing/Modules/`:**
- Purpose: Self-contained feature modules, each tracking one game mechanic
- Contains: One `.lua` file per tracked mechanic/aura; each file registers itself via `DMX:RegisterModule`
- Key files: `Duncedmaxxing/Modules/TipOfTheSpear.lua`

**`Duncedmaxxing/Media/`:**
- Purpose: Static texture/image assets referenced from Lua via `Interface\AddOns\Duncedmaxxing\Media\...` paths
- Contains: PNG images used as addon icon or in-game textures
- Key files: `Duncedmaxxing/Media/duncedgers_pony.png` (addon icon)

**`spec/`:**
- Purpose: Offline unit test suite using busted (Lua test framework)
- Contains: Test files, test support infrastructure (loader, WoW API mocks)
- Organization: One test file per major layer (`core_spec.lua`, `util_spec.lua`, `tip_spec.lua`); `support/` subdirectory for loader and stubs
- Isolation: Each test calls `loader.load()` to reload all addon source files fresh, preventing test pollution

**`spec/support/`:**
- Purpose: Test infrastructure — WoW API mocks and test loader
- `init.lua`: Loads addon files with WoW vararg injection, simulates ADDON_LOADED bootstrap, returns test context (DMX, Tip, mockClock)
- `wow_stubs.lua`: Mock implementations of WoW globals (`C_Timer`, `C_UnitAuras`, frame API, etc.); controllable mock clock for timer testing

**`.planning/codebase/`:**
- Purpose: GSD codebase map documents for AI-assisted development
- Generated: Yes (by `/gsd:map-codebase`)
- Committed: Developer choice; not part of the WoW addon distribution

## Key File Locations

**Entry Points:**
- `Duncedmaxxing/Core.lua`: Addon bootstrap — initializes `DMX` namespace, registers `ADDON_LOADED`, wires everything together
- `Duncedmaxxing/Duncedmaxxing.toc`: WoW load manifest — defines interface version, metadata, and file load order

**Configuration:**
- `Duncedmaxxing/Duncedmaxxing.toc`: Interface version (`120005`), addon title, SavedVariables name (`DuncedmaxxingDB`)
- `Duncedmaxxing/Core.lua:11–34`: `DEFAULTS` table — all default values for `DuncedmaxxingDB`
- `.busted`: Busted test runner config — test pattern, output format
- `.luacheckrc`: Luacheck static linter config — targets Lua 5.1, declares addon globals, excludes spec/

**Core Logic:**
- `Duncedmaxxing/Util.lua`: Shared validation helpers (`Clamp`, `ParseHexColor`, `ParseOnOff`, `Trim`)
- `Duncedmaxxing/Modules/TipOfTheSpear.lua`: All stack tracking, predictive model, aura verification, and WoW frame rendering
- `Duncedmaxxing/Core.lua:140–164`: Module registry (`RegisterModule`, `GetModule`, `ForEachModule`)

**Settings UI:**
- `Duncedmaxxing/Options.lua`: Entire settings popup window — `DMX.Options` table with `BuildWindow`, `Refresh`, `Open`

**Tests:**
- `spec/core_spec.lua`: DB migration tests, defaults merging tests (via `DMX._test` escape hatch)
- `spec/util_spec.lua`: Validator function tests (Clamp, ParseHexColor, ParseOnOff)
- `spec/tip_spec.lua`: Stack tracking logic tests (ApplySpell, SyncFromAura, timer scheduling with mock clock)
- `spec/support/init.lua`: Test loader with vararg injection and ADDON_LOADED bootstrap
- `spec/support/wow_stubs.lua`: WoW API mock layer with controllable mock clock

**Documentation:**
- `README.md`: End-user command reference and feature overview
- `DEVELOPMENT_NOTES.md`: Developer context — tracking model, API rules, future plans
- `API_REFERENCES.md`: WoW API call inventory

## Naming Conventions

**Files:**
- `PascalCase.lua` for all Lua source files: `Util.lua`, `Core.lua`, `Options.lua`, `TipOfTheSpear.lua`
- `PascalCase.toc` for the manifest, matching the addon directory name: `Duncedmaxxing.toc`
- `lowercase_with_underscores.png` for media assets: `duncedgers_pony.png`
- `UPPER_SNAKE_CASE.md` for documentation: `README.md`, `API_REFERENCES.md`, `DEVELOPMENT_NOTES.md`
- `lowercase_with_underscore` for test files and configuration: `*_spec.lua`, `.busted`, `.luacheckrc`

**Directories:**
- `PascalCase` for feature module subdirectories: `Modules/`, `Media/`
- `lowercase` for test infrastructure: `spec/`, `support/`

**Lua identifiers:**
- Module tables: `PascalCase` local (`Util`, `Tip`, `Options`)
- Module methods: `PascalCase` (`Tip:Initialize`, `Tip:ApplySpell`, `Util.Clamp`, `Options:BuildWindow`)
- Private/local functions: `PascalCase` (`ReadLiveState`, `ClassifySpellID`, `EnsureFrame`, `loadAddon`, `makeAuraData`, `noopFrame`)
- Local constants: `UPPER_SNAKE_CASE` (`TIP_OF_THE_SPEAR`, `MAX_STACKS`, `BUFF_DURATION`, `CONSUMER_UPSYNC_GRACE`, `AURA_VERIFY_DELAY`)
- WoW spell ID constant tables: `UPPER_SNAKE_CASE` (`CONSUMERS`, `GENERATORS`)
- DMX namespace methods: `PascalCase` (`DMX:RegisterModule`, `DMX:GetDB`, `DMX:IsSurvivalHunter`, `DMX._test`)

## Where to Add New Code

**New tracked mechanic (e.g., Pack Leader beast tracking):**
- Primary code: `Duncedmaxxing/Modules/<MechanicName>.lua` — create a new module table, implement `Initialize`, register with `DMX:RegisterModule("<key>", Module)`
- Add the new file to `Duncedmaxxing/Duncedmaxxing.toc` after existing module entries
- Add default settings under a new key in `DEFAULTS` in `Duncedmaxxing/Core.lua:11–34`
- Tests: Create `spec/<mechanicname>_spec.lua` following the pattern of `spec/tip_spec.lua`; test pure-logic methods with mock clock

**New display option or setting:**
- Default value: `Duncedmaxxing/Core.lua:11–34` (`DEFAULTS.tip` or a new sibling key)
- Persistence migration: Update `SETTINGS_MIGRATION` constant and `NormalizeDB` in `Duncedmaxxing/Core.lua` if the field is not nil-safe with old DB data
- Options widget: `Duncedmaxxing/Options.lua` `BuildWindow` method — add `CreateInput`, `CreateCheckbox`, or `CreateButton` call
- Slash command: `Duncedmaxxing/Core.lua:226–353` slash handler block — add new `elseif command == "..."` branch
- Tests: Add test cases to `spec/core_spec.lua:NormalizeDB` describe block if adding a new migration scenario

**New utility function:**
- Location: `Duncedmaxxing/Util.lua` — add function implementation, expose via `Util.<name> = <function>`
- Tests: Add describe block to `spec/util_spec.lua` with comprehensive test cases (valid input, edge cases, error paths)

**New slash command:**
- Location: `Duncedmaxxing/Core.lua:226–353` inside `SlashCmdList.DUNCEDMAXXING`
- Update `PrintHelp` at `Duncedmaxxing/Core.lua:192–196` to document it
- Update `README.md` Commands section

**New media asset:**
- Location: `Duncedmaxxing/Media/<filename>.png`
- Reference from Lua as: `"Interface\\AddOns\\Duncedmaxxing\\Media\\<filename>.png"`

**New WoW API call:**
- Add entry to `API_REFERENCES.md` per the API Documentation Rule in `DEVELOPMENT_NOTES.md`
- If adding to a module, ensure error handling via `pcall` in case of version mismatch

## Test File Organization

**Pattern:** Each major layer has one `*_spec.lua` file in the `spec/` directory root.

**Isolation:** Tests use `loader.load()` in `before_each()` to reload all addon source files fresh. This prevents cross-test pollution from timer state, stack state, and DB mutations. Provided functions:
- `loader.load()` — Loads addon files with WoW vararg injection, simulates ADDON_LOADED, returns (DMX, Tip, mockClock)
- `loader.resetTipState(Tip, clock)` — Zeros Tip runtime fields and resets clock to `now = 100`

**Mock Clock:** Tests use `mockClock:advance(seconds)` to move time forward deterministically. All scheduled callbacks auto-fire when `fireAt <= now`.

**Aura Mocking:** Tests override `stubs.mockAura.impl` to control what `ReadLiveState` receives. This is the only way to influence the module-level local `GetPlayerAuraBySpellID` captured at file-load time.

**AuraData Contract:** All mocked auras are built via `stubs.makeAuraData(overrides)`, which ensures full `Struct_AuraData` fidelity (all documented wiki fields present).

## Special Directories

**`Duncedmaxxing/Modules/`:**
- Purpose: Feature module Lua files, one per tracked game mechanic
- Generated: No
- Committed: Yes

**`Duncedmaxxing/Media/`:**
- Purpose: Static image assets bundled with the addon
- Generated: No
- Committed: Yes

**`spec/`:**
- Purpose: Offline unit test suite using busted
- Generated: No
- Committed: Yes (required for CI/CD testing)

**`spec/support/`:**
- Purpose: Test infrastructure — WoW API mocks and loader
- Generated: No
- Committed: Yes (required for all tests)

**`.planning/`:**
- Purpose: GSD planning artifacts — not part of the WoW addon
- Generated: Yes (by GSD commands)
- Committed: Developer choice; WoW will not load files from dot-directories

## Configuration Files

**`.busted`:**
- Purpose: Busted test runner configuration
- Pattern matching: `_spec` suffix (e.g., `*_spec.lua`)
- Output format: `utfTerminal` (UTF-8 formatted console output)
- Keep-going: Disabled (fail on first test failure)

**`.luacheckrc`:**
- Purpose: Static Lua linter configuration (luacheck)
- Target: Lua 5.1 (WoW sandbox)
- Declared writeable globals: `DuncedmaxxingDB`, `SLASH_DUNCEDMAXXING1/2`, `Duncedmaxxing`, `SlashCmdList`
- WoW API read-only globals: `CreateFrame`, `C_UnitAuras`, `C_Timer`, `C_SpecializationInfo`, `GetSpecialization`, `InCombatLockdown`, etc.
- Exclusions: `spec/**/*.lua` (test infrastructure uses busted globals like `describe`, `it`, which are not part of addon code)
- Line-length: No max (WoW UI code naturally has long lines)
- Ignore rule: W432 (shadowing upvalue argument — intentional in WoW SetScript closures where `self` is reused)

---

*Structure analysis: 2026-06-18*
