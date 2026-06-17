---
phase: 0
slug: repo-cleanup
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-17
---

# Phase 0 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | None — shell assertions only |
| **Config file** | none |
| **Quick run command** | `git ls-files "*:Zone.Identifier" \| wc -l` |
| **Full suite command** | See Per-Task Verification Map |
| **Estimated runtime** | ~2 seconds |

---

## Sampling Rate

- **After every task commit:** Run verification commands for that task's requirements
- **After every plan wave:** Run all verification commands
- **Before `/gsd:verify-work`:** All assertions must pass
- **Max feedback latency:** 2 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 00-01-01 | 01 | 1 | CLN-01 | — | N/A | shell assertion | `git ls-files "*:Zone.Identifier" \| wc -l \| grep -q "^0$"` | ✅ | ⬜ pending |
| 00-01-02 | 01 | 1 | CLN-01 | — | N/A | shell assertion | `find . -name "*:Zone.Identifier" -not -path "./.git/*" \| wc -l \| grep -q "^0$"` | ✅ | ⬜ pending |
| 00-01-03 | 01 | 1 | CLN-02 | — | N/A | shell assertion | `[ ! -f API_REFERENCES.md ] && ! git ls-files --error-unmatch API_REFERENCES.md 2>/dev/null` | ✅ | ⬜ pending |
| 00-01-04 | 01 | 1 | CLN-03 | — | N/A | shell assertion | `[ ! -f DEVELOPMENT_NOTES.md ] && ! git ls-files --error-unmatch DEVELOPMENT_NOTES.md 2>/dev/null` | ✅ | ⬜ pending |
| 00-01-05 | 01 | 1 | CLN-04 | — | N/A | shell assertion | `grep -qF "*:Zone.Identifier" .gitignore` | ✅ | ⬜ pending |
| 00-01-06 | 01 | 1 | CLN-05 | — | N/A | shell assertion | `find . -maxdepth 1 -name "*.toc" \| grep -q "." && find . -maxdepth 1 -name "*.lua" \| grep -q "." && [ -d Modules ] && [ -d Media ]` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. No test framework, config files, or fixtures needed — all validations are inline shell commands.

---

## Manual-Only Verifications

All phase behaviors have automated verification.

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 2s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
