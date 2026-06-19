# Phase 1: Utility Extraction and Module Encapsulation - Pattern Map

**Mapped:** 2026-06-17
**Files analyzed:** 5 (1 new, 4 modified)
**Analogs found:** 5 / 5

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `Duncedmaxxing/Util.lua` | utility | transform | `Duncedmaxxing/Core.lua` lines 38-70 | source-extract |
| `Duncedmaxxing/Core.lua` | config/registry | request-response | itself (targeted edits) | self |
| `Duncedmaxxing/Options.lua` | component | request-response | itself (targeted edits) | self |
| `Duncedmaxxing/Modules/TipOfTheSpear.lua` | module/component | event-driven | itself (targeted edits) | self |
| `Duncedmaxxing/Duncedmaxxing.toc` | config | — | itself (single-line insert) | self |

---

## Pattern Assignments

### `Duncedmaxxing/Util.lua` (NEW utility, transform)

**Analog:** `Duncedmaxxing/Core.lua` lines 1-7 (namespace bootstrap) + lines 38-70 (function definitions)

**File-open / namespace pattern** (`Core.lua` lines 1-7):
```lua
local addonName, DMX = ...

_G.Duncedmaxxing = DMX

DMX.name = addonName
DMX.version = "0.3.2"
DMX.modules = DMX.modules or {}
```
Util.lua uses the same vararg idiom but is simpler — it only needs to attach the `Util` table. Use `local _, DMX = ...` (drop `addonName`, match `Options.lua` line 1 and `TipOfTheSpear.lua` line 1 which also use the underscore form).

**Core utility definitions to extract verbatim** (`Core.lua` lines 38-70):
```lua
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
```
Note: Use the `Core.lua` version of `ParseHexColor` (Trim-based nil handling), NOT the `Options.lua` version (lines 25-37) which uses `tostring(value or "")`. Decision D-04 mandates this.

**Namespace attachment pattern** — after all local function definitions, assign to the Util table. Follow the project convention of declaring locals first, then assigning:
```lua
-- (at file top)
local _, DMX = ...
DMX.Util = {}
local Util = DMX.Util

-- (function definitions — see above)

-- (at file bottom)
Util.Trim         = Trim
Util.Clamp        = Clamp
Util.ParseOnOff   = ParseOnOff
Util.ParseHexColor = ParseHexColor
```
This matches the project's module-registration bottom-of-file pattern seen in `TipOfTheSpear.lua` line 770 (`DMX:RegisterModule("tip", Tip)`) and `Options.lua` lines 471-477 (`function DMX:InitializeOptions()` / `function DMX:OpenOptions()`).

**Do NOT include** `ToByte`, `ColorToHex`, `CopyDefaults`, or `MergeDefaults` — decision D-01 explicitly excludes them.

---

### `Duncedmaxxing/Core.lua` (MODIFIED — 3 targeted edits)

**Analog:** itself — read `Core.lua` lines 1-7 and 38-70 and 140-164 for the before state.

#### Edit 1: Remove utility definitions + add local aliases (lines 38-70 → replace)

**Remove** lines 38-70 (the four `local function` definitions of `Trim`, `Clamp`, `ParseOnOff`, `ParseHexColor`).

**Replace with** local aliases after line 1 (`local addonName, DMX = ...`):
```lua
local addonName, DMX = ...

-- Util.lua is loaded first in TOC; DMX.Util is guaranteed populated here
local Clamp        = DMX.Util.Clamp
local ParseHexColor = DMX.Util.ParseHexColor
local Trim         = DMX.Util.Trim
local ParseOnOff   = DMX.Util.ParseOnOff
```
All four call sites in the slash command handler (lines 227, 295-306, 315, 333) continue to work unchanged — the local names are identical.

#### Edit 2: Add `moduleOrder` to DMX initialization (line 7, after `DMX.modules`)

**Current** (`Core.lua` line 7):
```lua
DMX.modules = DMX.modules or {}
```

**After:**
```lua
DMX.modules    = DMX.modules    or {}
DMX.moduleOrder = DMX.moduleOrder or {}
```
The `or {}` guard mirrors the existing `DMX.modules` guard pattern — protects against re-loading.

#### Edit 3: Update `RegisterModule` and `ForEachModule` (lines 140-164)

