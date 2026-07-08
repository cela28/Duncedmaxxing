# Phase 1: Utility Extraction and Module Encapsulation - Research

**Researched:** 2026-06-17
**Domain:** Lua 5.1 / WoW Addon refactoring — pure code structure changes, no external packages
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**D-01:** Extract exactly 4 functions to `Duncedmaxxing/Util.lua`: `Clamp`, `ParseHexColor`, `Trim`, `ParseOnOff`. Do NOT include `ToByte`, `ColorToHex`, `CopyDefaults`, or `MergeDefaults` — those are single-file helpers, not shared utilities.

**D-02:** Expose utilities as `DMX.Util.Clamp`, `DMX.Util.ParseHexColor`, `DMX.Util.Trim`, `DMX.Util.ParseOnOff` (namespaced under a `Util` table on DMX).

**D-03:** Consumer files that use utilities frequently should assign local aliases at file top: `local Clamp = DMX.Util.Clamp`. This is standard WoW addon practice — keeps call sites clean and avoids double table lookup overhead.

**D-04:** The canonical `ParseHexColor` uses the Trim-based approach from Core.lua (`Trim(value)` at entry), NOT the `tostring(value or "")` approach from Options.lua. This keeps nil-handling consistent with how Trim is used everywhere else.

**D-05:** `Util.lua` must be listed in the TOC before `Core.lua` so utilities are available when Core loads.

**D-06:** Move all 5 module-level frame locals (`root`, `pips`, `borders`, `label`, `numberText`) from bare upvalues in TipOfTheSpear.lua to `Tip.root`, `Tip.pips`, `Tip.borders`, `Tip.label`, `Tip.numberText` fields on the Tip table.

**D-07:** `EnsureFrame()` writes frames directly to `self.root`, `self.pips`, etc. — clean ownership model where EnsureFrame creates frames and stores them on self.

**D-08:** Hot-path functions (`Update`, `RefreshLayout`) create local aliases at function entry: `local root, pips = self.root, self.pips`. This preserves Lua 5.1 local-access performance (~30% faster than table field reads) for combat-frequency code paths.

**D-09:** Maintain a `moduleOrder` array that appends each module key in the order `RegisterModule` is called. Since the TOC controls file load order and `RegisterModule` is called at file parse time, the order is deterministic from the TOC declaration — no explicit priority parameter needed.

**D-10:** `ForEachModule` iterates `moduleOrder` (the ordered array) instead of using `pairs(self.modules)`.

**D-11:** Remove the `pcall` wrapper from `ClassifySpellID`. It performs a pure table lookup and equality check — neither can raise a Lua error. Return directly from the function body.

### Claude's Discretion

None stated.

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| QUAL-01 | Shared utility functions (Clamp, ParseHexColor, Trim, ParseOnOff) extracted to Duncedmaxxing/Util.lua loaded before Core.lua and Options.lua via TOC order | Full source audit completed — all 4 definitions and all call sites identified |
| QUAL-02 | Module-level frame locals (root, pips, borders, label, numberText) moved to Tip table fields (Tip.root, Tip.pips, etc.) | All bare upvalue references catalogued; private function migration strategy documented |
| QUAL-04 | ForEachModule uses ordered moduleOrder array instead of unordered pairs iteration | Current implementation at Core.lua:157 confirmed; change is minimal and self-contained |
| QUAL-05 | Unnecessary pcall wrapper removed from ClassifySpellID — pure table lookup needs no error protection | ClassifySpellID at TipOfTheSpear.lua:56-69 confirmed; clean replacement pattern documented |
</phase_requirements>

---

## Summary

This phase is a pure Lua refactor with no external dependencies, no new packages, and no runtime environment changes. Every change is a code-structure improvement inside the three existing source files plus one new file.

The four work streams are independent and can be planned as separate tasks executed sequentially or (with care) in parallel. QUAL-01 (Util.lua extraction) creates no new API surface visible outside the addon — it just moves definitions that already exist. QUAL-02 (frame reference migration) is the largest and most surgical change, requiring updates to both private helper functions and Tip methods throughout TipOfTheSpear.lua. QUAL-04 (moduleOrder) is a small addition to Core.lua with no observable behavior change given the current single-module state. QUAL-05 (pcall removal) is a three-line simplification.

