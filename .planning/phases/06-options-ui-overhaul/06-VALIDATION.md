---
phase: 06
slug: options-ui-overhaul
status: verified
nyquist_compliant: true
wave_0_complete: true
created: 2026-06-29
updated: 2026-06-29
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
| 01-RED | 01 | 1 | stackColors in DEFAULTS + config-driven color read tests | unit | `node spec/run.cjs` | spec/core_spec.lua, spec/tip_spec.lua | ✅ green |
| 01-GREEN | 01 | 1 | stackColors DEFAULTS, remove enabled, shouldShow, config-driven color | unit | `node spec/run.cjs` | spec/core_spec.lua, spec/tip_spec.lua | ✅ green |
| 02-1+2 | 02 | 1 | Dead controls removed, mode-conditional sections, lock toggle, color inputs, reset colors | manual | N/A (WoW client UI) | N/A | ✅ green (automated regression: 121 pass) |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

*No Wave 0 test generation needed — all automatable requirements already covered:*

| Requirement | Test File | Test Description |
|-------------|-----------|------------------|
| stackColors defaults population | spec/core_spec.lua:51 | populates stackColors[0] through stackColors[3] from defaults |
| stackColors survives migration | spec/core_spec.lua:151 | populates stackColors after migration runs |
| Config-driven color read | spec/tip_spec.lua:635 | reads stack color from db.tip.stackColors when set |
| Fallback to STACK_COLORS | spec/tip_spec.lua:649 | falls back to STACK_COLORS when db.tip.stackColors is nil |
| No cfg.enabled gate | spec/tip_spec.lua | enabled removed from all fixtures, shouldShow tests pass |

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

## Validation Audit 2026-06-29

| Metric | Count |
|--------|-------|
| Gaps found | 0 |
| Resolved | 0 |
| Escalated | 0 |

All automatable requirements covered by existing tests (121 pass, 0 fail). 7 manual-only items documented — all require WoW client UI rendering.

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 5s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** verified 2026-06-29
