# Phase 06: Options UI Overhaul — Research

**Researched:** 2026-06-29
**Domain:** WoW Lua 5.1 addon UI — widget visibility gating, DB schema extension, test suite surgery
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Use 4 hex text input fields, same `CreateInput` widget style as existing Fill/Border/Text color inputs. Labels: "0 stacks", "1 stack", "2 stacks", "3 stacks". No preview swatches, no preset palettes.
- **D-02:** Colors stored in `db.tip.stackColors` as a table of 4 color entries (same `{r,g,b}` format as `fillColor`/`borderColor`). `Tip:Update()` reads from config instead of the hardcoded `STACK_COLORS` table. Default values match the current hardcoded colors.
- **D-03:** Toggle visibility approach — all widgets created once at `BuildWindow` time. On mode switch, call `:Show()`/`:Hide()` on mode-specific sections and adjust the window height via `SetSize`. No frame destruction/recreation.
- **D-04:** Single button with text swap only. Reads "Unlock" when locked, "Lock" when unlocked. No color tinting — relies on the text label alone.
- **D-05:** Inline two-click confirmation. First click changes button text to "Confirm Reset" (or similar). Second click within ~3 seconds performs the actual reset. Timeout or no second click reverts button text to "Reset Colors". No StaticPopup dialog.
- **D-06:** Remove the `enabled` checkbox entirely. Remove `cfg.enabled` from visibility logic — tracker always shows when survival spec is active.
- **D-07:** Remove both the "Reset" and "Reset Style" buttons. No replacement.

### Claude's Discretion

- Exact Y-offset positioning of controls within the window.
- How to group the mode-specific sections internally (container frame vs individual widget tracking).
- Whether to extract the two-click confirm pattern into a reusable helper or inline it.
- Test file organization for new settings structure assertions.

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.
</user_constraints>

---

## Summary

Phase 6 restructures `Options.lua` so that only mode-relevant controls are visible at any time, removes six dead/redundant controls (`enabled` checkbox, two separate lock buttons, Reset, Reset Style, "Other Modes" label), and adds four per-stack hex color inputs plus a two-click Reset Colors button for number mode. The DB schema gains `db.tip.stackColors` (table of 4 `{r,g,b,a}` entries) and loses `db.tip.enabled`. The `Tip:Update()` rendering path switches from the hardcoded `STACK_COLORS` constant to reading the config table, keeping the constant as a fallback only.

All changes are confined to three source files — `Duncedmaxxing/Options.lua`, `Duncedmaxxing/Core.lua`, and `Duncedmaxxing/Modules/TipOfTheSpear.lua` — plus test updates in `spec/core_spec.lua` and `spec/tip_spec.lua`. No new WoW API calls are needed; every building block (`CreateInput`, `CreateButton`, `ParseHexColor`, `ColorToHex`, `C_Timer.After`, `GetCfg()`, `Options:CanChange()`) is already wired and working.

The 117 existing busted tests all pass at the start of this phase. The primary test surgery is: remove `db.tip.enabled` field from every fixture that seeds it, update the `cfg.enabled` idempotency assertion, and add new assertions for `db.tip.stackColors` presence and for config-driven color reads in `Tip:Update()`.

**Primary recommendation:** Implement in two waves — Wave 1: DB/Core changes and Tip:Update() color-read switch; Wave 2: Options.lua UI restructure plus test updates. This order ensures the data layer is tested before the UI consumes it.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Per-stack color storage | DB / SavedVariables (Core.lua DEFAULTS) | — | Persistent config; owned by Core.lua just like fillColor/borderColor |
| Per-stack color rendering | TipOfTheSpear.lua (Tip:Update) | — | Only the tracker rendering layer reads stack colors at draw time |
| Per-stack color editing (hex inputs) | Options.lua (BuildWindow) | — | All user-facing settings widgets live in Options |
| Two-click Reset Colors confirm | Options.lua | C_Timer (WoW) | Timer-based state machine; all state on the button object; no server |
| Mode-conditional visibility | Options.lua (Refresh) | — | Show/Hide on sub-frames; height resize via SetSize |
| Lock toggle | Options.lua + TipOfTheSpear.lua (ApplyLock) | DMX.db.locked | Options writes db.locked; Tip.ApplyLock applies it to the frame |
| `enabled` flag removal | Core.lua (DEFAULTS) + TipOfTheSpear.lua (shouldShow) | spec/core_spec.lua | Data layer first, rendering logic second, then tests |

