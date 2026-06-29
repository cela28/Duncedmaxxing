---
phase: 06-options-ui-overhaul
reviewed: 2026-06-29T00:00:00Z
depth: standard
files_reviewed: 5
files_reviewed_list:
  - Duncedmaxxing/Core.lua
  - Duncedmaxxing/Modules/TipOfTheSpear.lua
  - Duncedmaxxing/Options.lua
  - spec/core_spec.lua
  - spec/tip_spec.lua
findings:
  critical: 2
  warning: 1
  info: 2
  total: 5
status: issues_found
---

# Phase 06: Code Review Report

**Reviewed:** 2026-06-29T00:00:00Z
**Depth:** standard
**Files Reviewed:** 5
**Status:** issues_found

## Summary

Phase 06 added per-stack color configuration to the DB schema (`stackColors` table in `DEFAULTS`), simplified `shouldShow` by removing the `enabled` gate, restructured `Options.lua` with mode-conditional sections (`barSection` / `numberSection`), and added a two-click-confirm Reset Colors button.

The `stackColors` DB schema change and the `ColorTuple` fallback chain in `TipOfTheSpear.lua` are implemented correctly. The `NormalizeDB` migration correctly resets on version bump, and `MergeDefaults` iterates integer keys (including `[0]`) reliably via `pairs()`. The mode-conditional section show/hide logic and lock-toggle text sync are sound.

Two blockers were found: production `Options.lua` calls into the `_test`-namespaced `CopyDefaults` function (explicitly marked "do not use in production"), and the Reset Colors button text is not restored to "Reset Colors" after a successful confirmed reset — it stays stuck on "Confirm Reset".

---

## Critical Issues

### CR-01: Production code calls `DMX._test.CopyDefaults` — test-only escape hatch used in shipped code

**File:** `Duncedmaxxing/Options.lua:424`

**Issue:** The Reset Colors second-click handler calls `DMX._test.CopyDefaults(DMX.defaults.tip.stackColors)` to deep-copy the default color table. The `_test` table is declared in `Core.lua:213-220` with an explicit comment: "Test-only escape hatch: exposes local functions for spec/core_spec.lua — Do not use in production addon code." Using it in production `Options.lua` violates this contract. While `DMX._test` is always present at runtime, any future refactor that strips or restructures `_test` (e.g., conditional compilation for a release build) would silently break Reset Colors.

**Fix:** Expose `CopyDefaults` through `DMX.Util` (the production utility namespace already used by `Options.lua`) or directly on `DMX`, and call that instead:

In `Duncedmaxxing/Util.lua`, add:
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

Util.CopyDefaults = CopyDefaults
```

Then in `Options.lua:424`:
```lua
-- Before (broken boundary):
GetCfg().stackColors = DMX._test.CopyDefaults(DMX.defaults.tip.stackColors)

-- After (clean):
local CopyDefaults = DMX.Util.CopyDefaults
-- ...
GetCfg().stackColors = CopyDefaults(DMX.defaults.tip.stackColors)
```

Alternatively, expose `CopyDefaults` directly on the `DMX` object in `Core.lua` (alongside `DMX.defaults`) without burying it in `_test`.

---

### CR-02: Reset Colors button text is not restored after a confirmed reset

**File:** `Duncedmaxxing/Options.lua:417-427`

**Issue:** On the second click (confirm path), `Options.resetColorsPending` is set to `false` at line 419 before `Options:Refresh()` is called at line 426. Inside `Refresh`, the text-restore guard at line 469 checks `self.resetColorsPending` — which is already `false` — so the guard body never executes and the button text is never reset. The button remains displaying "Confirm Reset" indefinitely after a successful color reset, requiring the user to close and reopen the options window before it reverts (and even then `OnShow -> Refresh` does not help because `resetColorsPending` is already `false` at that point).

This contradicts the plan spec: "On second click within 3 seconds: reset button text to 'Reset Colors'."

**Fix:** Explicitly reset the button text on the confirm path before calling `Refresh`:

```lua
else
    -- Second click: perform the reset
    Options.resetColorsPending = false
    if Options.resetColorsTimer then
        Options.resetColorsTimer:Cancel()
        Options.resetColorsTimer = nil
    end
    resetColorsBtn:SetText("Reset Colors")    -- ADD THIS LINE
    GetCfg().stackColors = DMX._test.CopyDefaults(DMX.defaults.tip.stackColors)
    RefreshTracker()
    Options:Refresh()
