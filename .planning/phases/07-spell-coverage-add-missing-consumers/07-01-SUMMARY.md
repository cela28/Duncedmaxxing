---
phase: 07-spell-coverage-add-missing-consumers
plan: 01
subsystem: testing
tags: [wow-addon, lua, spell-table, fengari, unit-test]

# Dependency graph
requires:
  - phase: 02-test-framework-and-core-logic-tests
    provides: fengari/busted-style test harness (spec/run.cjs, spec/support/init.lua, spec/support/wow_stubs.lua)
provides:
  - CONSUMERS table entries for Moonlight Chakram (1264902) and Hatchet Toss (193265)
  - DMX._test.tip escape hatch exposing ClassifySpellID for direct unit testing
  - 4 new unit tests (2 ClassifySpellID, 2 ApplySpell decrement)
  - 2 pending in-game UAT verification entries
affects: [08-spell-coverage-followups (if any), future spell-audit phases]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Test-only DMX._test escape hatch extended per-module (DMX._test.tip), mirroring DMX._test in Core.lua, without clobbering existing fields"

key-files:
  created: []
  modified:
    - Duncedmaxxing/Modules/TipOfTheSpear.lua
    - spec/tip_spec.lua
    - .planning/phases/01-utility-extraction-and-module-encapsulation/01-HUMAN-UAT.md

key-decisions:
  - "Per 07-CONTEXT.md D-01: only 2 spells in scope (Moonlight Chakram, Hatchet Toss); Flamefang Pitch (1251592) explicitly excluded"
  - "Per D-04: no confirmed alternate spell IDs added; ambiguous variant 1264949 for Moonlight Chakram deferred to UAT verification rather than added speculatively"
  - "ClassifySpellID tested via new DMX._test.tip escape hatch (not via ApplySpell hard-coded kind), per RESEARCH.md Pitfall 1 — ApplySpell tests alone do not exercise classification"

patterns-established:
  - "One-line CONSUMERS table addition: [spellID] = true, -- Comment naming the spell — established pattern, now used a 3rd/4th time"

requirements-completed: [SC-1, SC-2, SC-3, SC-4, SC-5]

coverage:
  - id: D1
    description: "CONSUMERS table contains [1264902] = true (Moonlight Chakram) and [193265] = true (Hatchet Toss)"
    requirement: "SC-1"
    verification:
      - kind: unit
        ref: "spec/tip_spec.lua#ClassifySpellID returns \"consumer\" for Moonlight Chakram (1264902)"
        status: pass
      - kind: unit
        ref: "spec/tip_spec.lua#ClassifySpellID returns \"consumer\" for Hatchet Toss (193265)"
        status: pass
    human_judgment: false
  - id: D2
    description: "ClassifySpellID returns \"consumer\" for both new spell IDs via DMX._test.tip escape hatch"
    requirement: "SC-2"
    verification:
      - kind: unit
        ref: "spec/tip_spec.lua#describe(\"ClassifySpellID\") block"
        status: pass
    human_judgment: false
  - id: D3
    description: "ApplySpell(\"consumer\", spellID) decrements stacks by 1 for both new spell IDs"
    requirement: "SC-3"
    verification:
      - kind: unit
        ref: "spec/tip_spec.lua#Moonlight Chakram (1264902) decrements 1 stack instantly"
        status: pass
      - kind: unit
        ref: "spec/tip_spec.lua#Hatchet Toss (193265) decrements 1 stack instantly"
        status: pass
    human_judgment: false
  - id: D4
    description: "In-game verification of both spells (including 1264949 variant check for Moonlight Chakram) flagged in UAT checklist"
    requirement: "SC-4"
    verification: []
    human_judgment: true
    rationale: "Live spell-cast behavior and combat-log spell ID confirmation cannot be verified offline; requires WoW client access, tracked as pending UAT tests 9 and 10 in 01-HUMAN-UAT.md"
  - id: D5
    description: "Full test suite passes at 125/125 via fengari harness (121 baseline + 4 new)"
    requirement: "SC-5"
    verification:
      - kind: unit
        ref: "npx -y -p fengari@0.1.5 node spec/run.cjs"
        status: pass
    human_judgment: false

