# Phase 0: Repo Cleanup - Context

**Gathered:** 2026-06-17
**Status:** Ready for planning

<domain>
## Phase Boundary

The repository contains only intentional addon files — no NTFS metadata artifacts, no stale reference docs, and a folder structure that matches standard WoW addon conventions. This phase establishes a clean baseline before any code changes begin.

</domain>

<decisions>
## Implementation Decisions

### .gitignore Scope
- **D-01:** Create a comprehensive WoW addon `.gitignore` covering: `*:Zone.Identifier`, OS junk (`.DS_Store`, `Thumbs.db`), editor files (`.vscode/`, `*.swp`, `*~`), backups (`*.bak`), and SavedVariables directories.
- **D-02:** Do NOT add `.planning/` to `.gitignore`. The `.planning/` directory stays tracked on dev/feature branches and is excluded from main via `/gsd:pr-branch` at PR creation time.

### Content Preservation
- **D-03:** Delete `API_REFERENCES.md` and `DEVELOPMENT_NOTES.md` outright with no content salvaging. All useful content is already captured in `PROJECT.md`, `CLAUDE.md`, and `.planning/codebase/` maps.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project Context
- `.planning/PROJECT.md` — Core value, constraints, and key decisions
- `.planning/REQUIREMENTS.md` — CLN-01 through CLN-05 define exact cleanup targets

### Codebase Structure
- `.planning/codebase/STRUCTURE.md` — Current directory layout and file purposes (validates CLN-05)
- `.planning/codebase/CONCERNS.md` — Tech debt inventory (context for why cleanup matters)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- None applicable — this phase only deletes files and creates `.gitignore`

### Established Patterns
- `Duncedmaxxing.toc` defines the canonical file list; only files declared there are loaded by WoW
- `Modules/` and `Media/` directories follow standard WoW addon layout conventions

### Integration Points
- `.gitignore` must not exclude any files referenced by `Duncedmaxxing.toc` or loaded by the addon
- Folder structure validation (CLN-05) should confirm the root contains `.toc` + `.lua` files, `Modules/`, and `Media/` — all already present

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 0-Repo Cleanup*
*Context gathered: 2026-06-17*
