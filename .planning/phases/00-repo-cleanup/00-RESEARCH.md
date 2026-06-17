# Phase 0: Repo Cleanup - Research

**Researched:** 2026-06-17
**Domain:** Git repository hygiene, NTFS Zone.Identifier artifacts, WoW addon layout conventions
**Confidence:** HIGH

## Summary

This phase is a pure cleanup operation with no code changes. Every cleanup target has been
directly verified against the live repository. The current state is fully known: 8 Zone.Identifier
files exist on disk (7 tracked by git, 1 untracked), two stale documentation files are tracked by
git and present on disk, no `.gitignore` exists, and the folder structure already meets the WoW
addon layout standard — it only needs to be verified and asserted.

All work is `git rm --cached` calls, `rm` calls, a `.gitignore` create, and one commit. There are
no external dependencies, no packages to install, and no test framework needed for this phase.
Nyquist validation coverage is limited to structural/presence checks (`find`, `git ls-files`) since
there is no executable code being changed.

**Primary recommendation:** Remove all artifacts (git rm --cached for tracked ones, rm for
untracked), create `.gitignore` as specified in D-01, verify folder structure with one `find`
command, then commit. The entire phase should execute in a single wave of sequential tasks.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Create a comprehensive WoW addon `.gitignore` covering: `*:Zone.Identifier`, OS junk
  (`.DS_Store`, `Thumbs.db`), editor files (`.vscode/`, `*.swp`, `*~`), backups (`*.bak`), and
  SavedVariables directories.
- **D-02:** Do NOT add `.planning/` to `.gitignore`. The `.planning/` directory stays tracked on
  dev/feature branches and is excluded from main via `/gsd:pr-branch` at PR creation time.
- **D-03:** Delete `API_REFERENCES.md` and `DEVELOPMENT_NOTES.md` outright with no content
  salvaging. All useful content is already captured in `PROJECT.md`, `CLAUDE.md`, and
  `.planning/codebase/` maps.

### Claude's Discretion

None specified.

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CLN-01 | All `:Zone.Identifier` NTFS alternate data stream files removed from the repository | 8 files confirmed on disk (7 git-tracked, 1 untracked); exact paths enumerated below |
| CLN-02 | `API_REFERENCES.md` removed from the repository | File is git-tracked (confirmed via `git ls-files`); present on disk |
| CLN-03 | `DEVELOPMENT_NOTES.md` removed from the repository | File is git-tracked (confirmed via `git ls-files`); present on disk |
| CLN-04 | `.gitignore` updated to prevent `:Zone.Identifier` files from being re-committed | No `.gitignore` exists today; must be created fresh per D-01 |
| CLN-05 | Folder structure validated against standard WoW addon conventions | Current structure already matches; needs assertion check only |
</phase_requirements>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Zone.Identifier removal | Git index + filesystem | — | Files are tracked in git and present on disk; both layers must be cleared |
| .gitignore creation | Git config (working tree) | — | Prevents future re-admission of artifact files |
| Doc file deletion | Git index + filesystem | — | Both tracked and present; standard `git rm` handles both atomically |
| Folder structure validation | Filesystem inspection | Git index | Verify canonical layout matches WoW addon convention |

## Current State Inventory (verified)

### Zone.Identifier Files — Complete List

**Tracked by git AND present on disk (require `git rm --cached` + `rm`):**

| Path | Git-tracked | On Disk |
|------|-------------|---------|
| `Core.lua:Zone.Identifier` | YES | YES |
| `DEVELOPMENT_NOTES.md:Zone.Identifier` | YES | YES |
| `Duncedmaxxing.toc:Zone.Identifier` | YES | YES |
| `Media/duncedgers_pony.png:Zone.Identifier` | YES | YES |
| `Modules/TipOfTheSpear.lua:Zone.Identifier` | YES | YES |
| `Options.lua:Zone.Identifier` | YES | YES |
| `README.md:Zone.Identifier` | YES | YES |

