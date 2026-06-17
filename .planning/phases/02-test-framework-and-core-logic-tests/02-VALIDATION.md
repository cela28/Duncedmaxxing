---
phase: 02
slug: test-framework-and-core-logic-tests
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-17
---

# Phase 02 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | busted 2.3.0 (Lua 5.1) |
| **Config file** | `.busted` at repo root (Wave 0 creation) |
| **Quick run command** | `busted spec/` |
| **Full suite command** | `busted spec/ --verbose` |
| **Estimated runtime** | ~5 seconds |

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
| 02-01-01 | 01 | 1 | TEST-01 | — | N/A | smoke | `busted spec/` | ❌ W0 | ⬜ pending |
| 02-01-02 | 01 | 1 | TEST-02 | — | N/A | unit | `busted spec/util_spec.lua` | ❌ W0 | ⬜ pending |
| 02-02-01 | 02 | 2 | TEST-06 | — | N/A | unit | `busted spec/util_spec.lua` | ❌ W0 | ⬜ pending |
| 02-02-02 | 02 | 2 | TEST-05 | — | N/A | unit | `busted spec/core_spec.lua` | ❌ W0 | ⬜ pending |
| 02-02-03 | 02 | 2 | TEST-03 | — | N/A | unit | `busted spec/tip_spec.lua` | ❌ W0 | ⬜ pending |
| 02-02-04 | 02 | 2 | TEST-04 | — | N/A | unit | `busted spec/tip_spec.lua` | ❌ W0 | ⬜ pending |
| 02-03-01 | 03 | 3 | TEST-07 | — | N/A | static | `luacheck Duncedmaxxing/ --no-unused-args` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `spec/support/wow_stubs.lua` — WoW API mock layer (D-01 through D-04)
- [ ] `spec/support/init.lua` — dofile loader with vararg injection (D-05, D-06)
- [ ] `spec/util_spec.lua` — TEST-06 utility function tests
- [ ] `spec/core_spec.lua` — TEST-05 NormalizeDB tests
- [ ] `spec/tip_spec.lua` — TEST-03 + TEST-04 ApplySpell/SyncFromAura tests
- [ ] `.busted` — busted project config
- [ ] `.luacheckrc` — luacheck config (D-10, D-11)
- [ ] Framework install: `sudo apt install lua5.1 luarocks lua-check && sudo luarocks --lua-version=5.1 install busted`

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Twin Fangs +3 grant | TEST-03 (partial) | BUG-04 not implemented until Phase 3 | Mark as `pending()` in busted; verify after Phase 3 |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
