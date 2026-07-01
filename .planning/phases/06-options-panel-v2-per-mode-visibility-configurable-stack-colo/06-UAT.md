---
status: testing
phase: 06-options-panel-v2-per-mode-visibility-configurable-stack-colo
source: [06-VERIFICATION.md]
started: 2026-07-02T00:00:00Z
updated: 2026-07-02T00:00:00Z
---

## Current Test

number: 1
name: Per-mode widget visibility (Bar vs Number)
expected: |
  In Bar mode: Width, Height, Border size, Fill, Empty % are visible; Text size,
  "Color by stack" checkbox, the 4 per-stack color inputs, and the flat Text color
  input are hidden. Position (X/Y/Scale), Enabled, Hide empty, and Border color are
  visible in both modes. In Number mode the reverse holds (Number-only controls shown,
  Bar-only controls hidden). Matches ROADMAP SC-1 / DISP-05.
awaiting: user response

## Tests

### 1. Per-mode widget visibility (Bar vs Number)
expected: In Bar mode, Bar-only controls (Width, Height, Border size, Fill, Empty %) are visible and Number-only controls (Text size, "Color by stack" checkbox, 4 per-stack color inputs, flat Text color input) are hidden; in Number mode the reverse holds; shared controls (Position X/Y/Scale, Enabled, Hide empty, Border color) show in both. (SC-1 / DISP-05)
result: [pending]

### 2. Mode switching via buttons and slash command
expected: Clicking the Bar/Number buttons AND running `/dmax mode bar` / `/dmax mode number` with the panel open both refresh widget visibility and the active-button highlight immediately, with no Lua error and no window resize (window stays 386x484). (SC-2 / DISP-05 / DISP-07)
result: [pending]

### 3. Stack color editing and toggle behavior
expected: In Number mode, editing each of the 4 per-stack color hex inputs and the flat Text color input to distinct colors changes the in-game number color to match the intended source — per-stack colors when "Color by stack" is ON, the flat Text color when OFF. The inactive color group visibly greys out (dimmed, SetAlpha ~0.4) while the active group stays fully opaque. (SC-3 / SC-4 UI half / DISP-06)
result: [pending]

### 4. Display label removal and mode-button highlight
expected: No "Display:" text label appears anywhere in the window (in either mode) and it does not overlap the Bar button; the currently active mode button (Bar or Number) is visually distinguishable (locked highlight / full alpha) from the inactive button. (SC-5 / DISP-07)
result: [pending]

## Summary

total: 4
passed: 0
issues: 0
pending: 4
skipped: 0
blocked: 0

## Gaps
