---
phase: 07-spell-coverage-add-missing-consumers
verified: 2026-07-27T09:44:42Z
status: human_needed
score: 5/5 must-haves verified
behavior_unverified: 0
overrides_applied: 0
human_verification:
  - test: "Cast Moonlight Chakram (1264902) at 2+ Tip of the Spear stacks in-game (Sentinel hero talent active, procced via Takedown)"
    expected: "Stack tracker decrements by 1 instantly. Combat log / /etrace confirms the fired spell ID is 1264902, not the ambiguous variant 1264949."
    why_human: "Live UNIT_SPELLCAST_SUCCEEDED behavior and actual spell ID fired by the game client cannot be verified offline — requires a running WoW client and Sentinel hero talent setup."
  - test: "Cast Hatchet Toss (193265) at 2+ Tip of the Spear stacks in-game"
    expected: "Stack tracker decrements by 1 instantly."
    why_human: "Live UNIT_SPELLCAST_SUCCEEDED behavior cannot be verified offline — requires a running WoW client."
---

# Phase 07: Spell Coverage — Add Missing Consumers Verification Report

**Phase Goal:** All Survival Hunter abilities that consume Tip of the Spear stacks are tracked by the addon, closing gaps found in the spell audit.
**Verified:** 2026-07-27T09:44:42Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `CONSUMERS` table includes Moonlight Chakram (1264902) and Hatchet Toss (193265) — SC-1 | ✓ VERIFIED | `Duncedmaxxing/Modules/TipOfTheSpear.lua:28-29` contains `[1264902] = true, -- Moonlight Chakram` and `[193265]  = true, -- Hatchet Toss` |
| 2 | `ClassifySpellID` returns `"consumer"` for both new spell IDs — SC-2 | ✓ VERIFIED | `DMX._test.tip.ClassifySpellID` escape hatch present at `TipOfTheSpear.lua:678-681` (before `DMX:RegisterModule("tip", Tip)`); `spec/tip_spec.lua:240-257` `describe("ClassifySpellID", ...)` block asserts `ClassifySpellID(1264902)` and `ClassifySpellID(193265)` both equal `"consumer"`; test suite run confirms pass |
| 3 | `ApplySpell("consumer", spellID)` decrements stacks by 1 for each new consumer — SC-3 | ✓ VERIFIED | `spec/tip_spec.lua:222-234` — two `it(...)` blocks set `Tip.stacks = 2`, call `Tip:ApplySpell("consumer", 1264902\|193265)`, assert `Tip.stacks == 1`; `Tip:ApplySpell` at `TipOfTheSpear.lua:659` decrements via the plain consumer branch for both IDs (neither is `TAKEDOWN`, so the Twin Fangs special case does not apply) |
| 4 | In-game verification of both spells is flagged in the UAT checklist — SC-4 | ✓ VERIFIED (present in checklist) / requires human execution | `01-HUMAN-UAT.md` tests #9 and #10 present with `result: pending`, including explicit note to check combat log for ambiguous variant 1264949 per D-04; scope updated to "phases 01-07"; Summary updated to `total: 10`, `pending: 2` |
| 5 | Full test suite passes via the fengari harness — SC-5 | ✓ VERIFIED | `npx -y -p fengari@0.1.5 node spec/run.cjs` run directly by verifier: `125 passed, 0 failed, 125 total` |

**Score:** 5/5 truths verified (0 present, behavior-unverified)

