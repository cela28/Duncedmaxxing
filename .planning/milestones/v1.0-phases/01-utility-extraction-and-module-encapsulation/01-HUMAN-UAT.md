---
status: complete
phase: 01-utility-extraction-and-module-encapsulation
source: [01-VERIFICATION.md, 03-02-SUMMARY.md, 04-01-SUMMARY.md]
started: 2026-06-17T15:45:00Z
updated: 2026-06-23T00:00:00Z
scope: full-milestone smoke test (phases 01-05)
---

## Current Test

[testing complete]

## Tests

### 1. Addon loads without errors
expected: `/reload ui` with Duncedmaxxing enabled — no Lua errors in chat. Tracker frame appears at screen center (bar or number mode depending on saved settings).
result: pass

### 2. Kill Command grants +2 stacks
expected: Cast Kill Command on a target dummy. Tracker updates from 0→2 stacks instantly (before server aura confirmation). Bar fills 2 of 3 segments, or the number shows 2. Twin Fangs does NOT change this — KC always grants +2.
result: pass

### 3. Takedown with Twin Fangs grants stacks
expected: With Twin Fangs talented, cast Takedown. It grants +3 stacks then consumes 1 (net +2). Without Twin Fangs, Takedown only consumes 1 stack.
result: pass

### 4. Spender consumes stacks
expected: At 2+ stacks, cast Raptor Strike or Mongoose Bite. One stack consumed. Tracker updates instantly. At 0 stacks, tracker resets.
result: pass

### 5. Stack expiry and aura reconciliation
expected: Build stacks, then stop attacking. After ~10s buff expires (BUFF_DURATION = 10) — tracker resets to 0. During the buff window, tracker count matches the buff tooltip stack count (aura verification catches any drift).
result: pass

### 6. Combat show/hide behavior
expected: With `showOnlyInCombat` enabled, tracker is hidden out of combat. Pull a mob — tracker appears. Leave combat — tracker hides after a short delay. No Lua errors during transitions.
result: skipped
reason: "Not a defect. User decided the tracker should ALWAYS show — the showOnlyInCombat hide behavior is to be removed (stacks expire on their own after ~10s, so hiding out of combat is unnecessary). Tracked as a separate follow-up change, not a Phase 01 gap."

### 7. Settings persistence across reload
expected: Open settings (`/dmax`), change display mode (bar↔number), adjust scale, toggle border. `/reload ui` — all changes preserved. Settings popup blocks during combat (`InCombatLockdown` guard).
result: pass

### 8. Performance — no per-frame API spam
expected: With the addon loaded in combat, `/run print(GetFrameRate())` shows no FPS drop compared to addon disabled. Phase 04 caching should eliminate per-frame `GetSpellTexture`/config lookups.
result: pass
note: "Verified in-game via an addon profiler (C_AddOnProfiler) — Duncedmaxxing per-frame CPU stayed low/flat in combat, no sustained per-frame spam."

## Summary

total: 8
passed: 7
issues: 0
pending: 0
skipped: 1
blocked: 0

## Gaps
