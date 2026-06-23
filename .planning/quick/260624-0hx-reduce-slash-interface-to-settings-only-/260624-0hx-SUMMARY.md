---
phase: 260624-0hx
plan: "01"
subsystem: slash-interface
tags: [slash, settings, readme, cleanup]
status: complete

dependency_graph:
  requires: []
  provides: [SLASH-SETTINGS-ONLY, README-DEBLOAT]
  affects: [Duncedmaxxing/Core.lua, README.md]

tech_stack:
  added: []
  patterns: [settings-only slash dispatch]

key_files:
  created: []
  modified:
    - Duncedmaxxing/Core.lua
    - README.md

decisions:
  - Remove all subcommand branches; slash handler now unconditionally opens the settings window
  - Remove PrintHelp and all four unused Util aliases (Clamp, ParseHexColor, ParseOnOff, Trim) from Core.lua header
  - Fallback when Options unavailable: print a short message (not nothing, not PrintHelp)

metrics:
  duration: "3min"
  completed: "2026-06-24"
---

# Phase 260624-0hx Plan 01: Reduce Slash Interface to Settings-Only Summary

**One-liner:** Replaced 120-line multi-branch slash dispatcher + PrintHelp with a 6-line settings-only handler; README stripped of icon mode, combat-only, and Restriction notes.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Reduce slash dispatcher to settings-only, remove PrintHelp | c45e073 | Duncedmaxxing/Core.lua |
| 2 | De-bloat and de-stale README.md | 893c3a1 | README.md |
| 3 | Confirm specs still pass (no spec changes needed) | — | — |

## What Was Built

**Core.lua:** The 120-line `SlashCmdList.DUNCEDMAXXING` handler (lock, unlock, move, reset, show, hide, test, scale, mode, size/barsize, border, color, empty, resetstyle, numeric preview) was replaced with:

```lua
SlashCmdList.DUNCEDMAXXING = function()
    if DMX.OpenOptions then
        DMX:OpenOptions()
    else
        DMX:Print("Settings window unavailable — try reloading the UI.")
    end
end
```

`PrintHelp` (3-line function) was removed. The four Util alias locals at the top of Core.lua (`Clamp`, `ParseHexColor`, `Trim`, `ParseOnOff`) were removed as they had no remaining references.

**README.md:** Removed the "## Restriction notes" section, replaced the 15-item "## Commands" list with a single statement, stripped icon mode / combat-only / icon-size / icon-spacing from Settings bullets, leaving two display modes (bar or number) and always-show tracker as the accurate description.

## Verification Results

1. `npx -y -p fengari@0.1.5 node spec/run.cjs` — **117 passed, 0 failed** (no spec edits needed)
2. `grep -nE 'resetstyle|barsize|PrintHelp|mode bar' Duncedmaxxing/Core.lua` — **no output (PASS)**
3. `grep -niE 'icon|combat.?only|restriction' README.md` — **no output (PASS)**
4. Sanity: both SLASH tokens and `DMX:OpenOptions` present in Core.lua — **PASS**
5. Sanity: `git diff --stat` shows only `Duncedmaxxing/Core.lua` and `README.md` changed — **PASS**

## Deviations from Plan

None — plan executed exactly as written. The spec suite passed without any spec file modifications, confirming the planning assessment that no spec exercises the removed slash subcommands.

## Known Stubs

None.

## Threat Flags

None — changes are pure deletion/simplification with no new network endpoints, auth paths, or schema changes.

## Self-Check: PASSED

- `Duncedmaxxing/Core.lua` modified: confirmed (c45e073)
- `README.md` modified: confirmed (893c3a1)
- Both commits present in git log: confirmed
- Options.lua unchanged: confirmed (not in diff)
