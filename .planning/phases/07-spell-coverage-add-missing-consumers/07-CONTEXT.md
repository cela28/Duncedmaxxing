# Phase 7: Spell Coverage — Add Missing Consumers - Context

**Gathered:** 2026-07-27
**Status:** Ready for planning

<domain>
## Phase Boundary

This phase adds 2 missing Survival Hunter consumer spells to the CONSUMERS lookup table in TipOfTheSpear.lua, writes unit tests verifying ClassifySpellID and ApplySpell for each, and flags live testing in the UAT checklist. The spells are plain "consume 1 stack" abilities with no special mechanics.

**In scope:**
- Add Moonlight Chakram (1264902) and Hatchet Toss (193265) to the CONSUMERS table.
- Unit tests verifying ClassifySpellID returns "consumer" for both new spell IDs.
- Unit tests verifying ApplySpell("consumer", spellID) correctly decrements stacks for each.
- Flag in-game verification of both spells in the UAT checklist (consumption behavior unconfirmed live).
- Researcher to verify whether either spell has alternate spell IDs (e.g., Aspect of the Eagle ranged variants) that also need tracking.

**Out of scope:**
- Flamefang Pitch (1251592) — explicitly dropped by user decision.
- Any generator spell changes.
- Talent-conditional gating of consumer entries.
- Changes to ApplySpell consumption logic.

</domain>

<decisions>
## Implementation Decisions

### Spell scope
- **D-01:** Only 2 spells are added: Moonlight Chakram (1264902) and Hatchet Toss (193265). Flamefang Pitch (1251592) is excluded from this phase.

### Consumer behavior
- **D-02:** Both spells are plain consumers — consume exactly 1 stack, no special talent interactions or modified grant amounts. No changes to ApplySpell logic needed.

### Tracking approach
- **D-03:** Both spell IDs are added unconditionally to the CONSUMERS static lookup table, same pattern as all existing consumers. No runtime talent checks needed — uncast spells never fire UNIT_SPELLCAST_SUCCEEDED events so unused entries are harmless.

### Spell ID variants
- **D-04:** Researcher must verify whether Moonlight Chakram or Hatchet Toss have alternate spell IDs (like Raptor Strike's Eagle variant 265189 or Raptor Swipe's Eagle variant 1262343). If variants exist, add them too.

### Claude's Discretion
- Exact ordering of new entries within the CONSUMERS table (alphabetical by comment, grouped by type, or appended at end).
- Test assertion style and grouping within the spec file.
- UAT checklist format and location.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Source files
- `Duncedmaxxing/Modules/TipOfTheSpear.lua` — CONSUMERS table (lines 20-28), ClassifySpellID (lines 74-82), ApplySpell (line 657+). The only source file modified.

### Tests
- `spec/tip_spec.lua` — Existing consumer test coverage (ApplySpell consumer tests, ClassifySpellID assertions). Extend with new spell ID tests.
- `spec/support/wow_stubs.lua` — WoW API mocks. No changes expected for plain consumer additions.
- `spec/support/init.lua` — Test loader and bootstrap. No changes expected.

### Prior phase context
- `.planning/phases/05-refactor-display-modes-remove-icon-mode-and-add-a-bar-text-m/05-CONTEXT.md` — Test patterns, fengari harness note.

### Project rules
- `CLAUDE.md` — Naming conventions, combat-safety constraints.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `CONSUMERS` table (TipOfTheSpear.lua:20-28): Static `[spellID] = true` lookup. Adding entries is a one-line change per spell.
- `ClassifySpellID` (TipOfTheSpear.lua:74-82): Checks KILL_COMMAND for "generator", then CONSUMERS for "consumer". No changes needed — new entries auto-discovered.
- Existing consumer test patterns in `spec/tip_spec.lua`: `Tip:ApplySpell("consumer", spellID)` assertions for decrement, floor-at-zero, expiry clearing.

### Established Patterns
- All consumer spells are plain `[id] = true` entries with a descriptive comment.
- Tests use `loader.load()` for per-test isolation, `resetTipState` to zero tracking fields.
- Prior quick task (2026-06-22) added Raptor Swipe Eagle variant (1262343) using this exact same pattern.

### Integration Points
- `FindTrackedSpell` (TipOfTheSpear.lua:84-92): Iterates UNIT_SPELLCAST_SUCCEEDED args, calls ClassifySpellID. New consumer IDs are automatically found.
- `ApplySpell` (TipOfTheSpear.lua:657+): Consumer path decrements by 1. No special-case branches needed for the new spells.

</code_context>

<specifics>
## Specific Ideas

- The 2026-06-22 quick task that added Raptor Swipe (Eagle variant) is the exact template for this work — same pattern, same test structure.
- Researcher should check warcraft.wiki.gg and/or wowhead for spell ID variants before implementation.

</specifics>

<deferred>
## Deferred Ideas

- Flamefang Pitch (1251592) — dropped from this phase by user decision. Can be reconsidered in a future phase if needed.

</deferred>

---

*Phase: 07-spell-coverage-add-missing-consumers*
*Context gathered: 2026-07-27*
