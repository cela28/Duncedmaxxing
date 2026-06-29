# Phase 06: Options UI Overhaul — Pattern Map

**Mapped:** 2026-06-29
**Files analyzed:** 5 (3 source, 2 test)
**Analogs found:** 5 / 5

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `Duncedmaxxing/Options.lua` | UI module | request-response (settings read/write) | `Duncedmaxxing/Options.lua` itself | self (restructure) |
| `Duncedmaxxing/Core.lua` | config/data | CRUD (DB schema, defaults) | `Duncedmaxxing/Core.lua` itself | self (extension) |
| `Duncedmaxxing/Modules/TipOfTheSpear.lua` | rendering module | event-driven | `Duncedmaxxing/Modules/TipOfTheSpear.lua` itself | self (targeted edit) |
| `spec/core_spec.lua` | test | batch (fixture + assert) | `spec/core_spec.lua` itself | self (update) |
| `spec/tip_spec.lua` | test | batch (fixture + assert) | `spec/tip_spec.lua` itself | self (update) |

---

## Pattern Assignments

### `Duncedmaxxing/Options.lua` — Full Restructure

**Analog:** `Duncedmaxxing/Options.lua` (existing file)

#### Module header and shared locals (lines 1–47)

```lua
local _, DMX = ...

local Options = {}
DMX.Options = Options

local Clamp        = DMX.Util.Clamp
local ParseHexColor = DMX.Util.ParseHexColor

local function GetCfg()
    local db = DMX:GetDB()
    return db and db.tip
end

local function RefreshTracker()
    if DMX.RefreshTip then
        DMX:RefreshTip()
    end
end
```

#### `CreateButton` factory — copy for Lock toggle and Reset Colors (lines 63–76)

```lua
local function CreateButton(parent, text, x, y, width, height, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, height)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    button:SetText(text)
    button:SetScript("OnClick", function()
        if not Options:CanChange() then
            return
        end
        onClick()
        Options:Refresh()
    end)
    return button
end
```

**Note for Lock toggle (D-04):** `CreateButton` calls `Options:Refresh()` automatically after `onClick`. The `onClick` body only needs to toggle `db.locked`, call `DMX:ForEachModule("ApplyLock")`, and call `RefreshTracker()`. `Refresh()` will then update the button text via `self.lockBtn:SetText(...)`.

**Note for Reset Colors (D-05):** The two-click confirm state machine requires custom `OnClick` logic. Do NOT use `CreateButton` for the Reset Colors button — use raw `CreateFrame("Button", nil, numberSection, "UIPanelButtonTemplate")` and attach a custom `SetScript("OnClick", ...)` directly. The `CreateButton` factory's automatic `Options:Refresh()` call would revert the "Confirm Reset" text on every first click.

#### `CreateInput` factory — copy for all 4 stack color hex inputs (lines 104–139)

```lua
local function CreateInput(parent, text, x, y, width, getValue, setValue)
    CreateText(parent, text, x, y - 2)

    local editBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    editBox:SetSize(width, 22)
    editBox:SetPoint("TOPLEFT", parent, "TOPLEFT", x + 90, y)
    editBox:SetAutoFocus(false)

    local function Apply()
        if not Options:CanChange() then
            editBox:SetText(tostring(getValue()))
            return
        end

        local ok = setValue(editBox:GetText())
        if ok then
            RefreshTracker()
        end
        Options:Refresh()
    end

    editBox:SetScript("OnEnterPressed", function(self)
        Apply()
        self:ClearFocus()
    end)
    editBox:SetScript("OnEscapePressed", function(self)
        self:SetText(tostring(getValue()))
        self:ClearFocus()
    end)
    editBox:SetScript("OnEditFocusLost", Apply)

    table.insert(Options.inputs, {
        editBox = editBox,
        get = getValue,
    })
end
```

**Stack color input call pattern** (one per stack index 0–3, Y offsets relative to `numberSection:TOPLEFT`):