Note: Truth #4 is verified as an artifact ("flagged in the UAT checklist" — the documentation obligation the phase goal imposes), but the underlying in-game consumption behavior it flags is inherently unverifiable by a static-code verifier and remains `pending` per the checklist itself. This routes to human verification per Step 8 and is why overall status is `human_needed` rather than `passed`, consistent with the project's existing `ingame-testing-pending` backlog memory.

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `Duncedmaxxing/Modules/TipOfTheSpear.lua` CONSUMERS entries | `[1264902] = true` and `[193265] = true` with naming comments | ✓ VERIFIED | Lines 28-29, exact format matches existing entries (aligned `=`, comma, comment) |
| `DMX._test.tip` escape hatch | Exposes `ClassifySpellID` without clobbering `DMX._test` from Core.lua | ✓ VERIFIED | Lines 676-681: `DMX._test = DMX._test or {}` guard present, `DMX._test.tip = { ClassifySpellID = ClassifySpellID }`, placed before `DMX:RegisterModule("tip", Tip)` |
| `spec/tip_spec.lua` `describe("ClassifySpellID", ...)` block | Assertions for both new IDs | ✓ VERIFIED | Lines 240-257, 2 `it()` blocks, both pass |
| `spec/tip_spec.lua` ApplySpell decrement tests | `it(...)` blocks for both IDs | ✓ VERIFIED | Lines 222-234, mirrors existing 1262343/265189 pattern, both pass |
| `01-HUMAN-UAT.md` in-game verification entries | Entries for Moonlight Chakram and Hatchet Toss | ✓ VERIFIED | Tests #9 and #10 present, `pending`, variant note for 1264949 included |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| `CONSUMERS` table | `ClassifySpellID` | direct table lookup (`CONSUMERS[value]`) | ✓ WIRED | `TipOfTheSpear.lua:76-84` — `ClassifySpellID` returns `"consumer"` when `CONSUMERS[value]` is truthy |
| `ClassifySpellID` | `FindTrackedSpell` | called per-arg loop | ✓ WIRED | `TipOfTheSpear.lua:86-93` |
| `FindTrackedSpell` | `Tip:ApplySpell` | `UNIT_SPELLCAST_SUCCEEDED` event handler dispatch | ✓ WIRED | `TipOfTheSpear.lua:726-734` — `local kind, spellID = FindTrackedSpell(...)`; `if kind then self:ApplySpell(kind, spellID) end` |
| `DMX._test.tip` escape hatch | `spec/tip_spec.lua` assertions | direct function reference | ✓ WIRED | `spec/tip_spec.lua:251,255` call `DMX._test.tip.ClassifySpellID(...)` directly |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Full suite passes with new tests included | `npx -y -p fengari@0.1.5 node spec/run.cjs` | `125 passed, 0 failed, 125 total` | ✓ PASS |
| ClassifySpellID escape hatch exists in source | `grep -n "DMX._test.tip" Duncedmaxxing/Modules/TipOfTheSpear.lua` | 2 matches (declaration + field assignment) | ✓ PASS |
| Both CONSUMERS entries present | `grep -n "1264902.*true\|193265.*true" Duncedmaxxing/Modules/TipOfTheSpear.lua` | 2 matches, both with naming comments | ✓ PASS |
| Task commits exist in git log | `git log --all --oneline \| grep -E "58f3979\|35f22f9\|7c3e35a\|d3cd14e"` | All 4 hashes found | ✓ PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|--------------|--------|----------|
| SC-1 | 07-01-PLAN.md | CONSUMERS table includes Moonlight Chakram (1264902) and Hatchet Toss (193265) | ✓ SATISFIED | See Observable Truth #1 |
| SC-2 | 07-01-PLAN.md | Unit tests verify ClassifySpellID returns "consumer" for both new spell IDs | ✓ SATISFIED | See Observable Truth #2 |
| SC-3 | 07-01-PLAN.md | Unit tests verify ApplySpell decrements stacks for both new consumers | ✓ SATISFIED | See Observable Truth #3 |
| SC-4 | 07-01-PLAN.md | In-game verification flagged in UAT checklist | ✓ SATISFIED (documentation obligation met; underlying behavior is human_needed) | See Observable Truth #4 |
| SC-5 | 07-01-PLAN.md | Test suite passes via fengari harness | ✓ SATISFIED | See Observable Truth #5 |

