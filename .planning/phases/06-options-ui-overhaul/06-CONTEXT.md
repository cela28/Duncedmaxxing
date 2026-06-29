# Phase 6: Options UI Overhaul — Context

**Gathered:** 2026-06-29
**Status:** Ready for planning

<domain>
## Phase Boundary

This phase restructures the options window so each display mode shows only its relevant settings, removes dead/redundant controls, and adds per-stack color customization for number mode. The two display modes (`bar` and `number`) are already established from Phase 5.

**In scope:**
- Mode-conditional settings: bar mode shows bar-specific controls (width, height, border, fill color, border color, empty%); number mode shows number-specific controls (text size, 4 stack color hex inputs). Shared controls (position x/y, scale, hide empty) visible in both modes.
- Remove the `enabled` checkbox — tracker is always active when survival spec.
- Replace separate Unlock/Lock buttons with a single toggle button.
- Remove Reset and Reset Style buttons.
- Add per-stack color customization: 4 hex inputs for stacks 0–3, stored in `db.tip.stackColors`, read by `Tip:Update()` instead of the hardcoded `STACK_COLORS` table.
- Add a "Reset Colors" button (number mode only) with inline two-click confirmation.
- Window height adjusts to fit the active mode's controls without dead space.
- Update test suite for the new settings structure.

**Out of scope:**
- Adding new display modes.
- Color picker widgets or preset palettes.
- Changes to the tracker rendering logic beyond reading `stackColors` from config instead of the hardcoded table.

</domain>

<decisions>
## Implementation Decisions

### Stack color inputs
- **D-01:** Use 4 hex text input fields, same `CreateInput` widget style as existing Fill/Border/Text color inputs. Labels: "0 stacks", "1 stack", "2 stacks", "3 stacks". No preview swatches, no preset palettes.
- **D-02:** Colors stored in `db.tip.stackColors` as a table of 4 color entries (same `{r,g,b}` format as `fillColor`/`borderColor`). `Tip:Update()` reads from config instead of the hardcoded `STACK_COLORS` table. Default values match the current hardcoded colors.

### Mode-conditional layout
- **D-03:** Toggle visibility approach — all widgets created once at `BuildWindow` time. On mode switch, call `:Show()`/`:Hide()` on mode-specific sections and adjust the window height via `SetSize`. No frame destruction/recreation.

### Lock toggle
- **D-04:** Single button with text swap only. Reads "Unlock" when locked, "Lock" when unlocked. No color tinting — relies on the text label alone.

### Reset Colors confirmation
- **D-05:** Inline two-click confirmation. First click changes button text to "Confirm Reset" (or similar). Second click within ~3 seconds performs the actual reset. Timeout or no second click reverts button text to "Reset Colors". No StaticPopup dialog.

### Control removals
- **D-06:** Remove the `enabled` checkbox entirely. Remove `cfg.enabled` from visibility logic — tracker always shows when survival spec is active.
- **D-07:** Remove both the "Reset" and "Reset Style" buttons. No replacement.

### Claude's Discretion
- Exact Y-offset positioning of controls within the window.
- How to group the mode-specific sections internally (container frame vs individual widget tracking).
- Whether to extract the two-click confirm pattern into a reusable helper or inline it.
- Test file organization for new settings structure assertions.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Source files touched
- `Duncedmaxxing/Options.lua` — Current options window implementation. All widget creation in `BuildWindow()` (~line 179). Mode buttons (~248-249), Enabled checkbox (~251-253), Unlock/Lock buttons (~354-363), Reset/Reset Style buttons (~370-381). `Refresh()` method (~385-399).
- `Duncedmaxxing/Modules/TipOfTheSpear.lua` — Hardcoded `STACK_COLORS` table (to be replaced with config read). `Tip:Update()` rendering path that reads stack colors.
- `Duncedmaxxing/Core.lua` — `DEFAULTS.tip` table where `stackColors` defaults will be added and `enabled` default will be removed. `NormalizeDB` validation. `cfg.enabled` usage in visibility logic.

### Tests
- `spec/core_spec.lua` — NormalizeDB and defaults tests; update for `stackColors` addition and `enabled` removal.
- `spec/tip_spec.lua` — Stack display tests; update for config-driven colors.

### Prior phase context
- `.planning/phases/05-refactor-display-modes-remove-icon-mode-and-add-a-bar-text-m/05-CONTEXT.md` — Phase 5 decisions: exactly two modes (bar/number), no icons, no bartext.

### Project rules
- `CLAUDE.md` — Naming conventions, combat-safety constraints, idempotency guards.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `CreateInput` widget factory in `Options.lua` — reuse directly for the 4 stack color hex inputs (same pattern as Fill/Border/Text).
- `ParseHexColor` in `DMX.Util` — already used by color inputs; validates and converts hex strings to `{r,g,b,a}` tables.
- `ColorToHex` in `Options.lua` — converts `{r,g,b,a}` back to hex for display in input fields.
- `CreateCheckbox`, `CreateButton`, `CreateText` factories — reuse for the lock toggle and section headers.

### Established Patterns
- All settings mutations gated by `Options:CanChange()` (combat lockdown check).
- `RefreshTracker()` called after every setting change to update the display.
- `Options:Refresh()` syncs all widget values from config after any change.
- `GetCfg()` returns `db.tip` — all config reads go through this.

### Integration Points
- `Tip:Update()` in TipOfTheSpear.lua reads stack colors — needs to switch from hardcoded `STACK_COLORS` to `GetCfg().stackColors`.
- `DMX:GetDB().locked` — lock state already stored in DB; the toggle button reads/writes this same field.
- `DMX:ForEachModule("ApplyLock")` — existing lock application mechanism, reused by the toggle.

</code_context>

<specifics>
## Specific Ideas

- The window is currently fixed at 386×484. With mode-conditional visibility, bar mode will be shorter (no stack color inputs) and number mode will be taller (4 color inputs + reset button). Adjust height dynamically in `Refresh()` or in the mode-switch handler.
- The "Other Modes" label at line 310 of Options.lua should be renamed or removed since controls are now mode-conditional rather than grouped under a catch-all.
- Stack color defaults should match the current hardcoded `STACK_COLORS` values in TipOfTheSpear.lua so existing users see no visual change on upgrade.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 06-options-ui-overhaul*
*Context gathered: 2026-06-29*
