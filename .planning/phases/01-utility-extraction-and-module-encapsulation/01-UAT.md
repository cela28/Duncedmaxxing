---
status: diagnosed
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
  root_cause: "ApplySpell generator branch predicts the Kill Command grant as `self.hasTwinFangs and 3 or 2` (TipOfTheSpear.lua:695). Twin Fangs is a Takedown (consumer) modifier, NOT a Kill Command modifier — so when hasTwinFangs is true the predictive path over-predicts +3 while the real grant is 2. The display jumps to 3, then SyncFromAura reads the true aura (2 applications) and snaps back to 2, producing the '3 for an instant then 2' flicker. Introduced in commit 0cf4776 (Phase 03-02), surfaced by Phase 01 UAT."
  artifacts:
    - path: "Duncedmaxxing/Modules/TipOfTheSpear.lua:694-697"
      issue: "Generator (Kill Command) grant formula `self.hasTwinFangs and 3 or 2` incorrectly tied to Twin Fangs, which is a Takedown modifier."
    - path: "Duncedmaxxing/Modules/TipOfTheSpear.lua:35-43"
      issue: "HasTwinFangs() — Twin Fangs detection used in the wrong (generator) path; belongs only to the Takedown consumer path."
    - path: "Duncedmaxxing/Modules/TipOfTheSpear.lua:341-366"
      issue: "SyncFromAura corrects the over-prediction on the next aura read, making it a visible flicker rather than a stuck value."
  missing:
    - "Decouple the Kill Command (generator) grant from hasTwinFangs — keep Twin Fangs scoped to the Takedown consumer path (lines 699-703)."
    - "Derive the Kill Command grant from a Primal-Surge-aware value (base 1, +1 with Primal Surge) instead of hard-coding `3 or 2`; add Primal Surge detection analogous to HasTwinFangs()."
  debug_session: .planning/debug/kill-command-stack-overshoot.md
