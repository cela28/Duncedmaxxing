---
phase: 07-address-v1-0-tech-debt-remove-dead-code-tip-spelltexture-dmx
plan: 01
subsystem: testing
tags: [lua, wow-addon, dead-code-removal, test-hardening, fengari]

# Dependency graph
requires:
  - phase: 07 (CONTEXT/RESEARCH)
    provides: D-01 through D-07 decision contract and grep-verified symbol locations
provides:
  - Tip._test escape-hatch export (mirrors DMX._test) exposing ClassifySpellID to specs
  - Hardened CONSUMERS-membership regression tests for 265189, 1262293, 1262343
  - Removal of dead hasPrimalSurge field and its 2 tautological tests
  - Non-contradictory generator-branch comment
  - Removal of dead Tip.spellTexture / CacheSpellTexture / FALLBACK_ICON and both call sites
affects: [07-02, 07-03]

# Tech tracking
tech-stack:
  added: []
  patterns: ["Tip._test test-only escape hatch (mirrors existing DMX._test convention)"]

key-files:
  created: []
  modified:
    - Duncedmaxxing/Modules/TipOfTheSpear.lua
    - spec/tip_spec.lua
    - spec/support/init.lua

key-decisions:
  - "Added Tip._test = { ClassifySpellID = ClassifySpellID } as the sole new symbol this phase, replicating Core.lua's DMX._test pattern exactly (including its two-line comment)"
  - "Added a new minimal it() block for spell ID 1262293 (base Raptor Swipe), which previously had zero spec coverage, for parity with its 265189/1262343 siblings"
  - "Deleted both CacheSpellTexture call sites (Tip:OnEvent PLAYER_LOGIN/PLAYER_ENTERING_WORLD branch and Tip:Initialize) in the same commit as the function definition, per RESEARCH.md Pitfall 1"

patterns-established:
  - "Tip._test escape hatch: any future need to unit-test a private local function in TipOfTheSpear.lua should extend this table rather than creating a second mechanism"

requirements-completed: [D-01, D-02, D-03, D-04, D-06]

# Metrics
duration: 10min
completed: 2026-07-09
status: complete
---

# Phase 07 Plan 01: Dead-code removal and consumer regression hardening in TipOfTheSpear.lua Summary

**Removed hasPrimalSurge and Tip.spellTexture/CacheSpellTexture/FALLBACK_ICON dead code, added a Tip._test escape hatch, and hardened the 265189/1262293/1262343 consumer regression tests to assert CONSUMERS-table membership via ClassifySpellID.**

## Performance

- **Duration:** ~10 min
- **Completed:** 2026-07-09
- **Tasks:** 3/3 completed
- **Files modified:** 3 (Duncedmaxxing/Modules/TipOfTheSpear.lua, spec/tip_spec.lua, spec/support/init.lua)

