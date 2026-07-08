---
phase: 1
slug: utility-extraction-and-module-encapsulation
status: approved
nyquist_compliant: true
wave_0_complete: true
created: 2026-06-17
validated: 2026-07-09
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

> **Retro-validated 2026-07-09:** This phase originally shipped with no test harness (Phase 2 owned busted). The fengari suite that Phase 2 introduced now covers Phase 1's requirements retroactively, so the manual-only entries below have been upgraded to automated where the harness can reach them.

| Property | Value |
|----------|-------|
| **Framework** | busted-style specs under fengari (Lua-VM-in-JS) — added Phase 2, covers Phase 1 retroactively |
| **Config file** | `.busted` + `spec/run.cjs` |
| **Quick run command** | `npx -y -p fengari@0.1.5 node spec/run.cjs` |
| **Full suite command** | `npx -y -p fengari@0.1.5 node spec/run.cjs` |
| **Estimated runtime** | ~5–15 seconds |

---

## Sampling Rate

- **After every task commit:** Manual `/reload ui` with no Lua errors
- **After every plan wave:** Full in-game smoke: all display modes (bar, icons, number), slash commands (`/dmax test`, `/dmax scale`, `/dmax color`, `/dmax mode`, `/dmax border`), options window open/close
- **Before `/gsd:verify-work`:** All five success criteria from phase description must pass
- **Max feedback latency:** N/A (manual testing only)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 01-01-01 | 01 | 1 | QUAL-01 | — | N/A | unit | `npx ... node spec/run.cjs` — util_spec: Clamp / ParseHexColor / ParseOnOff / Trim via `DMX.Util.*` namespace | ✅ | ✅ green |
| 01-02-01 | 02 | 1 | QUAL-02 | — | N/A | unit | `npx ... node spec/run.cjs` — tip_spec:482 "QUAL-02 — frame references on Tip table" asserts Tip.root/pips/borders/label/numberText populated after Initialize | ✅ | ✅ green |
| 01-03-01 | 03 | 1 | QUAL-03 | — | N/A | unit | `npx ... node spec/run.cjs` — core_spec:407+ "NormalizeDB — deprecated fields ignored post-migration (QUAL-03)" | ✅ | ✅ green |
| 01-03-02 | 03 | 1 | QUAL-04 | — | N/A | unit | `npx ... node spec/run.cjs` — core_spec:357 "QUAL-04 — ordered module registry" asserts `moduleOrder[1] == "tip"` | ✅ | ✅ green |
| 01-04-01 | 04 | 1 | QUAL-05 | — | N/A | static + behavioral | `grep -n pcall Duncedmaxxing/Modules/TipOfTheSpear.lua` (pcalls only in ReadLiveState, none in ClassifySpellID) + tip_spec ApplySpell tests exercise ClassifySpellID as pure lookup | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

*Existing infrastructure covers all phase requirements. No test framework setup needed — Phase 2 owns busted installation.*

---

## Manual-Only Verifications

All phase behaviors now have automated verification via the fengari suite (added Phase 2, covers Phase 1 retroactively). QUAL-05's "no pcall in ClassifySpellID" property is additionally guarded by a static grep; its runtime behavior is exercised by the tip_spec ApplySpell tests.

---

## Validation Sign-Off

- [x] All tasks have automated verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without verify
- [x] Wave 0 covers all MISSING references (none — suite pre-existing from Phase 2)
- [x] No watch-mode flags
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-07-09

---

## Validation Audit 2026-07-09

| Metric | Count |
|--------|-------|
| Gaps found | 2 (QUAL-02 frame-fields-on-Tip; QUAL-04 ordered moduleOrder — neither had automated coverage) |
| Resolved | 2 (tip_spec:482 "QUAL-02 …"; core_spec:357 "QUAL-04 …") |
| Escalated | 0 |

State A audit. The original VALIDATION.md was written pre-test-harness (all entries manual-only). Since Phase 2 introduced the fengari suite, QUAL-01 and QUAL-03 were already covered retroactively; QUAL-05 is grep + behaviorally covered. Filled the two remaining automatable gaps. Suite after fill: **128 passed, 0 failed, 128 total**.