**Current** (`Core.lua` lines 140-164):
```lua
function DMX:RegisterModule(key, module)
    self.modules[key] = module
    module.key = key

    if self.ready and module.Initialize then
        module:Initialize(self)
    end
end

function DMX:GetModule(key)
    return self.modules[key]
end

function DMX:GetDB()
    return self.db
end

function DMX:ForEachModule(method, ...)
    for _, module in pairs(self.modules) do
        local fn = module[method]
        if fn then
            fn(module, ...)
        end
    end
end
```

**After (only `RegisterModule` and `ForEachModule` change):**
```lua
function DMX:RegisterModule(key, module)
    self.modules[key] = module
    module.key = key
    table.insert(self.moduleOrder, key)

    if self.ready and module.Initialize then
        module:Initialize(self)
    end
end

-- GetModule and GetDB are unchanged

function DMX:ForEachModule(method, ...)
    for _, key in ipairs(self.moduleOrder) do
        local module = self.modules[key]
        local fn = module and module[method]
        if fn then
            fn(module, ...)
        end
    end
end
```
The `ipairs` over `moduleOrder` replaces `pairs` over `self.modules` — this is the fix for QUAL-04. The `module and module[method]` nil-guard in the new version is a defensive addition for future robustness.

---

### `Duncedmaxxing/Options.lua` (MODIFIED — 1 targeted edit)

**Analog:** itself — read `Options.lua` lines 1-37 for the before state.

#### Edit: Remove duplicate utility defs + add local aliases (lines 1-37)

**Remove** lines 17-37: the local `Clamp` (lines 17-23) and local `ParseHexColor` (lines 25-37) definitions.

**Add** local aliases after line 1 (`local _, DMX = ...`) and line 3-4 (`local Options = {} / DMX.Options = Options`):
```lua
local _, DMX = ...

local Options = {}
DMX.Options = Options

local Clamp        = DMX.Util.Clamp
local ParseHexColor = DMX.Util.ParseHexColor
```
`Trim` and `ParseOnOff` are NOT used anywhere in Options.lua — do not add aliases for them (anti-pattern per research: no dead code).

**All call sites remain unchanged:** `Clamp(value, ...)` at lines 286, 294, 302, 312, 320, 329, 337, 345, 351, 357, 390 and `ParseHexColor(value)` at lines 364, 372, 380 — they already use the local name `Clamp` and `ParseHexColor`.

`ToByte` (line 39) calls `Clamp` — it will resolve to `DMX.Util.Clamp` via the new alias. This is correct and transparent as long as the alias appears before `ToByte`'s definition (which it will, since aliases are placed at file top).

---

### `Duncedmaxxing/Modules/TipOfTheSpear.lua` (MODIFIED — 3 targeted edits)

**Analog:** itself — read lines 1-36, 56-70, 140-252, 292-326, 451-548, 581-674, 743-770.

#### Edit 1: Remove module-level upvalue frame locals (lines 32-36)

**Current** (`TipOfTheSpear.lua` lines 32-36):
```lua
local root
local pips = {}
local label
local numberText
local borders = {}
```

**Remove all five lines.** After migration, ownership moves to `Tip.root`, `Tip.pips`, etc. These upvalue declarations become dead code.

#### Edit 2: `ClassifySpellID` — remove pcall (lines 56-70)

**Current** (`TipOfTheSpear.lua` lines 56-70):
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

**After (D-11):**
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
Pure table lookup and equality check — no error possible in Lua 5.1. Implicit `nil` return when neither branch matches is identical behavior to the pcall version.

#### Edit 3: Frame reference migration — private helpers + Tip methods

**Private helper functions (Category B):** `ApplyPosition`, `SavePosition`, `EnsureBorders`, `LayoutBorders`, `SetBordersShown`, `EnsureFrame` — each gains a `tip` first parameter. They do NOT become Tip methods (anti-pattern per research D-01 rationale: keeps private API private).

**`ApplyPosition`** — current lines 146-152, upvalue `root`:
```lua
-- BEFORE
local function ApplyPosition()
    if not root then return end
    local cfg = GetCfg()
    root:ClearAllPoints()
    root:SetPoint("CENTER", UIParent, "CENTER", cfg.x or 0, cfg.y or -160)
end

-- AFTER
local function ApplyPosition(tip)
    if not tip.root then return end
    local cfg = GetCfg()
    tip.root:ClearAllPoints()
    tip.root:SetPoint("CENTER", UIParent, "CENTER", cfg.x or 0, cfg.y or -160)
end
```

