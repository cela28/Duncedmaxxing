---
phase: quick-260622-tyy
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - Duncedmaxxing/Modules/TipOfTheSpear.lua
  - spec/tip_spec.lua
autonomous: true
requirements: []
must_haves:
  truths:
    - "Casting Raptor Swipe (Aspect of the Eagle ranged variant, 1262343) consumes exactly 1 Tip of the Spear stack"
    - "ClassifySpellID(1262343) returns \"consumer\""
    - "The busted regression test for 1262343 passes via the fengari harness"
  artifacts:
    - path: "Duncedmaxxing/Modules/TipOfTheSpear.lua"
      provides: "1262343 entry in CONSUMERS table"
      contains: "[1262343] = true"
    - path: "spec/tip_spec.lua"
      provides: "Regression test asserting 1262343 consumes 1 stack"
      contains: "1262343"
  key_links:
    - from: "spec/tip_spec.lua"
      to: "Duncedmaxxing/Modules/TipOfTheSpear.lua"
      via: "test loads Tip module and exercises ApplySpell consumer path; CONSUMERS table gates ClassifySpellID"
      pattern: "ApplySpell.*consumer.*1262343"
---

<objective>
Add spell ID 1262343 (Raptor Swipe — Aspect of the Eagle ranged variant) to the CONSUMERS table in the TipOfTheSpear module so it classifies as a plain consumer (consume 1 stack), and add a busted regression test mirroring the existing 265189 case.

Purpose: 1262343 is the Swipe-line analog of the 186270 -> 265189 Raptor Strike pair. It was missed in plan 01-04, which only added the Strike-line variant (265189). Without this entry, casting the Aspect-of-the-Eagle Raptor Swipe does not decrement the predicted stack count, producing a stale display.

Output: One CONSUMERS table line + one busted regression test.
</objective>

<execution_context>
@$HOME/.claude/gsd-core/workflows/execute-plan.md
@$HOME/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md

@Duncedmaxxing/Modules/TipOfTheSpear.lua
@spec/tip_spec.lua
</context>

<tasks>

<task type="auto">
  <name>Task 1: Register 1262343 as a consumer</name>
  <files>Duncedmaxxing/Modules/TipOfTheSpear.lua</files>
  <action>
In the CONSUMERS table (currently lines ~20-27), add a new entry immediately after the existing `[1262293] = true, -- Raptor Swipe` line:

`[1262343] = true, -- Raptor Swipe (Aspect of the Eagle ranged variant)`

Match the existing indentation and alignment style of surrounding entries exactly. This is a plain consumer — it is NOT the Takedown special-case (1250646), so no Twin Fangs grant-then-consume logic applies. The existing ClassifySpellID logic (line ~78: `if type(value) == "number" and CONSUMERS[value] then return "consumer" end`) requires no changes; adding the table entry is sufficient for it to classify as a consumer.

Mirror exactly how the sibling 265189 entry was added (it pairs 186270 base + 265189 Aspect variant); this entry pairs 1262293 base + 1262343 Aspect variant.
  </action>
  <verify>
    <automated>grep -q '\[1262343\] = true' Duncedmaxxing/Modules/TipOfTheSpear.lua && echo OK</automated>
  </verify>
  <done>CONSUMERS table contains `[1262343] = true` with an accurate "Aspect of the Eagle ranged variant" comment, placed adjacent to the existing 1262293 Raptor Swipe entry.</done>
</task>

<task type="auto">
  <name>Task 2: Add regression test for 1262343 consumer behavior</name>
  <files>spec/tip_spec.lua</files>
  <action>
In the same `describe` block that contains the existing 265189 test (the block ending at line ~210, just before the `Tip:SyncFromAura` describe block), add a new `it(...)` test directly after the 265189 test (line ~209), mirroring it exactly.

The new test must:
- Set `Tip.stacks = 2`
- Call `Tip:ApplySpell("consumer", 1262343)` (Aspect-of-the-Eagle ranged Raptor Swipe)
- Assert `assert.equals(1, Tip.stacks)` (consumes exactly 1 stack)

Use the same two-line lead comment style as the 265189 test, adapted for Raptor Swipe. Example test name: `"Aspect-of-the-Eagle Raptor Swipe (1262343) decrements 1 stack instantly"`. Do NOT introduce a new test framework or helper — use the existing busted `describe`/`it`/`before_each`/`assert.equals` setup and the already-loaded `Tip` from the surrounding block's `before_each`.
  </action>
  <verify>
    <automated>grep -q '1262343' spec/tip_spec.lua && echo OK</automated>
  </verify>
  <done>spec/tip_spec.lua contains a new `it(...)` test that sets stacks to 2, calls `Tip:ApplySpell("consumer", 1262343)`, and asserts stacks equals 1 — structurally identical to the 265189 test. The busted suite passes via the fengari harness.</done>
</task>

</tasks>

<verification>
- `grep '\[1262343\] = true' Duncedmaxxing/Modules/TipOfTheSpear.lua` returns the new CONSUMERS entry
- `grep '1262343' spec/tip_spec.lua` returns the new regression test
- Run the busted spec via the fengari harness; the new 1262343 test passes alongside the existing 265189 test (no regressions)
</verification>

<success_criteria>
- 1262343 classifies as "consumer" via ClassifySpellID (CONSUMERS table entry present)
- Casting it consumes exactly 1 stack (plain -1, no Twin Fangs logic)
- New busted regression test mirrors the 265189 case and passes
- No changes to ClassifySpellID or ApplySpell logic required
</success_criteria>

<output>
Create `.planning/quick/260622-tyy-add-spell-id-1262343-raptor-swipe-aspect/260622-tyy-SUMMARY.md` when done
</output>
