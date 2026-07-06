---
status: complete
phase: 06-options-panel-v2-per-mode-visibility-configurable-stack-colo
source: [06-VERIFICATION.md]
started: 2026-07-02T00:00:00Z
updated: 2026-07-06T00:00:00Z
---

## Current Test

[testing complete]

## Tests

### 1. Per-mode widget visibility (Bar vs Number)
expected: In Bar mode, Bar-only controls (Width, Height, Border size, Fill, Empty %) are visible and Number-only controls (Text size, "Color by stack" checkbox, 4 per-stack color inputs, flat Text color input) are hidden; in Number mode the reverse holds; shared controls (Position X/Y/Scale, Enabled, Hide empty, Border color) show in both. (SC-1 / DISP-05)
result: issue
reported: "We do not need border color for text or scale"
severity: minor

### 2. Mode switching via buttons and slash command
expected: Clicking the Bar/Number buttons AND running `/dmax mode bar` / `/dmax mode number` with the panel open both refresh widget visibility and the active-button highlight immediately, with no Lua error and no window resize (window stays 386x484). (SC-2 / DISP-05 / DISP-07)
result: issue
reported: "do not need enabled checkbox at all - also we asked for the reset button to be removed; I do not want any slash commands for modes"
severity: major

### 3. Stack color editing and toggle behavior
expected: In Number mode, editing each of the 4 per-stack color hex inputs and the flat Text color input to distinct colors changes the in-game number color to match the intended source — per-stack colors when "Color by stack" is ON, the flat Text color when OFF. The inactive color group visibly greys out (dimmed, SetAlpha ~0.4) while the active group stays fully opaque. (SC-3 / SC-4 UI half / DISP-06)
result: issue
reported: "the defaults look like this which seems inaccurate [screenshot: Border 000000, Text ffffff (greyed), 0 stacks ffffff, 1 stack ffffff, 2 stacks ffffff, 3 stacks ffffff]"
severity: major

### 4. Display label removal and mode-button highlight
expected: No "Display:" text label appears anywhere in the window (in either mode) and it does not overlap the Bar button; the currently active mode button (Bar or Number) is visually distinguishable (locked highlight / full alpha) from the inactive button. (SC-5 / DISP-07)
result: pass

### 5. Options panel layout / empty space organization
expected: Panel real estate is used efficiently — no large dead gaps (e.g. the empty upper-right area beside Position in Bar mode), columns balanced, sections evenly spaced across both modes.
result: issue
reported: "organize empty space better too [screenshots: Bar mode has large empty region upper-right next to Position; overall layout has uneven gaps]"
severity: cosmetic

## Summary

total: 5
passed: 1
issues: 4
pending: 0
skipped: 0
blocked: 0

## Gaps

- truth: "In Number (text) mode, only text-relevant controls show; Border color and Scale should be hidden because text has no border and uses Text size for sizing"
  status: failed
  reason: "User reported: We do not need border color for text or scale"
  severity: minor
  test: 1
  root_cause: ""
  artifacts: []
  missing: []
  debug_session: ""

- truth: "The Enabled checkbox is not wanted and should be removed from the options panel entirely"
  status: failed
  reason: "User reported: do not need enabled checkbox at all"
  severity: minor
  test: 2
  root_cause: ""
  artifacts: []
  missing: []
  debug_session: ""

- truth: "The Reset button should be removed from the options panel (previously requested, not yet done)"
  status: failed
  reason: "User reported: we asked for the reset button to be removed"
  severity: major
  test: 2
  root_cause: ""
  artifacts: []
  missing: []
  debug_session: ""

- truth: "Mode switching should be button-only; the /dmax mode bar|number slash commands should be removed entirely"
  status: failed
  reason: "User reported: I do not want any slash commands for modes"
  severity: major
  test: 2
  root_cause: ""
  artifacts: []
  missing: []
  debug_session: ""

- truth: "The per-stack color inputs should display the actual default colors (0=white, 1=green, 2=yellow, 3=red per Core.lua DEFAULTS.stackColors); instead all four render as ffffff"
  status: failed
  reason: "User reported: the defaults look like this which seems inaccurate (all 4 stack inputs show ffffff)"
  severity: major
  test: 3
  root_cause: ""
  artifacts:
    - path: "Duncedmaxxing/Core.lua"
      issue: "DEFAULTS.stackColors stored as positional arrays {r,g,b,a} indexed [0..3]"
    - path: "Duncedmaxxing/Options.lua"
      issue: "Stack color inputs likely read named r/g/b keys, so positional-array defaults yield nil -> ffffff fallback"
  missing: []
  debug_session: ""

- truth: "Options panel uses its space efficiently with no large dead gaps and balanced columns in both modes"
  status: failed
  reason: "User reported: organize empty space better too (Bar mode shows a large empty region upper-right beside Position; uneven section spacing)"
  severity: cosmetic
  test: 5
  root_cause: ""
  artifacts: []
  missing: []
  debug_session: ""
