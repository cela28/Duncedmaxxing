---
phase: 01-utility-extraction-and-module-encapsulation
reviewed: 2026-06-22T00:00:00Z
depth: standard
files_reviewed: 3
files_reviewed_list:
  - Duncedmaxxing/Modules/TipOfTheSpear.lua
  - spec/tip_spec.lua
  - spec/support/init.lua
findings:
  critical: 0
  warning: 3
  info: 3
  total: 6
status: issues_found
---

# Phase 01: Code Review Report (gap-closure 01-03 / 01-04)

**Reviewed:** 2026-06-22T00:00:00Z
**Depth:** standard
**Files Reviewed:** 3
**Status:** issues_found

> Note: this report covers the gap-closure changes from plans 01-03 and 01-04
> (diff range `f406a9d^..HEAD`). It supersedes the earlier full-phase review
> that previously occupied this path. The CR-01..CR-03 / WR-01..WR-05 findings
> from that earlier pass concerned `Core.lua`, `Options.lua`, and `Util.lua`,
> which are out of scope for this gap-closure review.

## Summary

Reviewed the gap-closure changes from plans 01-03 (Kill Command stack-overshoot
fix: generator grant decoupled from Twin Fangs, new `hasPrimalSurge` field) and
01-04 (Aspect-of-the-Eagle Raptor Strike `265189` registered as a consumer).

The core behavioral fix is correct: the generator grant in `ApplySpell` no
longer reads `self.hasTwinFangs` (line 700, now `local grant = 2`), so Kill
Command can no longer overshoot to 3 stacks from 0 — the 01-03 regression is
genuinely closed. The 265189 consumer registration is also functionally correct:
`ClassifySpellID(265189)` now returns `"consumer"` and the plain decrement
branch runs.

However, the change introduces a **dead state field** (`hasPrimalSurge`) that is
initialized, reset, and asserted on, but never read by any runtime code path.
This makes three "Primal Surge" tests **tautological** — they vary the field but
assert the same constant (2), so they verify nothing about the named behavior
and give false confidence. A self-contradictory comment block compounds the
problem by documenting a "base 1, +1" model the code does not implement. The
01-04 test exercises `ApplySpell` directly and bypasses the `ClassifySpellID`
dispatch path that the fix actually changed, so it does not guard the regression.

No security issues (WoW Lua sandbox, no I/O, no injection surface). No
correctness-breaking bugs in the shipped runtime path.

## Narrative Findings (AI reviewer)

## Warnings

### WR-01: `hasPrimalSurge` is dead state — declared, reset, and tested but never read

**File:** `Duncedmaxxing/Modules/TipOfTheSpear.lua:57` and `:700`
**Issue:** The 01-03 change adds `Tip.hasPrimalSurge = false` (line 57) and
`spec/support/init.lua:62` resets it, but `ApplySpell` hardcodes
`local grant = 2` (line 700) and never references `self.hasPrimalSurge`. No
event handler sets it to `true` either — unlike `hasTwinFangs`, which is updated
on `PLAYER_SPECIALIZATION_CHANGED` / `PLAYER_TALENT_UPDATE` (lines 746, 753). The
field is unreachable in the current build. Per CLAUDE.md, dead code and unused
state are quality defects; this one is worse than usual because it directly
undermines the test suite (see WR-02). A maintainer reading the field and its
tests will reasonably believe the grant varies with Primal Surge — it does not.

**Fix:** Prefer removing the field (and its resets/assertions) until the Primal
Surge spell ID is resolved. If kept as a deliberate placeholder, make its
inertness explicit:
```lua
-- hasPrimalSurge: RESERVED, not yet wired. No event sets it and ApplySpell
-- does not read it. Remove or wire before relying on it.
Tip.hasPrimalSurge = false
```

### WR-02: Primal Surge tests are tautological — they assert a constant, not behavior

**File:** `spec/tip_spec.lua:130-151`
**Issue:** Three tests set `Tip.hasPrimalSurge` (and/or `hasTwinFangs`) to
differing values and all assert `Tip.stacks == 2`:
- `:139` sets `hasPrimalSurge = true` → expects 2
- `:146` sets `hasPrimalSurge = false` → expects 2
- `:130` sets `hasTwinFangs = true, hasPrimalSurge = false` → expects 2

