---
phase: 06-options-ui-overhaul
plan: "02"
subsystem: ui
tags:
  - options-ui
  - mode-conditional
  - stack-colors
  - lock-toggle
  - reset-colors

dependency_graph:
  requires:
    - phase: 06-01
      provides: DEFAULTS.tip.stackColors, config-driven stack color read in Tip:Update()
  provides:
    - barSection sub-frame with mode-specific bar controls (width, height, border, fill/border color, empty%)
    - numberSection sub-frame with mode-specific number controls (text size, 4 stack color hex inputs, Reset Colors button)
    - Single lock toggle button replacing two separate Unlock Bar/Lock Bar buttons
    - Dynamic window height: 380px bar mode, 484px number mode
    - Two-click Reset Colors confirmation with C_Timer.NewTimer 3-second revert
  affects:
    - Duncedmaxxing/Options.lua

tech_stack:
  added: []
  patterns:
    - Sub-frame visibility gating — barSection/numberSection as CreateFrame siblings, shown/hidden in Refresh() based on cfg.displayMode
    - Raw CreateFrame button for two-click confirm state machine (bypasses factory auto-Refresh that would revert confirm text)
    - BOTTOMLEFT anchor override — create button via factory then ClearAllPoints/SetPoint BOTTOMLEFT for action row pinning

key_files:
  created: []
  modified:
    - Duncedmaxxing/Options.lua

key_decisions:
  - "barSection and numberSection both anchored at TOPLEFT (0, -248) — they overlap but only one is visible at a time per Refresh() show/hide logic"
  - "Reset Colors button uses raw CreateFrame not the CreateButton factory — factory auto-calls Options:Refresh() after onClick which would revert the Confirm Reset text on the first click"
  - "Lock toggle text sync done in Refresh() not in onClick closure — CreateButton factory calls Refresh() after onClick so the text update happens automatically"
  - "Reset Colors pending state cleared on every Refresh() call — prevents stale confirm state if mode is switched or window reopened while confirm is pending"

patterns-established:
  - "Sub-frame visibility toggle: create section sub-frames at BuildWindow time, show/hide in Refresh() based on cfg.displayMode"
  - "Action row BOTTOMLEFT pinning: create via factory (TOPLEFT anchor), then ClearAllPoints + SetPoint BOTTOMLEFT"

requirements-completed:
  - PHASE-06-GOAL

coverage:
  - id: D1
    description: "Dead controls removed: Enabled checkbox, Unlock Bar/Lock Bar buttons, Reset button, Reset Style button, Other Modes section header, Text color input"
    requirement: PHASE-06-GOAL
    verification:
      - kind: unit
        ref: "spec/ — 121 tests pass, no regressions from removed controls"
        status: pass
    human_judgment: true
    rationale: "Absence of UI elements requires WoW client visual inspection to confirm the controls are gone from the rendered window"
  - id: D2
    description: "Single lock toggle button replaces two separate lock buttons — shows Unlock when locked, Lock when unlocked; clicking toggles db.locked and calls ApplyLock"
    requirement: PHASE-06-GOAL
    verification:
      - kind: unit
        ref: "spec/ — 121 tests pass"
        status: pass
    human_judgment: true
    rationale: "Lock state toggle behavior and button text swap requires WoW client interaction to verify"
  - id: D3
    description: "Bar mode shows barSection controls (width, height, border, fill color, border color, empty%), numberSection is hidden; window height is 380px"
    requirement: PHASE-06-GOAL
    verification:
      - kind: unit
        ref: "spec/ — 121 tests pass"
        status: pass
    human_judgment: true
    rationale: "Mode-conditional visibility and window height require WoW client visual verification"
  - id: D4
    description: "Number mode shows numberSection controls (text size, 4 stack color hex inputs labeled 0 stacks/1 stack/2 stacks/3 stacks), barSection is hidden; window height is 484px"
    requirement: PHASE-06-GOAL
    verification:
      - kind: unit
        ref: "spec/ — 121 tests pass"
        status: pass
    human_judgment: true
    rationale: "Mode-conditional visibility and stack color input rendering require WoW client visual verification"
  - id: D5
    description: "Stack color hex inputs read/write GetCfg().stackColors[i] via ColorToHex/ParseHexColor; editing a color updates the tracker display"
    requirement: PHASE-06-GOAL
    verification:
      - kind: unit
        ref: "spec/ — 121 tests pass, config-driven color read covered by tip_spec.lua"
        status: pass
    human_judgment: true
    rationale: "Editing a hex input and observing tracker color update requires WoW client interaction"
  - id: D6
    description: "Reset Colors first click changes button text to Confirm Reset; waiting 3s reverts to Reset Colors; second click within 3s deep-copies stackColors defaults and resets tracker"
    requirement: PHASE-06-GOAL
    verification:
      - kind: unit
        ref: "spec/ — 121 tests pass"
        status: pass
    human_judgment: true
    rationale: "Two-click confirm state machine with timer behavior requires WoW client manual testing"
  - id: D7
    description: "Preview Tracker and lock toggle buttons anchored to BOTTOMLEFT of window action row at (16, 16) and (100, 16)"
    requirement: PHASE-06-GOAL
    verification:
      - kind: unit
        ref: "spec/ — 121 tests pass"
        status: pass
    human_judgment: true
    rationale: "Action row visual positioning requires WoW client inspection"

