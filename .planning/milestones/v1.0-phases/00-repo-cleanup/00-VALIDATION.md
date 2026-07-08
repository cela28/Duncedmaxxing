---
phase: 0
slug: repo-cleanup
status: approved
nyquist_compliant: true
wave_0_complete: true
created: 2026-06-17
validated: 2026-07-09
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
| 00-01-01 | 01 | 1 | CLN-01 | T-00-01 | No NTFS zone metadata leaks into the repo | shell assertion | `test "$(git ls-files "*:Zone.Identifier" \| wc -l)" -eq 0` | ✅ | ✅ green |
| 00-01-02 | 01 | 1 | CLN-01 | T-00-01 | No NTFS zone metadata on disk | shell assertion | `test "$(find . -name "*:Zone.Identifier" -not -path "./.git/*" \| wc -l)" -eq 0` | ✅ | ✅ green |
| 00-01-03 | 01 | 1 | CLN-02 | — | Stale doc removed (index + disk) | shell assertion | `test "$(git ls-files API_REFERENCES.md \| wc -l)" -eq 0 && [ ! -f API_REFERENCES.md ]` | ✅ | ✅ green |
| 00-01-04 | 01 | 1 | CLN-03 | — | Stale doc removed (index + disk) | shell assertion | `test "$(git ls-files DEVELOPMENT_NOTES.md \| wc -l)" -eq 0 && [ ! -f DEVELOPMENT_NOTES.md ]` | ✅ | ✅ green |
| 00-01-05 | 01 | 1 | CLN-04 | T-00-02 | Pattern present; `.planning/` NOT ignored (D-02) | shell assertion | `grep -qF "*:Zone.Identifier" .gitignore && ! grep -qE "^\.?/?\.planning/?$" .gitignore` | ✅ | ✅ green |
| 00-01-06 | 01 | 1 | CLN-05 | — | WoW addon layout intact | shell assertion | `find Duncedmaxxing -maxdepth 1 -name "*.toc" \| grep -q "." && find Duncedmaxxing -maxdepth 1 -name "*.lua" \| grep -q "." && [ -d Duncedmaxxing/Modules ] && [ -d Duncedmaxxing/Media ]` | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

> **CLN-05 path note (2026-07-09):** the addon was relocated from the repo root into a `Duncedmaxxing/` subfolder during Phase 1 (module encapsulation). The original VALIDATION.md commands used `-maxdepth 1` at the repo root and now report red against current layout even though the structure is intact. The commands above are corrected to the nested `Duncedmaxxing/` layout; all four checks pass green.

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. No test framework, config files, or fixtures needed — all validations are inline shell commands.

---

## Manual-Only Verifications

All phase behaviors have automated verification.

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references (none — no framework needed)
- [x] No watch-mode flags
- [x] Feedback latency < 2s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-07-09

---

## Validation Audit 2026-07-09

| Metric | Count |
|--------|-------|
| Gaps found | 0 (all 5 CLN reqs have automated shell-assertion verification) |
| Resolved | 0 |
| Escalated | 0 |

State A audit: existing VALIDATION.md was structurally complete but never finalized (all statuses `pending`, `nyquist_compliant: false`). Ran the full assertion battery — **12/12 checks pass green** — and finalized statuses, sign-off, and frontmatter. No test files generated: this is a file-cleanup phase whose correct verification type is shell assertions, not a unit-test framework. The only correction was CLN-05's commands, updated for the post-Phase-1 `Duncedmaxxing/` nested layout (see path note above).
