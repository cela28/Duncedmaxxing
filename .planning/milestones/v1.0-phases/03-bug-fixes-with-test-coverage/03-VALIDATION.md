---
phase: 03
slug: bug-fixes-with-test-coverage
status: approved
nyquist_compliant: true
wave_0_complete: true
created: 2026-06-18
validated: 2026-07-09
---

# Phase 03 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | busted-style specs via fengari locally; busted on CI (Lua 5.1) |
| **Config file** | `.busted` + `spec/run.cjs` |
| **Quick run command** | `npx -y -p fengari@0.1.5 node spec/run.cjs` |
| **Full suite command** | `npx -y -p fengari@0.1.5 node spec/run.cjs` (+ `luacheck Duncedmaxxing/` on CI) |
| **Estimated runtime** | ~5–15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `busted spec/`
- **After every plan wave:** Run `busted spec/ && luacheck Duncedmaxxing/`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 3 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 03-01-01 | 03-01 | 1 | BUG-01 | — | N/A | unit | `npx ... node spec/run.cjs` — tip_spec:549 "Tip:ScheduleAuraVerify — auraVerifyPending flag (BUG-01)" | ✅ | ✅ green |
| 03-01-02 | 03-01 | 1 | QUAL-03 | — | N/A | unit | `npx ... node spec/run.cjs` — core_spec:372 "NormalizeDB — deprecated fields ignored post-migration (QUAL-03)" | ✅ | ✅ green |
| 03-01-03 | 03-01 | 1 | BUG-02 | — | N/A | unit | `npx ... node spec/run.cjs` — tip_spec:422 "RefreshTip — out-of-combat aura sync (BUG-02)" | ✅ | ✅ green |
| 03-02-01 | 03-02 | 2 | BUG-03 | — | N/A | unit | `npx ... node spec/run.cjs` — tip_spec:137 "caps at MAX_STACKS on generator from 2 stacks (BUG-03)" | ✅ | ✅ green |
| 03-02-02 | 03-02 | 2 | BUG-04 | — | N/A | unit | `npx ... node spec/run.cjs` — tip_spec:144–178 Twin Fangs Takedown "grant 3 then consume 1 = 2 (BUG-04)" (5 cases; hardened by Phase 7 with ClassifySpellID assertions) | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. busted, luacheck, wow_stubs.lua, and the test loader are all in place from Phase 2.

---

## Manual-Only Verifications

All phase behaviors have automated verification. (The original BUG-02 manual-only entry — "switch mode via `/dmax mode icon`" — is obsolete: icon mode was removed in Phase 5 and the slash `mode` sub-command in Phase 7. BUG-02's out-of-combat aura-resync behavior is now automated at tip_spec:422.)

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 15s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-06-18; finalized 2026-07-09

---

## Validation Audit 2026-07-09

| Metric | Count |
|--------|-------|
| Gaps found | 0 (BUG-01…04 + QUAL-03 all have dedicated automated tests) |
| Resolved | 0 |
| Escalated | 0 |

State A audit. This phase was already `nyquist_compliant: true` with a complete map — it only needed finalizing (`status: draft → approved`) and modernizing stale references. Swapped the non-runnable `busted spec/` commands for the fengari `npx` form (busted remains the CI path), pinned each requirement to its live test location, retired the obsolete `/dmax mode icon` manual-only note, and confirmed all five requirement tests survive the Phase 7 cleanup. Suite: **111 passed, 0 failed**.