duration: 8min
completed: 2026-06-29
status: complete
---

# Phase 06 Plan 02: Options Window Restructure with Mode-Conditional Sections Summary

Options.lua fully restructured with barSection/numberSection sub-frames, 4 per-stack color hex inputs, Reset Colors two-click confirm, single lock toggle button, dead controls removed, and dynamic window height (380px bar / 484px number).

## Performance

- **Duration:** ~8 min
- **Started:** 2026-06-29T12:00:00Z
- **Completed:** 2026-06-29T12:08:00Z
- **Tasks:** 2 (implemented together in one atomic write)
- **Files modified:** 1

## Accomplishments

- Removed 6 dead controls: Enabled checkbox, Unlock Bar button, Lock Bar button, Reset button, Reset Style button, Other Modes section header, Text color input
- Created barSection sub-frame with Width, Height, Border, Fill color, Border color, and Empty % controls (visible only in bar mode)
- Created numberSection sub-frame with Text size, 4 stack color hex inputs (0 stacks/1 stack/2 stacks/3 stacks), and Reset Colors button (visible only in number mode)
- Added single lock toggle button (BOTTOMLEFT action row) replacing two separate buttons, with Unlock/Lock text sync in Refresh()
- Reset Colors uses raw CreateFrame with two-click inline confirm and C_Timer.NewTimer 3-second auto-revert
- Shared controls (Position X/Y/Scale, Hide empty) repositioned per UI-SPEC; both action-row buttons pinned to BOTTOMLEFT
- Dynamic window height: 380px in bar mode, 484px in number mode via SetSize in Refresh()

## Task Commits

1. **Task 1+2: Remove dead controls, restructure shared section, add lock toggle, barSection/numberSection** - `ff2788d` (feat)

**Plan metadata:** pending (docs commit)

## Files Created/Modified

- `Duncedmaxxing/Options.lua` — Full restructure: dead controls removed, shared controls repositioned, barSection/numberSection sub-frames added, lock toggle, 4 stack color inputs, Reset Colors two-click confirm, dynamic window height

## Decisions Made

- Both tasks implemented in a single atomic write: the restructure is logically atomic — barSection, numberSection, and the shared controls repositioning are interdependent and cannot be partially applied.
- Reset Colors button uses raw `CreateFrame("Button", nil, numberSection, "UIPanelButtonTemplate")` instead of the `CreateButton` factory because the factory auto-calls `Options:Refresh()` after `onClick`, which would revert the "Confirm Reset" text on the first click before any second click could fire.
- Lock toggle placed only in the action row (BOTTOMLEFT), not duplicated in the shared controls section — UI-SPEC note on line 180 says "implement as one widget positioned in the action row only, simplifying the layout."
- Reset Colors pending state cleared in every `Refresh()` call to handle edge case where user switches modes while confirm is pending.

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

Options window restructure is complete. All controls are mode-conditional per UI-SPEC. Pending WoW client UAT (in-game testing required to visually verify all 7 deliverables listed in coverage block above).

The 8 smoke tests + stack color check from MEMORY.md remain as in-game UAT items before milestone close.

---
*Phase: 06-options-ui-overhaul*
*Completed: 2026-06-29*

## Self-Check: PASSED

- `Duncedmaxxing/Options.lua` — present on disk
- `.planning/phases/06-options-ui-overhaul/06-02-SUMMARY.md` — present on disk
- Commit `ff2788d` confirmed in git log
- `busted spec/` — 121 successes / 0 failures / 0 errors / 0 pending