## Accomplishments
- Added `Tip._test.ClassifySpellID` export and hardened all three consumer regression tests (265189, 1262293 [new], 1262343) to assert `"consumer"` classification, not just decrement arithmetic
- Removed the dead `hasPrimalSurge` field, its reset, and the 2 tautological tests that varied it while always asserting 2; rewrote the self-contradictory generator-branch comment to state the grant is always 2 stacks
- Removed `Tip.spellTexture`, `CacheSpellTexture`, `FALLBACK_ICON`, and both call sites (the `PLAYER_LOGIN`/`PLAYER_ENTERING_WORLD` branch and `Tip:Initialize` — the second call site was flagged by RESEARCH.md as missing from CONTEXT.md's canonical refs)
- Full fengari suite green after every task commit: 129 → 127 → 125 passed, 0 failed throughout

## Task Commits

Each task was committed atomically:

1. **Task 1: Add Tip._test export and harden consumer regression tests (D-06)** - `5f19189` (feat)
2. **Task 2: Remove hasPrimalSurge and rewrite the generator comment (D-01, D-02, D-03)** - `1ec6026` (fix) — see Deviations for a note on this commit's message/scope
3. **Task 3: Remove Tip.spellTexture, CacheSpellTexture, FALLBACK_ICON, and both call sites (D-04)** - `841482b` (fix)

_Note: no TDD tasks in this plan; each task is a single commit._

## Files Created/Modified
- `Duncedmaxxing/Modules/TipOfTheSpear.lua` - Added `Tip._test` export; removed `hasPrimalSurge` field + rewrote generator comment; removed `FALLBACK_ICON`, `Tip.spellTexture`, `CacheSpellTexture`, and both call sites
- `spec/tip_spec.lua` - Hardened 265189/1262343 tests with `ClassifySpellID` assertions; added new 1262293 test; removed 2 tautological Primal Surge tests and the retired-field toggle from the Twin-Fangs-independence test; removed 2 spellTexture tests and renamed the describe block to "Caching -- isSurvival"
- `spec/support/init.lua` - Removed `hasPrimalSurge` and `spellTexture` resets from `resetTipState`

## Decisions Made
- Followed RESEARCH.md's recommended sequencing: D-06 export first (unblocks hardening), then D-01/02/03, then D-04 — each as its own commit with the suite verified green in between
- Added the new 1262293 test with both a classify assertion and a decrement assertion (matching its siblings) rather than a classify-only test, per RESEARCH.md's Open Question 2 recommendation

## Deviations from Plan

### Auto-fixed Issues

None — Rules 1-3 were not triggered; the plan's own grep-verified symbol locations and call-site enumeration (including the second `CacheSpellTexture` call site) were accurate and required no further discovery.

### Environment/Concurrency Note (not a code deviation)

**Task 2 commit (`1ec6026`) message and file scope were altered by a concurrent process on the shared working tree.** This executor ran without worktree isolation (`isolation` was not set to `worktree` for this sequential plan), and another auto-chain process (a background Nyquist-validation backfill for phase 02) was staging and committing to the same repository concurrently. A race between `git add`/`git commit` calls from both processes resulted in commit `1ec6026` carrying the message `docs(phase-02): finalize validation strategy (Nyquist-compliant, 7/7 TEST reqs green)` instead of this task's intended message, and bundling in `.planning/phases/02-test-framework-and-core-logic-tests/02-VALIDATION.md` changes alongside this task's 3 intended files.

Verified via `git show 1ec6026 -- Duncedmaxxing/Modules/TipOfTheSpear.lua`: the diff content is exactly Task 2's intended change (hasPrimalSurge field removal + generator comment rewrite), with no missing or extra lines relative to what was staged for this task. No code was lost or corrupted — only the commit message and the presence of one unrelated file within that commit are affected. Per the destructive-git-operations prohibition, no rebase/amend was attempted to "fix" this after-the-fact, since commit `841482b` (Task 3) already depends on it and rewriting history could destroy the concurrent process's legitimate work. Flagging here for visibility; no action needed unless commit-message hygiene for phase 07 specifically is later audited.

---

**Total deviations:** 0 auto-fixed code changes; 1 environment/concurrency note (commit-message/scope artifact, content verified correct)
**Impact on plan:** None on functional correctness — all D-01/D-02/D-03/D-04/D-06 acceptance criteria are met and the full suite is green.

## Verification Results

- `grep -rn "hasPrimalSurge\|spellTexture\|CacheSpellTexture\|FALLBACK_ICON" Duncedmaxxing/ spec/` → zero matches
- `grep -c "Tip._test" Duncedmaxxing/Modules/TipOfTheSpear.lua` → 1 (assignment appears before `DMX:RegisterModule("tip", Tip)`)
- `grep -c "Tip._test.ClassifySpellID" spec/tip_spec.lua` → 3 (265189, 1262293, 1262343)
- `grep -c "CacheSpellTexture" Duncedmaxxing/Modules/TipOfTheSpear.lua` → 0
- `grep -c "grant = 2" Duncedmaxxing/Modules/TipOfTheSpear.lua` → 1 (logic unchanged)
- `npx -y -p fengari@0.1.5 node spec/run.cjs` → 125 passed, 0 failed, 125 total (final state; was 129 after Task 1, 127 after Task 2, 125 after Task 3 — each drop matches the expected removed-test count)
- `luacheck` was not run: no `luacheck`/`luarocks`/`lua` binary is present in this execution environment (consistent with RESEARCH.md's Environment Availability finding — Pitfall 5). This is an environment gap, not a regression; luacheck should be run in CI or a developer machine where it's installed before this plan is considered fully lint-clean.

## Issues Encountered
- None blocking. See the Environment/Concurrency Note above for a non-blocking git-history observation.

## Next Phase Readiness
- Plan 07-02 and 07-03 (remaining D-05 ParseOnOff removal and D-07 db.locked documentation, per ROADMAP) are unaffected by this plan's changes — no shared symbols or files overlap based on the Symbol Location Table in 07-RESEARCH.md.

---
*Phase: 07-address-v1-0-tech-debt-remove-dead-code-tip-spelltexture-dmx*
*Completed: 2026-07-09*

## Self-Check: PASSED

- FOUND: .planning/phases/07-address-v1-0-tech-debt-remove-dead-code-tip-spelltexture-dmx/07-01-SUMMARY.md
- FOUND: commit 5f19189 (Task 1)
- FOUND: commit 1ec6026 (Task 2)
- FOUND: commit 841482b (Task 3)