---

## Standard Stack

### Core (no external packages — pure WoW Lua)

| Component | Current State | Phase Change |
|-----------|--------------|--------------|
| `CreateFrame("Frame", nil, window)` | Used for window | Use for barSection / numberSection sub-frames |
| `CreateInput` (Options.lua factory) | Used for all numeric/color inputs | Reuse directly for 4 stack color hex inputs |
| `ParseHexColor` (DMX.Util) | Used for Fill/Border/Text color inputs | Reuse for stack color inputs |
| `ColorToHex` (Options.lua local) | Used for color input display | Reuse for stack color inputs |
| `CreateButton` (Options.lua factory) | Used for mode/lock/reset buttons | Reuse for Lock toggle and Reset Colors button |
| `C_Timer.After` | Used in TipOfTheSpear.lua | Use for Reset Colors 3-second revert timer |
| `Options:CanChange()` | Combat guard on all mutations | Apply to both clicks of Reset Colors confirm |
| `Options:Refresh()` | Syncs all widgets from config | Update to handle barSection/numberSection show/hide and SetSize |
| `GetCfg()` | Returns `db.tip` | No change; all new inputs read/write through it |
| `ColorTuple` (TipOfTheSpear.lua local) | Normalizes `{r,g,b,a}` or `{1,2,3,4}` arrays | Reuse for reading `stackColors[stacks]` |

**No npm packages. No build toolchain. No installation step.**

---

## Package Legitimacy Audit

> Not applicable. This phase adds no external packages. Runtime is the WoW client; test runner is busted (already installed).

---

## Architecture Patterns

### System Architecture Diagram

```
Options window (BuildWindow)
  │
  ├─ Fixed chrome (title, close, mode buttons, modeText)
  │
  ├─ Shared controls section (always visible)
  │    Position X/Y, Scale, Hide-empty checkbox, Lock toggle
  │
  ├─ barSection sub-frame  ─── shown when displayMode == "bar"
  │    Width, Height, Border inputs
  │    Colors header, Fill, Border, Empty% inputs
  │
  └─ numberSection sub-frame ─ shown when displayMode == "number"
       Text size input
       Stack Colors header
       "0 stacks" / "1 stack" / "2 stacks" / "3 stacks" hex inputs
       Reset Colors button (two-click confirm state machine)

Options:Refresh()
  ├─ Update modeText label
  ├─ Sync all checkbox values
  ├─ Sync all input values (existing loop)
  ├─ Sync Reset Colors button text (revert pending state on Refresh)
  └─ Show/Hide barSection vs numberSection
     SetSize(386, 380 or 484) on window

Tip:Update() [TipOfTheSpear.lua]
  └─ number mode path:
       local sc = (GetCfg().stackColors or STACK_COLORS)[stacks] or STACK_COLORS[0]
       numberText:SetTextColor(sc[1] or sc.r, sc[2] or sc.g, sc[3] or sc.b, sc[4] or sc.a)
```

### Recommended Project Structure

No new files are required. Changes are confined to existing files:

```
Duncedmaxxing/
├── Core.lua                     -- DEFAULTS.tip: add stackColors, remove enabled
├── Options.lua                  -- Full restructure: barSection/numberSection sub-frames
└── Modules/
    └── TipOfTheSpear.lua        -- Update shouldShow and color read in Tip:Update()
spec/
├── core_spec.lua                -- Update fixtures: remove enabled, add stackColors assertions
└── tip_spec.lua                 -- Update number mode color test: use config path, not hardcoded
```

### Pattern 1: Sub-frame Section Visibility Toggle (D-03)

**What:** Create one sub-frame per mode section as a child of the window. Parent all mode-specific widgets to their section frame. Show/Hide the section frame on mode switch.

