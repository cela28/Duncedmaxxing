---
status: complete
phase: 01-utility-extraction-and-module-encapsulation
source: [01-01-SUMMARY.md, 01-02-SUMMARY.md]
started: 2026-06-21T21:11:37Z
updated: 2026-06-21T21:15:20Z
---

## Current Test

[testing complete]

## Tests

### 1. Cold load — no Lua errors
expected: With addon enabled, /reload ui produces no Lua errors in chat and no error popup. Tracker frame renders (or is hidden per settings) cleanly. This is the core behavior-preservation check after the Util.lua extraction and frame-reference migration.
result: pass

### 2. Options window opens and is functional
expected: Typing /dmax (or /duncedmaxxing) opens the movable settings popup. All widgets render, the window can be dragged, and it closes without error. Confirms Options.lua still wires to DMX.Util.Clamp / DMX.Util.ParseHexColor aliases correctly.
result: pass

### 3. Stack tracking works (Survival Hunter)
expected: On a Survival Hunter, casting Kill Command increments the displayed Tip of the Spear stack count instantly, the bar/icon display updates, and stacks expire correctly over time. Confirms the Tip-table frame ownership and pcall-free ClassifySpellID still drive the live display.
result: issue
reported: "when I press Kill command the stacks go to 3 for one instant before dropping back to 2"
severity: major

### 4. Settings changes apply and persist
expected: In the options window, changing display mode (bar ↔ icon), a color, scale, and position applies live to the tracker. After /reload ui the changes persist. Confirms ParseHexColor / Clamp aliases and SavePosition still work through the migrated frame fields.
result: pass

### 5. Spec gating
expected: Switching off the Survival spec (or onto a non-Hunter character) stops stack tracking / hides the tracker as before, with no Lua errors. Confirms deterministic module iteration (moduleOrder/ipairs) and spec-detection still gate the tracker.
result: pass

## Summary

total: 5
passed: 4
issues: 1
pending: 0
skipped: 0
blocked: 0

## Gaps

- truth: "Casting Kill Command increments the Tip of the Spear stack display to the correct count without overshooting"
  status: failed
  reason: "User reported: when I press Kill command the stacks go to 3 for one instant before dropping back to 2"
  severity: major
  test: 3
  root_cause: ""     # Filled by diagnosis
  artifacts: []      # Filled by diagnosis
  missing: []        # Filled by diagnosis
  debug_session: ""  # Filled by diagnosis
