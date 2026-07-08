---
phase: 4
slug: performance-caching-and-ci-cd
status: validated
nyquist_compliant: false
wave_0_complete: true
created: 2026-06-18
validated: 2026-07-09
validation_note: "PARTIAL — PERF-01 automated; PERF-02 retired (impl removed in Phase 7 dead-code cleanup); CICD-01 manual-only (GitHub Actions release workflow, not locally automatable)"
---

# Phase 4 — Validation Strategy

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
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 04-01-01 | 01 | 1 | PERF-01 | — | N/A | unit | `npx ... node spec/run.cjs` — tip_spec "Caching -- isSurvival" (496+): cached at Initialize; refreshed only on PLAYER_SPECIALIZATION_CHANGED / PLAYER_TALENT_UPDATE; ignored for non-player unit | ✅ | ✅ green |
| 04-01-02 | 01 | 1 | PERF-02 | — | N/A | — | **RETIRED** — `Tip.spellTexture`/`CacheSpellTexture`/`FALLBACK_ICON` removed as dead code in Phase 7 (`841482b`) after Phase 5 removed icon mode (their only consumer). No runtime surface remains to test; the 2 spellTexture tests were correctly removed. | n/a | ⊘ retired |
| 04-02-01 | 02 | 2 | CICD-01 | — | N/A | manual (CI) | GitHub Actions release on `v*` tag push — cannot run locally | ✅ on `main` | 🖐 manual |
| 04-02-02 | 02 | 2 | CICD-01 | — | N/A | static | `git show main:.github/workflows/release.yml` — well-formed: `v*` trigger, zips top-level `Duncedmaxxing/`, syncs `## Version:` in TOC via sed | ✅ on `main` | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky · ⊘ retired · 🖐 manual*

> **PERF-02 lifecycle note:** PERF-02 was satisfied and tested when Phase 4 shipped (texture resolved/cached once at Initialize, not per-Update). Phase 5 then removed icon display mode — the sole consumer of the cached texture — rendering the cache orphaned. Phase 7 removed it as dead code (documented in `07-01-SUMMARY.md`). The requirement's *history* is intact; its *code* no longer exists, so no automated regression test is possible or appropriate. **Flag for milestone audit:** REQUIREMENTS.md still marks PERF-02 "Complete" — consider annotating it as "Complete → later retired (Phase 7)".

---

## Wave 0 Requirements

*Existing infrastructure covers all phase requirements.*

- busted + luacheck already installed and configured from Phase 2
- WoW API stubs already cover `C_SpecializationInfo`, `C_Spell`, and event system
- `spec/support/init.lua` `resetTipState` needs extension for new cache fields (part of caching task)

---

## Manual-Only Verifications

CICD-01 is inherently manual/CI — a GitHub Actions release workflow can only be exercised by a real `v*` tag push. Its workflow artifact (`.github/workflows/release.yml`, on `main`) is statically verified present and well-formed (see map row 04-02-02).

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Release workflow produces zip | CICD-01 | GitHub Actions only runs on GitHub | Push a `v*` tag, verify zip asset appears on the release |
| Zip extracts with correct folder structure | CICD-01 | Requires GitHub release artifact | Download zip, verify `Duncedmaxxing/` top-level with TOC + Lua files |
| Version injected into TOC | CICD-01 | Requires CI sed step execution | Check `## Version:` in TOC inside zip matches tag |

---

## Validation Sign-Off

- [x] All tasks have automated verify, are retired, or are justified manual-only
- [x] Sampling continuity: PERF-01 automated; CICD-01 manual by nature (external CI)
- [x] Wave 0 covers all MISSING references (suite pre-existing)
- [x] No watch-mode flags
- [x] Feedback latency < 15s
- [ ] `nyquist_compliant: true` — **NOT set**: CICD-01 is manual-only (GitHub release workflow); PERF-02 retired. This is the honest ceiling for this phase.

**Approval:** approved PARTIAL 2026-07-09

---

## Validation Audit 2026-07-09

| Metric | Count |
|--------|-------|
| Gaps found | 0 fillable (PERF-01 already covered; PERF-02 retired; CICD-01 inherently manual) |
| Resolved | 0 |
| Retired | 1 (PERF-02 — impl removed in Phase 7) |
| Manual-only | 1 (CICD-01 — release workflow) |

State A audit, re-run after the concurrent Phase 7 execution settled (suite re-baselined at 111 passed / 0 failed). PERF-01's isSurvival cache is fully covered by the tip_spec "Caching -- isSurvival" block. PERF-02's texture-cache implementation was removed downstream (Phase 5 dropped icon mode → Phase 7 removed the orphaned cache), so no automated test is possible; recorded as retired. CICD-01's `release.yml` verified present and well-formed on `main`; it remains manual/CI. Phase marked **validated (partial)** — the honest ceiling, since one requirement is inherently non-automatable and one no longer has code.
