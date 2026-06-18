---
phase: 03
slug: bug-fixes-with-test-coverage
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-06-18
---

# Phase 03 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | busted 2.3.0 (Lua 5.1) |
| **Config file** | `.busted` |
| **Quick run command** | `busted spec/` |
| **Full suite command** | `busted spec/ && luacheck Duncedmaxxing/` |
| **Estimated runtime** | ~3 seconds |

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
| 03-01-01 | 03-01 | 1 | BUG-01, QUAL-03 | — | N/A | unit | `busted spec/tip_spec.lua && busted spec/core_spec.lua` | ✅ | ⬜ pending |
| 03-01-02 | 03-01 | 1 | BUG-02 | — | N/A | unit | `busted spec/tip_spec.lua && busted spec/core_spec.lua && busted` | ✅ | ⬜ pending |
| 03-02-01 | 03-02 | 2 | BUG-03, BUG-04 | — | N/A | unit | `busted spec/tip_spec.lua && luacheck Duncedmaxxing/ --no-unused-args` | ✅ | ⬜ pending |
| 03-02-02 | 03-02 | 2 | BUG-03, BUG-04 | — | N/A | unit | `busted spec/tip_spec.lua && busted` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. busted, luacheck, wow_stubs.lua, and the test loader are all in place from Phase 2.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Display mode switch shows correct stacks in-game | BUG-02 | Requires WoW client with combat state | Switch mode via `/dmax mode icon` while out of combat, verify pip count matches aura tooltip |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 3s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-06-18