**⚠️ Documentation gap (not a phase-goal blocker):** SC-1 through SC-5 are defined locally in `ROADMAP.md` Phase 7's "Success Criteria" section and mirrored in the PLAN frontmatter `requirements:` field, but **no SC-1..SC-5 entries exist in `.planning/REQUIREMENTS.md`** — neither in the v1 Requirements sections (Bug Fixes/Code Quality/Performance/Testing/Cleanup/CI-CD/Display Modes) nor in the Traceability table (which stops at Phase 5 / DISP-04). Every other phase in this project (0–6) uses REQUIREMENTS.md-native IDs (BUG-*, QUAL-*, TEST-*, PERF-*, CICD-*, DISP-*, CLN-*); Phase 7 is the only phase using a locally-scoped `SC-N` convention that was never back-filled into REQUIREMENTS.md. This is a process/traceability inconsistency, not a functional gap — the roadmap Success Criteria are the authoritative source for this phase and all 5 are independently verified above. Recommend adding a "Spell Coverage" section to REQUIREMENTS.md (or an explicit Phase 7 row in the Traceability table) to keep the requirements ledger complete, but this does not block phase closure.

### Anti-Patterns Found

None. Scanned `Duncedmaxxing/Modules/TipOfTheSpear.lua`, `spec/tip_spec.lua`, and `.planning/phases/01-utility-extraction-and-module-encapsulation/01-HUMAN-UAT.md` for `TBD`/`FIXME`/`XXX`/`TODO`/`HACK`/`PLACEHOLDER`/stub-language patterns — no matches.

### Human Verification Required

### 1. Moonlight Chakram (1264902) in-game consumption + variant check

**Test:** With Sentinel hero talent active, build 2+ Tip of the Spear stacks via Kill Command, cast Takedown (procs Moonlight Chakram replacement for 15s), then cast Moonlight Chakram on target.
**Expected:** Tracker decrements by 1 instantly. Combat log / `/etrace` confirms the fired spell ID is 1264902 (not the ambiguous variant 1264949 flagged in D-04).
**Why human:** Requires a live WoW client, the Sentinel hero talent, and combat-log inspection — cannot be exercised by static analysis or the offline fengari test harness.

### 2. Hatchet Toss (193265) in-game consumption

**Test:** At 2+ stacks, cast Hatchet Toss (40yd ranged, 30 Focus).
**Expected:** Tracker decrements by 1 instantly.
**Why human:** Requires a live WoW client to observe `UNIT_SPELLCAST_SUCCEEDED` firing and the tracker responding in real time.

### Gaps Summary

No gaps. All 5 roadmap Success Criteria (SC-1 through SC-5) are verified against the actual codebase: both new spell IDs are present in the `CONSUMERS` table with correct comments, the classify→dispatch→decrement wiring is intact and covered end-to-end by the `UNIT_SPELLCAST_SUCCEEDED` handler, the `DMX._test.tip` escape hatch genuinely exercises `ClassifySpellID` (not just `ApplySpell` with a hard-coded kind, avoiding the Pitfall 1 trap called out in 07-RESEARCH.md), 4 new unit tests were added and the full suite is green at 125/125 (verified independently by the verifier, not taken from SUMMARY.md claims), and the UAT checklist documentation obligation (SC-4) is met with both pending entries plus the 1264949 variant note.

The only outstanding item is the live in-game behavior itself — inherently outside static verification, correctly deferred to human UAT tests #9 and #10, and consistent with the project's existing `ingame-testing-pending` memory note (8 smoke tests + stack color check already awaiting game access). This phase adds 2 more items to that same backlog rather than introducing a new kind of gap.

A minor documentation-traceability inconsistency (SC-1..SC-5 never added to REQUIREMENTS.md) is noted above as a non-blocking recommendation.

---
*Verified: 2026-07-27T09:44:42Z*
*Verifier: Claude (gsd-verifier)*