**`SavePosition`** — current lines 154-167, upvalues `root` and calls `ApplyPosition()`:
```lua
-- BEFORE
local function SavePosition()
    if not root then return end
    local cfg = GetCfg()
    local centerX, centerY = root:GetCenter()
    local parentX, parentY = UIParent:GetCenter()
    if centerX and centerY and parentX and parentY then
        cfg.x = centerX - parentX
        cfg.y = centerY - parentY
    end
    ApplyPosition()
end

-- AFTER
local function SavePosition(tip)
    if not tip.root then return end
    local cfg = GetCfg()
    local centerX, centerY = tip.root:GetCenter()
    local parentX, parentY = UIParent:GetCenter()
    if centerX and centerY and parentX and parentY then
        cfg.x = centerX - parentX
        cfg.y = centerY - parentY
    end
    ApplyPosition(tip)
end
```

**`EnsureBorders`** — current lines 191-200, upvalue `borders`:
```lua
-- BEFORE
local function EnsureBorders(parent)
    if borders.top then return end
    borders.top    = CreateBorder(parent)
    borders.bottom = CreateBorder(parent)
    borders.left   = CreateBorder(parent)
    borders.right  = CreateBorder(parent)
    borders.divider1 = CreateBorder(parent)
    borders.divider2 = CreateBorder(parent)
end

-- AFTER
local function EnsureBorders(tip)
    if tip.borders and tip.borders.top then return end
    tip.borders          = {}
    tip.borders.top      = CreateBorder(tip.root)
    tip.borders.bottom   = CreateBorder(tip.root)
    tip.borders.left     = CreateBorder(tip.root)
    tip.borders.right    = CreateBorder(tip.root)
    tip.borders.divider1 = CreateBorder(tip.root)
    tip.borders.divider2 = CreateBorder(tip.root)
end
```
The idempotency guard changes from `if borders.top then` to `if tip.borders and tip.borders.top then` — the `and` guard is required because `tip.borders` starts as nil (pitfall 5).

**`LayoutBorders`** — current lines 207-242, upvalues `borders` and `root`:
```lua
-- BEFORE signature
local function LayoutBorders(width, height, borderSize, segmentWidths)
    -- uses borders.* and root directly

-- AFTER signature
local function LayoutBorders(tip, width, height, borderSize, segmentWidths)
    -- all borders.* become tip.borders.*, all root become tip.root
    if borderSize <= 0 then
        for _, border in pairs(tip.borders) do
            border:Hide()
        end
        return
    end

    tip.borders.top:ClearAllPoints()
    tip.borders.top:SetPoint("TOPLEFT", tip.root, "TOPLEFT", 0, 0)
    tip.borders.top:SetSize(width, borderSize)
    -- ... (same pattern for all 6 borders, replacing `root` with `tip.root`)

    for _, border in pairs(tip.borders) do
        PaintBorder(border)
    end
end
```

**`SetBordersShown`** — current lines 244-252, upvalue `borders`:
```lua
-- BEFORE
local function SetBordersShown(shown)
    for _, border in pairs(borders) do
        if shown then border:Show() else border:Hide() end
    end
end

-- AFTER
local function SetBordersShown(tip, shown)
    for _, border in pairs(tip.borders) do
        if shown then border:Show() else border:Hide() end
    end
end
```

