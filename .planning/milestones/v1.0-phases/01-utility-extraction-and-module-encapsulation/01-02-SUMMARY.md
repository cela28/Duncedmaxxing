---
phase: 01-utility-extraction-and-module-encapsulation
plan: "02"
subsystem: tip-module-frame-ownership
tags: [frame-migration, pcall-removal, encapsulation, testability]
dependency_graph:
  requires: [01-01]
  provides: [Tip.root, Tip.pips, Tip.borders, Tip.label, Tip.numberText, pcall-free-ClassifySpellID]
  affects: [Duncedmaxxing/Modules/TipOfTheSpear.lua]
tech_stack:
  added: []
  patterns: [tip-parameter-private-helpers, D-08-local-aliases, Tip-table-frame-ownership]
key_files:
  created: []
  modified:
    - Duncedmaxxing/Modules/TipOfTheSpear.lua
decisions:
  - "Private helper functions receive 'tip' as first parameter instead of being converted to Tip methods — keeps private API private per A1/D-07"
  - "EnsureFrame initializes tip.pips={} and tip.borders={} before EnsureBorders(tip) call — prevents nil-index crash (Pitfall 4/5)"
  - "OnDragStop closure captures outer 'tip' parameter for SavePosition(tip) — avoids WoW frame 'self' collision (Pitfall 3)"
  - "EnsureBorders guard uses 'if tip.borders and tip.borders.top' two-part check — tip.borders starts as nil before EnsureFrame runs (Pitfall 5)"
metrics:
  duration: 4min
  completed: "2026-06-17T12:49:00Z"
  tasks_completed: 2
  tasks_total: 2
  files_changed: 1
---

# Phase 01 Plan 02: Frame Reference Migration and pcall Removal Summary

## One-Liner

Migrated all five module-level frame upvalues (root, pips, borders, label, numberText) to Tip table fields with tip-parameter private helpers and D-08 local aliases, and simplified ClassifySpellID to a direct three-line table lookup with no pcall wrapper.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Remove pcall from ClassifySpellID and frame upvalue declarations | 0dddf2c | Duncedmaxxing/Modules/TipOfTheSpear.lua |
| 2 | Migrate all frame references to Tip table fields | 35c7dce | Duncedmaxxing/Modules/TipOfTheSpear.lua |

## What Was Built

**Duncedmaxxing/Modules/TipOfTheSpear.lua** — Fully refactored frame ownership:

### ClassifySpellID simplification (QUAL-05 / D-11)
- Removed pcall wrapper and inner anonymous function
- Function body is now three lines: `KILL_COMMAND` check, `CONSUMERS[value]` check, implicit nil return
- ReadLiveState pcall calls preserved (intentional WoW API error protection)

### Frame upvalue declarations removed
- Five module-level locals (`local root`, `local pips = {}`, `local label`, `local numberText`, `local borders = {}`) deleted

### Category B private functions — gained `tip` first parameter (D-07)
- `ApplyPosition(tip)`: `root` -> `tip.root`
- `SavePosition(tip)`: `root` -> `tip.root`, calls `ApplyPosition(tip)`
- `EnsureBorders(tip)`: `parent` -> `tip`, guard `if tip.borders and tip.borders.top`, creates `tip.borders` table, `borders.*` -> `tip.borders.*` using `tip.root` as parent
- `LayoutBorders(tip, w, h, b, s)`: `borders.*` -> `tip.borders.*`, `root` -> `tip.root`
- `SetBordersShown(tip, shown)`: `borders` -> `tip.borders`
- `EnsureFrame(tip)`: all 5 upvalues -> `tip.*`; initializes `tip.pips = {}` and `tip.borders = {}` before use; `EnsureBorders(tip)`; `OnDragStop` closure captures `tip` (not `self`) for `SavePosition(tip)`

### Category A Tip methods — D-08 local aliases at hot-path entry (D-08)
- `Tip:RefreshLayout()`: `EnsureFrame(self)`, `local root = self.root`, `local pips = self.pips`, `local numberText = self.numberText`; calls updated to `SetBordersShown(self, false)`, `LayoutBorders(self, ...)`, `ApplyPosition(self)`
- `Tip:ApplyLock()`: guard `if not self.root then return end`; `local root, label = self.root, self.label`
- `Tip:Update()`: `EnsureFrame(self)`, `local root = self.root`, `local pips = self.pips`, `local label = self.label`, `local numberText = self.numberText`; calls updated to `SetBordersShown(self, ...)`
- `Tip:Initialize(core)`: `EnsureFrame(self)`

### Functions unchanged (no frame upvalue references)
- ClampStacks, FindTrackedSpell, ReadLiveState, GetCfg, ColorTuple, ResolveSpellTexture
- CreateBorder, CreatePip, PaintBorder, SetPipBordersShown, LayoutPipBorder
- Tip:RefreshActive, Tip:SyncFromAura, Tip:ScheduleExpiration, Tip:ScheduleCastVerify
- Tip:ScheduleAuraVerify, Tip:ResetPosition, Tip:SetTestStacks, Tip:GetStacks, Tip:ApplySpell, Tip:OnEvent

## Verification Results

All plan verification checks passed:
1. `grep -c "pcall" TipOfTheSpear.lua` → 2 (both in ReadLiveState) — PASS
2. Module-level upvalue declarations (`^local root$`, `^local pips = {}$`, etc.) → 0 — PASS
3. `grep -c "tip\.root"` → 30 (positive count) — PASS
4. `grep -c "self\.root"` → 4 (positive count) — PASS
5. `grep -c "EnsureFrame(self)"` → 3 (Initialize, Update, RefreshLayout) — PASS
6. `grep -c "SavePosition(tip)"` → 2 (OnDragStop closure, SavePosition body calling ApplyPosition(tip)) — PASS

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None — all frame ownership is fully wired. Tip.root, Tip.pips, Tip.borders, Tip.label, Tip.numberText are populated after Initialize completes.

## Threat Flags

T-01-05 (EnsureFrame idempotency) mitigated: guard `if tip.root then return end` preserved; `tip.pips = {}` and `tip.borders = {}` initialization prevents nil-index crash on first call.

T-01-06 (OnDragStop variable capture) mitigated: `tip.root:SetScript("OnDragStop", function(self) ... SavePosition(tip) end)` correctly captures `tip` (Tip module table) from outer EnsureFrame parameter, not `self` (WoW frame).

## Self-Check: PASSED

Files confirmed present:
- `Duncedmaxxing/Modules/TipOfTheSpear.lua` — exists, modified

Commits confirmed in git log:
- 0dddf2c — refactor(01-02): remove pcall from ClassifySpellID and frame upvalue declarations
- 35c7dce — refactor(01-02): migrate frame references to Tip table fields (D-06, D-07, D-08)
