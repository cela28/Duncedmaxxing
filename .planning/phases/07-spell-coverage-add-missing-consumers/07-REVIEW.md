---
phase: 07
status: findings
depth: standard
files_reviewed: 2
findings_count: 2
date: 2026-07-27
---

# Phase 07: Code Review Report

**Reviewed:** 2026-07-27
**Depth:** standard
**Files Reviewed:** 2
**Status:** findings

## Summary

Reviewed the phase-07 diff in isolation (commits `58f3979`, `35f22f9`): two new `CONSUMERS` table
entries (`[1264902] = true` Moonlight Chakram, `[193265] = true` Hatchet Toss), the
`DMX._test.tip` escape hatch exposing `ClassifySpellID`, and 4 new tests in `spec/tip_spec.lua`.

The change is small, additive, and low-risk. Verified directly:
- No duplicate keys introduced in `CONSUMERS` (checked against all 9 existing entries).
- Neither new spell ID collides with `TAKEDOWN` (1250646), `TWIN_FANGS` (1272139), or
  `KILL_COMMAND` (259489), so both correctly fall through to the plain decrement branch in
  `Tip:ApplySpell`, as the tests assert.
- The `DMX._test.tip = DMX._test.tip or {}` guard is unnecessary in practice (TOC load order
  guarantees `Core.lua`'s `DMX._test = {...}` runs before `TipOfTheSpear.lua`), but it's a
  harmless defensive pattern that matches the existing `DMX._test` convention in `Core.lua:215`.
- Ran the full suite (`npx -y -p fengari@0.1.5 node spec/run.cjs`): 125/125 passing, matching the
  summary's claim.

No Critical/Blocker issues found. Two lower-severity items below are worth addressing.

## Warnings

### WR-01: New consumer IDs are never exercised through the actual production call chain

**File:** `spec/tip_spec.lua:220-234` (new `ApplySpell` decrement tests) and `spec/tip_spec.lua:250-256` (new `ClassifySpellID` tests)
**Issue:** The 4 new tests prove two things independently — (1) `ClassifySpellID(1264902|193265)`
returns `"consumer"`, and (2) `Tip:ApplySpell("consumer", 1264902|193265)` decrements stacks by 1.
Neither test (nor any pre-existing test in the file — confirmed via `grep -n
"UNIT_SPELLCAST_SUCCEEDED\|FindTrackedSpell" spec/tip_spec.lua`, zero hits) drives the real
production path: `Tip:OnEvent("UNIT_SPELLCAST_SUCCEEDED", ...) → FindTrackedSpell(...) →
ClassifySpellID(id) → Tip:ApplySpell(kind, spellID)`. A regression that breaks the argument
forwarding between `FindTrackedSpell` and `ApplySpell` (e.g., passing the wrong vararg index, or
swapping `kind`/`spellID`) would not be caught by any test currently in the suite for these two
IDs, or for any of the other 7 pre-existing consumer entries. This is precisely the class of gap
`07-RESEARCH.md`'s "Pitfall 1" warns about; the escape-hatch tests close half the gap
(classification is proven) but not the composition of classification with dispatch.
**Fix:** Add at least one integration-style test that fires the real event path, e.g.:
```lua
it("UNIT_SPELLCAST_SUCCEEDED with Moonlight Chakram spellID decrements stacks via full dispatch", function()
    Tip.isSurvival = true
    Tip.stacks = 2
    Tip:OnEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-guid", 1264902)
    assert.equals(1, Tip.stacks)
end)
```
This would also retroactively cover the other 7 existing `CONSUMERS` entries if generalized into a
table-driven test.

## Info

### IN-01: Unused `Tip` and `clock` locals in the new `ClassifySpellID` describe block

**File:** `spec/tip_spec.lua:241-246`
**Issue:** The new `describe("ClassifySpellID", ...)` block's `before_each` assigns
`DMX, Tip, clock = loader.load()` and calls `loader.resetTipState(Tip, clock)`, but neither test
body in the block (`spec/tip_spec.lua:250-256`) references `Tip` or `clock` — only
`DMX._test.tip.ClassifySpellID` is used. This mirrors the boilerplate used elsewhere in the file
for consistency, so it's a minor nit rather than a functional problem, but it is dead setup work
for this specific block.
**Fix:** Either drop the unused locals/`resetTipState` call for this block (classification is
pure and stateless — it needs neither `Tip` state nor the mock clock), or add a brief comment
noting the boilerplate is kept only for stylistic consistency with sibling `describe` blocks.

---

_Reviewed: 2026-07-27_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