**`EnsureFrame`** — current lines 292-326, upvalues `root`, `pips`, `label`, `numberText`, `borders`:
```lua
-- BEFORE
local function EnsureFrame()
    if root then return end
    root = CreateFrame("Frame", "Duncedmaxxing_TipOfTheSpear", UIParent)
    root:SetFrameStrata("MEDIUM")
    root:SetFrameLevel(20)
    root:SetClampedToScreen(true)
    EnsureBorders(root)
    for i = 1, MAX_STACKS do pips[i] = CreatePip(root) end
    label = root:CreateFontString(nil, "OVERLAY")
    label:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    label:SetText("|cffaad372Duncedmaxxing|r")
    label:SetPoint("BOTTOM", root, "TOP", 0, 4)
    numberText = root:CreateFontString(nil, "OVERLAY")
    numberText:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 22, "OUTLINE")
    numberText:SetPoint("CENTER", root, "CENTER", 0, 0)
    numberText:SetText("0")
    numberText:Hide()
    root:RegisterForDrag("LeftButton")
    root:SetScript("OnDragStart", function(self)
        if not DMX:GetDB().locked then self:StartMoving() end
    end)
    root:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition()
    end)
end

-- AFTER
local function EnsureFrame(tip)
    if tip.root then return end
    tip.root = CreateFrame("Frame", "Duncedmaxxing_TipOfTheSpear", UIParent)
    tip.root:SetFrameStrata("MEDIUM")
    tip.root:SetFrameLevel(20)
    tip.root:SetClampedToScreen(true)
    tip.pips = {}
    tip.borders = {}
    EnsureBorders(tip)
    for i = 1, MAX_STACKS do tip.pips[i] = CreatePip(tip.root) end
    tip.label = tip.root:CreateFontString(nil, "OVERLAY")
    tip.label:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    tip.label:SetText("|cffaad372Duncedmaxxing|r")
    tip.label:SetPoint("BOTTOM", tip.root, "TOP", 0, 4)
    tip.numberText = tip.root:CreateFontString(nil, "OVERLAY")
    tip.numberText:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 22, "OUTLINE")
    tip.numberText:SetPoint("CENTER", tip.root, "CENTER", 0, 0)
    tip.numberText:SetText("0")
    tip.numberText:Hide()
    tip.root:RegisterForDrag("LeftButton")
    tip.root:SetScript("OnDragStart", function(self)
        if not DMX:GetDB().locked then self:StartMoving() end
    end)
    tip.root:SetScript("OnDragStop", function(self)   -- self = WoW frame here
        self:StopMovingOrSizing()
        SavePosition(tip)   -- tip = Tip module table, captured from outer scope
    end)
end
```
Key: `tip.pips = {}` and `tip.borders = {}` must be initialized before `EnsureBorders(tip)` is called and before the pips loop — pitfall 4 and 5 prevention. The `OnDragStop` closure uses `tip` (the outer parameter) not `self` (the WoW frame) when calling `SavePosition` — pitfall 3 prevention.

**Tip methods (Category A):** Update all bare upvalue references to `self.*` accesses, and create D-08 local aliases at hot-path function entry.

**`Tip:RefreshLayout`** — current lines 451-538, references `pips`, `root`, `numberText`:
```lua
-- BEFORE
function Tip:RefreshLayout()
    EnsureFrame()
    -- uses bare: pips[i], root, numberText, SetBordersShown(false), LayoutBorders(w,h,b,s)

-- AFTER
function Tip:RefreshLayout()
    EnsureFrame(self)
    local root       = self.root       -- D-08 local alias
    local pips       = self.pips
    local numberText = self.numberText
    -- all pips[i], root, numberText references below use the local aliases
    -- private helper calls gain self as first arg:
    SetBordersShown(self, false)
    LayoutBorders(self, width, height, borderSize, segmentWidths)
    ApplyPosition(self)
    -- self:ApplyLock() and self:Update() are unchanged (method calls)
end
```

**`Tip:Update`** — current lines 581-673, references `root`, `pips`, `numberText`, `label`:
```lua
-- BEFORE
function Tip:Update()
    EnsureFrame()
    -- uses bare: root, pips[i], numberText, label

-- AFTER
function Tip:Update()
    EnsureFrame(self)
    local root       = self.root       -- D-08 local alias
    local pips       = self.pips
    local label      = self.label
    local numberText = self.numberText
    -- all bare references replaced with locals
    -- SetBordersShown(shown) → SetBordersShown(self, shown)
end
```

**`Tip:ApplyLock`** — current lines 540-547, references `root` and `label`:
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

**`Tip:Initialize`** — current lines 743-768, calls `EnsureFrame()`:
```lua
-- BEFORE
function Tip:Initialize(core)
    -- ...
    EnsureFrame()

-- AFTER
function Tip:Initialize(core)
    -- ...
    EnsureFrame(self)
```

---

### `Duncedmaxxing/Duncedmaxxing.toc` (MODIFIED — single-line insert)

**Current** (`Duncedmaxxing.toc` lines 10-12):
```
Core.lua
Options.lua
Modules\TipOfTheSpear.lua
```

**After** (insert `Util.lua` as new first file entry):
```
Util.lua
Core.lua
Options.lua
Modules\TipOfTheSpear.lua
```
TOC entries use no leading path component — same convention as existing `Core.lua` and `Options.lua` entries. `Modules\TipOfTheSpear.lua` uses backslash (Windows path convention for WoW TOC) — do not change it. The metadata block (lines 1-9) is unchanged.

---

## Shared Patterns

