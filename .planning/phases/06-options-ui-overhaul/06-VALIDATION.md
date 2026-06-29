---
phase: 06
slug: options-ui-overhaul
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-29
---

# Phase 06 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | busted (Lua 5.1) + fengari (Lua-VM-in-JS) harness |
| **Config file** | `.busted` / `spec/support/wow_stubs.lua` |
| **Quick run command** | `node spec/run.cjs` |
| **Full suite command** | `node spec/run.cjs` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `node spec/run.cjs`
- **After every plan wave:** Run `node spec/run.cjs`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| TBD | TBD | TBD | TBD | TBD | TBD | TBD | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

*Existing infrastructure covers all phase requirements.*

---

## Manual-Only Verifications

| Behavior | Why Manual | Test Instructions |
|----------|------------|-------------------|
| Mode-specific controls show/hide correctly | Requires WoW client UI rendering | Toggle between bar/number mode in Options window, verify correct controls visible |
| Window height adjusts on mode switch | Requires WoW client frame rendering | Switch modes, verify no dead space below controls |
| Lock toggle visual state | Requires WoW client button rendering | Click lock toggle, verify text changes |
| Reset Colors two-click confirmation | Requires WoW client interaction | Click Reset Colors, verify "Confirm Reset" text, verify timeout revert |
| Per-stack color inputs render correctly | Requires WoW client text input | Enter hex colors, verify number mode uses custom colors |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