**When to use:** When groups of widgets must appear/disappear together without destroying and recreating frames. Avoids re-layout on every mode switch.

**Example:**
```lua
-- Source: CONTEXT.md D-03, UI-SPEC.md Visibility/Show-Hide Contract

-- In BuildWindow():
local barSection = CreateFrame("Frame", nil, window)
barSection:SetSize(386, 200)
barSection:SetPoint("TOPLEFT", window, "TOPLEFT", 0, -248)
-- ... create bar-specific inputs parented to barSection ...
self.barSection = barSection

local numberSection = CreateFrame("Frame", nil, window)
numberSection:SetSize(386, 240)
numberSection:SetPoint("TOPLEFT", window, "TOPLEFT", 0, -248)
-- ... create number-specific inputs parented to numberSection ...
self.numberSection = numberSection

-- In Refresh():
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
```

**Critical detail:** `CreateInput` positions the label at `(x, y-2)` and the editBox at `(x+90, y)` relative to the PARENT. When `parent` is the sub-frame (not the window), x/y offsets must be local to the sub-frame origin. Recalculate all Y values as offsets from the section frame top, not from the window top.

### Pattern 2: Two-Click Inline Confirm (D-05)

**What:** A button holds pending state directly on itself. First click arms; second click (within timeout) executes; timer revert disarms.

**When to use:** Destructive single-button actions with no StaticPopup required.

**Example:**
```lua
-- Source: CONTEXT.md D-05, UI-SPEC.md Interaction Contracts

local resetPending = false
local resetRevertTimer = nil

local resetBtn = CreateButton(numberSection, "Reset Colors", 16, -216, 100, 24, function()
    -- Note: CreateButton's onClick already checks CanChange() and calls Refresh()
    -- The Reset Colors button needs custom logic, so use raw CreateFrame here instead.
end)

-- Implement directly on the button's script rather than through CreateButton factory:
local resetBtnRaw = CreateFrame("Button", nil, numberSection, "UIPanelButtonTemplate")
resetBtnRaw:SetSize(100, 24)
resetBtnRaw:SetPoint("TOPLEFT", numberSection, "TOPLEFT", 16, -216)
resetBtnRaw:SetText("Reset Colors")
resetBtnRaw:SetScript("OnClick", function()
    if not Options:CanChange() then return end
    if not resetPending then
        resetPending = true
        resetBtnRaw:SetText("Confirm Reset")
        resetRevertTimer = C_Timer.After(3, function()
            resetPending = false
            resetBtnRaw:SetText("Reset Colors")
        end)
    else
        resetPending = false
        if resetRevertTimer then resetRevertTimer = nil end
        -- Write defaults back to stackColors
        local cfg = GetCfg()
        local defaults = DMX.defaults.tip.stackColors
        cfg.stackColors = DMX._test and DMX.defaults.tip.stackColors
            or CopyStackColorDefaults()
        RefreshTracker()
        Options:Refresh()
    end
end)
self.resetColorsBtn = resetBtnRaw
```

**Key concern:** `C_Timer.After` returns no cancellable handle (unlike `C_Timer.NewTimer`). The timer will fire and revert the text even after a successful second-click reset. Guard the revert with a check: `if not resetPending then return end` inside the timer callback. Alternatively use `C_Timer.NewTimer` which returns a handle with `:Cancel()`.

**Recommendation:** Use `C_Timer.NewTimer` so the timer can be cancelled on a successful second click or when `Options:Refresh()` is called (e.g., the window hides and re-shows).

### Pattern 3: Config-Driven Stack Colors in Tip:Update()

**What:** Replace `STACK_COLORS[stacks]` lookup with `GetCfg().stackColors[stacks]`, keeping the module-level constant as a nil-safety fallback only.

**Example:**
```lua
-- Source: UI-SPEC.md Data Contract, CONTEXT.md D-02

-- In Tip:Update(), number mode branch (TipOfTheSpear.lua ~line 621):
-- BEFORE:
--   local sc = STACK_COLORS[stacks] or STACK_COLORS[0]
-- AFTER:
local stackColors = GetCfg().stackColors or STACK_COLORS
local sc = stackColors[stacks] or stackColors[0] or STACK_COLORS[0]
numberText:SetTextColor(sc[1] or sc.r, sc[2] or sc.g, sc[3] or sc.b, sc[4] or sc.a)
```

