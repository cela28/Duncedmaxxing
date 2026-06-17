---
type: quick
description: Move addon files into Duncedmaxxing/ subdirectory, update all path references
autonomous: true
files_modified:
  - Duncedmaxxing/Core.lua
  - Duncedmaxxing/Options.lua
  - Duncedmaxxing/Duncedmaxxing.toc
  - Duncedmaxxing/Modules/TipOfTheSpear.lua
  - Duncedmaxxing/Media/duncedgers_pony.png
  - CLAUDE.md
  - .planning/codebase/ARCHITECTURE.md
  - .planning/codebase/STRUCTURE.md
  - .planning/codebase/STACK.md
  - .planning/codebase/CONCERNS.md
  - .planning/codebase/CONVENTIONS.md
  - .planning/codebase/INTEGRATIONS.md
  - .planning/codebase/TESTING.md
  - .planning/ROADMAP.md
  - .planning/REQUIREMENTS.md
  - .planning/PROJECT.md
  - .planning/research/PITFALLS.md
  - .planning/research/ARCHITECTURE.md
  - .planning/research/STACK.md
  - .planning/research/FEATURES.md
---

<objective>
Move all WoW addon files (Core.lua, Options.lua, Duncedmaxxing.toc, Modules/, Media/) from the repo root into a Duncedmaxxing/ subdirectory. Then update every file path reference in CLAUDE.md and all .planning/ artifacts to reflect the new locations. Dev-only files (README.md, CLAUDE.md, .gitignore, .planning/) stay at repo root.

Purpose: Standard WoW addon repos keep the addon directory as a subdirectory so users can clone/extract directly into Interface/AddOns/. Currently the addon files sit at repo root which means manual restructuring after download.

Output: All addon files under Duncedmaxxing/, all documentation path references updated, git history preserved via git mv.
</objective>

<context>
@CLAUDE.md
@.planning/PROJECT.md
@.planning/ROADMAP.md
</context>

<tasks>

<task type="auto">
  <name>Task 1: Move addon files into Duncedmaxxing/ subdirectory</name>
  <files>
    Duncedmaxxing/Core.lua
    Duncedmaxxing/Options.lua
    Duncedmaxxing/Duncedmaxxing.toc
    Duncedmaxxing/Modules/TipOfTheSpear.lua
    Duncedmaxxing/Media/duncedgers_pony.png
  </files>
  <action>
    Create the Duncedmaxxing/ directory, then use git mv to move all addon files. The moves must be done in this order to handle directories correctly:

    1. Create target directories: mkdir -p Duncedmaxxing/Modules Duncedmaxxing/Media
    2. git mv Core.lua Duncedmaxxing/Core.lua
    3. git mv Options.lua Duncedmaxxing/Options.lua
    4. git mv Duncedmaxxing.toc Duncedmaxxing/Duncedmaxxing.toc
    5. git mv Modules/TipOfTheSpear.lua Duncedmaxxing/Modules/TipOfTheSpear.lua
    6. git mv Media/duncedgers_pony.png Duncedmaxxing/Media/duncedgers_pony.png
    7. Remove now-empty Modules/ and Media/ directories with rmdir

    IMPORTANT: The TOC file's internal references (Core.lua, Options.lua, Modules\TipOfTheSpear.lua) are relative to the .toc file location. Since the .toc moves into the same subdirectory as the Lua files, these references do NOT change. Do NOT edit Duncedmaxxing.toc contents.

    Do NOT move: README.md, CLAUDE.md, .gitignore, .planning/ -- these stay at repo root.
  </action>
  <verify>
    <automated>cd /home/cela/random-projects/Duncedmaxxing && test -f Duncedmaxxing/Core.lua && test -f Duncedmaxxing/Options.lua && test -f Duncedmaxxing/Duncedmaxxing.toc && test -f Duncedmaxxing/Modules/TipOfTheSpear.lua && test -f Duncedmaxxing/Media/duncedgers_pony.png && ! test -f Core.lua && ! test -f Options.lua && ! test -d Media && ! test -d Modules && echo "PASS: all files moved" || echo "FAIL"</automated>
  </verify>
  <done>All addon files exist under Duncedmaxxing/, no addon files remain at repo root, empty directories removed. Git staging shows renames, not delete+add.</done>
