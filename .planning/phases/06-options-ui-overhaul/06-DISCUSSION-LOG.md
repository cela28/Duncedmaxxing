# Phase 6: Options UI Overhaul — Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-29
**Phase:** 06-options-ui-overhaul
**Areas discussed:** Stack color inputs, Mode-conditional layout, Lock toggle style, Reset Colors confirmation

---

## Stack Color Inputs

| Option | Description | Selected |
|--------|-------------|----------|
| Hex inputs (Recommended) | 4 hex text fields, same style as existing Fill/Border/Text inputs. Labels: '0 stacks', '1 stack', '2 stacks', '3 stacks'. Consistent with the rest of the panel. | ✓ |
| Hex inputs with preview swatch | Same hex fields but with a small colored square next to each showing the current color. More visual feedback but more rendering code. | |
| Preset palettes only | Pick from 3-4 predefined color schemes (e.g., Red ramp, Green ramp, Class colors). No free hex entry. Simpler but less flexible. | |

**User's choice:** Hex inputs (Recommended)
**Notes:** None — straightforward consistency choice.

---

## Mode-Conditional Layout

| Option | Description | Selected |
|--------|-------------|----------|
| Toggle visibility (Recommended) | Show/hide sections with :Show()/:Hide() on mode switch. Simpler code, instant toggle, window resizes by adjusting SetSize height. All widgets created once at build time. | ✓ |
| Rebuild on mode switch | Destroy and recreate the mode-specific section each time. Cleaner state but more complex, briefly flickers, and fights WoW's frame recycling. | |

**User's choice:** Toggle visibility (Recommended)
**Notes:** None.

---

## Lock Toggle Style

| Option | Description | Selected |
|--------|-------------|----------|
| Text swap + color | Button reads 'Unlock' (red-ish tint) when locked, 'Lock' (green-ish tint) when unlocked. Clear state at a glance. | |
| Text swap only | Button reads 'Unlock'/'Lock' — no color change. Minimal, relies on the text label alone. | ✓ |
| Icon-style toggle | Uses a lock/unlock unicode symbol with text. Visually distinct but depends on WoW font glyph support. | |

**User's choice:** Text swap only
**Notes:** None — user prefers minimal approach.

---

## Reset Colors Confirmation

| Option | Description | Selected |
|--------|-------------|----------|
| Inline two-click | First click changes button text to 'Confirm Reset'. Second click within ~3s actually resets. No click or timeout reverts to 'Reset Colors'. Simple, no extra frames. | ✓ |
| StaticPopup dialog | Uses WoW's StaticPopup_Show to display a modal 'Are you sure?' dialog with Accept/Cancel. Standard WoW UX but heavier. | |

**User's choice:** Inline two-click (changed from initial StaticPopup selection)
**Notes:** User changed their mind after initial selection. Final decision: inline two-click.

---

## Claude's Discretion

- Exact Y-offset positioning of controls within the window
- How to group mode-specific sections internally (container frame vs individual widget tracking)
- Whether to extract the two-click confirm pattern into a reusable helper or inline it
- Test file organization for new settings structure assertions

## Deferred Ideas

None — discussion stayed within phase scope.
