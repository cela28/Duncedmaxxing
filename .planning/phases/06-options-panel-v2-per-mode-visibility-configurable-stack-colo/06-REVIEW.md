---
phase: 06-options-panel-v2-per-mode-visibility-configurable-stack-colo
reviewed: 2026-07-07T00:00:00Z
depth: standard
files_reviewed: 4
files_reviewed_list:
  - Duncedmaxxing/Options.lua
  - Duncedmaxxing/Modules/TipOfTheSpear.lua
  - Duncedmaxxing/Core.lua
  - spec/core_spec.lua
findings:
  critical: 1
  warning: 5
  info: 2
  total: 8
status: issues_found
---

# Phase 06: Code Review Report

**Reviewed:** 2026-07-07T00:00:00Z
**Depth:** standard
**Files Reviewed:** 4
**Status:** issues_found

## Summary

Reviewed the gap-closure changes from plans 06-04 (widget removal + per-mode visibility in `Options.lua`, orphaned `Tip:ResetPosition` removal), 06-05 (`stackColors` defaults converted to named-key form + `SETTINGS_MIGRATION` bump in `Core.lua`, `core_spec.lua` assertions updated), and 06-06 (options-panel layout rebalance in `Options.lua`).

The per-mode visibility regrouping (Scale/Border color → bar-only, Text size/Color-by-stack/stack pickers → number-only) is wired correctly through the existing `AddToGroup`/`SetWidgetShown` engine, and the 06-06 layout rebalance does not introduce any widget coordinate collisions — I traced every `SetPoint` pair in both columns and all mutually-exclusive bar/number rows are genuinely mutually exclusive at runtime. `core_spec.lua`'s new named-key assertions correctly match the new `DEFAULTS.tip.stackColors` shape, and `ColorTuple`/`ParseHexColor` consistently produce/consume the same `{r,g,b,a}` shape end to end.

However, I found one BLOCKER: the `SETTINGS_MIGRATION` version bump in `Core.lua` triggers `NormalizeDB`'s full-tip-wipe migration branch for every user who is not already on `"0.3.3-stackcolorfmt"`, and that branch overwrites every `tip.*` field (display mode, colors, width/height/border, `hideWhenEmpty`, `colorByStack`, `enabled`, stack colors) with fresh defaults, preserving only position/scale/options-window-position. This is real, reproducible data loss for any existing user who customized anything beyond position — not a hypothetical edge case, but the direct, guaranteed effect of this phase's migration bump landing in production. I also found a genuine functional regression from 06-04's "Scale → bar-only" regrouping: `cfg.scale` is still applied to the frame in Number mode (`TipOfTheSpear.lua:492`), but the Scale control is now hidden whenever Number mode is active, so a non-1.0 scale value cannot be corrected from within the mode it visibly affects.

## Critical Issues

### CR-01: `SETTINGS_MIGRATION` bump silently wipes all user tip customization except position/scale on next login

**File:** `Duncedmaxxing/Core.lua:75-94`
**Issue:**
```lua
if db.settingsMigration ~= SETTINGS_MIGRATION then
    local x, y, scale = tip.x, tip.y, tip.scale
    local optionsX, optionsY = tip.optionsX, tip.optionsY
    local fresh = CopyDefaults(DEFAULTS.tip)

    for key, value in pairs(fresh) do
        tip[key] = value
    end

    tip.x = x or fresh.x
    tip.y = y or fresh.y
    tip.scale = scale or fresh.scale
    tip.optionsX = optionsX or fresh.optionsX
    tip.optionsY = optionsY or fresh.optionsY
    ...
```
`SETTINGS_MIGRATION` was bumped from `"0.3.2-fontfix"` to `"0.3.3-stackcolorfmt"` in this phase specifically to re-seed the old positional-array `stackColors` into the new named-key form. But the migration mechanism does not do a targeted `stackColors` fix — it overwrites the *entire* `tip` table with `CopyDefaults(DEFAULTS.tip)` and then restores only 5 fields (`x`, `y`, `scale`, `optionsX`, `optionsY`). Every other customization a user made through the Options panel — `displayMode` ("number" reverts to "bar"), `width`, `height`, `borderSize`, `fillColor`, `emptyColor`, `borderColor`, `textColor`, `hideWhenEmpty`, `colorByStack`, all 4 `stackColors` entries, and `enabled` — is silently discarded and replaced with stock defaults the next time the addon loads after this update, with no warning, no backup, and no way to undo. This will visibly reset every existing user's tracker to factory settings on update.
**Fix:** Do a targeted re-seed of only the field whose *shape* actually changed, instead of nuking the whole `tip` table:
```lua
local function StackColorsAreLegacyFormat(stackColors)
    local sample = stackColors and stackColors[0]
    return type(sample) == "table" and sample.r == nil and sample[1] ~= nil
end

local function NormalizeDB(db)
    local tip = db.tip

    if StackColorsAreLegacyFormat(tip.stackColors) then
        tip.stackColors = CopyDefaults(DEFAULTS.tip.stackColors)
    end

    if db.settingsMigration ~= SETTINGS_MIGRATION then
        tip.barWidth = nil
        tip.barHeight = nil
        tip.spacing = nil
        db.settingsMigration = SETTINGS_MIGRATION
    end

    if tip.displayMode ~= "bar" and tip.displayMode ~= "number" then
        tip.displayMode = DEFAULTS.tip.displayMode
    end
end
```
This preserves every field the user actually customized and only repairs the one field whose format is provably broken, while still bumping `settingsMigration` so the fix runs exactly once. (Note: this also requires updating the `core_spec.lua` migration-branch tests, which currently assert a full wipe-and-restore.)