```lua
CreateInput(numberSection, "0 stacks", 16, -28, 78,
    function() return ColorToHex(GetCfg().stackColors[0]) end,
    function(value)
        local color = ParseHexColor(value)
        if not color then return false end
        GetCfg().stackColors[0] = color
        return true
    end)
```

#### `Options:CanChange()` — combat guard (lines 141–148)

```lua
function Options:CanChange()
    if InCombat() then
        DMX:Print("Settings cannot be opened or changed in combat.")
        return false
    end
    return true
end
```

**Apply to:** Every interactive widget `OnClick` handler, including both clicks of the Reset Colors confirm state machine.

#### `BuildWindow` idempotency guard (lines 179–182)

```lua
function Options:BuildWindow()
    if self.window then
        return
    end
    -- ...
end
```

**Preserve this guard unchanged.**

#### Sub-frame section visibility toggle (D-03) — new pattern to add in `BuildWindow`

```lua
-- barSection: parent all bar-specific widgets here
local barSection = CreateFrame("Frame", nil, window)
barSection:SetSize(386, 200)
barSection:SetPoint("TOPLEFT", window, "TOPLEFT", 0, -248)
self.barSection = barSection

-- numberSection: parent all number-specific widgets here
local numberSection = CreateFrame("Frame", nil, window)
numberSection:SetSize(386, 240)
numberSection:SetPoint("TOPLEFT", window, "TOPLEFT", 0, -248)
self.numberSection = numberSection
```

**Critical:** All `CreateInput` / `CreateText` calls inside a section must pass the section frame as `parent`, not `window`. The x/y offsets passed to `CreateInput` must be relative to the section frame's TOPLEFT, not the window's TOPLEFT.

#### `Options:Refresh()` — add show/hide and height resize (lines 385–400)

Extend the existing `Refresh()` body to add after the existing checkbox/input sync loops:

```lua
local cfg = GetCfg()
if cfg.displayMode == "bar" then
    self.barSection:Show()
    self.numberSection:Hide()
    self.window:SetSize(386, 380)
else
    self.barSection:Hide()
    self.numberSection:Show()
    self.window:SetSize(386, 484)
end

-- Sync lock toggle text
if self.lockBtn then
    self.lockBtn:SetText(DMX:GetDB().locked and "Unlock" or "Lock")
end

-- Reset Colors button: revert pending state on any Refresh
if self.resetColorsBtn and self.resetColorsPending then
    self.resetColorsPending = false
    if self.resetColorsTimer then
        self.resetColorsTimer:Cancel()
        self.resetColorsTimer = nil
    end
    self.resetColorsBtn:SetText("Reset Colors")
end
```

#### Existing color input pattern to copy for Fill/Border/Empty% (lines 321–352)

```lua
CreateInput(window, "Fill", 204, -276, 78,
    function() return ColorToHex(GetCfg().fillColor) end,
    function(value)
        local color = ParseHexColor(value)
        if not color then return false end
        GetCfg().fillColor = color
        return true
    end)
```

Stack color inputs follow the identical structure with `GetCfg().stackColors[i]` as the get/set target.

---

### `Duncedmaxxing/Core.lua` — DEFAULTS extension and migration bump

**Analog:** `Duncedmaxxing/Core.lua` (existing file)

#### DEFAULTS.tip structure to copy/extend (lines 12–32)

```lua
local DEFAULTS = {
    locked = true,
    tip = {
        -- enabled field: REMOVE this line
        hideWhenEmpty = false,
        x = 0,
        y = -160,
        scale = 1,
        -- ... existing fields unchanged ...
        textColor = { r = 1, g = 1, b = 1, a = 1 },
        -- ADD stackColors table:
        stackColors = {
            [0] = { r = 1,       g = 1,       b = 1,       a = 1 },
            [1] = { r = 0.18039, g = 0.80000, b = 0.44314, a = 1 },
            [2] = { r = 1,       g = 0.94118, b = 0,       a = 1 },
            [3] = { r = 1,       g = 0.29804, b = 0.18824, a = 1 },
        },
        optionsX = 360,
        optionsY = 170,
    },
}
```

