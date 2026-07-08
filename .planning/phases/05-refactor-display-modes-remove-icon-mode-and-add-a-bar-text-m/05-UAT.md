---
status: complete
phase: 05-refactor-display-modes-remove-icon-mode-and-add-a-bar-text-m
source: [05-01-SUMMARY.md, 05-02-SUMMARY.md]
started: 2026-06-23T22:01:42Z
updated: 2026-07-08T12:35:00Z
---

## Current Test

[testing complete]

## Tests

### 1. Options window — two modes only
expected: /dmax opens settings; exactly two mode buttons (Bar, Number); no Icons button; no Icon size / Icon gap sliders
result: pass

### 2. Bar mode renders correctly
expected: Select Bar mode. The tracker shows Tip of the Spear stacks as a segmented bar that fills/empties as the stack count changes (0–3) in combat
result: pass

### 3. Number mode renders correctly
expected: Select Number mode. The tracker shows the stack count as a number that updates (0–3) as you generate/consume Tip of the Spear stacks
result: pass

### 4. Slash mode bar/number switch
expected: /dmax mode bar switches to bar display; /dmax mode number switches to number display. Both work with no Lua error
result: skipped
reason: "Stale — feature removed. The `/dmax mode …` subcommand was deleted in quick task 260624-0hx (slash interface reduced to settings-only) and its absence was re-confirmed in Phase 06 verification (grep 'mode' Core.lua → 0 subcommand hits; Phase 06 UAT test 1 verified `/dmax mode bar` is a no-op and passed). Test describes a removed interface; no code to exercise."

### 5. Slash rejects icons/icon
expected: /dmax mode icons and /dmax mode icon are BOTH rejected with a usage hint that lists only bar|number — neither changes the display
result: skipped
reason: "Stale — depends on the removed `/dmax mode` subcommand (see test 4). No slash mode parser exists to reject anything; mode switching is button-only."

### 6. Legacy persisted "icons" falls back to bar
expected: With a stored displayMode of "icons" (or any unknown value) in SavedVariables, /reload loads cleanly with the display in Bar mode — no Lua error and no settings wipe (your other settings are preserved)
result: pass
note: "User accepts on automated-test evidence (Core.lua:127-128 unknown-mode fallback + fengari suite). User noted they don't care about legacy options; the fallback still guarantees no Lua error on any unknown displayMode value."

### 7. Test suite green (dev machine)
expected: Running `npx -y -p fengari@0.1.5 node spec/run.cjs` from the repo root reports all tests passing with 0 failures, icon-mode assertions removed and bar/number coverage intact
result: pass

## Summary

total: 7
passed: 5
issues: 0
pending: 0
skipped: 2
blocked: 0

## Gaps

[none yet]