### WoW Addon Private Namespace Bootstrap
**Source:** `Duncedmaxxing/Core.lua` line 1, `Duncedmaxxing/Options.lua` line 1, `Duncedmaxxing/Modules/TipOfTheSpear.lua` line 1
**Apply to:** `Duncedmaxxing/Util.lua` (new file)
```lua
local _, DMX = ...
```
Every non-Core file uses the underscore form (discarding `addonName`). Util.lua should follow Options.lua and TipOfTheSpear.lua — use `local _, DMX = ...`, not `local addonName, DMX = ...`.

### Module Table + DMX Attachment Pattern
**Source:** `Duncedmaxxing/Options.lua` lines 3-4, `Duncedmaxxing/Modules/TipOfTheSpear.lua` lines 3
**Apply to:** `Duncedmaxxing/Util.lua`
```lua
-- Options.lua pattern (module table on DMX):
local Options = {}
DMX.Options = Options

-- TipOfTheSpear.lua pattern (module table standalone, registered later):
local Tip = {}
```
For Util.lua, use the Options.lua pattern (attach directly to DMX at declaration): `DMX.Util = {}` then `local Util = DMX.Util`.

### Local Alias for Frequently-Called Table Fields
**Source:** `Duncedmaxxing/Modules/TipOfTheSpear.lua` line 30
**Apply to:** All consumer call sites for `DMX.Util.*`; all hot-path Tip methods for `self.*`
```lua
-- Existing example (TipOfTheSpear.lua line 30):
local GetPlayerAuraBySpellID = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID

-- New pattern (D-03 for Util consumers, D-08 for hot-path Tip methods):
local Clamp = DMX.Util.Clamp     -- file-top alias in Core.lua, Options.lua

local root, pips = self.root, self.pips  -- function-entry alias in Update, RefreshLayout
```

### Idempotency Guard Pattern
**Source:** `Duncedmaxxing/Core.lua` line 7, `Duncedmaxxing/Options.lua` lines 199-201, `Duncedmaxxing/Modules/TipOfTheSpear.lua` lines 292-293
**Apply to:** `EnsureBorders`, `EnsureFrame` after migration; `DMX.moduleOrder` initialization
```lua
-- Core.lua line 7:
DMX.modules = DMX.modules or {}

-- Options.lua lines 199-201:
function Options:BuildWindow()
    if self.window then return end

-- TipOfTheSpear.lua lines 292-293 (EnsureFrame):
local function EnsureFrame()
    if root then return end
```
The `or {}` guard for tables and `if self.X then return end` guard for frame creation are the two established idempotency patterns. Both are preserved after migration — only the variable names change.

### `GetCfg()` Local Helper Pattern
**Source:** `Duncedmaxxing/Modules/TipOfTheSpear.lua` lines 120-122, `Duncedmaxxing/Options.lua` lines 58-61
**Apply to:** No new files need this — it is an existing pattern to preserve, not introduce
```lua
-- TipOfTheSpear.lua:
local function GetCfg()
    return DMX:GetDB().tip
end

-- Options.lua:
local function GetCfg()
    local db = DMX:GetDB()
    return db and db.tip
end
```
Options.lua guards for `db` being nil; TipOfTheSpear.lua does not (assumes Initialize has run). Both patterns are intentional — do not homogenize them in this phase.

### Frame Script `self` vs Module Table Naming
**Source:** `Duncedmaxxing/Options.lua` lines 242-250 (`BuildWindow` OnDragStop closure)
**Apply to:** `EnsureFrame(tip)` OnDragStop closure in TipOfTheSpear.lua
```lua
-- Options.lua lines 247-250:
window:SetScript("OnDragStop", function(self)   -- self = WoW frame
    self:StopMovingOrSizing()
    Options:SavePosition()                       -- Options is the module table (outer var)
end)
```
In Options.lua, `Options` (the module table) is the outer-scope variable captured by the closure — `self` is the WoW frame. The exact same pattern applies to `EnsureFrame(tip)`: `tip` is the outer-scope module table, `self` inside frame scripts is the WoW frame.

---

## No Analog Found

All files in this phase have analogs in the codebase — either as direct sources to extract from or as self-analogs for surgical edits. No file requires falling back to RESEARCH.md patterns exclusively.

---

## Metadata

**Analog search scope:** `Duncedmaxxing/` directory (Core.lua, Options.lua, Modules/TipOfTheSpear.lua, Duncedmaxxing.toc)
**Files scanned:** 4 source files (all read in full)
**Pattern extraction date:** 2026-06-17
