---
phase: 05
slug: refactor-display-modes-remove-icon-mode-and-add-a-bar-text-m
status: approved
nyquist_compliant: true
wave_0_complete: true
created: 2026-07-09
---

# Phase 05 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Reconstructed retroactively (State B) from PLAN/SUMMARY artifacts; one gap filled 2026-07-09.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | busted-style specs under fengari (Lua-VM-in-JS) — no native Lua/busted |
| **Config file** | `.busted` (pattern `_spec`) + `spec/run.cjs` (node runner) |
| **Quick run command** | `node spec/run.cjs \|\| npx -y -p fengari@0.1.5 node spec/run.cjs` |
| **Full suite command** | `node spec/run.cjs \|\| npx -y -p fengari@0.1.5 node spec/run.cjs` |
| **Estimated runtime** | ~5–15 seconds (npx fetch adds ~10s cold-cache) |

Runner self-test (proves VM boots, catches a stubbed runner): `node spec/run.cjs --self-test` (npx fallback same).

---

## Sampling Rate

- **After every task commit:** Run the full suite (fast; single command)
- **After every plan wave:** Run the full suite
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** ~15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 05-01-01 | 01 | 1 | DISP-01 | T-05-01 / T-05-03 | Stored/typed `"icons"` rejected → falls back to `bar`; no crash | unit | `node spec/run.cjs` (core_spec: `NormalizeDB` resets `"icons"`→`"bar"`, lines 278, 452) | ✅ | ✅ green |
| 05-01-01 | 01 | 1 | DISP-01 | T-05-02 | Bar & number render paths remain the only branches (bar `else` is catch-all) | unit | `node spec/run.cjs` (tip_spec: number-mode color coding 604–666; bar mode 632) | ✅ | ✅ green |
| 05-01-01 | 01 | 1 | DISP-02 | T-05-01 | Any unknown stored `displayMode` normalizes to `bar` with no wipe | unit | `node spec/run.cjs` (core_spec: 135, 278, 440, 446, 452, 458, 464) | ✅ | ✅ green |
| 05-01-02 | 01 | 1 | DISP-03 | — | `iconSize`/`iconSpacing` never reintroduced into `DEFAULTS.tip` | unit | `node spec/run.cjs` (core_spec: 74–77, `MergeDefaults` → `is_nil`) | ✅ | ✅ green |
| 05-02-03 | 02 | 2 | DISP-04 | T-05-04 / T-05-SC | Suite runs green under fengari; assertions never weakened | integration | `node spec/run.cjs` (self-verifying — 126 passed, 0 failed) | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. The fengari harness (`spec/run.cjs`) and busted-style spec files (`spec/core_spec.lua`, `spec/tip_spec.lua`, `spec/util_spec.lua`) were in place; the only gap — a DISP-03 regression guard — was filled by adding one test to the existing `MergeDefaults` describe block in `spec/core_spec.lua` (no new files, no framework install).

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Options window offers exactly two mode buttons (Bar, Number); no icon sliders | DISP-01 / DISP-03 | Widget-factory / WoW UI surface is not loaded in the fengari VM (no `CreateFrame`) | Static-verified by grep: `grep -c 'self:SetMode' Duncedmaxxing/Options.lua` → `2`; `grep -nE 'iconSize\|iconSpacing\|"Icons"' Duncedmaxxing/Options.lua` → no matches. In-game: `/dmax` → confirm only Bar + Number buttons, no Icon size/gap sliders |
| `/dmax mode icons` / `/dmax mode icon` rejected; `bar`/`number` accepted | DISP-01 | The slash `mode` sub-command handler was later removed (current `/dmax` only opens Options); no harness-reachable parser remains | Static-verified by grep: `grep -rnE 'iconSize\|iconSpacing\|"icons"\|"icon"\|bartext' Duncedmaxxing/` → exit 1 (no matches). Behaviorally superseded — mode is now set via the Options UI, whose write path is validated by `NormalizeDB` tests |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references (none — infra pre-existing)
- [x] No watch-mode flags
- [x] Feedback latency < 15s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-07-09

---

## Validation Audit 2026-07-09

| Metric | Count |
|--------|-------|
| Gaps found | 1 (DISP-03 — no test guarding `iconSize`/`iconSpacing` removal) |
| Resolved | 1 (added `MergeDefaults` regression test, core_spec.lua:74–77) |
| Escalated | 0 |

Suite after fill: **126 passed, 0 failed, 126 total**. DISP-01's slash/Options-UI surface recorded as static-verified (not harness-reachable); its behavioral core (validation + rendering) is automated.
