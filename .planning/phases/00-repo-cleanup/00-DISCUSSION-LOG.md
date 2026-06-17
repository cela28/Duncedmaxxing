# Phase 0: Repo Cleanup - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-17
**Phase:** 0-Repo Cleanup
**Areas discussed:** .gitignore scope, Content preservation

---

## .gitignore Scope

| Option | Description | Selected |
|--------|-------------|----------|
| Comprehensive WoW addon (Recommended) | Zone.Identifier + SavedVariables dirs + backups + OS junk + editor files | |
| Minimal — just CLN-04 | Only *:Zone.Identifier pattern | |
| Comprehensive + .planning/ | Same as comprehensive, plus exclude .planning/ directory | |

**User's choice:** Comprehensive WoW addon, with the caveat that .planning/ should be ignored from main branch but allowed on dev/feature branches.

**Follow-up — .planning/ handling:**

| Option | Description | Selected |
|--------|-------------|----------|
| Works for me | Comprehensive .gitignore without .planning/, use /gsd:pr-branch to filter on PRs to main | ✓ |
| Add .planning/ to .gitignore | Exclude .planning/ everywhere | |

**User's choice:** Keep .planning/ tracked, handle main-branch exclusion via /gsd:pr-branch at PR time.

---

## Content Preservation

| Option | Description | Selected |
|--------|-------------|----------|
| Delete outright (Recommended) | Everything useful is already in PROJECT.md, CLAUDE.md, and .planning/codebase/ maps | ✓ |
| Archive to .planning/ | Move both files into .planning/archive/ as historical reference | |
| Merge highlights into README | Pull tracking model summary and key spell IDs into README.md | |

**User's choice:** Delete outright — no content salvaging needed.

---

## Claude's Discretion

None — all decisions were made by the user.

## Deferred Ideas

None — discussion stayed within phase scope.
