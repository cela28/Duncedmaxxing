---
phase: 02-test-framework-and-core-logic-tests
plan: "02"
subsystem: test-core-logic
tags: [testing, busted, lua5.1, normalizedb, mergedefaults, migration]
dependency_graph:
  requires: [02-01]
  provides: [TEST-05]
  affects: [Duncedmaxxing/Core.lua, spec/core_spec.lua, spec/support/init.lua]
tech_stack:
  added: []
  patterns: [DMX._test-escape-hatch, direct-db-construction, per-describe-isolation]
key_files:
  created:
    - spec/core_spec.lua
  modified:
    - Duncedmaxxing/Core.lua
    - spec/support/init.lua
decisions:
  - "DMX._test escape hatch added at bottom of Core.lua after coreFrame:SetScript closure — exposes MergeDefaults, NormalizeDB, CopyDefaults, SETTINGS_MIGRATION for offline testing without changing production behavior"
  - "Each NormalizeDB test constructs its own db table directly rather than going through full load() bootstrap, ensuring surgical isolation of migration/validation logic"
  - "init.lua fallback block removed — DMX._test is now always present and the fallback was dead code"
metrics:
  duration: "~7 minutes"
  completed_date: "2026-06-17"
  tasks_completed: 2
  files_created: 1
  files_modified: 2
  tests_passing: 65
---

# Phase 02 Plan 02: NormalizeDB and MergeDefaults Tests Summary

DMX._test escape hatch added to Core.lua exposing NormalizeDB, MergeDefaults, CopyDefaults, and SETTINGS_MIGRATION; 27 unit tests covering migration trigger, position preservation, deprecated field clearing, displayMode validation, and already-migrated skipping bring the full suite to 65 passing tests.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Expose Core.lua local functions via DMX._test and update init.lua | 731f7a7 | Duncedmaxxing/Core.lua, spec/support/init.lua |
| 2 | Write NormalizeDB and MergeDefaults tests | 7a9e901 | spec/core_spec.lua |

## Verification Results

1. `grep -c "DMX._test" Duncedmaxxing/Core.lua` → `1` ✓
2. `busted spec/core_spec.lua` → 27 successes / 0 failures / 0 errors ✓
3. `busted spec/` → 65 successes / 0 failures / 0 errors ✓

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None. All tested functions (NormalizeDB, MergeDefaults, CopyDefaults) are fully implemented pure-Lua functions with no WoW API dependencies. Tests exercise real production code against manually constructed DB tables.

## Threat Flags

None. DMX._test only exposes local functions to sibling test files; no secrets are exposed and the table is not accessible by other addons.

## Self-Check: PASSED

- Duncedmaxxing/Core.lua contains `DMX._test`: FOUND (grep -c returns 1)
- spec/core_spec.lua exists: FOUND
- spec/support/init.lua uses DMX._test directly: FOUND (fallback removed)
- Task 1 commit 731f7a7: FOUND
- Task 2 commit 7a9e901: FOUND
- busted spec/core_spec.lua → 27 successes: VERIFIED
- busted spec/ → 65 successes: VERIFIED