Because `ApplySpell` ignores `hasPrimalSurge` entirely (WR-01), each passes for
the trivial reason that the grant is a hardcoded `2`. Setting `hasPrimalSurge`
has zero effect on the assertion; these tests would still pass if the field were
deleted, and would not catch a future regression where someone wires
`hasPrimalSurge` incorrectly. The test names ("yields 2 stacks from 0 with Primal
Surge") assert a contract the code does not implement. The one genuinely valuable
assertion is the Twin-Fangs-independence check at `:134`
(`assert.not_equals(3, Tip.stacks)`) — that guards the real 01-03 regression; the
Primal-Surge-specific tests do not.

**Fix:** Collapse the redundant Primal Surge tests, or defer them until the field
is wired. If flat-2 is the permanent contract, name the test for what it
verifies:
```lua
it("generator always grants flat 2 (Primal Surge not yet wired)", function()
    Tip:ApplySpell("generator")
    assert.equals(2, Tip.stacks)
end)
```
Do not keep multiple tests that vary an input with no observable output.

### WR-03: 01-04 regression test bypasses the dispatch path it claims to protect

**File:** `spec/tip_spec.lua:198-202`
**Issue:** The 01-04 fix is the addition of `[265189] = true` to the `CONSUMERS`
table (TipOfTheSpear.lua:25). That table controls `ClassifySpellID(265189)`
returning `"consumer"` (line 72) and `FindTrackedSpell` dispatching through
`OnEvent`/`UNIT_SPELLCAST_SUCCEEDED`. The new test instead calls
`Tip:ApplySpell("consumer", 265189)` with the kind passed in explicitly,
short-circuiting `ClassifySpellID`. As the test's own comment admits, it
"exercises the same plain -1 branch as 186270" — it would pass identically even
if `265189` were never added to `CONSUMERS`. Removing the fix does not make the
test fail, so it is not a regression guard for 01-04.

**Fix:** Assert against the classifier via the event path so the test binds to
the actual change:
```lua
it("classifies 265189 (Aspect-of-the-Eagle Raptor Strike) as a consumer", function()
    Tip.isSurvival = true
    Tip.stacks = 2
    Tip:OnEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-guid", 265189)
    assert.equals(1, Tip.stacks)   -- fails if 265189 missing from CONSUMERS
end)
```
This routes through `FindTrackedSpell` → `ClassifySpellID` → `ApplySpell`, so
reverting the table entry makes the test fail as intended.

## Info

### IN-01: Self-contradictory comment in the generator branch

**File:** `Duncedmaxxing/Modules/TipOfTheSpear.lua:697-700`
**Issue:** Line 697 states the grant "derives from Primal Surge (base 1, +1 with
Primal Surge)" — implying base grant is 1, and 2 only when Primal Surge is known.
Line 698 then states "grant is 2 in all cases," and line 700 hardcodes
`grant = 2`. The "base 1" claim contradicts the implemented flat-2 behavior. A
maintainer who later wires `hasPrimalSurge` per line 697 would change the
no-Primal-Surge grant to 1, silently breaking the flat-2 contract the tests pin.

**Fix:** Reconcile the comment to a single intent. If flat-2 is the accepted
fallback, drop the "base 1, +1" sentence; if the eventual model is base-1/+1,
say so explicitly and note the current code is a deliberate over-grant fallback
pending ID resolution.

### IN-02: Takedown+Twin Fangs decrement is not re-clamped

**File:** `Duncedmaxxing/Modules/TipOfTheSpear.lua:706-708`
**Issue:** `self.stacks = self.stacks - 1` (line 708) operates on the result of
`ClampStacks(self.stacks + 3)` without re-clamping. Today this is safe — the
prior line guarantees `self.stacks >= 3` for inputs `>= 0`, so the result is
`>= 2` and never out of range. But the raw `- 1` is latent fragility: if
`MAX_STACKS` or the grant constant changes, or if `self.stacks` ever enters
negative, this can produce an out-of-range value that bypasses `ClampStacks`. The
sibling branch (line 710) correctly clamps its decrement. This branch predates
the gap-closure work but sits in the modified function.

**Fix:** Route the decrement through the clamp for consistency:
```lua
self.stacks = ClampStacks(ClampStacks(self.stacks + 3) - 1)
```

### IN-03: 265189 + 186270 both consumers — verify no double-decrement in-game

**File:** `Duncedmaxxing/Modules/TipOfTheSpear.lua:24-25`
**Issue:** Both `186270` (Raptor Strike) and `265189` (Aspect-of-the-Eagle ranged
Raptor Strike) are now consumers. `FindTrackedSpell` (line 77) returns on the
first tracked ID found in the vararg list, so a single
`UNIT_SPELLCAST_SUCCEEDED` produces at most one decrement — good. The residual
risk is only if the client emits both IDs across two separate
`UNIT_SPELLCAST_SUCCEEDED` events for one logical Raptor Strike press (melee +
ranged variant), which would decrement twice. This cannot be verified offline
(no game client), so it is flagged for in-game UAT, not as a code defect.

**Fix:** Confirm via in-game UAT that pressing Raptor Strike under Aspect of the
Eagle drops exactly one stack. If a double-decrement is observed, dedupe within a
short window in `OnEvent`.

---

_Reviewed: 2026-06-22T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
