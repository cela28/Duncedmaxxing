---
status: partial
phase: 01-utility-extraction-and-module-encapsulation
source: [01-VERIFICATION.md, 03-02-SUMMARY.md, 04-01-SUMMARY.md]
started: 2026-06-17T15:45:00Z
updated: 2026-06-22T00:00:00Z
scope: full-milestone smoke test (phases 01-04)
---

## Current Test

[awaiting human testing — no game access]

## Tests

### 1. Addon loads without errors
expected: `/reload ui` with Duncedmaxxing enabled — no Lua errors in chat. Tracker frame appears at screen center (bar or icon mode depending on saved settings).
result: [pending]

### 2. Kill Command grants stacks (no Twin Fangs)
expected: Without Twin Fangs talented, cast Kill Command on a target dummy. Tracker updates from 0→2 stacks instantly (before server aura confirmation). Bar fills 2 of 5 segments or 2 icon pips light up.
result: [pending]

### 3. Kill Command grants stacks (with Twin Fangs)
expected: With Twin Fangs talented, cast Kill Command. Tracker updates from 0→3 stacks instantly. Subsequent Kill Command caps at 5 (not 6). Respec away from Twin Fangs, `/reload ui`, Kill Command grants +2 again.
result: [pending]

### 4. Takedown consume-after-grant order
expected: At 2+ stacks, cast a spender (Raptor Strike/Mongoose Bite). One stack consumed. If Twin Fangs active AND Takedown procs, the Takedown cast should grant before consuming (net +2 with Twin Fangs, net +1 without).
result: [pending]

### 5. Stack expiry and aura reconciliation
expected: Build stacks, then stop attacking. After ~12s buff expires — tracker resets to 0. During the buff window, tracker count matches the buff tooltip stack count (aura verification catches any drift).
result: [pending]

### 6. Combat show/hide behavior
expected: With `showOnlyInCombat` enabled, tracker is hidden out of combat. Pull a mob — tracker appears. Leave combat — tracker hides after a short delay. No Lua errors during transitions.
result: [pending]

### 7. Settings persistence across reload
expected: Open settings (`/dmax`), change display mode (bar↔icon), adjust scale, toggle border. `/reload ui` — all changes preserved. Settings popup blocks during combat (`InCombatLockdown` guard).
result: [pending]

### 8. Performance — no per-frame API spam
expected: With the addon loaded in combat, `/run print(GetFrameRate())` shows no FPS drop compared to addon disabled. Phase 04 caching should eliminate per-frame `GetSpellTexture`/config lookups.
result: [pending]

## Summary

total: 8
passed: 0
issues: 0
pending: 8
skipped: 0
blocked: 0

## Gaps
