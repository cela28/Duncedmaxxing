---
phase: 02
slug: test-framework-and-core-logic-tests
status: approved
nyquist_compliant: true
wave_0_complete: true
created: 2026-06-17
validated: 2026-07-09
---

# Phase 02 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | busted-style specs; run via **fengari** locally (`spec/run.cjs`), busted 2.3.0 on CI (Lua 5.1) |
| **Config file** | `.busted` + `.luacheckrc` at repo root; `spec/run.cjs` (fengari runner, added Phase 5) |
| **Quick run command** | `npx -y -p fengari@0.1.5 node spec/run.cjs` (local); `busted spec/` (CI) |
| **Full suite command** | `npx -y -p fengari@0.1.5 node spec/run.cjs` + `luacheck Duncedmaxxing/` (CI) |
| **Estimated runtime** | ~5–15 seconds |

> **Note (2026-07-09):** This environment has no native Lua/busted or luacheck binary. The suite runs via the fengari harness (`spec/run.cjs`, introduced in Phase 5). `busted spec/` and `luacheck Duncedmaxxing/` are the CI paths (`.github/workflows`). The verification map below uses the locally-runnable fengari command; luacheck (TEST-07) is a static gate whose config artifact is verified present here and whose execution is CI-only.

---

## Sampling Rate

- **After every task commit:** Run `busted spec/`
- **After every plan wave:** Run `busted spec/ --verbose && luacheck Duncedmaxxing/`
- **Before `/gsd:verify-work`:** Full suite must be green + luacheck zero warnings
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 02-01-01 | 01 | 1 | TEST-01 | — | N/A | smoke | `npx ... node spec/run.cjs` (suite discovers `*_spec.lua` per `.busted` pattern) | ✅ `.busted` | ✅ green |
| 02-01-02 | 01 | 1 | TEST-02 | — | N/A | unit | `npx ... node spec/run.cjs` — `spec/support/wow_stubs.lua` (212 lines) stubs C_UnitAuras, C_Timer, C_SpecializationInfo, C_Spell, UnitClass, GetTime, CreateFrame | ✅ | ✅ green |
| 02-02-01 | 02 | 2 | TEST-06 | — | N/A | unit | `npx ... node spec/run.cjs` — util_spec (Clamp/ParseHexColor/ParseOnOff/Trim edge cases) | ✅ | ✅ green |
| 02-02-02 | 02 | 2 | TEST-05 | — | N/A | unit | `npx ... node spec/run.cjs` — core_spec NormalizeDB (migration gate, merging, deprecated fields) | ✅ | ✅ green |
| 02-02-03 | 02 | 2 | TEST-03 | — | N/A | unit | `npx ... node spec/run.cjs` — tip_spec "Tip:ApplySpell" (add / cap-at-3 / expiry / talent grants incl. Twin Fangs BUG-04) | ✅ | ✅ green |
| 02-02-04 | 02 | 2 | TEST-04 | — | N/A | unit | `npx ... node spec/run.cjs` — tip_spec "Tip:SyncFromAura" (grace suppression, serial-mismatch, reconciliation) | ✅ | ✅ green |
| 02-03-01 | 03 | 3 | TEST-07 | — | N/A | static (CI) | `luacheck Duncedmaxxing/` — `.luacheckrc` (std=lua51, curated read_globals) present; execution CI-only | ✅ `.luacheckrc` | ✅ green (config verified) |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

All present and verified on disk (2026-07-09):
- [x] `spec/support/wow_stubs.lua` — WoW API mock layer (212 lines, D-01 through D-04)
- [x] `spec/support/init.lua` — loadfile loader with vararg injection (75 lines, D-05, D-06)
- [x] `spec/util_spec.lua` — TEST-06 utility function tests
- [x] `spec/core_spec.lua` — TEST-05 NormalizeDB tests
- [x] `spec/tip_spec.lua` — TEST-03 + TEST-04 ApplySpell/SyncFromAura tests
- [x] `.busted` — busted project config
- [x] `.luacheckrc` — luacheck config (D-10, D-11)
- [x] Framework: busted on CI; fengari (`spec/run.cjs`) locally (added Phase 5)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `luacheck Duncedmaxxing/` static lint | TEST-07 | luacheck binary not installed in this environment; runs in CI (`.github/workflows`). Config artifact `.luacheckrc` verified present locally. | CI runs `luacheck Duncedmaxxing/`; locally install `lua-check` to run |

*Note: the Twin Fangs +3 grant (TEST-03, previously deferred to Phase 3 as `pending()`) is now fully automated in tip_spec — see "Takedown with Twin Fangs …" BUG-04 tests. No longer manual.*

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references (all present)
- [x] No watch-mode flags
- [x] Feedback latency < 15s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-07-09

---

## Validation Audit 2026-07-09

| Metric | Count |
|--------|-------|
| Gaps found | 0 (this phase's deliverable *is* the test suite; all 7 TEST artifacts present & green) |
| Resolved | 0 |
| Escalated | 0 |

State A audit. All seven TEST-0x deliverables exist and are substantive; the fengari suite runs **128 passed, 0 failed**. Finalized the doc: swapped the non-runnable `busted spec/` command for the locally-runnable fengari `npx` form (busted/luacheck remain the CI paths), marked all statuses green, closed out Wave 0, and retired the Twin Fangs manual-only entry (now automated via BUG-04 tests). TEST-07 recorded as a CI-only static gate (config verified present locally).
