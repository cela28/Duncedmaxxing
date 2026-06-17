# Coding Conventions

**Analysis Date:** 2026-06-17

## Language

This is a World of Warcraft addon written in **Lua 5.1** (the WoW runtime). All conventions are Lua idioms, not Lua with any external toolchain.

## Naming Patterns

**Module-level constants:**
- `ALL_CAPS_SNAKE_CASE` for numeric/string constants and color tables
- Examples: `TIP_OF_THE_SPEAR`, `MAX_STACKS`, `BUFF_DURATION`, `BORDER_SIZE`, `WHITE_TEX`, `TIP_COLOR`
- Defined at the top of each file with `local`

**File-local private functions:**
- `PascalCase` for all file-scoped `local function` declarations
- Examples: `Trim`, `Clamp`, `ParseHexColor`, `CopyDefaults`, `MergeDefaults`, `NormalizeDB`, `PrintHelp`, `RegisterSlashCommands`, `EnsureFrame`, `CreatePip`, `LayoutBorders`, `ColorTuple`

**Module/object methods (public interface):**
- `PascalCase` for methods defined on a module table
- Examples: `DMX:RegisterModule`, `DMX:GetDB`, `DMX:ForEachModule`, `Tip:Initialize`, `Tip:Update`, `Tip:RefreshLayout`, `Options:BuildWindow`, `Options:Refresh`

**Local variables (inside functions):**
- `camelCase` for local variables within function bodies
- Examples: `addonName`, `borderSize`, `segmentWidths`, `iconSize`, `liveStacks`, `liveExpiresAt`, `requestedDelay`

**Module table names:**
- `PascalCase` for the module table itself: `Tip`, `Options`
- The addon namespace table: `DMX` (all-caps abbreviation)

**Parameters:**
- `camelCase`: `minValue`, `maxValue`, `getValue`, `setValue`, `segmentWidths`

**WoW event names:**
- `ALL_CAPS_SNAKE_CASE` strings matching the WoW API convention: `"PLAYER_REGEN_DISABLED"`, `"UNIT_AURA"`, `"UNIT_SPELLCAST_SUCCEEDED"`

## File Organization

**Module pattern:**
```lua
local _, DMX = ...

local ModuleName = {}

-- Module-level constants (ALL_CAPS)
local SPELL_ID = 260286

-- File-local frame references (camelCase or lowercase)
local root
local pips = {}

-- File-local private helpers (PascalCase)
local function HelperName(args)
    ...
end

-- Public methods on module table (PascalCase)
function ModuleName:MethodName()
    ...
end

-- Register with core at end of file
DMX:RegisterModule("key", ModuleName)
```

**Core addon initialization:**
```lua
local addonName, DMX = ...
_G.Duncedmaxxing = DMX
-- ... define methods and locals ...
-- Bootstrap via ADDON_LOADED event at end of file
local coreFrame = CreateFrame("Frame")
coreFrame:RegisterEvent("ADDON_LOADED")
```

**`Options.lua` exports back to DMX via assignment at end:**
```lua
function DMX:InitializeOptions()
    Options:Initialize()
end
function DMX:OpenOptions()
    Options:Open()
end
```

## Indentation and Formatting

**Indentation:** 4 spaces (no tabs — confirmed by byte-level inspection of `Core.lua`, `Options.lua`, `Modules/TipOfTheSpear.lua`)

**Line length:** No enforced limit; long lines appear in `LayoutBorders` and slash-command chains but are kept readable.

**String delimiters:** Double quotes for string literals everywhere: `"bar"`, `"icons"`, `"number"`, `"player"`.

**Backslash in paths:** WoW texture paths use `\\` (escaped backslash): `"Interface\\Buttons\\WHITE8X8"`.

## Constants and Magic Numbers

All spell IDs, numeric limits, timing delays, and default dimensions are extracted to named `local` constants at the top of the file — never embedded inline as magic numbers.

```lua
-- Good (as written in codebase):
local TIP_OF_THE_SPEAR = 260286
local AURA_VERIFY_DELAY = 1.25
local TRACKER_WIDTH = 247

-- Not found in codebase:
local stacks = ClampStacks(260286)  -- bare magic number
```

## Guard Clauses and Nil Safety

Functions use **early returns** to handle nil/missing state rather than deeply nested if-blocks:

```lua
-- Pattern used throughout Core.lua and TipOfTheSpear.lua:
function DMX:ResetTipStyle()
    local db = self:GetDB()
    if not db then return end
    ...
end

function Tip:ApplyLock()
    if not root then return end
    ...
end
```