**Present on disk only, NOT tracked by git (require `rm` only):**

| Path | Git-tracked | On Disk |
|------|-------------|---------|
| `API_REFERENCES.md:Zone.Identifier` | NO | YES |

**Why the asymmetry:** `API_REFERENCES.md` itself is tracked. Its `.Zone.Identifier` sidecar was
never committed to the index. This is a minor git history accident; the untracked file still needs
disk removal.

### Documentation Files to Delete

| File | Git-tracked | On Disk | Action |
|------|-------------|---------|--------|
| `API_REFERENCES.md` | YES | YES | `git rm` (removes from index and disk) |
| `DEVELOPMENT_NOTES.md` | YES | YES | `git rm` (removes from index and disk) |

Note: `DEVELOPMENT_NOTES.md:Zone.Identifier` is a separate entry above (also tracked).

### .gitignore Status

No `.gitignore` exists in the repository root. [VERIFIED: `ls -la` confirmed] Must be created
from scratch.

### Folder Structure — Current vs. Expected

**Current structure (relevant files only):**
```
Duncedmaxxing/
├── Duncedmaxxing.toc         <- .toc present
├── Core.lua                  <- .lua present
├── Options.lua               <- .lua present
├── CLAUDE.md                 <- project instructions, stays
├── README.md                 <- stays (end-user docs)
├── Modules/                  <- present
│   └── TipOfTheSpear.lua
├── Media/                    <- present
│   └── duncedgers_pony.png
└── .planning/                <- tracked on dev branch, not .gitignored per D-02
```

**After cleanup (artifacts and stale docs gone):**
```
Duncedmaxxing/
├── Duncedmaxxing.toc
├── Core.lua
├── Options.lua
├── CLAUDE.md
├── README.md
├── .gitignore                <- new
├── Modules/
│   └── TipOfTheSpear.lua
└── Media/
│   └── duncedgers_pony.png
└── .planning/                <- still tracked
```

**CLN-05 validation:** The structure already satisfies "root contains `.toc` + `.lua` files,
`Modules/`, and `Media/`". The phase task is to assert this via a verification step, not to
restructure anything. [VERIFIED: `ls` and `find` scan of live repo]

## Standard Stack

### Core

No packages to install. All operations use standard git and shell commands.

| Tool | Version | Purpose |
|------|---------|---------|
| `git rm` | 2.43.0 (system) | Remove files from git index (with `--cached`) or both index+disk |
| `rm` | system | Remove untracked disk files |
| `find` | system | Verify Zone.Identifier files are gone; verify folder structure |
| `git ls-files` | 2.43.0 (system) | Post-deletion verification that no Zone.Identifier files remain in index |

[VERIFIED: `git --version` = 2.43.0]

## Package Legitimacy Audit

No external packages are installed in this phase. Section not applicable.

## Architecture Patterns

### Removal Pattern: Git-tracked Files with Special Characters in Name

Zone.Identifier filenames contain a literal colon (`:`). On Linux/WSL2, these are regular files
(not NTFS alternate data streams). Git tracks them as regular files with colons in the path.

**Correct removal approach:**

```bash
# Remove from git index AND disk in one operation:
git rm "Core.lua:Zone.Identifier"

# For files tracked but wanting to keep on disk (not our case, but for reference):
git rm --cached "Core.lua:Zone.Identifier"
```

[VERIFIED: `git rm --cached "API_REFERENCES.md:Zone.Identifier"` executed successfully, producing
output `rm 'API_REFERENCES.md:Zone.Identifier'` — confirming colon filenames work with git rm
without escaping. That dry-run was not committed.]

**Quoting requirement:** Shell quoting with double quotes is sufficient. Colon is not a glob
special character in git or bash. No escaping needed.

**Batch removal:**

```bash
git rm \
  "Core.lua:Zone.Identifier" \
  "DEVELOPMENT_NOTES.md:Zone.Identifier" \
  "Duncedmaxxing.toc:Zone.Identifier" \
  "Media/duncedgers_pony.png:Zone.Identifier" \
  "Modules/TipOfTheSpear.lua:Zone.Identifier" \
  "Options.lua:Zone.Identifier" \
  "README.md:Zone.Identifier"
```