**Primary recommendation:** Implement in dependency order — QUAL-01 first (Util.lua creates the shared table consumers depend on), then QUAL-02 (self-contained within TipOfTheSpear.lua), then QUAL-04 and QUAL-05 together (both are small Core.lua / TipOfTheSpear.lua edits with no interdependency).

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Shared utility functions | New Util.lua module | DMX namespace table | Functions used by Core.lua AND Options.lua must live in a file loaded before both |
| Frame reference ownership | TipOfTheSpear.lua (Tip table) | — | Frames are created, owned, and used exclusively by the Tip module |
| Module dispatch ordering | Core.lua (DMX namespace) | — | RegisterModule and ForEachModule are Core.lua responsibilities |
| Error-protection decisions | TipOfTheSpear.lua (call site) | — | pcall use is a per-function decision at the implementation site |

---

## Standard Stack

This phase installs no packages. The stack is the existing WoW addon runtime: Lua 5.1, WoW Widget API, TOC file loading. No `npm`, `pip`, or `cargo` commands.

**No Package Legitimacy Audit required** — this phase adds no external dependencies.

---

## Architecture Patterns

### System Architecture Diagram

```
TOC load order (controls availability at file-parse time):
  Util.lua      → populates DMX.Util.{Clamp,ParseHexColor,Trim,ParseOnOff}
       ↓
  Core.lua      → reads DMX.Util.*; local aliases at file top
                  initializes DMX.moduleOrder = {}
       ↓
  Options.lua   → reads DMX.Util.*; local aliases at file top
       ↓
  Modules/TipOfTheSpear.lua
                → Tip table owns all frame refs (Tip.root, Tip.pips, etc.)
                → DMX:RegisterModule("tip", Tip) appends to DMX.moduleOrder
                       ↓
              ADDON_LOADED fires
                → DMX:ForEachModule("Initialize", DMX)
                   iterates DMX.moduleOrder (ordered array, not pairs)
```

Data flow for utilities is one-way: Util.lua writes to the shared namespace; consumers read from it via local aliases.

### Recommended Project Structure

```
Duncedmaxxing/
├── Util.lua                    # NEW: shared utilities (4 functions)
├── Core.lua                    # MODIFIED: remove 4 utility defs, add local aliases, add moduleOrder
├── Options.lua                 # MODIFIED: remove 2 utility defs, add local aliases
├── Modules/
│   └── TipOfTheSpear.lua       # MODIFIED: frame refs → Tip fields, pcall removal
└── Duncedmaxxing.toc           # MODIFIED: add Util.lua as first entry
```

### Pattern 1: Util.lua New File

```lua
-- Source: WoW addon namespace convention (established codebase pattern)
local _, DMX = ...

DMX.Util = {}

local Util = DMX.Util

local function Trim(text)
    return (text or ""):match("^%s*(.-)%s*$")
end

local function Clamp(value, minValue, maxValue)
    value = tonumber(value)
    if not value then return nil end
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local function ParseOnOff(value)
    value = string.lower(Trim(value))
    if value == "on" or value == "true" or value == "1" or value == "yes" then
        return true
    elseif value == "off" or value == "false" or value == "0" or value == "no" then
        return false
    end
end

local function ParseHexColor(value)
    value = Trim(value):gsub("^#", "")
    if not value:match("^[0-9a-fA-F]+$") or (#value ~= 6 and #value ~= 8) then
        return nil
    end
    local r = tonumber(value:sub(1, 2), 16) / 255
    local g = tonumber(value:sub(3, 4), 16) / 255
    local b = tonumber(value:sub(5, 6), 16) / 255
    local a = (#value == 8) and (tonumber(value:sub(7, 8), 16) / 255) or 1
    return { r = r, g = g, b = b, a = a }
end

Util.Trim = Trim
Util.Clamp = Clamp
Util.ParseOnOff = ParseOnOff
Util.ParseHexColor = ParseHexColor
```