end
```

---

## Warnings

### WR-01: `self.numberSection` accessed without nil guard inside `if self.barSection` block

**File:** `Duncedmaxxing/Options.lua:450-460`

**Issue:** The show/hide block uses `self.barSection` as the sole nil guard but directly dereferences `self.numberSection` inside both branches (lines 453 and 457). Both fields are set in the same `BuildWindow` call, so co-presence is guaranteed in practice, but the asymmetric guard is fragile: if a future refactor creates `barSection` without `numberSection` (or vice versa), `Refresh` would throw an attempt-to-index-nil error.

```lua
if self.barSection then
    if cfg.displayMode == "bar" then
        self.barSection:Show()
        self.numberSection:Hide()   -- numberSection not guarded
```

**Fix:** Guard symmetrically:

```lua
if self.barSection and self.numberSection then
    if cfg.displayMode == "bar" then
        self.barSection:Show()
        self.numberSection:Hide()
        self.window:SetSize(386, 380)
    else
        self.barSection:Hide()
        self.numberSection:Show()
        self.window:SetSize(386, 484)
    end
end
```

---

## Info

### IN-01: `textColor` field is now orphaned — present in `DEFAULTS` and read at runtime but no longer editable via the Options UI

**File:** `Duncedmaxxing/Core.lua:27`, `Duncedmaxxing/Modules/TipOfTheSpear.lua:494`

**Issue:** The "Text" color input was intentionally removed from the bar-mode `Colors` section in this phase. `textColor` remains in `DEFAULTS` and is read in `TipOfTheSpear.lua:494` to color bar-mode number text. There is no UI control to modify it. Users who previously set a custom `textColor` silently keep it; new users cannot change it. This hidden configuration path may confuse future maintainers who see the field in `DEFAULTS` but cannot find an input for it.

**Fix:** Either re-add a `textColor` input to `barSection` (if the feature is wanted), or remove `textColor` from `DEFAULTS` and the `RefreshLayout` reference, replacing it with the hardcoded `{1, 1, 1, 1}` white. A comment in `DEFAULTS` noting the intentional omission would also suffice.

---

### IN-02: `spec/core_spec.lua` migration-fixture test does not include `stackColors` in the fixture tip table

**File:** `spec/core_spec.lua:168-187`

**Issue:** The `migratedDB` helper in the "already migrated branch" and "deprecated fields" describe blocks constructs a `tip` table without a `stackColors` key. A fully-migrated DB would have `stackColors` populated. The tests verify that `NormalizeDB` skips migration (correct), but they don't assert anything about `stackColors` on the already-migrated path. If `NormalizeDB` were to accidentally strip `stackColors` from an already-migrated DB, these tests would not catch it.

**Fix:** Add an assertion to the already-migrated idempotency test confirming `stackColors` is not stripped:

```lua
it("NormalizeDB idempotency — double call does not wipe settings", function()
    local db = migratedDB()
    -- Inject stackColors to verify it survives normalization
    db.tip.stackColors = { [0]={r=1,g=1,b=1,a=1}, [1]={r=0,g=1,b=0,a=1} }
    DMX._test.NormalizeDB(db)
    DMX._test.NormalizeDB(db)
    assert.equals("bar", db.tip.displayMode)
    assert.equals(0,     db.tip.x)
    assert.equals(-160,  db.tip.y)
    assert.equals(1,     db.tip.scale)
    assert.is_table(db.tip.stackColors, "stackColors must survive idempotent NormalizeDB")
end)
```

---

_Reviewed: 2026-06-29T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
