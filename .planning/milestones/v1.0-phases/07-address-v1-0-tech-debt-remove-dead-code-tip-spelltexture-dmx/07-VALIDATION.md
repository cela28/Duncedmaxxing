---
phase: 7
slug: address-v1-0-tech-debt-remove-dead-code-tip-spelltexture-dmx
status: approved
nyquist_compliant: true
wave_0_complete: true
created: 2026-07-09
validated: 2026-07-09
---

# Phase 7 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Custom busted-compatible shim running inside fengari (Lua-VM-in-JS), NOT native busted (`.busted` in repo root is vestigial) |
| **Config file** | `spec/run.cjs` (the actual runner; discovers `*_spec.lua` itself) |
| **Quick run command** | `npx -y -p fengari@0.1.5 node spec/run.cjs` |
| **Full suite command** | `npx -y -p fengari@0.1.5 node spec/run.cjs` (identical — no subset mode) |
| **Estimated runtime** | ~5–15 seconds (111 specs, post-cleanup) |

---

## Sampling Rate

- **After every task commit:** Run `npx -y -p fengari@0.1.5 node spec/run.cjs`
- **After every plan wave:** Run the full suite **plus** `grep -rn "<removed-symbol>" Duncedmaxxing/ spec/` for every symbol removed so far (expect zero matches)
- **Before `/gsd-verify-work`:** Full suite green; grep-absence sweep clean for all removed symbols; luacheck zero-warnings if available (else documented manual verification)
- **Max feedback latency:** ~5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 07-01 | 01 | 1 | D-01/02/03 (remove hasPrimalSurge) | — / — | N/A | unit (edited) + grep-absence | `npx ... node spec/run.cjs` && `grep -rn "hasPrimalSurge" Duncedmaxxing/ spec/` → 0 | ✅ `spec/tip_spec.lua` | ✅ green |
| 07-01 | 01 | 1 | D-04 (remove spellTexture) | — / — | N/A | unit (deleted) + grep-absence | `... run.cjs` && `grep -rn "spellTexture\|CacheSpellTexture\|FALLBACK_ICON" Duncedmaxxing/ spec/` → 0 | ✅ `spec/tip_spec.lua` | ✅ green |
| 07-02 | 02 | 1 | D-05 (remove ParseOnOff) | — / — | N/A | unit (deleted) + grep-absence | `... run.cjs` && `grep -rn "ParseOnOff" Duncedmaxxing/ spec/` → 0 | ✅ `spec/util_spec.lua` | ✅ green |
| 07-01 | 01 | 1 | D-06 (harden consumer tests) | — / — | N/A | unit (new assertions + `Tip._test` export) | `npx ... node spec/run.cjs` — `Tip._test.ClassifySpellID` (TipOfTheSpear.lua:743) asserted `== "consumer"` for 265189/1262293/1262343 (tip_spec:189+) | ✅ `TipOfTheSpear.lua` + `spec/tip_spec.lua` | ✅ green |
| 07-01 | 01 | 1 | D-07 (keep db.locked; add comment) | — / — | N/A | unit (existing) | `npx ... node spec/run.cjs` — core_spec:147 "sets db.locked = true during migration" | ✅ `spec/core_spec.lua` | ✅ green |
| 07-03 | 03 | 2 | Overall regression + grep sweep | — / — | N/A | full suite + grep-absence | `npx ... node spec/run.cjs` (111/0) + all-symbol grep sweep clean | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure (`spec/run.cjs`, `spec/support/init.lua`, `spec/support/wow_stubs.lua`) covers all phase requirements. The one net-new piece of test-reachable infrastructure is the `Tip._test = { ClassifySpellID = ClassifySpellID }` export in `Duncedmaxxing/Modules/TipOfTheSpear.lua` (replicating the existing `DMX._test` convention in `Core.lua`), required to unblock D-06 — this is a production-code addition tracked as a task, not a harness gap.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| luacheck zero warnings | project quality gate | luacheck/luarocks/lua absent in the research sandbox — may or may not exist in the execution environment | Run `luacheck Duncedmaxxing/` if installed; expect zero warnings. If unavailable, record a `checkpoint:human-verify` noting lint was not run and why. |

*All other phase behaviors have automated verification via the fengari suite + grep-absence sweeps.*

---

## Validation Sign-Off

- [x] All tasks have automated verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references (`Tip._test` export added as a tracked task)
- [x] No watch-mode flags
- [x] Feedback latency < 15s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-07-09

---

## Validation Audit 2026-07-09

| Metric | Count |
|--------|-------|
| Gaps found | 0 (all D-01…D-07 verified: grep-absence sweeps + suite + D-06 assertions) |
| Resolved | 0 |
| Escalated | 0 |

State A audit, run immediately after Phase 7's own execution completed. Converted the pre-execution draft into a finalized record. Verified against post-execution source:
- **D-01/02/03** `hasPrimalSurge`, **D-04** `spellTexture`/`CacheSpellTexture`/`FALLBACK_ICON`, **D-05** `ParseOnOff` — grep-absence sweep across `Duncedmaxxing/` + `spec/`: **0 matches each**.
- **D-06** — `Tip._test = { ClassifySpellID = ... }` export present (TipOfTheSpear.lua:743); consumer tests hardened to assert `ClassifySpellID(id) == "consumer"` for 265189/1262293/1262343 (tip_spec:189+).
- **D-07** — `db.locked` migration behavior retained and tested (core_spec:147).
- Suite: **111 passed, 0 failed**. luacheck remains a CI/optional lint gate (binary absent locally; auto-approved per 07-03-SUMMARY).