Key details:
- `local _, DMX = ...` — same vararg pattern as every other file (decision D-05 means Util.lua loads first in TOC, so DMX may not yet have any methods, but that's fine — we only need the table reference to attach `Util` to it)
- `DMX.Util = {}` created before functions are defined so `local Util = DMX.Util` alias works
- Functions are `local` first, then assigned to `Util` table — this matches the project's PascalCase local-function convention
- `ParseHexColor` uses the Trim-based nil-handling from Core.lua per D-04 (not the `tostring(value or "")` pattern from Options.lua) [VERIFIED: source audit of both implementations]

### Pattern 2: TOC Entry Order

```
## Interface: 120005
## ...
## SavedVariables: DuncedmaxxingDB

Util.lua
Core.lua
Options.lua
Modules\TipOfTheSpear.lua
```

`Util.lua` inserted as the first file entry. TOC file entries use no leading path — same convention as the existing `Core.lua` and `Options.lua` entries. [VERIFIED: inspection of Duncedmaxxing/Duncedmaxxing.toc]

### Pattern 3: Consumer File Local Aliases (D-03)

At the top of Core.lua (after the `local addonName, DMX = ...` line, before any function definitions):

```lua
local addonName, DMX = ...

-- Util.lua is loaded first in TOC; DMX.Util is guaranteed populated here
local Clamp       = DMX.Util.Clamp
local ParseHexColor = DMX.Util.ParseHexColor
local Trim        = DMX.Util.Trim
local ParseOnOff  = DMX.Util.ParseOnOff
```

Same pattern at the top of Options.lua (only `Clamp` and `ParseHexColor` are used there — `Trim` and `ParseOnOff` are not called in Options.lua):

```lua
local _, DMX = ...

local Clamp       = DMX.Util.Clamp
local ParseHexColor = DMX.Util.ParseHexColor
```

**Important:** The local duplicate definitions of `Clamp` (Options.lua:17-23) and `ParseHexColor` (Options.lua:25-36) must be REMOVED. The local aliases above replace them entirely. [VERIFIED: source audit]

In Core.lua, the four local function definitions at lines 38-70 must also be removed. The local aliases provide the same binding. [VERIFIED: source audit of Core.lua:38-70]

### Pattern 4: Frame Reference Migration — the Private Function Problem [ASSUMED]

This is the most nuanced change in the phase. The five frame locals (`root`, `pips`, `borders`, `label`, `numberText`) are declared at module scope (TipOfTheSpear.lua:32-36) and accessed by TWO categories of code:

**Category A — Tip methods** (have `self`): `RefreshLayout`, `Update`, `ApplyLock`, `ResetPosition`, `Initialize`

**Category B — private local functions** (do NOT have `self`): `ApplyPosition`, `SavePosition`, `EnsureBorders`, `LayoutBorders`, `SetBordersShown`, `EnsureFrame`

Decision D-07 says `EnsureFrame()` writes to `self.root`, etc. This means `EnsureFrame` must receive `self` as a parameter. The same applies to all Category B functions that access frame upvalues.

**Recommended approach per decisions D-07 and D-08:**

Convert each Category B function to accept `tip` (the Tip table) as its first parameter:

```lua
local function EnsureFrame(tip)
    if tip.root then return end

    tip.root = CreateFrame("Frame", "Duncedmaxxing_TipOfTheSpear", UIParent)
    tip.root:SetFrameStrata("MEDIUM")
    tip.root:SetFrameLevel(20)
    tip.root:SetClampedToScreen(true)
    EnsureBorders(tip)

    tip.pips = {}
    for i = 1, MAX_STACKS do
        tip.pips[i] = CreatePip(tip.root)
    end

    tip.label = tip.root:CreateFontString(nil, "OVERLAY")
    -- ...etc

    tip.borders = {}
    -- ...etc
end

local function EnsureBorders(tip)
    if tip.borders and tip.borders.top then return end
    tip.borders = {}
    tip.borders.top = CreateBorder(tip.root)
    -- ...etc
end

local function ApplyPosition(tip)
    if not tip.root then return end
    local cfg = GetCfg()
    tip.root:ClearAllPoints()
    tip.root:SetPoint("CENTER", UIParent, "CENTER", cfg.x or 0, cfg.y or -160)
end

local function SavePosition(tip)
    if not tip.root then return end
    -- ...uses tip.root
    ApplyPosition(tip)
end

local function LayoutBorders(tip, width, height, borderSize, segmentWidths)
    -- uses tip.borders.top, tip.borders.bottom, etc. and tip.root
end

local function SetBordersShown(tip, shown)
    for _, border in pairs(tip.borders) do
        -- ...
    end
end
```

Then in Tip methods, callers pass `self`:

```lua
function Tip:RefreshLayout()
    EnsureFrame(self)
    local root, pips, numberText = self.root, self.pips, self.numberText   -- D-08 local aliases
    -- ...
    SetBordersShown(self, false)
    LayoutBorders(self, width, height, borderSize, segmentWidths)
    ApplyPosition(self)
end

function Tip:Update()
    EnsureFrame(self)
    local root, pips, label, numberText = self.root, self.pips, self.label, self.numberText
    -- ...
    SetBordersShown(self, drawShell and hasBorder)
end

function Tip:ApplyLock()
    if not self.root then return end
    local root, label = self.root, self.label
    -- ...
end
```

The `OnDragStop` script closure inside `EnsureFrame` calls `SavePosition`. After migration, it must pass `tip` (the Tip table captured at `EnsureFrame` call time):

```lua
tip.root:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    SavePosition(tip)   -- tip is the Tip table, self is the WoW frame
end)
```

Note: the `self` variable name collision — WoW frame scripts use `self` to refer to the frame. Inside closures within `EnsureFrame(tip)`, use `tip` for the Tip module table to avoid shadowing the WoW frame `self` argument. [ASSUMED — this naming guidance follows from the existing codebase pattern where frame script closures already use `self` for the WoW frame]

**`pips` initialization:** The current code declares `local pips = {}` at module scope and then does `pips[i] = CreatePip(root)`. After migration, `Tip.pips` must be initialized as an empty table before the loop — `tip.pips = {}` inside `EnsureFrame` before the loop. [VERIFIED: source audit of TipOfTheSpear.lua:33, 301-303]

**`borders` initialization:** Same — `Tip.borders = {}` must be initialized inside `EnsureFrame`/`EnsureBorders`. The current `EnsureBorders` idempotency guard checks `if borders.top then return end` — after migration it checks `if tip.borders and tip.borders.top then return end`. [VERIFIED: source audit of TipOfTheSpear.lua:191-199]

### Pattern 5: ClassifySpellID After pcall Removal

Before (TipOfTheSpear.lua:56-70):
```lua
local function ClassifySpellID(value)
    local ok, kind = pcall(function()
        if value == KILL_COMMAND then
            return "generator"
        end
        if type(value) == "number" and CONSUMERS[value] then
            return "consumer"
        end
    end)
    if ok then
        return kind
    end
end
```

After (D-11):
```lua
local function ClassifySpellID(value)
    if value == KILL_COMMAND then
        return "generator"
    end
    if type(value) == "number" and CONSUMERS[value] then
        return "consumer"
    end
end
```

No behavior change — the function returns `nil` implicitly when neither branch matches, same as the pcall version returned `nil` when the inner function returned nothing. [VERIFIED: Lua 5.1 behavior — functions return nil implicitly]

### Pattern 6: moduleOrder in Core.lua

Before (Core.lua:7, 140-147, 157-164):
```lua
DMX.modules = DMX.modules or {}

function DMX:RegisterModule(key, module)
    self.modules[key] = module
    -- ...
end

function DMX:ForEachModule(method, ...)
    for _, module in pairs(self.modules) do
        local fn = module[method]
        if fn then fn(module, ...) end
    end
end
```

After (D-09, D-10):
```lua
DMX.modules = DMX.modules or {}
DMX.moduleOrder = DMX.moduleOrder or {}

function DMX:RegisterModule(key, module)
    self.modules[key] = module
    module.key = key
    table.insert(self.moduleOrder, key)

    if self.ready and module.Initialize then
        module:Initialize(self)
    end
end

function DMX:ForEachModule(method, ...)
    for _, key in ipairs(self.moduleOrder) do
        local module = self.modules[key]
        local fn = module and module[method]
        if fn then fn(module, ...) end
    end
end
```

The `DMX.moduleOrder = DMX.moduleOrder or {}` guard mirrors the existing `DMX.modules = DMX.modules or {}` pattern (which protects against re-loading). [VERIFIED: source audit of Core.lua:7]

### Anti-Patterns to Avoid

- **Do not add `Trim` to Options.lua aliases if it is not called there.** Grepping confirms `Trim` is not called anywhere in Options.lua — only `Clamp` and `ParseHexColor` are used. Adding an unused alias introduces dead code.
- **Do not leave the old local function definitions in Core.lua and Options.lua.** If both the old `local function Clamp` and the new `local Clamp = DMX.Util.Clamp` exist in the same file, Lua will shadow the alias with the local function declaration — the Util version will never be reached. Remove old definitions before or simultaneously with adding aliases.
- **Do not use `pairs` in the new `ForEachModule`.** The fix is specifically to use `ipairs` over `moduleOrder`, which guarantees insertion order. Using `pairs` on `moduleOrder` would still be non-deterministic.
- **Do not convert `ClampStacks` to `DMX.Util.ClampStacks`.** Decision D-01 explicitly excludes it. `ClampStacks` is TipOfTheSpear-private (stacks clamped 0–MAX_STACKS) — it is not a general-purpose utility.
- **Do not convert the private helper functions to Tip methods.** They do not need to be on the public Tip interface. Passing `tip` as a parameter to private local functions keeps them private and avoids polluting `Tip`'s method table.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| TOC load ordering | Custom lazy-load scheme | TOC file declaration order | WoW client guarantees file execution in TOC order — this is the correct and only mechanism |
| Lua module namespacing | Custom require shim | DMX namespace table via vararg | WoW Lua 5.1 sandbox has no `require`; the vararg pattern is the established addon idiom |
| Ordered iteration | Custom sort function | `table.insert` + `ipairs` | Simple insertion-order array is sufficient and idiomatic Lua 5.1 |

---

## Runtime State Inventory

Step 2.5: SKIPPED — this is not a rename/refactor/migration of stored data or runtime system names. The changes are purely structural code edits. No saved variables keys change. No WoW SavedVariables content is affected. `DuncedmaxxingDB` schema is unchanged.

---

## Common Pitfalls

### Pitfall 1: Lua File-Scope Shadow of DMX.Util Alias
**What goes wrong:** A consumer file retains the old `local function Clamp(...)` definition AND adds `local Clamp = DMX.Util.Clamp`. Lua's scoping rules mean whichever declaration appears later in the file shadows the earlier one. If the old function definition is below the new alias, the function definition wins — meaning call sites inside that function's closure still call the OLD function. If the alias is below the function definition, the alias wins but the function definition is dead code (and a luacheck warning).
**Why it happens:** Forgetting to remove the old definition when adding the alias.
**How to avoid:** Remove the old `local function` definition in the same edit that adds the `local Alias = DMX.Util.X` binding. Never have both in the same file.
**Warning signs:** luacheck reports "unused variable" or "variable shadowed" for Clamp/ParseHexColor in Core.lua or Options.lua after the change.

### Pitfall 2: EnsureFrame Called Before DMX.db is Populated
**What goes wrong:** `EnsureFrame` creates WoW frames. The migration to `self.*` means `EnsureFrame(self)` is called from `Tip:Initialize` and from `Tip:Update` / `Tip:RefreshLayout`. If `Update` is somehow called before `Initialize` (e.g. from a timer that fired before ADDON_LOADED completes), `self.root` would be nil and frames would not be created yet.
**Why it happens:** `EnsureFrame` is an idempotency guard — it is designed to create frames exactly once on first call. This is unchanged. The risk is if the guard check `if tip.root then return end` runs correctly.
**How to avoid:** The guard check moves from `if root then return end` to `if tip.root then return end`. These are equivalent. No behavioral change — only the variable name changes. Verify the guard is the first line of `EnsureFrame(tip)`.
**Warning signs:** Multiple WoW frames named `"Duncedmaxxing_TipOfTheSpear"` in the UI hierarchy, or nil errors from `tip.root:Show()` on first Update call.

### Pitfall 3: OnDragStop Closure Captures Wrong `self`
**What goes wrong:** Inside `EnsureFrame(tip)`, WoW frame script closures use the parameter name `self` to receive the WoW frame object. After migration, if the `SavePosition` call inside `OnDragStop` tries to use `self` meaning "the Tip table", it will instead receive the WoW frame.
**Why it happens:** Name collision between WoW script callback convention (`self` = frame) and the Tip module convention (`self` = Tip table).
**How to avoid:** Inside `EnsureFrame(tip)`, the outer parameter is `tip` (not `self`). Frame script closures use `self` for the WoW frame. Call `SavePosition(tip)` — using the outer variable `tip`, not the inner `self`. The existing code already calls `SavePosition()` with no args; just change the call to `SavePosition(tip)`.
**Warning signs:** Error "attempt to call field 'GetCenter' (a nil value)" or "attempt to index a nil value" from within `SavePosition` — indicates `tip.root` is nil because `tip` is actually the WoW frame.

### Pitfall 4: `pips` Table Not Initialized Before Loop in EnsureFrame
**What goes wrong:** The current module-level `local pips = {}` initializes the pips table at file load time. After migration, `tip.pips` does not exist until `EnsureFrame(tip)` creates it. If `EnsureFrame` does `tip.pips[i] = CreatePip(tip.root)` without first doing `tip.pips = {}`, Lua will error "attempt to index a nil value (field 'pips')".
**Why it happens:** The module-level table initializer is removed when the upvalue is removed.
**How to avoid:** Add `tip.pips = {}` and `tip.borders = {}` at the start of frame creation in `EnsureFrame(tip)`, before any indexed assignment.
**Warning signs:** Lua error on first `/reload ui` containing "attempt to index a nil value (field 'pips')".

### Pitfall 5: `EnsureBorders` Idempotency Guard Breaks
**What goes wrong:** `EnsureBorders` currently guards with `if borders.top then return end`. After migration, if `tip.borders` is `nil` (not yet initialized), `tip.borders.top` will error "attempt to index a nil value".
**Why it happens:** Moving from a module-level `local borders = {}` (always a table, even before population) to a `tip.borders` field that starts as nil.
**How to avoid:** Two options — (a) initialize `tip.borders = {}` in `EnsureFrame(tip)` before calling `EnsureBorders(tip)`, so `tip.borders` is always a table when `EnsureBorders` is called; or (b) change the guard to `if tip.borders and tip.borders.top then return end`. Option (a) is cleaner because it preserves the table initialization in one place.
**Warning signs:** Lua error "attempt to index a nil value (field 'borders')" on first `/reload ui`.

### Pitfall 6: Options.lua ToByte/ColorToHex Use Their Local Clamp
**What goes wrong:** `ToByte` in Options.lua (line 39) calls the local `Clamp`. After migration, the local `Clamp` definition is removed and replaced with `local Clamp = DMX.Util.Clamp`. This is correct and transparent — `ToByte` calls whatever `Clamp` resolves to in its scope. No issue IF the alias is at file scope and `ToByte` is defined after the alias.
**Why it happens:** Could become an issue if the alias is placed after `ToByte`'s definition. In Options.lua, `ToByte` is at line 39 and local declarations happen at file top (lines 1-16 currently).
**How to avoid:** Place the `local Clamp = DMX.Util.Clamp` alias at the top of Options.lua, before any function definitions. The existing `local function Clamp` is at line 17, `ToByte` at line 39 — so placing the new alias at lines 3-5 (after `local _, DMX = ...` and `local Options = {}`) is correct.
**Warning signs:** `ColorToHex` returns unexpected values or nil — indicating `Clamp` in `ToByte` is resolving to nil.

---

## Code Examples

### Current ClassifySpellID (TipOfTheSpear.lua:56-70) — remove pcall

```lua
-- BEFORE (current)
local function ClassifySpellID(value)
    local ok, kind = pcall(function()
        if value == KILL_COMMAND then return "generator" end
        if type(value) == "number" and CONSUMERS[value] then return "consumer" end
    end)
    if ok then return kind end
end

-- AFTER (D-11)
local function ClassifySpellID(value)
    if value == KILL_COMMAND then return "generator" end
    if type(value) == "number" and CONSUMERS[value] then return "consumer" end
end
```

### Current EnsureFrame (TipOfTheSpear.lua:292-326) — migration to self

```lua
-- BEFORE: uses module-level upvalues root, pips, label, numberText, borders
local function EnsureFrame()
    if root then return end
    root = CreateFrame("Frame", "Duncedmaxxing_TipOfTheSpear", UIParent)
    -- ...
    EnsureBorders(root)
    for i = 1, MAX_STACKS do pips[i] = CreatePip(root) end
    label = root:CreateFontString(...)
    numberText = root:CreateFontString(...)
    root:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition()
    end)
end

-- AFTER: takes tip parameter, writes to tip.*
local function EnsureFrame(tip)
    if tip.root then return end
    tip.root = CreateFrame("Frame", "Duncedmaxxing_TipOfTheSpear", UIParent)
    -- ...
    tip.pips = {}
    tip.borders = {}
    EnsureBorders(tip)
    for i = 1, MAX_STACKS do tip.pips[i] = CreatePip(tip.root) end
    tip.label = tip.root:CreateFontString(...)
    tip.numberText = tip.root:CreateFontString(...)
    tip.root:SetScript("OnDragStop", function(self)  -- self = WoW frame here
        self:StopMovingOrSizing()
        SavePosition(tip)  -- tip = Tip module table, captured from outer scope
    end)
end
```

### Update / RefreshLayout — local alias pattern for hot path (D-08)

```lua
function Tip:Update()
    EnsureFrame(self)
    local root      = self.root       -- D-08: local alias for hot-path performance
    local pips      = self.pips
    local label     = self.label
    local numberText = self.numberText

    -- all subsequent references use local root, pips, label, numberText
    -- (no self.root, self.pips inside this function body)
    root:Show()
    -- ...
end

function Tip:RefreshLayout()
    EnsureFrame(self)
    local root      = self.root
    local pips      = self.pips
    local numberText = self.numberText

    -- ...
    SetBordersShown(self, false)   -- pass self for borders access
    LayoutBorders(self, width, height, borderSize, segmentWidths)
    ApplyPosition(self)
end
```

### ApplyLock — thin method, local alias optional

```lua
-- BEFORE
function Tip:ApplyLock()
    if not root then return end
    local unlocked = not DMX:GetDB().locked
    root:EnableMouse(unlocked)
    root:SetMovable(unlocked)
    label:SetShown(unlocked)
end

-- AFTER
function Tip:ApplyLock()
    if not self.root then return end
    local root, label = self.root, self.label
    local unlocked = not DMX:GetDB().locked
    root:EnableMouse(unlocked)
    root:SetMovable(unlocked)
    label:SetShown(unlocked)
end
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Duplicate utility definitions per file | Single definition in Util.lua, aliases in consumers | This phase | Bug fixes propagate to all consumers; test coverage covers one implementation |
| Module-level upvalue frame locals (not testable) | Tip table fields (accessible externally for testing) | This phase | Phase 2 test suite can read Tip.root, Tip.pips, etc. for assertions |
| Arbitrary-order ForEachModule | Insertion-order moduleOrder array | This phase | Initialization, ApplyLock, and future cross-module calls execute deterministically |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Private local functions (`ApplyPosition`, `SavePosition`, `EnsureBorders`, `LayoutBorders`, `SetBordersShown`, `EnsureFrame`) should receive `tip` as a parameter rather than being converted to Tip methods | Architecture Patterns, Pattern 4 | If converted to methods instead, the public Tip API grows unnecessarily; but no functional risk |
| A2 | `Trim` and `ParseOnOff` are NOT used in Options.lua — only `Clamp` and `ParseHexColor` need aliases there | Pattern 3 | If wrong: Options.lua would call a nil function at runtime; easy to fix by adding missing alias |

**Verification for A2:** Confirmed by grep — `Trim` and `ParseOnOff` do not appear anywhere in Options.lua (grepped all 478 lines). [VERIFIED: source audit]

**Verification for A1:** The decisions explicitly say `EnsureFrame()` writes to `self.root`, etc. (D-07) and hot-path methods create local aliases (D-08). The natural implementation of D-07 when `EnsureFrame` is a private local function is to pass `tip` as a parameter. This is consistent with the decision text. [CITED: 01-CONTEXT.md D-07]

---

## Open Questions (RESOLVED)

1. **Should `EnsureFrame` and the other private helpers also clear the module-level upvalue declarations?**
   - What we know: The five `local` declarations at TipOfTheSpear.lua:32-36 (`local root`, `local pips = {}`, etc.) become unused after migration. They should be removed.
   - What's unclear: Whether leaving them as declared-but-never-written locals would cause luacheck warnings or any runtime issue.
   - Recommendation: Remove all five module-level upvalue declarations as part of the migration. Dead upvalues add confusion and luacheck noise.

2. **Does `LayoutBorders` need `tip` passed for `root` references inside it?**
   - What we know: `LayoutBorders` at TipOfTheSpear.lua:207-242 references `root` 10 times and `borders.*` 12 times.
   - What's unclear: Whether to change the signature to `LayoutBorders(tip, width, height, borderSize, segmentWidths)` or to `LayoutBorders(root, borders, width, height, borderSize, segmentWidths)`.
   - Recommendation: Pass `tip` as the first argument (consistent with the pattern for all other private helpers). The function body then uses `tip.root` and `tip.borders.*` — or creates local aliases at entry for brevity.

---

## Environment Availability

Step 2.6: SKIPPED — this phase makes no use of external tools, services, CLIs, databases, or package managers. All changes are edits to `.lua` and `.toc` files that are loaded by the WoW client. No environment probe is needed.

---

## Validation Architecture

`nyquist_validation` is `true` in config.json.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | None — Phase 2 installs busted. Phase 1 has no automated tests. |
| Config file | None yet |
| Quick run command | Manual: `/reload ui` in-game, observe no Lua errors |
| Full suite command | Manual: Exercise all display modes and slash commands post-reload |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| QUAL-01 | `DMX.Util.Clamp`, `DMX.Util.ParseHexColor`, `DMX.Util.Trim`, `DMX.Util.ParseOnOff` exist and are callable after `/reload ui`; no duplicate definitions remain | manual-only | `/reload ui` then `/run print(DMX.Util.Clamp(5,0,10))` | — Phase 2 |
| QUAL-02 | `Tip.root`, `Tip.pips`, `Tip.label`, `Tip.numberText`, `Tip.borders` exist and are non-nil after initialize; display renders correctly | manual-only | `/reload ui`, verify tracker displays | — Phase 2 |
| QUAL-04 | `DMX.moduleOrder` is a table with `"tip"` as its first entry | manual-only | `/run print(DMX.moduleOrder[1])` should print `tip` | — Phase 2 |
| QUAL-05 | No `pcall` in `ClassifySpellID`; code review confirms removal | code review | — | — Phase 2 |

**Note:** Phase 2 will install busted and create `spec/` directory. Phase 1 has no test harness. Validation is in-game smoke testing only.

### Sampling Rate
- **Per task commit:** Manual `/reload ui` with no Lua errors
- **Per wave merge:** Full in-game smoke: all display modes (bar, icons, number), slash commands (`/dmax test`, `/dmax scale`, `/dmax color`, `/dmax mode`, `/dmax border`), options window open/close
- **Phase gate:** All five success criteria from phase description must pass before `/gsd:verify-work`

### Wave 0 Gaps
None — no test infrastructure is being set up in this phase. Phase 2 owns the busted setup.

---

## Security Domain

WoW addon context. No network calls, no authentication, no user data beyond local SavedVariables. ASVS categories V2-V6 do not apply. This phase makes no changes to data handling.

---

## Sources

### Primary (HIGH confidence)
- `Duncedmaxxing/Core.lua` — direct source inspection, all function definitions and call sites
- `Duncedmaxxing/Options.lua` — direct source inspection, duplicate utility definitions confirmed
- `Duncedmaxxing/Modules/TipOfTheSpear.lua` — direct source inspection, all frame upvalue references, ClassifySpellID, EnsureFrame
- `Duncedmaxxing/Duncedmaxxing.toc` — direct inspection, current load order confirmed
- `.planning/phases/01-utility-extraction-and-module-encapsulation/01-CONTEXT.md` — locked decisions D-01 through D-11

### Secondary (MEDIUM confidence)
- `.planning/codebase/ARCHITECTURE.md` — architecture analysis performed 2026-06-17
- `.planning/codebase/CONCERNS.md` — tech debt audit, root cause confirmation for each requirement
- `.planning/codebase/CONVENTIONS.md` — naming and style patterns

### Tertiary (LOW confidence)
None — all claims are grounded in direct source inspection or the CONTEXT.md locked decisions.

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no external packages; pure Lua edits to known files
- Architecture: HIGH — all affected lines identified by direct grep and read
- Pitfalls: HIGH — derived from direct analysis of the exact code paths being changed

**Research date:** 2026-06-17
**Valid until:** Indefinite — source files are stable; no upstream API changes affect this phase
