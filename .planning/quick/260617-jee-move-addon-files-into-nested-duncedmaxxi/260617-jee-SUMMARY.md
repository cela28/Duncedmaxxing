---
status: complete
phase: quick
plan: 260617-jee
subsystem: repo-structure
tags: [restructure, file-move, documentation]
dependency_graph:
  requires: []
  provides: [nested-addon-layout]
  affects: [all-planning-docs, CLAUDE.md]
tech_stack:
  added: []
  patterns: [nested-addon-directory]
key_files:
  created: []
  modified:
    - Duncedmaxxing/Core.lua (moved from Core.lua)
    - Duncedmaxxing/Options.lua (moved from Options.lua)
    - Duncedmaxxing/Duncedmaxxing.toc (moved from Duncedmaxxing.toc)
    - Duncedmaxxing/Modules/TipOfTheSpear.lua (moved from Modules/TipOfTheSpear.lua)
    - Duncedmaxxing/Media/duncedgers_pony.png (moved from Media/duncedgers_pony.png)
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
    - .planning/research/FEATURES.md
    - .planning/research/SUMMARY.md
decisions:
  - TOC internal paths left unchanged since they are relative to the .toc file location
  - Phase 00 historical artifacts preserved as-is (historical records of completed work)
  - TOC-relative references in prose (e.g., "loaded before Core.lua in the TOC") kept without prefix
  - research/SUMMARY.md also updated (not in original plan file list but contained stale paths)
metrics:
  duration: 18m
  completed: 2026-06-17
---

# Quick Task 260617-jee: Move Addon Files into Duncedmaxxing/ Subdirectory

Moved all WoW addon files into a Duncedmaxxing/ subdirectory for standard addon repo layout, and updated all file path references across CLAUDE.md and 15 planning artifacts.

## Task Results

| Task | Name | Commit | Key Changes |
|------|------|--------|-------------|
| 1 | Move addon files into Duncedmaxxing/ subdirectory | 7dd71a0 | git mv of 5 files (Core.lua, Options.lua, Duncedmaxxing.toc, Modules/TipOfTheSpear.lua, Media/duncedgers_pony.png) |
| 2 | Update all file path references in CLAUDE.md and planning artifacts | a24b2cf | 15 files updated with Duncedmaxxing/ prefix on all backtick-quoted file paths |

## What Changed

### Task 1: File Moves
All addon files moved from repo root into `Duncedmaxxing/` subdirectory using `git mv` to preserve rename tracking:
- `Core.lua` -> `Duncedmaxxing/Core.lua`
- `Options.lua` -> `Duncedmaxxing/Options.lua`
- `Duncedmaxxing.toc` -> `Duncedmaxxing/Duncedmaxxing.toc`
- `Modules/TipOfTheSpear.lua` -> `Duncedmaxxing/Modules/TipOfTheSpear.lua`
- `Media/duncedgers_pony.png` -> `Duncedmaxxing/Media/duncedgers_pony.png`

Empty `Modules/` and `Media/` directories removed from repo root.

### Task 2: Path Reference Updates
Updated all backtick-quoted file path references across 16 files (15 planned + 1 discovered):
- **CLAUDE.md**: All Technology Stack, Key Dependencies, Configuration, Component Responsibilities, Layers, Key Abstractions, Entry Points, Error Handling references
- **Codebase docs** (7 files): ARCHITECTURE, STRUCTURE, STACK, CONCERNS, CONVENTIONS, INTEGRATIONS, TESTING
- **Planning docs** (3 files): ROADMAP, REQUIREMENTS, PROJECT
- **Research docs** (4 files): PITFALLS, ARCHITECTURE, FEATURES, SUMMARY

Context-sensitive rules applied:
- TOC-internal paths (e.g., `Core.lua` within TOC load order descriptions) left unchanged
- WoW `Interface\AddOns\` texture paths left unchanged
- Phase 00 historical artifacts left unchanged
- STRUCTURE.md tree diagram rewritten to show new nested layout

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing] research/SUMMARY.md had stale file path references**
- **Found during:** Task 2
- **Issue:** `.planning/research/SUMMARY.md` was not listed in the plan's file list but contained stale bare file path references (Core.lua, Options.lua, Modules/TipOfTheSpear.lua)
- **Fix:** Updated all stale references in SUMMARY.md with Duncedmaxxing/ prefix
- **Files modified:** `.planning/research/SUMMARY.md`
- **Commit:** a24b2cf

## Verification Results

- All addon files exist under `Duncedmaxxing/` (Core.lua, Options.lua, Duncedmaxxing.toc, Modules/TipOfTheSpear.lua, Media/duncedgers_pony.png)
- No addon files remain at repo root
- Git shows R100 renames (not delete+add) for all moves
- TOC internal paths unchanged (Core.lua, Options.lua, Modules\TipOfTheSpear.lua)
- No stale bare `Core.lua` references in CLAUDE.md or planning docs (excluding TOC-relative context)
- No phase 00 files modified
- No untracked files left behind