**Note:** `STACK_COLORS` uses array indexing `sc[1]` while `fillColor`/`borderColor` use named keys `sc.r`. `ColorTuple` already normalizes both formats. For consistency with the rest of the codebase, store `stackColors` values using the same `{r,g,b,a}` named-key format as `fillColor`. `ColorTuple` then handles the read:

```lua
local r, g, b, a = ColorTuple(sc, STACK_COLORS[0])
numberText:SetTextColor(r, g, b, a)
```

This avoids adding a second normalization path.

### Anti-Patterns to Avoid

- **Destroying and recreating frames on mode switch:** WoW frames cannot be garbage collected easily and recreating them causes memory fragmentation. Use Show/Hide on section sub-frames (D-03).
- **Reading `enabled` after removal:** Remove all reads of `cfg.enabled` atomically with the DEFAULTS removal. A partial removal (e.g., removing from DEFAULTS but not from `Tip:Update()`) will silently treat `enabled` as `nil` which is falsy — the tracker will never show until the nil-check is correct.
- **Positioning widgets relative to window when they should be relative to section sub-frame:** If a widget is parented to `barSection` but anchored to `window`, it will render at the wrong position when the section is shown/hidden, because the anchor frame is not the parent.
- **Using `C_Timer.After` for cancellable timers:** `C_Timer.After` callbacks cannot be cancelled. Use `C_Timer.NewTimer` when the timer may need to be cancelled (e.g., Reset Colors revert on successful second click).
- **Hardcoding the SETTINGS_MIGRATION string in tests:** `core_spec.lua` already imports `DMX._test.SETTINGS_MIGRATION` by reference. New migration tests must use the same pattern — never hardcode the version string in test fixtures.
- **Forgetting to update `NormalizeDB` after removing `enabled` from DEFAULTS:** `MergeDefaults` won't add the removed field to existing databases, but `NormalizeDB` does not strip unknown keys on an already-migrated DB. The field becomes inert (harmless) if left in old saves. However: `Tip:Update()` must not read it after removal, and the migration version string bump is required to force a fresh defaults pass for users upgrading from pre-phase-6 saves.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Hex → RGB conversion | Custom regex parser | `ParseHexColor` (DMX.Util) | Already handles 3/6/8-char hex, returns `{r,g,b,a}`, already wired in Options.lua |
| RGB → hex display | `string.format` inline | `ColorToHex` (Options.lua local) | Handles alpha-channel, rounds correctly, already used by 3 color inputs |
| Numeric range validation | Manual `tonumber` + if guards | `Clamp` (DMX.Util) | Returns nil for non-numeric strings; pattern already used by all existing numeric inputs |
| Combat guard | `InCombatLockdown()` inline | `Options:CanChange()` | Centralized; includes the print message; already called by every existing interactive widget |
| Timer for Reset Colors revert | Custom polling | `C_Timer.NewTimer` | Returns cancellable handle; already a project dependency |
| DB deep copy for stackColors defaults | Custom copy loop | `CopyDefaults` (Core.lua `_test` or local) | Already exists; used by `ResetTipStyle` for the same purpose |

---

## Common Pitfalls

### Pitfall 1: `CreateInput` Label Anchor Is Relative to Parent

**What goes wrong:** `CreateInput(parent, label, x, y, width, ...)` creates the label at `(x, y-2)` relative to `parent:TOPLEFT`. When `parent` is a sub-frame positioned at y=-248 in the window, passing `y = -276` (the window-relative coordinate) yields `-276` relative to the sub-frame, which places the widget far below the window bottom.

**Why it happens:** The sub-frame approach makes all child widget offsets relative to the sub-frame origin, not the window origin. All existing `CreateInput` calls in Options.lua use window-relative coordinates because the window itself was previously the parent for everything.

**How to avoid:** Calculate section-frame-relative Y offsets. If the section frame's TOPLEFT is at window y=-248, then a widget intended to appear at window y=-276 must use section-relative y=-28.