## Warnings

### WR-01: `cfg.scale` still applies to Number mode, but the Scale control was moved to the bar-only visibility group

**File:** `Duncedmaxxing/Options.lua:307-315` (Scale registered `AddToGroup("bar", ...)`) vs `Duncedmaxxing/Modules/TipOfTheSpear.lua:489-495`
**Issue:** Plan 06-04 moved the Scale input into the bar-only widget group so it hides while the panel is in Number mode (per UAT feedback "we do not need... scale" for text mode). But `Tip:RefreshLayout()`'s Number-mode branch still calls `root:SetScale(cfg.scale or 1)`:
```lua
if mode == "number" then
    local fontSize = tonumber(cfg.numberFontSize) or 22
    root:SetSize(fontSize * 2, fontSize + 4)
    root:SetScale(cfg.scale or 1)   -- still reads the shared scale value
    ...
```
`cfg.scale` is a single value shared between both display modes — it is not mode-scoped. A user who sets Scale to, say, 1.5 while in Bar mode and then switches to Number mode will see the number display rendered 1.5x larger than the "Text size" control implies, with no way to see or correct that from the Number-mode view of the panel (Scale is hidden). The only workaround is switching back to Bar mode, which is not discoverable from the Number-mode UI.
**Fix:** Either keep Scale in the shared (`"both"`) group since it demonstrably affects both render paths, or stop applying `cfg.scale` in the Number branch and rely solely on `numberFontSize` for that mode's sizing (decoupling the two modes' scale semantics entirely). Silently hiding a control that still has an effect is the wrong fix for the UAT complaint.

### WR-02: Removing the Enabled checkbox leaves no UI path to recover a legacy `enabled = false` state

