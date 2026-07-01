---
phase: 06-options-panel-v2-per-mode-visibility-configurable-stack-colo
reviewed: 2026-07-02T00:00:00Z
depth: standard
files_reviewed: 5
files_reviewed_list:
  - Duncedmaxxing/Core.lua
  - Duncedmaxxing/Modules/TipOfTheSpear.lua
  - Duncedmaxxing/Options.lua
  - spec/core_spec.lua
  - spec/tip_spec.lua
findings:
  critical: 0
  warning: 3
  info: 3
  total: 6
status: issues_found
---

# Phase 06: Code Review Report

**Reviewed:** 2026-07-02T00:00:00Z
**Depth:** standard
**Files Reviewed:** 5
**Status:** issues_found

## Summary

Reviewed the phase-6 changes: `colorByStack`/`stackColors` defaults and migration in `Core.lua`, the per-stack color render read in `TipOfTheSpear.lua:Update()`, and the Options.lua v2 panel (per-mode widget visibility groups, stack color pickers, checkbox/input toggle greying, and active-mode button highlighting).

The core logic is sound: `ColorTuple` correctly handles both positional (`{r,g,b,a}`) and keyed (`{r=,g=,b=,a=}`) color tables, `MergeDefaults`/`NormalizeDB` correctly backfill `colorByStack`/`stackColors` onto legacy DBs without wiping existing settings (verified against `core_spec.lua`'s dedicated D-11 test), stack indices are always clamped to `[0, MAX_STACKS]` before table lookups so no nil-index crash is reachable, and all mutating Options controls remain gated by `Options:CanChange()` / `InCombatLockdown()` consistent with the project's combat-safety pattern.

The most significant finding is a test-coverage gap: `spec/support/init.lua` explicitly skips loading `Options.lua` in the test harness ("Options.lua (skipped)"), so none of the phase-6 Options.lua work — per-mode visibility gating, stack color pickers, toggle greying, mode-button highlighting — has any automated test coverage despite `tip_spec.lua` and `core_spec.lua` thoroughly covering the corresponding Core/Tip render-path changes. Two smaller robustness/consistency issues are noted below.

## Warnings

### WR-01: Options.lua has zero automated test coverage — phase-6 UI logic changes are unverified

**File:** `spec/support/init.lua:30` (harness), `Duncedmaxxing/Options.lua` (subject)
**Issue:** The test loader comment explicitly states `-- Options.lua (skipped)` and the `load()` function only loads `Util.lua`, `Core.lua`, and `Modules/TipOfTheSpear.lua` (lines 31-33). None of this phase's Options.lua additions — `AddToGroup`/`widgetGroups` per-mode show/hide (`Options.lua:183-190,505-514`), `SetColorGroupEnabled` toggle-greying (`Options.lua:448-466`), `HighlightModeButton` active-mode highlighting (`Options.lua:468-486`), or the four stack color picker inputs (`Options.lua:394-406`) — has any unit test exercising it. A regression here (e.g. a mode-group misassignment, or `Refresh()` skipping the `colorByStack` enable/disable branch) would ship silently since `core_spec.lua`/`tip_spec.lua` cannot detect it.
**Fix:** Either extend the test harness to load `Options.lua` (it will need `CreateFrame`/widget stubs for `CheckButton`, `EditBox`, `Button` with `Enable`/`Disable`/`SetAlpha`/`LockHighlight` support in `wow_stubs.lua`), or explicitly document in the phase plan that Options.lua UI wiring is verified only via manual/UAT testing, so the gap is a conscious tradeoff rather than an oversight.

### WR-02: `Options:Refresh()` only recomputes stack/flat color-group enable state when `mode == "number"`

**File:** `Duncedmaxxing/Options.lua:521-525`
**Issue:**
```lua
if mode == "number" and self.colorGroups then
    local colorByStack = cfg.colorByStack ~= false
    SetColorGroupEnabled(self.colorGroups.stack, colorByStack)
    SetColorGroupEnabled(self.colorGroups.flat, not colorByStack)
end
```
This branch is a no-op whenever `mode == "bar"`. In practice this happens to be harmless today because the same widgets are `Hide()`-n via the `groups.number` loop a few lines above (so a disabled-vs-stale-enabled state is not visibly reachable), and the branch re-runs correctly the next time the panel is shown in number mode. However, this makes correctness depend on the *order* of two unrelated code paths (visibility gating vs. enable/alpha gating) rather than on an invariant, which is fragile: any future change that reorders these blocks, or that stops fully hiding disabled color widgets, will surface stale grey/enabled state.
**Fix:** Make the state computation mode-independent so it doesn't rely on hide-ordering as a correctness crutch:
```lua
if self.colorGroups then
    local colorByStack = cfg.colorByStack ~= false
    SetColorGroupEnabled(self.colorGroups.stack, mode == "number" and colorByStack)
    SetColorGroupEnabled(self.colorGroups.flat, mode == "number" and not colorByStack)
end
```

### WR-03: `numberText` text-color duplication across the early-return and fallthrough code paths in `Tip:Update()`

**File:** `Duncedmaxxing/Modules/TipOfTheSpear.lua:613-633` vs `635-658`
**Issue:** The number-mode branch (`cfg.colorByStack`/`stackColors`/`ColorTuple` fallback logic) and the bar-mode branch both independently call `label:SetShown(unlocked)` at their respective tails (lines 631 and 657), and the `ColorTuple(cfg.textColor, DMX.defaults.tip.textColor)` fallback call appears twice with subtly different intent (once for the `colorByStack == false` flat-color case at line 627, and implicitly assumed available at `RefreshLayout:494` for initial layout). This isn't a functional bug today, but the duplicated `ColorTuple(cfg.textColor, ...)` call pattern between `RefreshLayout` and `Update` means a future change to text-color fallback logic (e.g. adding a new fallback tier) has to be made in two places or will silently diverge.
**Fix:** Extract a small `GetFlatTextColor(cfg)` helper used by both `RefreshLayout` and `Update` to keep the fallback chain single-sourced. Low priority — quality/maintainability only.

## Info

### IN-01: `stackLabels` table and stack-picker loop use magic numbers `0`/`3` instead of `MAX_STACKS`

**File:** `Duncedmaxxing/Options.lua:394-406`
**Issue:** `local stackLabels = { [0] = "0 stacks", [1] = "1 stack", [2] = "2 stacks", [3] = "3 stacks" }` and `for stack = 0, 3 do` hardcode the stack range even though `Duncedmaxxing/Modules/TipOfTheSpear.lua` defines `MAX_STACKS = 3` and Options.lua has no equivalent shared constant. If `MAX_STACKS` ever changes, this loop and the `Core.lua` `stackColors` defaults table (`Core.lua:30-35`, also hardcoded `[0]`..`[3]`) must be manually kept in sync across three files with no compiler/linter to catch a mismatch.
**Fix:** Not urgent given WoW Lua's lack of shared constant modules across files without extra wiring, but consider exposing `DMX.defaults.tip.stackColors` keys (`Core.lua` already owns the canonical range) and building the Options.lua loop by iterating `pairs(DMX.defaults.tip.stackColors)` sorted by key, rather than a separately hardcoded `0, 3` literal range.

### IN-02: `SetColorGroupEnabled` silently no-ops `Enable`/`Disable` on widgets lacking those methods, but still forces `SetAlpha`

**File:** `Duncedmaxxing/Options.lua:448-466`
**Issue:** The guard `if widget.Disable and widget.Enable then` correctly protects the `Enable()`/`Disable()` calls, but `widget:SetAlpha(enabled and 1 or 0.4)` is called unconditionally outside that guard. For any widget type that doesn't support `SetAlpha` (unlikely for standard `Frame`-derived widgets, but not guaranteed for all templates), this would error. All current callers pass `EditBox`/`FontString`-backed widgets that do support `SetAlpha`, so this is not currently reachable, but the inconsistent guarding (checked for `Enable`/`Disable`, unchecked for `SetAlpha`) is worth normalizing.
**Fix:**
```lua
if widget.SetAlpha then
    widget:SetAlpha(enabled and 1 or 0.4)
end
```

### IN-03: `Tip:Update()` number-mode branch shadows the outer `mode` boolean check with an early `return`, making the function's control flow harder to follow

**File:** `Duncedmaxxing/Modules/TipOfTheSpear.lua:613-633`
**Issue:** `Tip:Update()` is a single function handling both display modes via an early `return` inside the `if mode == "number" then ... return end` block, followed by ~25 more lines of bar-mode-only logic with no `else`. This is pre-existing structure, not newly introduced by phase 6, but the phase-6 diff added another 8 lines of branching (`colorByStack` on/off) inside that early-return block, further growing an already ~75-line function with two divergent responsibilities.
**Fix:** No action required for this phase; flagged for awareness only if `Tip:Update()` grows again — consider splitting into `Tip:UpdateNumberMode()`/`Tip:UpdateBarMode()` helpers in a future cleanup pass.

---

_Reviewed: 2026-07-02T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
