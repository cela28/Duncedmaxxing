---
phase: 1
slug: utility-extraction-and-module-encapsulation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-17
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | None — Phase 2 installs busted. Phase 1 has no automated test harness. |
| **Config file** | None yet |
| **Quick run command** | Manual: `/reload ui` in-game, observe no Lua errors |
| **Full suite command** | Manual: Exercise all display modes and slash commands post-reload |
| **Estimated runtime** | ~30 seconds (manual in-game verification) |

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
| 01-01-01 | 01 | 1 | QUAL-01 | — | N/A | manual-only | `/reload ui` then `/run print(DMX.Util.Clamp(5,0,10))` | — Phase 2 | ⬜ pending |
| 01-01-02 | 01 | 1 | QUAL-01 | — | N/A | manual-only | `/reload ui`, verify no duplicate definitions | — Phase 2 | ⬜ pending |
| 01-02-01 | 02 | 1 | QUAL-02 | — | N/A | manual-only | `/reload ui`, verify tracker displays correctly | — Phase 2 | ⬜ pending |
| 01-02-02 | 02 | 1 | QUAL-02 | — | N/A | manual-only | `/run print(type(Duncedmaxxing.modules.tip.root))` | — Phase 2 | ⬜ pending |
| 01-03-01 | 03 | 1 | QUAL-04 | — | N/A | manual-only | `/run print(DMX.moduleOrder[1])` should print `tip` | — Phase 2 | ⬜ pending |
| 01-04-01 | 04 | 1 | QUAL-05 | — | N/A | code review | Grep for `pcall` in ClassifySpellID | — Phase 2 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

*Existing infrastructure covers all phase requirements. No test framework setup needed — Phase 2 owns busted installation.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Utility functions callable via DMX.Util namespace | QUAL-01 | No test framework until Phase 2 | `/reload ui`, then `/run print(DMX.Util.Clamp(5,0,10))`, `/run print(DMX.Util.Trim("  hello  "))`, `/run print(DMX.Util.ParseOnOff("on"))`, `/run print(type(DMX.Util.ParseHexColor("FF0000")))` |
| Frame references on Tip table | QUAL-02 | No test framework until Phase 2 | `/reload ui`, verify tracker renders, then `/run print(type(Duncedmaxxing.modules.tip.root))` |
| ForEachModule iterates in order | QUAL-04 | No test framework until Phase 2 | `/run print(DMX.moduleOrder[1])` should print `tip` |
| ClassifySpellID has no pcall | QUAL-05 | Code review verification | `grep -n pcall Duncedmaxxing/Modules/TipOfTheSpear.lua` — should NOT match ClassifySpellID |

---

## Validation Sign-Off

- [ ] All tasks have manual verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