**Warning signs:** Widgets not visible in the window; very large negative Y values being passed to CreateInput inside section sub-frames.

### Pitfall 2: `cfg.enabled` Removal Requires Coordinated Change Across Three Locations

**What goes wrong:** Removing `enabled` from `DEFAULTS.tip` alone causes `MergeDefaults` to stop injecting it into new saves, but old saves loaded before migration will still carry the field. More importantly, `Tip:Update()` line 595 still reads `cfg.enabled` and gates visibility with `(cfg.enabled and self.isSurvival)`. If this read is not removed, the tracker will be invisible for all existing users whose saved `enabled = true` becomes `nil` after the DEFAULTS removal without a migration bump.

**Why it happens:** The enabled field has three consumers that must all change atomically: DEFAULTS.tip (remove), Tip:Update() shouldShow logic (simplify), and test fixtures in spec/ (update).

**How to avoid:** The new shouldShow expression is:
```lua
local shouldShow = unlocked or self.testMode or self.isSurvival
```
Remove the `cfg.enabled` check entirely. This matches the phase goal: "tracker always active when survival spec."

**Warning signs:** Tests for `Tip:Update()` visibility still referencing `db.tip.enabled = true`; any `grep` hit for `cfg.enabled` remaining after the change.

### Pitfall 3: `stackColors` Table Keys Are 0-Based in Lua

**What goes wrong:** Lua arrays are 1-based by default. `MergeDefaults` iterates with `pairs` which handles non-integer-keyed tables, but the 0-indexed key requires explicit handling. Specifically: `table.insert` and `ipairs` will miss the `[0]` entry because they start at index 1.

**Why it happens:** The hardcoded `STACK_COLORS` and the existing per-stack color work (quick task 260622-hmo) both use `[0]` as the "zero stacks" key to mirror WoW's aura `applications` field which is also 0-based for the empty state.

**How to avoid:**
- In `DEFAULTS.tip.stackColors`, declare with explicit `[0] = { r=..., g=..., b=..., a=... }` key.
- In `MergeDefaults`: already uses `pairs` which iterates all keys including 0 — but ONLY for top-level-table keys within `stackColors`. Verify that `MergeDefaults` recurses into `stackColors` correctly. Since `stackColors` is a table whose values are subtables, `MergeDefaults` will recurse: `MergeDefaults(defaults.stackColors, target.stackColors)`. Each sub-table `{r,g,b,a}` will be deep-merged. This should work correctly — but test it.
- In `Options:Refresh()`, sync the stack color inputs using explicit index loop `for i = 0, 3 do`.

**Warning signs:** `stackColors[0]` is nil in the DB after `MergeDefaults`; color inputs for "0 stacks" show white (default fallback) even after a custom color is saved.

### Pitfall 4: Reset Colors Must Copy Defaults, Not Reference Them

**What goes wrong:** Reset Colors sets `cfg.stackColors = DMX.defaults.tip.stackColors` (a direct reference). Any subsequent edit to a color input would mutate the DEFAULTS table, corrupting all future saves.

**Why it happens:** Lua table assignment is reference assignment.

**How to avoid:** Use `CopyDefaults(DMX.defaults.tip.stackColors)` or iterate and copy. The `CopyDefaults` function already exists in Core.lua but is a file-local. Either expose it via `DMX._test.CopyDefaults` (it is already there) or write an inline deep-copy of the 4-entry table in the Reset Colors handler. The 4-entry inline copy is acceptable given the fixed structure.

### Pitfall 5: Window Height `SetSize` During `BuildWindow` vs `Refresh`

**What goes wrong:** `BuildWindow` sets the initial window size. If `Refresh` is called before the window is shown (e.g., from `Initialize`), it will resize correctly. But if height is only set in `BuildWindow` and never updated by `Refresh`, the height will be static regardless of mode.

**How to avoid:** The window height SetSize call belongs in `Options:Refresh()` (as the UI-SPEC specifies), not in `BuildWindow`. `BuildWindow` sets a default height; `Refresh` adjusts it every time mode changes.

### Pitfall 6: Existing Test Fixtures Carry `db.tip.enabled`

