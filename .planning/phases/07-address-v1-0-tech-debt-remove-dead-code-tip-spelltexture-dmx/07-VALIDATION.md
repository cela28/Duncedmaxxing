---
phase: 7
slug: address-v1-0-tech-debt-remove-dead-code-tip-spelltexture-dmx
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-09
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
| **Estimated runtime** | ~1 second (125 specs) |

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
| 7-xx | — | 1 | D-01/02/03 (remove hasPrimalSurge) | — / — | N/A | unit (edited) + grep-absence | `npx -y -p fengari@0.1.5 node spec/run.cjs` && `grep -rn "hasPrimalSurge" Duncedmaxxing/ spec/` (0 matches) | ✅ `spec/tip_spec.lua` | ⬜ pending |
| 7-xx | — | 1 | D-04 (remove spellTexture) | — / — | N/A | unit (deleted) + grep-absence | `... run.cjs` && `grep -rn "spellTexture\|CacheSpellTexture\|FALLBACK_ICON" Duncedmaxxing/ spec/` (0 matches) | ✅ `spec/tip_spec.lua` | ⬜ pending |
| 7-xx | — | 1 | D-05 (remove ParseOnOff) | — / — | N/A | unit (deleted) + grep-absence | `... run.cjs` && `grep -rn "ParseOnOff" Duncedmaxxing/ spec/` (0 matches) | ✅ `spec/util_spec.lua` | ⬜ pending |
| 7-xx | — | 1 | D-06 (harden 265189 test) | — / — | N/A | unit (new assertions + new `Tip._test` export) | `npx -y -p fengari@0.1.5 node spec/run.cjs` | ⚠️ needs `Tip._test` export in `TipOfTheSpear.lua` + new/edited assertions in `spec/tip_spec.lua` | ⬜ pending |
| 7-xx | — | 1 | D-07 (keep db.locked; add comment) | — / — | N/A | unit (existing, passing) | `npx -y -p fengari@0.1.5 node spec/run.cjs` | ✅ `spec/core_spec.lua:141-145` (no edit) | ⬜ pending |
| 7-xx | — | 1 | Overall regression | — / — | N/A | full suite | `npx -y -p fengari@0.1.5 node spec/run.cjs` | ✅ baseline 125/125 | ⬜ pending |

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

- [ ] All tasks have automated verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
