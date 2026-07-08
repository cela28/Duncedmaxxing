# Phase 6: Options panel v2 — per-mode visibility, configurable stack colors, layout fix - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-01
**Phase:** 06-options-panel-v2-per-mode-visibility-configurable-stack-colo
**Areas discussed:** Flat Text color picker interaction, Mode-selector layout fix, Panel sizing on mode switch

**Note:** The color model (toggle + 4 pickers, default ON) and the per-mode visibility mapping were already LOCKED in ROADMAP.md (user-confirmed 2026-07-01) and were not re-litigated. Discussion focused only on the remaining UI-presentation gray areas.

---

## Flat Text color picker + toggle interaction

| Option | Description | Selected |
|--------|-------------|----------|
| Hide flat picker when ON | In Number mode, show only the active model's controls: 4 stack pickers when ON, single flat Text picker when OFF | |
| Always show flat, grey pickers | Always show the flat Text picker and the 4 stack pickers; grey/disable whichever group is inactive per the toggle | ✓ |

**User's choice:** Always show flat, grey pickers
**Notes:** Both control groups always present in Number mode; the "Color by stack" toggle governs which group is greyed/disabled rather than swapping visibility.

---

## Mode-selector layout fix

| Option | Description | Selected |
|--------|-------------|----------|
| Highlight active button | Drop the "Display: X" text label; highlight the active mode button (Bar/Number) instead | ✓ |
| Reposition label above buttons | Keep the "Display: X" label but move it to its own line above the buttons | |

**User's choice:** Highlight active button
**Notes:** Removing the label both fixes the overlap and makes the active mode self-evident. Refresh logic that updated `modeText` is replaced by button-highlight logic.

---

## Panel sizing on mode switch

| Option | Description | Selected |
|--------|-------------|----------|
| Fixed size, blank space | Keep window a fixed size; hidden controls leave empty space, no reflow | ✓ |
| Compact per mode | Resize/reflow the window per mode to remove empty gaps | |

**User's choice:** Fixed size, blank space
**Notes:** Avoids a jumping window and layout-reflow logic.

---

## Claude's Discretion

- Field shape for the new stack colors in `DEFAULTS` (nested `stackColors` table vs. flat fields).
- Labeling and pixel layout of the 4 stack pickers.
- Visibility-gating mechanism (per-widget Show/Hide vs. per-mode containers).
- "Greyed/disabled" rendering technique for inactive color inputs.
- Test file organization for the new assertions.

## Deferred Ideas

None — discussion stayed within phase scope.
