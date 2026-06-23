---
phase: 05-refactor-display-modes-remove-icon-mode-and-add-a-bar-text-m
plan: "01"
subsystem: display-modes
tags:
  - lua
  - wow-addon
  - refactor
  - display-modes
dependency_graph:
  requires: []
  provides:
    - two-mode display surface (bar + number only)
    - clean NormalizeDB validation for bar|number
    - slash parser with no icon/icons token
  affects:
    - Duncedmaxxing/Core.lua
    - Duncedmaxxing/Options.lua
    - Duncedmaxxing/Modules/TipOfTheSpear.lua
tech_stack:
  added: []
  patterns:
    - Pure source removal — no new abstractions introduced
key_files:
  created: []
  modified:
    - Duncedmaxxing/Core.lua
    - Duncedmaxxing/Options.lua
    - Duncedmaxxing/Modules/TipOfTheSpear.lua
decisions:
  - Remove icons mode entirely with no migration path — persisted icons/icon values normalize to bar via NormalizeDB
  - Bar else-branch is the catch-all in both RefreshLayout and Update for any unknown displayMode value
  - spellTexture, CacheSpellTexture, FALLBACK_ICON left in place (out of scope per Phase 5 decisions)
metrics:
  duration: "~12 minutes"
  completed: "2026-06-23"
  tasks_completed: 3
  tasks_total: 3
  files_changed: 3
status: complete
requirements:
  - DISP-01
  - DISP-02
  - DISP-03
---

# Phase 05 Plan 01: Remove Icons Display Mode Summary

**One-liner:** Removed icons display mode in full from all three addon source files, leaving exactly bar and number as the final mode set.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Remove icons from Core.lua — validation, slash parser, help text, orphaned defaults | `6f5d89e` | `Duncedmaxxing/Core.lua` |
| 2 | Remove icons from Options.lua — MODE_LABELS, Icons button, icon sliders | `bd98215` | `Duncedmaxxing/Options.lua` |
| 3 | Remove icons branches from TipOfTheSpear.lua RefreshLayout and Update | `b6951f9` | `Duncedmaxxing/Modules/TipOfTheSpear.lua` |

## What Was Built

This plan is a pure removal/refactor. The following were deleted:

**Core.lua:**
- `iconSize = 28` and `iconSpacing = 4` keys removed from `DEFAULTS.tip`
- `NormalizeDB` displayMode validation changed from three-mode (`bar|icons|number`) to two-mode (`bar|number`); stored `"icons"` now normalizes to default `"bar"` without a migration table
- Slash mode handler: removed `if mode == "icon" then mode = "icons" end` legacy alias
- Slash mode handler: removed `icons` from the accept set; usage hint now reads `bar|number`
- `PrintHelp` mode line updated from `bar|icons|number` to `bar|number`

**Options.lua:**
- `icons = "Icons"` entry removed from `MODE_LABELS` table
- `CreateButton("Icons", ...)` call removed (was the middle of three mode buttons)
- `CreateInput("Icon size", ...)` slider removed (bound to `iconSize`)
- `CreateInput("Icon gap", ...)` slider removed (bound to `iconSpacing`)
- `CreateInput("Text size", ...)` and all other widgets left intact
- `Options:Refresh` modeText fallback (`MODE_LABELS[cfg.displayMode] or "Bar"`) unchanged — correctly falls back to "Bar" for any unknown mode

**TipOfTheSpear.lua:**
- `if mode == "icons" then ... end` block in `RefreshLayout` removed; `elseif mode == "number"` promoted to leading `if`
- `if mode == "icons" then ... return end` block in `Update` removed; bar `else` fallback is unchanged catch-all
- `EnsureFrame`, pip creation, `spellTexture`, `CacheSpellTexture`, `FALLBACK_ICON` left untouched

## Verification Results

```
# Repo-wide scan — authoritative pattern
grep -rnE 'iconSize|iconSpacing|"icons"|"icon"|bartext' Duncedmaxxing/ ; test $? -eq 1
→ CLEAN (no matches)

# Two-mode NormalizeDB validation present
grep -nE 'displayMode ~= "bar" and tip.displayMode ~= "number"' Duncedmaxxing/Core.lua
→ Core.lua:96 match confirmed

# Exactly two mode buttons
grep -c 'self:SetMode' Duncedmaxxing/Options.lua
→ 2
```

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None — this plan removes dead code only; no stubs were introduced.

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes introduced. This is a pure deletion/refactor with no new WoW API surface.

The threat mitigations from the plan's threat register were applied:
- **T-05-01** (Tampering — stored displayMode): NormalizeDB now rejects any value that is not `bar` or `number`, falling back to default `bar`.
- **T-05-02** (DoS — RefreshLayout/Update mode branch): The `else` branch in both functions is the bar catch-all for any unexpected value that bypasses validation.
- **T-05-03** (Tampering — slash mode handler): Accepted set is `bar|number` only; any other token is rejected with the usage hint and no state is mutated.

## Self-Check: PASSED

All modified files present. All three task commits verified in git log.
