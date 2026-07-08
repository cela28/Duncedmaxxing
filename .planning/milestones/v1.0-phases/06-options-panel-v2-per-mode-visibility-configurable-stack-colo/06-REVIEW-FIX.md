---
phase: 06-options-panel-v2-per-mode-visibility-configurable-stack-colo
fixed_at: 2026-07-08T00:00:00Z
review_source: 06-REVIEW.md
fix_scope: critical_warning
findings_in_scope: 3
fixed: 3
skipped: 0
iteration: 1
status: all_fixed
---

# Phase 06: Code Review Fix Report

**Fixed:** 2026-07-08
**Scope:** critical_warning (Critical + Warning findings)
**Source review:** `06-REVIEW.md`
**Result:** 3/3 in-scope findings fixed; full fengari suite green (125/125)

## Summary

The gap-closure code review confirmed a Critical (CR-01) plus two Warnings on the
06-07 `stackColors` migration. All three were fixed in a single cohesive change to the
migration logic and its regression test, committed as `8c87070`. The fix was validated
empirically: the rewritten regression test **fails against the pre-fix code** (proving it
exercises the real defect) and **passes after the fix** (125/125).

## Fixed Findings

### CR-01 — Reseed was dead code in production; test bypassed the real path — FIXED
**Files:** `Duncedmaxxing/Core.lua`, `spec/core_spec.lua`
**Root cause:** Production runs `MergeDefaults(DEFAULTS, db)` before `NormalizeDB`
(`Core.lua:206-207`). `MergeDefaults` injects `.r/.g/.b/.a` into legacy positional
`stackColors` entries, so the old `first.r == nil` detection always returned false at
runtime and the reseed never fired.
**Fix:** `StackColorsAreLegacyFormat` now detects legacy shape by the surviving numeric
`[1]` key (which persists through `MergeDefaults`), so the migration fires under the real
init order. The SC-6 regression test was rewritten to run the production order
(`MergeDefaults` → `NormalizeDB`) and now asserts the migration genuinely repairs the data.
**Verification:** Restored the pre-fix `Core.lua` and ran the suite — the new test FAILED
(1 failed / 124 passed), confirming it is a true regression test, not a tautology. With the
fix applied: 125/125 pass.

### WR-01 — Detection only inspected index [0] — FIXED
**File:** `Duncedmaxxing/Core.lua`
**Fix:** `StackColorsAreLegacyFormat` now scans all four slots (`for i = 0, 3`) and treats
the table as legacy if *any* present entry carries a numeric `[1]` key, so a partially
hand-edited or partially-migrated DB is still detected and repaired.

### WR-02 — Legacy user customizations silently discarded — FIXED
**File:** `Duncedmaxxing/Core.lua`
**Fix:** Added `ConvertLegacyStackColors`, which remaps each positional `{r,g,b,a}` entry
into keyed form **in place** — recovering the user's customized colors from the positional
data instead of overwriting them with defaults — and drops the stale numeric keys. The
regression test seeds a distinctly custom stack-1 color (`0.9` red) and asserts it survives
migration (`stackColors[1].r ≈ 0.9`, not the `0.18039` default).

## Out-of-Scope Findings (not fixed — Info tier, excluded without `--all`)

### IN-01 — `NormalizeDB` lacks a `db.tip` nil guard — NOT FIXED
Info-tier; left as-is per the critical_warning fix scope. Production always creates
`db.tip` via `MergeDefaults` before `NormalizeDB`, so the invariant holds at runtime.

### IN-02 — Regression test asserted only `stackColors[0]` — EFFECTIVELY ADDRESSED
Not formally in scope (Info), but the CR-01 test rewrite already loops `for i = 0, 3`
asserting every index is keyed (`.r/.g/.b/.a` present) and that all stale numeric keys
(`[1]..[4]`) are removed — which is exactly IN-02's recommendation.

## Commits

- `8c87070` — fix(06-07): repair legacy stackColors migration for real production init order

_Fixed: 2026-07-08 — applied directly on `dev` and verified via the fengari harness._