duration: 3min
completed: 2026-07-27
status: complete
---

# Phase 07 Plan 01: Spell Coverage — Add Missing Consumers Summary

**Registered Moonlight Chakram (1264902) and Hatchet Toss (193265) as Tip of the Spear consumers via a one-line CONSUMERS table addition, with a new DMX._test.tip escape hatch proving ClassifySpellID classification directly (not just decrement behavior).**

## Performance

- **Duration:** 3 min
- **Started:** 2026-07-27T09:37:17Z
- **Completed:** 2026-07-27T09:39:40Z
- **Tasks:** 3 completed
- **Files modified:** 3

## Accomplishments
- Added `[1264902] = true` (Moonlight Chakram) and `[193265] = true` (Hatchet Toss) to the `CONSUMERS` static lookup table in `Duncedmaxxing/Modules/TipOfTheSpear.lua`
- Added a `DMX._test.tip` escape hatch (extending, not clobbering, the existing `DMX._test` table from `Core.lua`) exposing `ClassifySpellID` for direct unit assertions
- Added 4 new tests to `spec/tip_spec.lua`: 2 `ClassifySpellID` classification tests via the new escape hatch, and 2 `ApplySpell` decrement tests — full suite green at 125/125 (baseline 121 + 4 new)
- Appended 2 pending in-game UAT verification entries (tests 9 and 10) to the consolidated `01-HUMAN-UAT.md`, including an explicit instruction to watch the combat log for the ambiguous `1264949` variant when verifying Moonlight Chakram live

## Task Commits

Each task was committed atomically:

1. **Task 1: Add Moonlight Chakram and Hatchet Toss to CONSUMERS table + ClassifySpellID escape hatch** - `58f3979` (feat)
2. **Task 2: Add ClassifySpellID and ApplySpell unit tests for both new consumer spells** - `35f22f9` (test)
3. **Task 3: Append in-game verification entries to UAT checklist** - `7c3e35a` (docs)

**Plan metadata:** (pending — final commit below)

## Files Created/Modified
- `Duncedmaxxing/Modules/TipOfTheSpear.lua` - Added 2 CONSUMERS entries and DMX._test.tip escape hatch
- `spec/tip_spec.lua` - Added 4 new tests (2 ApplySpell decrement, 2 ClassifySpellID classification via new describe block)
- `.planning/phases/01-utility-extraction-and-module-encapsulation/01-HUMAN-UAT.md` - Extended scope to phases 01-07, appended tests 9 and 10 (pending), updated summary counts (total 10, pending 2)

## Decisions Made
- Followed D-01/D-02/D-03/D-04 from `07-CONTEXT.md` exactly: 2-spell scope, plain unconditional consumer entries, no speculative addition of the ambiguous 1264949 ID (deferred to UAT instead)
- Used the escape-hatch pattern (option 1 from RESEARCH.md Pitfall 1) over the full event-path test (option 2) to satisfy SC-2 literally, matching the plan's explicit instruction

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Both new consumer spells are fully wired into the classify → apply → render chain with no code changes needed beyond the table entry
- Two UAT items (tests 9 and 10) remain pending live WoW client access; per project memory (`ingame-testing-pending`), these join the existing backlog of in-game smoke tests awaiting game access
- ROADMAP.md's original Phase 7 success-criteria text still mentions Flamefang Pitch (1251592) as in-scope — this is stale per `07-CONTEXT.md` D-01 override and was left unedited per RESEARCH.md Pitfall 2 (Claude's discretion, not required for this plan's success criteria)

---
*Phase: 07-spell-coverage-add-missing-consumers*
*Completed: 2026-07-27*

## Self-Check: PASSED

All modified files verified present on disk. All 4 task/summary commit hashes (58f3979, 35f22f9, 7c3e35a, d3cd14e) verified present in git log.
