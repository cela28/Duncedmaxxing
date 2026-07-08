---
phase: 04-performance-caching-and-ci-cd
plan: "01"
subsystem: TipOfTheSpear
tags: [perf, caching, tests]
dependency_graph:
  requires: []
  provides: [PERF-01, PERF-02]
  affects: [Duncedmaxxing/Modules/TipOfTheSpear.lua, spec/tip_spec.lua, spec/support/init.lua]
tech_stack:
  added: []
  patterns:
    - Event-driven cache invalidation (Tip.isSurvival, Tip.spellTexture)
    - Cache-populating local function (CacheSpellTexture) instead of call-and-return
key_files:
  created: []
  modified:
    - Duncedmaxxing/Modules/TipOfTheSpear.lua
    - spec/tip_spec.lua
    - spec/support/init.lua
decisions:
  - "PERF-01: Removed self:RefreshActive() from Update() hot path; isSurvival is now always fresh from event handlers"
  - "PERF-02: Replaced ResolveSpellTexture() call-and-return pattern with CacheSpellTexture(tip) that writes tip.spellTexture; called at Initialize and PLAYER_LOGIN"
  - "RefreshActive() method retained as convenience wrapper but repurposed to write self.isSurvival"
  - "Lazy self:RefreshActive() call in UNIT_SPELLCAST_SUCCEEDED removed since cache is always event-fresh"
metrics:
  duration: "4min"
  completed_date: "2026-06-18"
  tasks_completed: 2
  files_modified: 3
---

# Phase 04 Plan 01: Spec and Texture Caching — Summary

**One-liner:** Event-driven isSurvival and spellTexture caches eliminate IsSurvivalHunter() and GetSpellTexture() API calls from the Update() and RefreshLayout() hot paths.

## What Was Built

Two performance caches on the `Tip` module table:

**PERF-01 — Spec state cache (`Tip.isSurvival`):**
- `Tip.active` field renamed to `Tip.isSurvival` across all 4 occurrence sites
- `RefreshActive()` now writes `self.isSurvival` instead of `self.active`
- `self:RefreshActive()` removed from `Update()` — cache is populated at `Initialize()` and refreshed only in `OnEvent` handlers (`PLAYER_LOGIN`, `PLAYER_SPECIALIZATION_CHANGED`, `PLAYER_TALENT_UPDATE`)
- Lazy `self:RefreshActive()` call inside `UNIT_SPELLCAST_SUCCEEDED` removed; cache is always event-fresh

**PERF-02 — Texture cache (`Tip.spellTexture`):**
- `ResolveSpellTexture()` local function (call-and-return) replaced by `CacheSpellTexture(tip)` (writes to `tip.spellTexture`)
- Dual-path API call pattern preserved: `C_Spell.GetSpellTexture` first, `_G.GetSpellTexture` fallback, `FALLBACK_ICON` final
- `CacheSpellTexture(self)` called in `Initialize()` and at the top of the `PLAYER_LOGIN`/`PLAYER_ENTERING_WORLD` event branch
- Both `ResolveSpellTexture()` call sites in `RefreshLayout()` (icon mode) and `Update()` (icon mode) replaced with `self.spellTexture`

**Regression tests (6 new):**
- `Tip.isSurvival` is true after Initialize with Survival Hunter stub
- `Tip.isSurvival` is false after `PLAYER_SPECIALIZATION_CHANGED` with non-Survival spec
- `Tip.isSurvival` stays unchanged on `PLAYER_SPECIALIZATION_CHANGED` for non-player unit
- `Tip.spellTexture` is non-nil after Initialize
- `Tip.spellTexture` equals 132275 (expected icon ID from C_Spell stub) after Initialize
- `Tip.isSurvival` refreshes on `PLAYER_TALENT_UPDATE` (tested in both directions)

`resetTipState` extended with `Tip.isSurvival = false` and `Tip.spellTexture = nil` for per-test isolation.

## Task Commits

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Implement spec cache (PERF-01) and texture cache (PERF-02) | 385522a | Duncedmaxxing/Modules/TipOfTheSpear.lua |
| 2 | Add caching regression tests and extend resetTipState | 5647961 | spec/tip_spec.lua, spec/support/init.lua |

## Verification Results

```
busted spec/: 108 successes / 0 failures / 0 errors / 0 pending
ResolveSpellTexture in TipOfTheSpear.lua: 0
self.active in TipOfTheSpear.lua: 0
RefreshActive in Update(): 0 (method def + 3 OnEvent handlers only)
self.isSurvival occurrences: 4
CacheSpellTexture occurrences: 3
```

## Deviations from Plan

None — plan executed exactly as written.

The one minor interpretation: the plan stated `grep for 'self.spellTexture' returns >= 3 hits` but the declaration uses `Tip.spellTexture = nil` (not `self.spellTexture`). Total `spellTexture` references are 5 (declaration, CacheSpellTexture write, comment, 2 call sites). The `self.spellTexture` count is 2 (RefreshLayout + Update), with `tip.spellTexture` being the write in CacheSpellTexture. This satisfies the intent of the acceptance criteria.

## Self-Check: PASSED

- [x] `Duncedmaxxing/Modules/TipOfTheSpear.lua` — modified, committed 385522a
- [x] `spec/tip_spec.lua` — modified, committed 5647961
- [x] `spec/support/init.lua` — modified, committed 5647961
- [x] Commits exist: `git log --oneline | grep -E "385522a|5647961"` — both present
- [x] 108 tests passing (102 existing + 6 new caching tests)
- [x] ResolveSpellTexture: 0 occurrences
- [x] self.active: 0 occurrences
