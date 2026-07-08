---
phase: 06-options-panel-v2-per-mode-visibility-configurable-stack-colo
plan: 02
subsystem: ui
tags: [lua, wow-addon, options-ui, mode-gating, color-picker]

# Dependency graph
requires:
  - phase: 06-options-panel-v2-per-mode-visibility-configurable-stack-colo
    provides: DEFAULTS.tip.colorByStack + DEFAULTS.tip.stackColors (plan 01)
provides:
  - Per-mode widget visibility gating in Options:Refresh ("both"/"bar"/"number" groups)
  - "Color by stack" checkbox + 4 per-stack hex color inputs (stackColors[0..3]) in the options panel
  - Toggle-driven greying between the flat Text picker and the 4 stack pickers within Number mode
  - Active mode button highlight replacing the removed "Display: X" label
  - Options:SetMode triggers a panel refresh when the window is open (closes the /dmax mode slash-path gap)
affects: [06-03-options-panel-v2-plan (spec coverage)]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Widget-group tagging: CreateInput/CreateCheckbox now return their created frame(s) so BuildWindow can tag every widget into Options.widgetGroups[\"both\"|\"bar\"|\"number\"] for centralized Show/Hide gating in Refresh"
    - "Color-group greying: Options.colorGroups[\"flat\"|\"stack\"] pairs {widget,label} tables; SetColorGroupEnabled uses EditBox:Disable()/:Enable() + SetAlpha for a combat-safe visual toggle without show/hide-swapping either group"

key-files:
  created: []
  modified:
    - Duncedmaxxing/Options.lua

key-decisions:
  - "Reused array-indexed stackColors[N] tuples (set via ParseHexColor which returns r/g/b/a keys) — ColorTuple in TipOfTheSpear.lua already reads both .r/.g/.b/.a and [1]/[2]/[3]/[4] shapes, so no shape reconciliation was needed"
  - "Repositioned the Bar/Number mode buttons to x=16/x=82 (was x=108/x=244) after removing the colliding 'Display: X' label, and moved the right-column Colors block up (header at -238) to make room for 4 stack-color rows above the -414 bottom-button row, all within the unchanged 386x484 window (D-10)"
  - "Unrecognized/nil displayMode values fall back to 'bar' visibility in Refresh, mirroring the existing bar-as-catch-all pattern from Phase 5"

patterns-established:
  - "Mode-gated widget visibility: any future widget added to BuildWindow must call AddToGroup(\"both\"|\"bar\"|\"number\", widget, label) to participate in per-mode Show/Hide"

requirements-completed: [DISP-05, DISP-06, DISP-07]

# Metrics
duration: 8min
completed: 2026-07-02
status: complete
---

# Phase 06 Plan 02: Options Panel Per-Mode Visibility, Stack Colors, and Mode-Button Highlight Summary

**Options.lua now gates every widget's visibility by the active display mode, adds a "Color by stack" toggle plus 4 per-stack hex color inputs with toggle-driven greying against the flat Text picker, and replaces the "Display: X" label with an active mode-button highlight — all inside the unchanged 386x484 window.**

## Performance

- **Duration:** 8 min
- **Started:** 2026-07-01T21:08:33Z
- **Completed:** 2026-07-01T21:16:04Z
- **Tasks:** 2 completed
- **Files modified:** 1

## Accomplishments
- `CreateInput`/`CreateCheckbox` now return their created frame(s), enabling every `BuildWindow` widget to be tagged into `Options.widgetGroups` (`both`/`bar`/`number`) per the D-04/D-05/D-06 mapping.
- Added a "Color by stack" checkbox (`GetCfg().colorByStack`) and four per-stack hex color inputs (`GetCfg().stackColors[0..3]`) using the existing `CreateInput` + `ColorToHex`/`ParseHexColor` pattern verbatim.
- `Options:Refresh` now drives per-mode Show/Hide from `cfg.displayMode`: "both" widgets always shown, "bar" widgets only in bar mode, "number" widgets (Text size, the toggle, the 4 stack pickers, the flat Text picker) only in number mode.
- Within Number mode, `cfg.colorByStack` drives `SetColorGroupEnabled`, which disables/greys (via `EditBox:Disable()` + alpha) whichever of {flat Text picker} / {4 stack pickers} is inactive — both groups stay visible per D-08, only enabled state swaps.
- The "Display: X" label (`self.modeText` and its `Options:Refresh` update block) is fully removed. The Bar/Number mode buttons are captured as `Options.modeButtons.bar`/`.number` and highlighted (`LockHighlight`/alpha) to indicate the active mode, replacing the label as the mode indicator and eliminating the overlap bug (ROADMAP SC-5, D-09).
- `Options:SetMode` now calls `Options:Refresh()` (guarded by `self.window and self.window:IsShown()`) after setting `cfg.displayMode`, so `/dmax mode bar|number` updates visibility + highlight immediately when the panel is open (ROADMAP SC-2), closing the slash-path gap that previously only the button `onClick` handlers covered.
- Repositioned the mode buttons and the right-column layout to fit the 4 new stack-color rows without resizing the window or colliding with the bottom Unlock/Lock/Preview/Reset button rows.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add colorByStack toggle, 4 per-stack color inputs, and register widgets for mode-gating** - `c3b6b8c` (feat)
2. **Task 2: Per-mode visibility gating, toggle-driven greying, and mode-button highlight in Options:Refresh** - `c35638a` (feat)

**Plan metadata:** (recorded below after this commit)

## Files Created/Modified
- `Duncedmaxxing/Options.lua` - Widget-group tagging, colorByStack toggle + 4 stack color inputs, per-mode visibility gating in `Options:Refresh`, toggle-driven greying between flat Text and stack pickers, mode-button highlight replacing the removed "Display: X" label, `Options:SetMode` now refreshes the open panel

## Decisions Made
- Kept `stackColors[N]` as array-indexed RGBA tuples (set via `ParseHexColor`'s `.r/.g/.b/.a`-keyed return value) — `ColorTuple` in `TipOfTheSpear.lua` (from plan 01) already reads both shapes, so no additional reconciliation code was needed in Options.lua.
- Relaid out the right-hand column (Colors header moved to y=-238, Border/Fill/Empty%/Text/stack rows tightened to 22-28px spacing) so the 4 new stack-color rows fit above the existing bottom button row at y=-414 without any window resize, satisfying D-10.
- Treated any `displayMode` value other than exactly `"bar"` or `"number"` as `"bar"` for visibility purposes in `Options:Refresh`, mirroring the Phase 5 "bar is the catch-all" convention already used in `TipOfTheSpear.lua`.

## Deviations from Plan

None - plan executed exactly as written. Layout coordinates were adjusted from the plan's suggested positions to avoid widget overlap, which the plan explicitly left to "Claude's Discretion" (pixel layout of the 4 stack pickers).

## Issues Encountered

Initial widget placement for the 4 new stack-color pickers (stacked directly below the existing Fill/Border/Text/Empty% rows) extended past the bottom button row (y=-414) and would have overlapped the Unlock/Lock/Preview/Reset buttons. Resolved by moving the Colors header up 10px and using a shared row layout where Bar-only rows (Fill, Empty %) and Number-only rows (flat Text, 4 stack pickers) reuse the same vertical slots — since the two mode groups never render simultaneously, this keeps everything inside the fixed 386x484 window with no resize.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 03 (spec coverage) can now add fengari/Lua-VM assertions for the widget-group visibility gating, the colorByStack-driven greying, and the mode-button highlight behavior if in-scope for that plan's test additions.
- All ROADMAP success criteria for this plan (SC-1 visibility mapping, SC-2 mode-switch refresh, SC-3 stack-color controls, SC-5 label removal + highlight) are implemented in source; manual in-game verification (button/slash mode switching, toggle greying, no window resize) is still recommended before shipping per the plan's `<verification>` section.
- No blockers.

---
*Phase: 06-options-panel-v2-per-mode-visibility-configurable-stack-colo*
*Completed: 2026-07-02*

## Self-Check: PASSED

- FOUND: Duncedmaxxing/Options.lua
- FOUND: .planning/phases/06-options-panel-v2-per-mode-visibility-configurable-stack-colo/06-02-SUMMARY.md
- FOUND: commit c3b6b8c
- FOUND: commit c35638a