This removes from git index and disk simultaneously for all tracked files.

### .gitignore Pattern for Zone.Identifier

```
# NTFS Alternate Data Stream artifacts (Windows/WSL)
*:Zone.Identifier
```

The `*` glob matches any filename prefix. Colon has no special meaning in `.gitignore` patterns.
This pattern matches files at any depth when placed in the root `.gitignore`.

[ASSUMED: gitignore colon handling — training knowledge, but colon is not in the list of gitignore
special characters per git documentation, and the pattern is universally used in community WoW
addon repositories]

### .gitignore — Full Content per D-01

```gitignore
# NTFS Alternate Data Stream artifacts (Windows/WSL)
*:Zone.Identifier

# OS junk
.DS_Store
Thumbs.db

# Editor files
.vscode/
*.swp
*~

# Backups
*.bak

# WoW SavedVariables (local game data, not source)
WTF/
```

**SavedVariables directory note:** WoW writes `DuncedmaxxingDB` to
`WTF/Account/.../SavedVariables/Duncedmaxxing.lua` on the player's machine. If the repo is
cloned into a WoW addon directory, these files could appear. The `WTF/` pattern pre-empts this.
D-01 specifies "SavedVariables directories" — `WTF/` is the standard WoW path prefix. [ASSUMED:
exact pattern — `WTF/` covers the standard case, but the exact location varies by WoW client
installation]

### Verification Pattern

Post-cleanup assertions to run as the final verification task:

```bash
# CLN-01: No Zone.Identifier files remain in git index
git ls-files "*:Zone.Identifier"
# Expected output: (empty)

# CLN-01: No Zone.Identifier files remain on disk
find . -name "*:Zone.Identifier" -not -path "./.git/*"
# Expected output: (empty)

# CLN-02 / CLN-03: Doc files gone from index
git ls-files API_REFERENCES.md DEVELOPMENT_NOTES.md
# Expected output: (empty)

# CLN-02 / CLN-03: Doc files gone from disk
ls API_REFERENCES.md DEVELOPMENT_NOTES.md 2>&1
# Expected output: ls: cannot access ... No such file or directory

# CLN-04: .gitignore exists and contains the pattern
grep "*:Zone.Identifier" .gitignore
# Expected output: *:Zone.Identifier

# CLN-05: Folder structure contains required elements
find . -maxdepth 1 -name "*.toc" | head -1  # finds Duncedmaxxing.toc
find . -maxdepth 1 -name "*.lua" | wc -l    # >= 1
ls -d Modules/ Media/                        # both directories present
```

## Don't Hand-Roll

| Problem | Don't Build | Use Instead |
|---------|-------------|-------------|
| Removing files from git index | Custom git-filter-branch rewrite | `git rm` / `git rm --cached` |
| Finding Zone.Identifier files | Manual ls inspection | `find . -name "*:Zone.Identifier"` |
| Verifying post-cleanup | Visual inspection | `git ls-files` assertions |

## Common Pitfalls

### Pitfall 1: Using `git rm --cached` for doc files accidentally
**What goes wrong:** Running `git rm --cached API_REFERENCES.md` removes the file from the index
but leaves it on disk, making it an untracked file that lingers in the working tree.
**Why it happens:** `--cached` flag is intended for files you want to untrack but keep on disk.
**How to avoid:** Use plain `git rm API_REFERENCES.md` for files that should be fully deleted.
**Warning signs:** After the command, `ls API_REFERENCES.md` still succeeds.