**File:** `Duncedmaxxing/Options.lua` (checkbox deleted in 06-04) vs `Duncedmaxxing/Modules/TipOfTheSpear.lua:587`
**Issue:** `shouldShow = unlocked or self.testMode or (cfg.enabled and self.isSurvival)` still gates visibility on `cfg.enabled`, and `DEFAULTS.tip.enabled = true` is preserved per the 06-04 plan. However, any returning user whose `SavedVariables` already has `tip.enabled = false` (set via the now-removed checkbox, or the slash command that was removed even earlier) has no remaining way to set it back to `true` — there is no checkbox, no slash command, and `MergeDefaults` will never touch an already-non-nil `false` value. The only recovery path is "Reset Style", which (per CR-01) already wipes far more than intended, or manually editing the `WTF` SavedVariables file. A first-time user is unaffected (default is `true`), but this is a real dead-end for anyone upgrading from a version where the checkbox existed and was unchecked.
**Fix:** Either force `tip.enabled = true` unconditionally in `NormalizeDB` (since there is no longer any legitimate way to set it to `false` through the UI, the field is effectively vestigial), or keep a minimal recovery affordance (e.g. treat `cfg.enabled` as always-true and remove the field's read in `TipOfTheSpear.lua` entirely) rather than leaving a partially-wired on/off flag with only one direction reachable from the UI.

### WR-03: `Options.lua` has zero automated test coverage; this phase's visibility/grouping/migration-interaction changes are unverified by the suite

**File:** `spec/support/init.lua` (loader) / `Duncedmaxxing/Options.lua` (subject)
**Issue:** The test harness's `load()` function loads `Util.lua`, `Core.lua`, and `Modules/TipOfTheSpear.lua` only — `Options.lua` is explicitly skipped. None of this phase's `AddToGroup`/`widgetGroups` per-mode gating (`Options.lua:190-197, 509-518`), the `SetColorGroupEnabled` toggle-greying (`Options.lua:452-470`), or the Scale/Border-color regrouping (`Options.lua:307-315, 365-373`, see WR-01) has any unit test. A regression in any of these (e.g. a mode-group mis-assignment reintroducing the bug this phase just fixed) would ship silently.
**Fix:** Extend the test harness to load `Options.lua` with minimal `CheckButton`/`EditBox`/`Button` stubs (`Enable`/`Disable`/`SetAlpha`/`LockHighlight`), or explicitly document in the phase's STATE/ROADMAP that Options.lua UI wiring is UAT-only coverage by design.

### WR-04: `Options:Refresh()` only recomputes stack/flat color-group enable state when `mode == "number"`

**File:** `Duncedmaxxing/Options.lua:525-529`
**Issue:**
```lua
if mode == "number" and self.colorGroups then
    local colorByStack = cfg.colorByStack ~= false
    SetColorGroupEnabled(self.colorGroups.stack, colorByStack)
    SetColorGroupEnabled(self.colorGroups.flat, not colorByStack)
end
```
This branch is a no-op whenever `mode == "bar"`. It's currently harmless only because the same widgets are also `Hide()`-n via the `groups.number` visibility loop a few lines above, so a stale enabled/disabled alpha state is never visibly reachable. Correctness here depends on execution order between two logically-unrelated code paths (visibility gating vs. enable/alpha gating) rather than an invariant — fragile if either block is ever reordered or a widget is added to `colorGroups` without also being added to `widgetGroups.number`.
**Fix:**
```lua
if self.colorGroups then
    local colorByStack = cfg.colorByStack ~= false
    SetColorGroupEnabled(self.colorGroups.stack, mode == "number" and colorByStack)
    SetColorGroupEnabled(self.colorGroups.flat, mode == "number" and not colorByStack)
end
```

### WR-05: Duplicated text-color fallback logic between `Tip:Update()`'s Number branch and `Tip:RefreshLayout()`

**File:** `Duncedmaxxing/Modules/TipOfTheSpear.lua:494` and `:619`
**Issue:** `ColorTuple(cfg.textColor, DMX.defaults.tip.textColor)` is called independently in both `RefreshLayout` (initial paint) and `Update` (the `colorByStack == false` flat-color path). Not a functional bug today, but a future change to the text-color fallback chain (e.g. adding a "combat-tinted" override) must be made in two places or will silently diverge. `Tip:Update()` is already a single ~75-line function handling both display modes via an early `return`; this phase's `colorByStack` branching added another 8 lines to that early-return block.
**Fix:** Extract a small `GetFlatTextColor(cfg)` helper shared by both call sites. Low priority — maintainability only.

## Info

### IN-01: Stack-color range (`0`-`3`) hardcoded independently in three files with no shared constant

**File:** `Duncedmaxxing/Options.lua:404-405`, `Duncedmaxxing/Core.lua:30-35`, `Duncedmaxxing/Modules/TipOfTheSpear.lua:7,33-38`
**Issue:** `local stackLabels = { [0] = "0 stacks", ... }` / `for stack = 0, 3 do` in `Options.lua`, the `stackColors` default table in `Core.lua`, and `MAX_STACKS = 3` / `STACK_COLORS` in `TipOfTheSpear.lua` all encode the same `0..MAX_STACKS` range independently. If `MAX_STACKS` ever changes, all three must be updated in lockstep with no compiler/linter to catch a mismatch.
**Fix:** Not urgent given Lua's lack of a shared-constant-module mechanism across these files without extra wiring; consider building the `Options.lua` loop by iterating `pairs(DMX.defaults.tip.stackColors)` (Core.lua already owns the canonical range) instead of a separately hardcoded `0, 3` literal.

### IN-02: `SetColorGroupEnabled` guards `Enable`/`Disable` but calls `SetAlpha` unconditionally

**File:** `Duncedmaxxing/Options.lua:452-470`
**Issue:** `if widget.Disable and widget.Enable then ... end` correctly guards the `Enable()`/`Disable()` calls, but `widget:SetAlpha(enabled and 1 or 0.4)` runs outside that guard for every widget passed in. All current callers pass `EditBox`/`FontString`-backed widgets that support `SetAlpha`, so this isn't currently reachable, but the inconsistent guarding is worth normalizing before a new widget type is added to `colorGroups`.
**Fix:**
```lua
if widget.SetAlpha then
    widget:SetAlpha(enabled and 1 or 0.4)
end
```

---

_Reviewed: 2026-07-07T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