</task>

<task type="auto">
  <name>Task 2: Update all file path references in CLAUDE.md and planning artifacts</name>
  <files>
    CLAUDE.md
    .planning/codebase/ARCHITECTURE.md
    .planning/codebase/STRUCTURE.md
    .planning/codebase/STACK.md
    .planning/codebase/CONCERNS.md
    .planning/codebase/CONVENTIONS.md
    .planning/codebase/INTEGRATIONS.md
    .planning/codebase/TESTING.md
    .planning/ROADMAP.md
    .planning/REQUIREMENTS.md
    .planning/PROJECT.md
    .planning/research/PITFALLS.md
    .planning/research/ARCHITECTURE.md
    .planning/research/STACK.md
    .planning/research/FEATURES.md
  </files>
  <action>
    Perform a systematic search-and-replace across all listed files. The key transformations are:

    PATH PREFIX ADDITIONS (bare references that need Duncedmaxxing/ prefix):
    - `Core.lua` -> `Duncedmaxxing/Core.lua` (when used as a file path, NOT when referring to the filename in prose like "WoW loads Core.lua")
    - `Options.lua` -> `Duncedmaxxing/Options.lua` (same rule)
    - `Modules/TipOfTheSpear.lua` -> `Duncedmaxxing/Modules/TipOfTheSpear.lua`
    - `Duncedmaxxing.toc` -> `Duncedmaxxing/Duncedmaxxing.toc`
    - `Media/duncedgers_pony.png` -> `Duncedmaxxing/Media/duncedgers_pony.png`
    - `Media/` -> `Duncedmaxxing/Media/` (directory references)
    - `Modules/` -> `Duncedmaxxing/Modules/` (directory references)

    CONTEXT-SENSITIVE RULES (critical -- read carefully):

    1. BACKTICK-QUOTED FILE REFERENCES get the prefix. Examples:
       - `Core.lua` -> `Duncedmaxxing/Core.lua` (in backticks as a path)
       - `Core.lua:11` -> `Duncedmaxxing/Core.lua:11` (line number references)
       - `Options.lua:58-61` -> `Duncedmaxxing/Options.lua:58-61`
       - `Modules/TipOfTheSpear.lua:86-117` -> `Duncedmaxxing/Modules/TipOfTheSpear.lua:86-117`

    2. TABLE CELL file references get the prefix. Examples:
       - `| Core | ... | Core.lua |` -> `| Core | ... | Duncedmaxxing/Core.lua |`

    3. PROSE REFERENCES describing "in Core.lua" or "from Core.lua" get the prefix when they identify a file location. Example:
       - "Location: `Core.lua`" -> "Location: `Duncedmaxxing/Core.lua`"
       - "defined in both `Core.lua` (lines 42-70) and `Options.lua`" -> "defined in both `Duncedmaxxing/Core.lua` (lines 42-70) and `Duncedmaxxing/Options.lua`"

    4. TOC LOAD ORDER references describing what the TOC file contains do NOT change the internal paths. The TOC lists "Core.lua" as a relative path from itself -- that stays the same. But referring to the TOC file itself as a path gets the prefix.

    5. WoW TEXTURE PATHS like `Interface\AddOns\Duncedmaxxing\Media\...` do NOT change -- these are WoW internal paths.

    6. STRUCTURE.md DIRECTORY LAYOUT TREE: Update the tree diagram. The addon files now live one level deeper. The new tree should show:
       ```
       repo-root/
       ├── Duncedmaxxing/              # WoW addon directory (drop into Interface/AddOns/)
       │   ├── Duncedmaxxing.toc       # WoW addon manifest
       │   ├── Core.lua                # Bootstrap: namespace, DB init, module registry
       │   ├── Options.lua             # Settings popup UI
       │   ├── Modules/
       │   │   └── TipOfTheSpear.lua
       │   └── Media/
       │       └── duncedgers_pony.png
       ├── README.md
       ├── CLAUDE.md
       ├── .gitignore
       └── .planning/
       ```
       Within the Duncedmaxxing/ subtree description, files can be referenced without the prefix since context is clear. But in "Key File Locations", "Where to Add New Code", and other sections that reference paths from repo root, use the full Duncedmaxxing/ prefix.

    7. HISTORICAL ARTIFACTS: Phase 00 SUMMARY, RESEARCH, VERIFICATION, CONTEXT, and PLAN files are historical records of completed work. Do NOT update path references in these files -- they document what was true at execution time.

    8. CLAUDE.md is the most critical file. It contains dozens of path references in the Technology Stack, Conventions, and Architecture sections. Every single backtick-quoted file path reference must be updated. Read the file carefully and update ALL references.

    9. The "All addon logic" line in STACK section: `Lua 5.1 (WoW-flavored) - All addon logic; Core.lua, Options.lua, Modules/TipOfTheSpear.lua` -- these are identifying files, so prefix them.

    After all edits, run a verification grep to ensure no stale bare references remain outside of:
    - Phase 00 historical artifacts
    - TOC internal content descriptions
    - WoW Interface\ texture path strings
    - Inline code examples showing Lua source (e.g., dofile("Modules/TipOfTheSpear.lua"))
  </action>
  <verify>
    <automated>cd /home/cela/random-projects/Duncedmaxxing && echo "=== Checking for stale bare Core.lua refs ===" && grep -rn '`Core\.lua' CLAUDE.md .planning/codebase/ .planning/ROADMAP.md .planning/REQUIREMENTS.md .planning/PROJECT.md .planning/research/PITFALLS.md .planning/research/ARCHITECTURE.md .planning/research/FEATURES.md 2>/dev/null | grep -v 'Duncedmaxxing/Core\.lua' | grep -v 'phases/00-' || echo "No stale Core.lua refs" && echo "=== Checking for stale bare Options.lua refs ===" && grep -rn '`Options\.lua' CLAUDE.md .planning/codebase/ .planning/ROADMAP.md .planning/REQUIREMENTS.md .planning/PROJECT.md .planning/research/ 2>/dev/null | grep -v 'Duncedmaxxing/Options\.lua' | grep -v 'phases/00-' || echo "No stale Options.lua refs" && echo "=== Checking for stale bare Modules/TipOfTheSpear refs ===" && grep -rn 'Modules/TipOfTheSpear' CLAUDE.md .planning/codebase/ .planning/research/ 2>/dev/null | grep -v 'Duncedmaxxing/Modules/TipOfTheSpear' | grep -v 'phases/00-' | grep -v 'dofile(' || echo "No stale Modules/TipOfTheSpear refs" && echo "=== Checking addon files exist ===" && test -f Duncedmaxxing/Core.lua && echo "PASS" || echo "FAIL"</automated>
  </verify>
  <done>Every backtick-quoted file path reference in CLAUDE.md and all .planning/ codebase/research/roadmap/requirements/project files points to Duncedmaxxing/ prefixed paths. No stale bare references remain (excluding historical phase 00 artifacts, TOC internal paths, and WoW texture paths). STRUCTURE.md tree diagram reflects the new layout.</done>