Nil-coalescing uses Lua `or` chaining:
```lua
local cfg = GetCfg() or DMX.defaults.tip
local mode = cfg.displayMode or "bar"
local borderSize = tonumber(cfg.borderSize or cfg.spacing) or BORDER_SIZE
```

## Error Handling

**`pcall` for WoW API calls that may fail:**

WoW API functions that could throw (typically C_* namespace calls and aura reads) are wrapped in `pcall`. On failure the function returns `nil` instead of propagating the error.

```lua
-- From TipOfTheSpear.lua ReadLiveState():
local ok, aura = pcall(GetPlayerAuraBySpellID, TIP_OF_THE_SPEAR)
if not ok then
    return nil, nil
end

local ok, kind = pcall(function()
    if value == KILL_COMMAND then return "generator" end
    if type(value) == "number" and CONSUMERS[value] then return "consumer" end
end)
if ok then return kind end
```

**Validation functions return `nil` on invalid input** (not errors):
```lua
local function Clamp(value, minValue, maxValue)
    value = tonumber(value)
    if not value then return nil end  -- nil signals invalid
    ...
end
```

**Input handling:**
- `Clamp` validates and constrains numeric inputs; returns `nil` for non-numeric strings
- `ParseHexColor` returns `nil` for invalid hex; callers check before using
- `ParseOnOff` returns `nil` for unrecognized tokens

**No `error()` or `assert()` calls** — the addon fails silent/quiet rather than raising errors to the player.

## API Compatibility

WoW API calls that differ between game versions are resolved defensively with `and`/`or` chains:

```lua
-- From TipOfTheSpear.lua:
local GetPlayerAuraBySpellID = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID

local function ResolveSpellTexture()
    if C_Spell and C_Spell.GetSpellTexture then
        return C_Spell.GetSpellTexture(TIP_OF_THE_SPEAR) or FALLBACK_ICON
    end
    if _G.GetSpellTexture then
        return _G.GetSpellTexture(TIP_OF_THE_SPEAR) or FALLBACK_ICON
    end
    return FALLBACK_ICON
end

-- From Core.lua:
if C_SpecializationInfo and C_SpecializationInfo.GetSpecialization then
    spec = C_SpecializationInfo.GetSpecialization()
elseif GetSpecialization then
    spec = GetSpecialization()
end
```

A `FALLBACK_ICON` constant (`132275`) is defined so icon resolution always returns something valid.

## Module Registration Pattern

Modules self-register at end of file:
```lua
-- End of Modules/TipOfTheSpear.lua:
DMX:RegisterModule("tip", Tip)
```

`DMX:RegisterModule` also calls `module:Initialize(DMX)` if the core is already ready, enabling late-loading of modules.

## Idempotency Guards

Long-lived objects use an `initialized` flag to prevent double-initialization:
```lua
function Tip:Initialize(core)
    if self.initialized then return end
    self.initialized = true
    ...
end

function Options:Initialize()
    if self.initialized then return end
    self.initialized = true
    ...
end
```

Frame creation uses "ensure" functions for the same reason:
```lua
local function EnsureFrame()
    if root then return end
    root = CreateFrame(...)
    ...
end

local function EnsureBorders(parent)
    if borders.top then return end
    ...
end
```

## Combat Safety

The addon enforces a strict rule: **no settings changes or window opens in combat**. This is checked via `InCombatLockdown()` at every UI entry point:

```lua
function Options:CanChange()
    if InCombat() then
        DMX:Print("Settings cannot be opened or changed in combat.")
        return false
    end
    return true
end
```

The options window closes itself on `PLAYER_REGEN_DISABLED`.

## Comments

**Inline comments** (`-- text`) are used sparingly — only for data annotations where the value alone is ambiguous:
```lua
local CONSUMERS = {
    [1261193] = true, -- Boomstick
    [1250646] = true, -- Takedown
    [259495] = true,  -- Wildfire Bomb
    [186270] = true,  -- Raptor Strike
    [1262293] = true, -- Raptor Swipe
}
```

**No block comments, no function-level docstrings.** Code is intended to be self-documenting through clear naming. Design rationale lives in `DEVELOPMENT_NOTES.md`, not inline.

## Logging

**Single output mechanism:** `DMX:Print(message)` — writes to `DEFAULT_CHAT_FRAME` with the addon name prefix in green (`|cffaad372Duncedmaxxing|r`).

All user-facing messages go through `DMX:Print`. There is no debug logging, no file logging.

---

*Convention analysis: 2026-06-17*
