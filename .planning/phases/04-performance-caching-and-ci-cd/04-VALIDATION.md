---
phase: 4
slug: performance-caching-and-ci-cd
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-18
---

# Phase 4 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | busted (Lua 5.1) |
| **Config file** | `.busted` |
| **Quick run command** | `busted spec/` |
| **Full suite command** | `busted spec/ && luacheck Duncedmaxxing/` |
| **Estimated runtime** | ~5 seconds |

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
| 04-01-01 | 01 | 1 | PERF-01 | — | N/A | unit | `busted spec/tip_spec.lua` | ✅ | ⬜ pending |
| 04-01-02 | 01 | 1 | PERF-02 | — | N/A | unit | `busted spec/tip_spec.lua` | ✅ | ⬜ pending |
| 04-02-01 | 02 | 2 | CICD-01 | — | N/A | integration | `act -j release` or manual | ❌ W0 | ⬜ pending |
| 04-02-02 | 02 | 2 | CICD-01 | — | N/A | integration | `luacheck Duncedmaxxing/` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

*Existing infrastructure covers all phase requirements.*

- busted + luacheck already installed and configured from Phase 2
- WoW API stubs already cover `C_SpecializationInfo`, `C_Spell`, and event system
- `spec/support/init.lua` `resetTipState` needs extension for new cache fields (part of caching task)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Release workflow produces zip | CICD-01 | GitHub Actions only runs on GitHub | Push a `v*` tag or create a release, verify zip asset appears |
| Zip extracts with correct folder structure | CICD-01 | Requires GitHub release artifact | Download zip, verify `Duncedmaxxing/` top-level with TOC + Lua files |
| Version injected into TOC | CICD-01 | Requires CI sed step execution | Check `## Version:` in TOC inside zip matches tag |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