**What goes wrong:** After removing `enabled` from DEFAULTS, the `NormalizeDB` migration will wipe and reset all fields (since the migration version bump triggers a full reset). This means old `enabled = true` values in fixtures no longer match what a freshly-migrated DB looks like. Tests that assert `db.tip.enabled == true` post-migration will fail with nil.

**How to avoid:** 
- The `NormalizeDB` idempotency test (core_spec.lua line 243) asserts `db.tip.enabled == true` — this must be removed.
- Fixture helper functions in core_spec.lua that set `enabled = true` in the seed DB must have the field removed.
- `tip_spec.lua` line 593 sets `db.tip.enabled = true` in the number mode color test setup — this line should be removed (it is only needed because shouldShow was gated on `cfg.enabled`; after removal, `Tip.isSurvival = true` is sufficient).
- The migration version string (`SETTINGS_MIGRATION`) must be bumped in Core.lua so existing users' saves are wiped and re-defaulted. This is the same pattern used when `showOnlyInCombat` was removed.

---

## Code Examples

### Complete `shouldShow` simplification after enabled removal

```lua
-- Source: CONTEXT.md D-06, TipOfTheSpear.lua line 595 (current)
-- BEFORE:
local shouldShow = unlocked or self.testMode or (cfg.enabled and self.isSurvival)
-- AFTER:
local shouldShow = unlocked or self.testMode or self.isSurvival
```

### `db.tip.stackColors` DEFAULTS entry (Core.lua)

```lua
-- Source: UI-SPEC.md Data Contract
-- Add inside DEFAULTS.tip table in Core.lua
stackColors = {
    [0] = { r = 1,       g = 1,       b = 1,       a = 1 }, -- white (0 stacks)
    [1] = { r = 0.18039, g = 0.80000, b = 0.44314, a = 1 }, -- green
    [2] = { r = 1,       g = 0.94118, b = 0,       a = 1 }, -- gold
    [3] = { r = 1,       g = 0.29804, b = 0.18824, a = 1 }, -- red-orange
},
```

### `Tip:Update()` stack color read (TipOfTheSpear.lua)

```lua
-- Source: UI-SPEC.md Data Contract, CONTEXT.md D-02
-- In the number mode branch of Tip:Update(), replace:
--   local sc = STACK_COLORS[stacks] or STACK_COLORS[0]
--   numberText:SetTextColor(sc[1], sc[2], sc[3], sc[4])
-- With:
local stackColors = GetCfg().stackColors or STACK_COLORS
local sc = stackColors[stacks] or stackColors[0] or STACK_COLORS[0]
local r, g, b, a = ColorTuple(sc, STACK_COLORS[0])
numberText:SetTextColor(r, g, b, a)
```

Note: `STACK_COLORS` entries use array format `{1,2,3,4}` while `stackColors` config entries use named-key format `{r,g,b,a}`. `ColorTuple` normalizes both.

### Stack color input factory call pattern

```lua
-- Source: Options.lua CreateInput pattern (existing)
-- Each of the 4 stack color inputs follows the same pattern as Fill/Border/Text color inputs.
-- i is 0, 1, 2, 3 in loop or explicit calls.
CreateInput(numberSection, "0 stacks", 16, -28, 78,
    function() return ColorToHex(GetCfg().stackColors[0]) end,
    function(value)
        local color = ParseHexColor(value)
        if not color then return false end
        GetCfg().stackColors[0] = color
        return true
    end)
```

Y offset -28 is relative to numberSection's TOPLEFT (which is at window y=-344 per UI-SPEC).

### Lock toggle replacement

```lua
-- Source: CONTEXT.md D-04, UI-SPEC.md Lock Toggle Interaction Contract
-- Replaces the two buttons "Unlock Bar" (line 354) and "Lock Bar" (line 359)
local lockBtn = CreateButton(window, "Unlock", 100, 16, 76, 24, function()
    local db = DMX:GetDB()
    db.locked = not db.locked
    DMX:ForEachModule("ApplyLock")
    RefreshTracker()
    -- Refresh() is called by CreateButton's OnClick wrapper after onClick returns
end)
-- Anchor to BOTTOMLEFT per UI-SPEC action row layout
lockBtn:ClearAllPoints()
lockBtn:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", 100, 16)
self.lockBtn = lockBtn
-- In Refresh(), sync the label:
if self.lockBtn then
    self.lockBtn:SetText(DMX:GetDB().locked and "Unlock" or "Lock")
end
```