**Key concern (Pitfall 3):** `stackColors` uses `[0]` as a valid Lua table key. `MergeDefaults` uses `pairs` which iterates all keys including `[0]` — this works correctly. `ipairs` must NOT be used to iterate `stackColors` (it would skip `[0]`). Use `for i = 0, 3 do` in `Options:Refresh()`.

#### SETTINGS_MIGRATION bump (line 10)

```lua
-- BEFORE:
local SETTINGS_MIGRATION = "0.3.2-fontfix"
-- AFTER (pick the new string):
local SETTINGS_MIGRATION = "0.3.2-stackcolors"
```

#### `CopyDefaults` — use for Reset Colors deep copy (lines 36–46)

```lua
local function CopyDefaults(defaults)
    local copy = {}
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            copy[key] = CopyDefaults(value)
        else
            copy[key] = value
        end
    end
    return copy
end
```

**Apply in Reset Colors handler:** `GetCfg().stackColors = CopyDefaults(DMX.defaults.tip.stackColors)` — never assign the defaults table by reference (Pitfall 4). `CopyDefaults` is exposed via `DMX._test.CopyDefaults` for tests.

---

### `Duncedmaxxing/Modules/TipOfTheSpear.lua` — two targeted edits

**Analog:** `Duncedmaxxing/Modules/TipOfTheSpear.lua` (existing file)

#### Edit 1: `shouldShow` simplification — line 595

```lua
-- BEFORE:
local shouldShow = unlocked or self.testMode or (cfg.enabled and self.isSurvival)
-- AFTER (D-06 — remove cfg.enabled entirely):
local shouldShow = unlocked or self.testMode or self.isSurvival
```

#### Edit 2: Stack color read in `Tip:Update()` number mode branch — lines 621–622

```lua
-- BEFORE:
local sc = STACK_COLORS[stacks] or STACK_COLORS[0]
numberText:SetTextColor(sc[1], sc[2], sc[3], sc[4])

-- AFTER (D-02 — read from config, fall back to hardcoded constant):
local stackColors = GetCfg().stackColors or STACK_COLORS
local sc = stackColors[stacks] or stackColors[0] or STACK_COLORS[0]
local r, g, b, a = ColorTuple(sc, STACK_COLORS[0])
numberText:SetTextColor(r, g, b, a)
```

**Why `ColorTuple`:** `STACK_COLORS` uses array format `{1, 2, 3, 4}` while config `stackColors` uses named-key format `{r, g, b, a}`. `ColorTuple` already normalizes both. Do not add a separate normalization path.

#### `STACK_COLORS` constant (lines 33–38) — keep as fallback only

```lua
local STACK_COLORS = {
    [0] = { 1, 1, 1, 1 },
    [1] = { 0.18039, 0.80000, 0.44314, 1 },
    [2] = { 1, 0.94118, 0, 1 },
    [3] = { 1, 0.29804, 0.18824, 1 },
}
```

Do not remove this constant — it is the nil-safety fallback in the new `Tip:Update()` color-read expression.

---

### `spec/core_spec.lua` — test surgery

**Analog:** `spec/core_spec.lua` (existing file)

#### Existing fixture helper pattern to update (lines 239–248)

```lua
-- BEFORE (line 243 — remove this assertion):
assert.equals(true, db.tip.enabled)

-- AFTER: remove the line entirely; enabled is no longer in DEFAULTS
```

#### `migratedDB` fixture helpers — remove `enabled` field

The fixture at lines 266–276 (and all similar `migratedDB`/`migrationDB` helpers in the file) set `enabled = true`. Remove that key from all fixtures:

```lua
-- BEFORE:
tip = {
    enabled    = true,
    displayMode = displayMode,
    x = 0, y = -160, scale = 1,
    optionsX = 360, optionsY = 170,
},
-- AFTER:
tip = {
    displayMode = displayMode,
    x = 0, y = -160, scale = 1,
    optionsX = 360, optionsY = 170,
},
```

#### New test pattern to add — `stackColors` presence after `MergeDefaults`

Copy the existing deep-merge test structure (lines 27–31) and adapt:

```lua
it("populates stackColors[0] through stackColors[3] from defaults", function()
    local result = DMX._test.MergeDefaults(DMX.defaults, {tip = {}})
    assert.is_table(result.tip.stackColors)
    assert.is_table(result.tip.stackColors[0])
    assert.is_table(result.tip.stackColors[3])
    assert.near(1, result.tip.stackColors[0].r, 0.001)
end)
```

---

### `spec/tip_spec.lua` — test surgery

**Analog:** `spec/tip_spec.lua` (existing file)

#### Remove `db.tip.enabled` from number mode color test setup (line 593)

```lua
-- BEFORE (lines 591–596):
local db = DMX:GetDB()
db.tip.displayMode = "number"
db.tip.enabled = true       -- REMOVE this line
db.locked = true
Tip.isSurvival = true

-- AFTER:
local db = DMX:GetDB()
db.tip.displayMode = "number"
db.locked = true
Tip.isSurvival = true
```

#### New test pattern — config-driven color read

Copy the `assertColor` helper and test structure (lines 599–634) and add:

```lua
it("reads stack color from db.tip.stackColors when set", function()
    local db = DMX:GetDB()
    db.tip.stackColors = {
        [0] = { r = 1, g = 0, b = 0, a = 1 },  -- custom red for 0 stacks
        [1] = { r = 0.18039, g = 0.80000, b = 0.44314, a = 1 },
        [2] = { r = 1, g = 0.94118, b = 0, a = 1 },
        [3] = { r = 1, g = 0.29804, b = 0.18824, a = 1 },
    }
    Tip.stacks = 0
    Tip:Update()
    assertColor(Tip.numberText._textColor, { 1, 0, 0, 1 },
        "0 stacks should use config color, not hardcoded white")
end)
```

---

## Shared Patterns

### Combat guard
**Source:** `Duncedmaxxing/Options.lua` lines 141–148 (`Options:CanChange()`)
**Apply to:** Every `OnClick` handler in Options.lua — including both the first and second clicks of the Reset Colors confirm state machine.

```lua
if not Options:CanChange() then return end
```

### Tracker refresh after settings change
**Source:** `Duncedmaxxing/Options.lua` lines 43–47 (`RefreshTracker()`)
**Apply to:** Every `setValue` callback in `CreateInput`, every button `onClick` that mutates config.

```lua
local function RefreshTracker()
    if DMX.RefreshTip then
        DMX:RefreshTip()
    end
end
```

### `ColorToHex` for color input display
**Source:** `Duncedmaxxing/Options.lua` lines 24–36
**Apply to:** All 4 stack color `getValue` callbacks.

```lua
function() return ColorToHex(GetCfg().stackColors[i]) end
```

### `ParseHexColor` for color input parsing
**Source:** `Duncedmaxxing/Options.lua` line 8 (imported from `DMX.Util`)
**Apply to:** All 4 stack color `setValue` callbacks. Returns `nil` for invalid hex — return `false` from `setValue` on nil to prevent a tracker refresh.

### C_Timer nil guard for Reset Colors revert
**Source:** `Duncedmaxxing/Modules/TipOfTheSpear.lua` (existing C_Timer usage pattern)
**Apply to:** Reset Colors timer creation in Options.lua.

```lua
if C_Timer and C_Timer.NewTimer then
    self.resetColorsTimer = C_Timer.NewTimer(3, function()
        if not self.resetColorsPending then return end
        self.resetColorsPending = false
        self.resetColorsTimer = nil
        self.resetColorsBtn:SetText("Reset Colors")
    end)
else
    -- No timer available: stay armed until next Refresh or second click
end
```

Use `C_Timer.NewTimer` (not `C_Timer.After`) so the timer handle can be cancelled on a successful second click via `self.resetColorsTimer:Cancel()`.

---

## No Analog Found

All files in this phase are modifications of existing files. No new files require analogs from outside the existing codebase.

---

## Metadata

**Analog search scope:** `Duncedmaxxing/`, `spec/`
**Files scanned:** 5
**Pattern extraction date:** 2026-06-29
