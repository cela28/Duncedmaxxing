---
phase: 07
slug: spell-coverage-add-missing-consumers
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-27
---

# Phase 07 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | fengari 0.1.5 (Lua 5.3 → JS bridge) with busted-style spec files |
| **Config file** | `spec/run.cjs` — test runner entry point |
| **Quick run command** | `npx -y -p fengari@0.1.5 node spec/run.cjs` |
| **Full suite command** | `npx -y -p fengari@0.1.5 node spec/run.cjs` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `npx -y -p fengari@0.1.5 node spec/run.cjs`
- **After every plan wave:** Run `npx -y -p fengari@0.1.5 node spec/run.cjs`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 07-01-01 | 01 | 1 | SC-1 | — | N/A | unit | `npx -y -p fengari@0.1.5 node spec/run.cjs` | ✅ | ⬜ pending |
| 07-01-02 | 01 | 1 | SC-2, SC-3 | — | N/A | unit | `npx -y -p fengari@0.1.5 node spec/run.cjs` | ❌ W0 | ⬜ pending |
| 07-01-03 | 01 | 1 | SC-4 | — | N/A | manual | N/A — in-game UAT | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- Existing infrastructure covers all phase requirements. The fengari harness and spec/tip_spec.lua are already in place.
- New test cases will be added to `spec/tip_spec.lua` as part of the implementation tasks.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Moonlight Chakram consumes 1 stack in-game | SC-4 | Requires live WoW client to verify UNIT_SPELLCAST_SUCCEEDED fires with expected spell ID | Cast Moonlight Chakram at 2+ stacks, verify stack count decrements by 1 |
| Hatchet Toss consumes 1 stack in-game | SC-4 | Requires live WoW client to verify UNIT_SPELLCAST_SUCCEEDED fires with expected spell ID | Cast Hatchet Toss at 2+ stacks, verify stack count decrements by 1 |
| Moonlight Chakram spell ID 1264949 variant check | D-04 | Cannot confirm without live combat log | Check combat log for alternate spell ID when casting Moonlight Chakram |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