Note: The existing `CreateButton` factory anchors to TOPLEFT. The action row uses BOTTOMLEFT anchors per UI-SPEC. Either pass adjusted Y values to CreateButton (which uses TOPLEFT), or anchor manually after creation.

---

## State of the Art

| Old Approach | Current Approach | Phase Change |
|--------------|-----------------|--------------|
| `cfg.enabled` gates visibility | `isSurvival` alone gates visibility (D-06) | Remove `cfg.enabled` from DEFAULTS and shouldShow |
| Hardcoded `STACK_COLORS` in TipOfTheSpear.lua | Config-driven `db.tip.stackColors` | Add to DEFAULTS; read in Tip:Update(); keep constant as fallback |
| Separate "Unlock Bar" / "Lock Bar" buttons | Single toggle button (D-04) | Text swap only; one button, one state |
| All widgets parented to window | Section sub-frames (D-03) | barSection / numberSection sub-frames; Refresh shows/hides + resizes |

**Deprecated/outdated after this phase:**

- `cfg.enabled` — removed from DEFAULTS, shouldShow, and all tests; inert on old saves until migration bump
- `DMX:ResetTipStyle()` — the "Reset Style" button that called this is removed. The function itself may remain in Core.lua unless a future cleanup phase removes it.
- `Unlock Bar` / `Lock Bar` button labels — replaced by single "Unlock" / "Lock" toggle

---

## Assumptions Log

> All claims in this research were verified directly from the codebase source files. No assumptions were required.

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| — | — | — | — |

**All claims in this research were verified by direct code inspection — no user confirmation needed.**

---

## Open Questions (RESOLVED)

1. **SETTINGS_MIGRATION version bump** — RESOLVED: Use `"0.3.2-stackcolors"` to signal the DB schema change.
   - What we know: `NormalizeDB` runs a full reset when `db.settingsMigration` does not match `SETTINGS_MIGRATION`. The current value is `"0.3.2-fontfix"`.
   - Resolution: Use `"0.3.2-stackcolors"` to signal the specific DB schema change. The version bump triggers the migration branch which resets all `tip.*` fields except preserved ones (x, y, scale, optionsX, optionsY). `stackColors` will be populated from DEFAULTS.

2. **`DMX:ResetTipStyle()` in Core.lua** — RESOLVED: Leave as-is (dead code cleanup is out of scope).
   - What we know: This function deep-copies DEFAULTS.tip back over db.tip, preserving position/scale. It was called by the now-removed "Reset Style" button.
   - Resolution: Leave it. It's a Core-layer function, not UI. Phase 6 scope is Options.lua changes. Dead code cleanup is a separate concern.

3. **`C_Timer` availability in Reset Colors handler** — RESOLVED: Add nil guard matching existing TipOfTheSpear.lua pattern.
   - What we know: `C_Timer` is checked for nil in TipOfTheSpear.lua before every use. Options.lua currently never uses `C_Timer`.
   - Resolution: Add a nil guard: `if C_Timer then ... C_Timer.NewTimer(...) else` fallback to a flag-only approach with no auto-revert. This matches the existing dual-path pattern in TipOfTheSpear.lua.

---

## Environment Availability

This phase is code/config-only changes to existing Lua files and test specs. The only tooling dependency is the busted test runner.

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| busted | Test suite | Yes | runs 117 tests in 0.12s | — |
| WoW client | In-game verification | Not available | — | Flag in UAT checklist |

**Missing dependencies with no fallback:** None for development. In-game verification requires WoW client but is flagged as a UAT item, not a blocking build dependency.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | busted (Lua 5.1 compatible) |
| Config file | none — run directly via `busted spec/` |
| Quick run command | `busted spec/` |
| Full suite command | `busted spec/` |