</task>

</tasks>

<verification>
Final checks after both tasks complete:

1. `git status` shows only renames (R100 or similar) for moved files, plus modifications for updated docs
2. `ls Duncedmaxxing/` shows Core.lua, Options.lua, Duncedmaxxing.toc, Modules/, Media/
3. `ls` at repo root shows NO Core.lua, Options.lua, Modules/, Media/ (only Duncedmaxxing/, README.md, CLAUDE.md, .gitignore, .planning/)
4. `cat Duncedmaxxing/Duncedmaxxing.toc` still references Core.lua (not Duncedmaxxing/Core.lua) -- internal paths unchanged
5. `grep -rn 'Core\.lua' CLAUDE.md | head -5` shows all references include Duncedmaxxing/ prefix
6. No planning artifacts in phases/00-repo-cleanup/ were modified (historical records preserved)
</verification>

<success_criteria>
- All addon files live under Duncedmaxxing/ with git rename tracking preserved
- TOC internal paths unchanged (relative to .toc location)
- CLAUDE.md: all file path references updated to Duncedmaxxing/ prefix
- .planning/codebase/*.md: all file path references updated
- .planning/ROADMAP.md, REQUIREMENTS.md, PROJECT.md: all file path references updated
- .planning/research/*.md: all file path references updated (excluding dofile examples in test code)
- Phase 00 historical files: untouched
- Single atomic commit with all changes
</success_criteria>