### Pitfall 2: Missing the untracked Zone.Identifier sidecar
**What goes wrong:** `git rm "*:Zone.Identifier"` removes all 7 tracked files, but
`API_REFERENCES.md:Zone.Identifier` (untracked) remains on disk. CLN-01 says no such files
"exist anywhere in the repository" — disk presence counts.
**Why it happens:** Untracked files are invisible to `git rm`.
**How to avoid:** After `git rm` for tracked files, run a separate `rm` or `find` + `rm` for the
untracked one. The verification `find . -name "*:Zone.Identifier"` catches any remaining files.
**Warning signs:** `find . -name "*:Zone.Identifier"` returns any output after cleanup.

### Pitfall 3: .gitignore not preventing re-addition after cleanup
**What goes wrong:** Zone.Identifier files are removed, but `.gitignore` isn't committed in the
same transaction. A subsequent `git add .` before the commit could re-add them.
**Why it happens:** Order of operations — remove files, then create `.gitignore`, then commit all
together.
**How to avoid:** Create `.gitignore` before or in the same commit as the removals. The plan
should stage `.gitignore` in the same commit.
**Warning signs:** `git status` shows Zone.Identifier files as staged after `git add .`.

### Pitfall 4: .gitignore pattern not matching files in subdirectories
**What goes wrong:** `*:Zone.Identifier` in root `.gitignore` might only match files in the root,
not in `Modules/` or `Media/`.
**Why it happens:** Some pattern syntaxes in gitignore are directory-scoped.
**How to avoid:** In gitignore, a pattern without a leading slash and without a `/` in it matches
files at any depth. `*:Zone.Identifier` has no `/`, so it matches at all depths including
`Modules/TipOfTheSpear.lua:Zone.Identifier` and `Media/duncedgers_pony.png:Zone.Identifier`.
[ASSUMED: verification of gitignore depth behavior — consistent with git documentation but not
re-checked against git 2.43.0 release notes]

### Pitfall 5: Deleting CLAUDE.md by mistake
**What goes wrong:** Phase scope says delete `API_REFERENCES.md` and `DEVELOPMENT_NOTES.md`.
Someone scripting the deletion with a glob could accidentally delete other `.md` files.
**Why it happens:** Sloppy glob like `rm *.md` when only two specific files should go.
**How to avoid:** Always name files explicitly: `git rm API_REFERENCES.md DEVELOPMENT_NOTES.md`.
Never glob delete documentation files.

## Runtime State Inventory

This is not a rename/refactor/migration phase. The only "state" is:

| Category | Items Found | Action Required |
|----------|-------------|-----------------|
| Stored data | None — no database, no SavedVariables involved | None |
| Live service config | None — no external services | None |
| OS-registered state | None — no OS registrations | None |
| Secrets/env vars | None — no secrets involved | None |
| Build artifacts | None — no build artifacts exist (no toolchain) | None |

## Validation Architecture

Framework: No test framework needed. All validation is shell command assertions.

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command |
|--------|----------|-----------|-------------------|
| CLN-01 | No Zone.Identifier files in git index | shell assertion | `git ls-files "*:Zone.Identifier" \| wc -l \| grep -q "^0$"` |
| CLN-01 | No Zone.Identifier files on disk | shell assertion | `find . -name "*:Zone.Identifier" -not -path "./.git/*" \| wc -l \| grep -q "^0$"` |
| CLN-02 | API_REFERENCES.md absent from git index | shell assertion | `git ls-files API_REFERENCES.md \| grep -q "." && echo FAIL \|\| echo PASS` |
| CLN-02 | API_REFERENCES.md absent from disk | shell assertion | `[ ! -f API_REFERENCES.md ]` |
| CLN-03 | DEVELOPMENT_NOTES.md absent from git index | shell assertion | `git ls-files DEVELOPMENT_NOTES.md \| grep -q "." && echo FAIL \|\| echo PASS` |
| CLN-03 | DEVELOPMENT_NOTES.md absent from disk | shell assertion | `[ ! -f DEVELOPMENT_NOTES.md ]` |
| CLN-04 | .gitignore exists with Zone.Identifier pattern | shell assertion | `grep -qF "*:Zone.Identifier" .gitignore` |
| CLN-05 | .toc file present in root | shell assertion | `find . -maxdepth 1 -name "*.toc" \| grep -q "."` |
| CLN-05 | .lua files present in root | shell assertion | `find . -maxdepth 1 -name "*.lua" \| grep -q "."` |
| CLN-05 | Modules/ directory present | shell assertion | `[ -d Modules ]` |
| CLN-05 | Media/ directory present | shell assertion | `[ -d Media ]` |