### Phase Requirements → Test Map

| Behavior | Test Type | Automated Command | File Exists? |
|----------|-----------|-------------------|-------------|
| `db.tip.stackColors` populated by MergeDefaults | unit | `busted spec/core_spec.lua` | needs new test |
| `stackColors` survives NormalizeDB already-migrated branch | unit | `busted spec/core_spec.lua` | needs new test |
| NormalizeDB migration wipes and re-defaults when version bumped | unit | `busted spec/core_spec.lua` | existing test updated |
| `cfg.enabled` absent from DEFAULTS and not read in shouldShow | unit | `busted spec/tip_spec.lua` | existing test updated |
| `Tip:Update()` reads stack color from config, not hardcoded table | unit | `busted spec/tip_spec.lua` | existing test updated |
| Config-driven stack color persists after ParseHexColor write | unit | `busted spec/tip_spec.lua` | needs new test |

### Sampling Rate

- **Per task commit:** `busted spec/`
- **Per wave merge:** `busted spec/`
- **Phase gate:** Full suite green (all 117+ tests) before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] New test: `db.tip.stackColors` has all four entries after `MergeDefaults` with fresh DB — in `spec/core_spec.lua`
- [ ] New test: `stackColors[0]` through `stackColors[3]` survive NormalizeDB already-migrated path — in `spec/core_spec.lua`
- [ ] New test: `Tip:Update()` reads stack color from `db.tip.stackColors` when set (overriding hardcoded) — in `spec/tip_spec.lua`
- [ ] Update: Remove `db.tip.enabled = true` from `tip_spec.lua` line 593 number mode color test setup
- [ ] Update: Remove `assert.equals(true, db.tip.enabled)` from `core_spec.lua` idempotency test (line 243)
- [ ] Update: Remove `enabled = true` from all `migratedDB()` and `migrationDB()` fixture helpers in `core_spec.lua`

---

## Security Domain

Not applicable. This phase modifies only local WoW addon UI code with no network surface, no authentication, no user-provided data beyond hex color strings already validated by `ParseHexColor`, and no secrets.

---

## Sources

### Primary (HIGH confidence — direct codebase inspection)

- `Duncedmaxxing/Options.lua` — Full widget factory inventory, all existing control Y-positions, Refresh() logic, CreateInput/CreateButton/CreateCheckbox patterns
- `Duncedmaxxing/Core.lua` — DEFAULTS table, NormalizeDB, MergeDefaults, CopyDefaults, SETTINGS_MIGRATION constant, DMX._test exposure
- `Duncedmaxxing/Modules/TipOfTheSpear.lua` — STACK_COLORS table (lines 33-38), Tip:Update() number mode branch (line 595, 621), ColorTuple function
- `spec/core_spec.lua` — All fixture helpers, enabled assertions, migration test patterns
- `spec/tip_spec.lua` — Number mode color test (lines 585-649), db.tip.enabled usage (line 593)
- `spec/support/init.lua` — Test loader pattern, resetTipState fields
- `spec/support/wow_stubs.lua` — noopFrame capabilities, C_Timer stub structure
- `.planning/phases/06-options-ui-overhaul/06-CONTEXT.md` — All locked decisions D-01 through D-07
- `.planning/phases/06-options-ui-overhaul/06-UI-SPEC.md` — Full pixel layout, window dimensions, interaction contracts, data contract

### Secondary

- `.planning/REQUIREMENTS.md` — Phase 6 not assigned specific REQ-IDs; this phase is driven by CONTEXT.md decisions only
- `.planning/STATE.md` — Quick task 260622-hmo context (per-stack color coding added) — confirms stackColors pattern was explored but not yet DB-driven

---

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH — all building blocks are present and confirmed in source files
- Architecture: HIGH — sub-frame section visibility is a standard WoW pattern; all patterns verified against existing code in Options.lua
- Pitfalls: HIGH — derived from direct reading of the 3 source files and 2 test files that will change
- Test surgery: HIGH — all test lines requiring change identified with file + line references

**Research date:** 2026-06-29
**Valid until:** This is a closed codebase. Research is valid until source files change.
