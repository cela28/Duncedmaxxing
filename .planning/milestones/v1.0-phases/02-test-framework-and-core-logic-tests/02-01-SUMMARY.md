---
phase: 02-test-framework-and-core-logic-tests
plan: "01"
subsystem: test-infrastructure
tags: [testing, busted, lua5.1, wow-stubs, util]
dependency_graph:
  requires: []
  provides: [TEST-01, TEST-02, TEST-06]
  affects: [spec/util_spec.lua, spec/support/wow_stubs.lua, spec/support/init.lua, .busted]
tech_stack:
  added: [busted 2.3.0, lua5.1 5.1.5 (compiled from source), luarocks 3.11.1]
  patterns: [loadfile-vararg-injection, mock-clock-auto-fire, noopFrame-minimal-state, AuraData-full-contract]
key_files:
  created:
    - .busted
    - spec/support/wow_stubs.lua
    - spec/support/init.lua
    - spec/util_spec.lua
  modified: []
decisions:
  - "Lua 5.1 compiled from source with -fPIC and linked as shared library; required because lfs.so C module must link to exported Lua symbols"
  - "LuaRocks 3.11.1 installed to ~/.local without root; busted 2.3.0 works without system lua5.1 package"
  - "init.lua falls back gracefully when DMX._test is absent (wired in Plan 02)"
  - "38 it() blocks across 4 describe blocks — well above the minimum 20"
metrics:
  duration: "~6 minutes"
  completed_date: "2026-06-17"
  tasks_completed: 2
  files_created: 4
  tests_passing: 38
---

# Phase 02 Plan 01: Test Framework and Utility Function Tests Summary

busted 2.3.0 test framework configured for Lua 5.1 with full WoW API mock layer, loadfile vararg injection loader, and 38 passing utility function tests covering Clamp, ParseHexColor, ParseOnOff, and Trim edge cases.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Install busted and create test infrastructure | b23eb64 | .busted, spec/support/wow_stubs.lua, spec/support/init.lua |
| 2 | Write utility function tests and run to green | 95a66aa | spec/util_spec.lua |

## Verification Results

1. `busted --version` → `2.3.0` ✓
2. `busted spec/` → 38 successes / 0 failures / 0 errors ✓
3. `spec/support/wow_stubs.lua` contains stubs for all 11 D-04 APIs ✓
4. `spec/support/init.lua` uses `loadfile` (not `dofile`) for vararg injection ✓

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking Issue] lua5.1 and luarocks not installable via sudo apt**
- **Found during:** Task 1 — `sudo apt install lua5.1 luarocks` requires a password
- **Issue:** The plan's `user_setup` section specified `sudo apt install`, but the executor context does not have sudo password access
- **Fix:** Compiled Lua 5.1.5 from source with `-fPIC` flag and shared library support; installed LuaRocks 3.11.1 from source; both installed to `~/.local` without root access. The C extension modules (lfs.so) require the Lua binary to link against a shared library (`liblua5.1.so.0`) rather than a static archive — resolved by building and linking appropriately.
- **Files modified:** None (system-level, not tracked in repo)
- **Commit:** N/A (installation step, not committed)

## Known Stubs

None. All four utility functions (`Clamp`, `ParseHexColor`, `ParseOnOff`, `Trim`) are fully implemented pure-Lua functions with no WoW API dependencies. Tests exercise real production code.

The `DMX._test` escape hatch is absent from `Core.lua` — init.lua handles this gracefully with a fallback. This will be wired in Plan 02 so `MergeDefaults`/`NormalizeDB` are properly exposed for core_spec.lua tests.

## Threat Flags

None. This plan creates offline test infrastructure only — no network access, no user input processing, no authentication, no data persistence.

## Self-Check: PASSED

- .busted exists: FOUND
- spec/support/wow_stubs.lua exists: FOUND
- spec/support/init.lua exists: FOUND
- spec/util_spec.lua exists: FOUND
- Task 1 commit b23eb64: FOUND
- Task 2 commit 95a66aa: FOUND
- busted spec/ → 38 successes: VERIFIED