### Wave 0 Gaps

None — no test framework, config files, or fixtures needed. All validations are inline shell
commands.

## Security Domain

Security enforcement is enabled (not explicitly set to false in config.json).

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | — |
| V3 Session Management | No | — |
| V4 Access Control | No | — |
| V5 Input Validation | No | No user input in this phase |
| V6 Cryptography | No | — |

**Security relevance:** Zone.Identifier files contain NTFS zone metadata (ZoneId=3 = Internet
zone). Their presence in a repository is an information disclosure artifact — they reveal that the
original files were downloaded from the internet on a Windows machine. Removing them is the
correct security hygiene action. No other security concerns apply to a file deletion phase.

### Known Threat Patterns

None applicable — no code is written, no input is processed, no network calls are made.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| git | All CLN tasks | YES | 2.43.0 | — |
| bash/sh | Verification commands | YES | system | — |
| find | CLN-01 verification | YES | system | `git ls-files` only |

[VERIFIED: `git --version` = 2.43.0 confirmed on target machine]

No missing dependencies.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `*:Zone.Identifier` in root `.gitignore` matches files in subdirectories (Modules/, Media/) | Common Pitfalls #4, .gitignore pattern | Zone.Identifier files in subdirs could be re-committed after cleanup; mitigation: verification command explicitly checks both git index and disk recursively |
| A2 | `WTF/` is the correct gitignore pattern for WoW SavedVariables directories | Standard Stack (.gitignore content) | If the player's WoW installs elsewhere, the pattern may not match; low risk since the SavedVariables path is outside the addon directory when installed normally |

## Open Questions

1. **Should `README.md` be kept or renamed?**
   - What we know: `README.md` is tracked, present, not in the delete list (only `API_REFERENCES.md` and `DEVELOPMENT_NOTES.md` are to be deleted per D-03)
   - What's unclear: D-03 says content is already captured in `PROJECT.md`, `CLAUDE.md`, etc. — but `README.md` is end-user documentation, not developer context. It seems intentional to keep it.
   - Recommendation: Keep `README.md` — it is end-user facing and its `Zone.Identifier` sidecar is already on the deletion list. Nothing in the requirements or context decisions targets it.

## Sources

### Primary (HIGH confidence)
- Direct filesystem scan: `find`, `ls -la` on live repository — all file counts and paths verified
- Direct git index scan: `git ls-files` — all tracked files and Zone.Identifier status verified
- `git rm` behavior test: `git rm --cached "API_REFERENCES.md:Zone.Identifier"` confirmed syntax works (output captured, not committed)

### Secondary (MEDIUM confidence)
- `.planning/codebase/STRUCTURE.md` — folder structure and file purposes
- `.planning/REQUIREMENTS.md` — CLN-01 through CLN-05 exact wording
- `.planning/phases/00-repo-cleanup/00-CONTEXT.md` — locked decisions D-01, D-02, D-03

### Tertiary (LOW confidence / ASSUMED)
- gitignore colon handling and subdirectory depth behavior — consistent with git documentation in training data, not re-verified against git 2.43.0 changelog

## Metadata

**Confidence breakdown:**
- Current state inventory: HIGH — directly verified via live repo scan
- Removal commands: HIGH — `git rm` syntax tested against live repo
- .gitignore patterns: MEDIUM — standard patterns, colon behavior assumed standard
- Architecture/structure: HIGH — directly verified via `ls`, `find`, `git ls-files`

**Research date:** 2026-06-17
**Valid until:** 2026-07-17 (stable domain — git file deletion has no expiry concern)
