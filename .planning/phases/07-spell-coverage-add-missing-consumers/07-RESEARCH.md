# Phase 7: Spell Coverage — Add Missing Consumers - Research

**Researched:** 2026-07-27
**Domain:** WoW addon spell-table maintenance + fengari/Lua unit testing
**Confidence:** HIGH (code paths, test harness) / MEDIUM-LOW (live spell-ID variant claims, unverifiable offline)

## Summary

This phase is a small, mechanical addition to an already-established pattern: two Survival Hunter
Tip-of-the-Spear consumer spells — Moonlight Chakram (1264902) and Hatchet Toss (193265) — need
entries in the `CONSUMERS` static lookup table in `Duncedmaxxing/Modules/TipOfTheSpear.lua`, plus
tests proving both `ClassifySpellID` and `ApplySpell("consumer", spellID)` handle them correctly.
Flamefang Pitch (1251592) is explicitly out of scope per `07-CONTEXT.md` D-01/D-04 override —
**do not add it**, even though `ROADMAP.md`'s Phase 7 success criteria still list all three; the
CONTEXT.md decision supersedes the stale roadmap text.

The existing codebase already solved this exact problem twice (Raptor Strike's ranged variant
265189, added in Phase 01-04; Raptor Swipe's ranged variant 1262343, added in quick task
`260622-tyy`). Both additions were a one-line `[id] = true` entry with zero logic changes — the
`ClassifySpellID` → `FindTrackedSpell` → `ApplySpell` chain auto-discovers any ID present in
`CONSUMERS`. The same template applies here.

**Important gap found during research:** the existing tests for 265189 and 1262343 call
`Tip:ApplySpell("consumer", spellID)` directly with the `kind` hard-coded — this exercises the
`ApplySpell` decrement branch but does **not** actually invoke `ClassifySpellID` (it's a private
`local function`, never called by that test path). Phase 7's Success Criterion #2 explicitly names
`ClassifySpellID`, which is stricter than the precedent. The planner must add either a test-only
escape hatch (mirroring the existing `DMX._test` pattern in `Core.lua:215`) or drive tests through
the real `UNIT_SPELLCAST_SUCCEEDED` → `FindTrackedSpell` → `ClassifySpellID` path to genuinely
satisfy that criterion. See **Common Pitfalls → Pitfall 1** and **Code Examples** below.

**Primary recommendation:** Add `[1264902] = true` and `[193265] = true` to `CONSUMERS`
(TipOfTheSpear.lua:20-28), expose `ClassifySpellID` via a test-only escape hatch so it can be
asserted directly, write decrement tests mirroring the 265189/1262343 pattern, and append two
in-game-verification rows to the milestone's running UAT checklist
(`.planning/phases/01-utility-extraction-and-module-encapsulation/01-HUMAN-UAT.md`) — do not create
a fresh, orphaned UAT file since that consolidated file is what the project's own tooling/memory
already points users to.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Spell ID → consumer/generator classification | Addon logic (client Lua) | — | Pure table lookup in `ClassifySpellID`; no server or UI involvement |
| Stack decrement on cast | Addon logic (client Lua) | — | `ApplySpell` mutates `Tip.stacks`, a module-table field; predictive, runs before server aura confirms |
| Event dispatch | WoW client event system | Addon logic | `UNIT_SPELLCAST_SUCCEEDED` fired by the game engine; addon only classifies args it receives |
| Test verification | Node + fengari (Lua-VM-in-JS) harness | — | No in-game runtime available in this environment; `spec/tip_spec.lua` is the only verifiable tier here |
| Live consumption confirmation | WoW game client (manual) | — | Cannot be automated — flagged in UAT checklist per Success Criterion #4 |

This phase touches exactly one tier (addon Lua logic) plus its test harness. There is no UI,
network, or persistence surface in scope — consistent with the "no changes to ApplySpell
consumption logic" constraint in `07-CONTEXT.md` D-02/D-03.

## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01 (Spell scope):** Only 2 spells are added: Moonlight Chakram (1264902) and Hatchet Toss
  (193265). Flamefang Pitch (1251592) is excluded from this phase.
- **D-02 (Consumer behavior):** Both spells are plain consumers — consume exactly 1 stack, no
  special talent interactions or modified grant amounts. No changes to `ApplySpell` logic needed.
- **D-03 (Tracking approach):** Both spell IDs are added unconditionally to the `CONSUMERS` static
  lookup table, same pattern as all existing consumers. No runtime talent checks needed — uncast
  spells never fire `UNIT_SPELLCAST_SUCCEEDED` events so unused entries are harmless.
- **D-04 (Spell ID variants):** Researcher must verify whether Moonlight Chakram or Hatchet Toss
  have alternate spell IDs (like Raptor Strike's Eagle variant 265189 or Raptor Swipe's Eagle
  variant 1262343). If variants exist, add them too. **Research finding: see "D-04 Findings"
  below — no confirmed variant IDs to add for either spell; one ambiguous Wowhead/WoWDB listing
  (1264949) for Moonlight Chakram was investigated and is assessed as unlikely to be a
  cast-tracked ID, but this cannot be verified offline.**

### Claude's Discretion

- Exact ordering of new entries within the `CONSUMERS` table (alphabetical by comment, grouped by
  type, or appended at end).
- Test assertion style and grouping within the spec file.
- UAT checklist format and location.

### Deferred Ideas (OUT OF SCOPE)

- Flamefang Pitch (1251592) — dropped from this phase by user decision. Can be reconsidered in a
  future phase if needed.

## Phase Requirements

No `REQUIREMENTS.md` IDs are mapped to Phase 7 — it was added to `ROADMAP.md` after the original
v1 requirement set was finalized (spell-audit follow-up, not a v1 REQUIREMENTS.md line item).
Traceability instead runs through the ROADMAP.md Phase 7 Success Criteria, adjusted for the
2-spell scope per `07-CONTEXT.md`:

| ID | Description | Research Support |
|----|-------------|------------------|
| SC-1 | `CONSUMERS` table includes Moonlight Chakram (1264902) and Hatchet Toss (193265) — **not** Flamefang Pitch (1251592, dropped by D-01) | See "Standard Stack" and "Code Examples" — exact table location and one-line pattern confirmed at TipOfTheSpear.lua:20-28 |
| SC-2 | Unit tests verify `ClassifySpellID` returns `"consumer"` for both new spell IDs | See Pitfall 1 — `ClassifySpellID` is a private local; needs a test-only escape hatch or event-path test to genuinely exercise it |
| SC-3 | Unit tests verify `ApplySpell("consumer", spellID)` decrements stacks for both new consumers | Direct precedent in `spec/tip_spec.lua:205-218` (265189, 1262343 tests) — same pattern applies unchanged |
| SC-4 | In-game verification of both spells flagged in UAT checklist | See "UAT Checklist" section below — append to the existing consolidated `01-HUMAN-UAT.md`, don't fork a new file |
| SC-5 | Test suite passes via the fengari harness | Confirmed command and current baseline (121/121 passing) in "Validation Architecture" below |

## D-04 Findings: Spell ID Variant Verification (CRITICAL)

This was the highest-risk research question for this phase. Findings, with confidence tags:

### Moonlight Chakram (1264902)

- `[CITED: wowhead.com/spell=1264902]` — Wowhead's live (non-PTR) spell page for ID 1264902 names
  it "Moonlight Chakram," a Sentinel hero-talent ability: "For 15 sec after casting Trueshot
  [Marksmanship] / Takedown [Survival], it is replaced with Moonlight Chakram." This is the ID
  `07-CONTEXT.md` D-01 already locks in, and it is confirmed current/live (not a stale PTR ID —
  a separate PTR-era ID, 1266082, also exists and is explicitly superseded).
- `[CITED: warcraft.wiki.gg/wiki/Moonlight_Chakram_(hunter_hero_talent)]` — corroborates 1264902 as
  the talent-page ID and confirms the same Trueshot/Takedown replacement mechanic, single ID
  covering both specs (no per-spec ID split described).
- `[ASSUMED — unresolved]` — A second ID, **1264949**, also appears under the name "Moonlight
  Chakram" on Wowhead/WoWDB and on `warcraft.wiki.gg/wiki/Moonlight_Chakram` (the non-talent
  ability page, as opposed to the hero-talent page). Its tooltip data shows "Buff," "Bouncy Chain
  Missiles," and "Not In Spellbook" characteristics — consistent with an internal buff/impact
  effect (e.g., the bounce mechanic or the "explosion on expiry" AoE) rather than a player-cast,
  `UNIT_SPELLCAST_SUCCEEDED`-firing spell ID. No source found that describes 1264949 as something
  the player casts. **This could not be conclusively ruled out without live combat-log
  verification.** Given the addon already has Success Criterion #4 requiring in-game verification
  of consumption behavior, this ambiguity should be folded into that same UAT check rather than
  blocking the plan — recommend the UAT step explicitly ask the tester to watch combat log /
  `/dmax` debug output for the exact spell ID that fires when casting Moonlight Chakram as
  Survival, so 1264949 can be added later if it turns out to matter.
- No source found suggesting a melee/ranged split analogous to Raptor Strike's Aspect-of-the-Eagle
  pattern (186270/265189) for Moonlight Chakram. It's a fixed 40-yard-range ability regardless of
  stance, so that particular variant class does not apply here.

### Hatchet Toss (193265)

- `[CITED: wowhead.com/spell=193265]` — confirmed single spell ID, ranged (40yd) Physical-damage
  ability, "Cannot be used while shapeshifted," 30 Focus cost.
- `[CITED: maxroll.gg Survival Hunter Mythic+ Guide]` — confirms Hatchet Toss is a legitimate
  Tip-of-the-Spear-consuming cast in current Midnight (12.0.7) Survival Hunter play, particularly
  valuable under Pack Leader's Hogstrider talent.
- No alternate/variant spell ID surfaced in any of Wowhead, WoWDB, Wowpedia, or Warcraft Wiki
  search results. Unlike Raptor Strike/Raptor Swipe — which have a melee ID and a separate
  Aspect-of-the-Eagle ranged ID because the base ability is normally melee-only — Hatchet Toss is
  *inherently* a ranged ability with no melee counterpart, so there is no structural reason to
  expect a second ID. `[ASSUMED, MEDIUM confidence]` no variant exists.

**Net recommendation for D-04:** Add exactly the two IDs already locked (1264902, 193265). Do not
add 1264949 speculatively — there is no confirming evidence it is a live-castable/trackable ID,
and adding an unverified ID to `CONSUMERS` risks silently decrementing stacks on an unrelated proc
event if 1264949 turns out to be something else entirely (e.g., fired on an ally's cast, or a
periodic tick). Instead, fold the verification of "does casting Moonlight Chakram as Survival fire
UNIT_SPELLCAST_SUCCEEDED with ID 1264902" into the required UAT checklist item.

## Standard Stack

No new dependencies — this phase adds two `[spellID] = true` table entries and tests. No packages,
libraries, or external tools are installed. `## Package Legitimacy Audit` is omitted per its own
"Required whenever this phase installs external packages" gate — this phase installs none. The
`fengari` test dependency is pre-existing infrastructure from Phase 02, invoked via `npx`, not
newly introduced.

### Core (existing, unchanged)

| File | Location | Purpose |
|------|----------|---------|
| `CONSUMERS` table | `Duncedmaxxing/Modules/TipOfTheSpear.lua:20-28` | Static `[spellID] = true` lookup; add 2 entries here |
| `ClassifySpellID` | `Duncedmaxxing/Modules/TipOfTheSpear.lua:74-82` | Classifies a spell ID as `"generator"`/`"consumer"`/nil; **no changes needed**, new IDs auto-discovered |
| `FindTrackedSpell` | `Duncedmaxxing/Modules/TipOfTheSpear.lua:84-92` | Iterates `UNIT_SPELLCAST_SUCCEEDED` varargs, returns first classified ID |
| `Tip:ApplySpell` | `Duncedmaxxing/Modules/TipOfTheSpear.lua:657-688` | Consumer path at lines 673-678 decrements 1 stack, clamps at 0, clears `expiresAt` at 0 — **verified this is the plain path both new spells will take** (neither is `TAKEDOWN`, so the Twin-Fangs special case at line 668 does not trigger) |

**Verified via direct file read (2026-07-27):** neither 1264902 nor 193265 is currently present in
`CONSUMERS`. Confirmed clean addition, no duplicate-key risk.

## Architecture Patterns

### System Architecture Diagram

```
WoW Client Event Bus
        │
        │  UNIT_SPELLCAST_SUCCEEDED(unit, castGUID, spellID)
        ▼
Tip:OnEvent(event, ...)          [TipOfTheSpear.lua:724-732]
        │  guard: self.isSurvival must be true
        ▼
FindTrackedSpell(...)            [TipOfTheSpear.lua:84-92]
        │  iterates all varargs, calls ClassifySpellID(id) on each
        ▼
ClassifySpellID(value)           [TipOfTheSpear.lua:74-82]
        │  value == KILL_COMMAND?        → "generator"
        │  CONSUMERS[value] == true?     → "consumer"   ◄── new IDs land here
        │  else                          → nil (ignored)
        ▼
Tip:ApplySpell(kind, spellID)    [TipOfTheSpear.lua:657-688]
        │  kind == "consumer" and spellID ~= TAKEDOWN
        ▼
self.stacks = ClampStacks(self.stacks - 1)   ← plain decrement path, both new spells land here
        │
        ▼
Tip:Update() → renders bar/number display instantly (before server aura confirms)
```

A reader can trace the full path: game event → dispatch → classify → apply → render, entirely
within one file, with the two new spell IDs only touching the classify step's lookup table.

### Recommended Test Structure (extends existing spec/tip_spec.lua)

```
spec/
└── tip_spec.lua
    └── describe("Tip:ApplySpell", ...)      -- existing describe block, line 21
        ├── existing 265189 test (line 205)   -- template: Aspect-of-the-Eagle Raptor Strike
        ├── existing 1262343 test (line 214)  -- template: Aspect-of-the-Eagle Raptor Swipe
        ├── NEW: 1264902 decrement test        -- mirror the above two exactly
        └── NEW: 193265 decrement test          -- mirror the above two exactly
    └── describe("ClassifySpellID", ...)      -- NEW describe block — does not exist yet
        ├── NEW: returns "consumer" for 1264902
        └── NEW: returns "consumer" for 193265
```

### Pattern: One-line CONSUMERS addition (established, used twice already)

**What:** Add `[spellID] = true, -- Comment naming the spell` to the `CONSUMERS` table.
**When to use:** Any plain "consume 1 stack, no special interaction" ability.
**Example (from the actual commit history — quick task 260622-tyy):**
```lua
-- Source: git commit 9d6832b (Duncedmaxxing/Modules/TipOfTheSpear.lua)
local CONSUMERS = {
    [1261193] = true, -- Boomstick
    [1250646] = true, -- Takedown
    [259495] = true,  -- Wildfire Bomb
    [186270] = true,  -- Raptor Strike
    [265189] = true,  -- Raptor Strike (Aspect of the Eagle ranged variant)
    [1262293] = true, -- Raptor Swipe
    [1262343] = true, -- Raptor Swipe (Aspect of the Eagle ranged variant)
    -- NEW for Phase 7:
    [1264902] = true, -- Moonlight Chakram
    [193265]  = true, -- Hatchet Toss
}
```
Commit message convention observed in history (`feat(<task-id>): register <id> (<name>) as a
consumer`) — the planner should follow the same conventional-commit style used in commits
`8c2a42a` and `9d6832b`.

### Anti-Patterns to Avoid

- **Adding talent-conditional gating for the new entries:** `07-CONTEXT.md` D-03 explicitly says
  no runtime talent checks are needed — uncast spells never fire the event, so an unconditional
  `[id] = true` entry is harmless even for a hero-talent-locked ability like Moonlight Chakram.
  Do not add `if HasSentinelTalent() then ...` logic.
- **Testing `ClassifySpellID` behavior by only calling `ApplySpell("consumer", spellID)` directly:**
  this was the pattern used for 265189/1262343 and it does NOT invoke `ClassifySpellID` at all — see
  Pitfall 1.
- **Speculatively adding 1264949 to `CONSUMERS`:** no evidence confirms it fires
  `UNIT_SPELLCAST_SUCCEEDED`; adding an unverified ID risks a false-positive decrement on an
  unrelated event. Defer to UAT.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Spell classification | A new dispatch function or parallel lookup table | The existing `CONSUMERS` table + `ClassifySpellID` | Already generic; adding entries is the intended extension point |
| Exposing private functions to tests | A parallel "testable" copy of `ClassifySpellID` | `DMX._test` escape-hatch pattern (`Core.lua:213-220`) | Established project convention; keeps a single source of truth for the real logic while making it assertable |

**Key insight:** this phase has essentially zero net-new logic to write. The entire risk surface is
(1) picking the right spell IDs (resolved in D-04 Findings above) and (2) writing a test that
actually proves classification, not just decrement behavior (Pitfall 1).

## Common Pitfalls

### Pitfall 1: Testing decrement behavior instead of classification behavior

**What goes wrong:** Writing `Tip:ApplySpell("consumer", 1264902)` and asserting the stack count
decremented. This passes even if `1264902` were never added to `CONSUMERS` at all, because the
test hard-codes `"consumer"` as the `kind` argument — it never calls `ClassifySpellID`.
**Why it happens:** It's the literal pattern used for the two prior additions (265189, 1262343) in
`spec/tip_spec.lua:205-218`, and it's the path of least resistance to copy.
**How to avoid:** Satisfy Success Criterion #3 (`ApplySpell` decrement) with that pattern — it's
correct for that criterion. But satisfy Success Criterion #2 (`ClassifySpellID` returns
`"consumer"`) with a *second*, distinct test that actually reaches the private function. Two
options, in order of preference:
  1. **Test-only escape hatch (recommended):** add to `TipOfTheSpear.lua`, mirroring
     `Core.lua:213-220`'s comment and pattern:
     ```lua
     -- Test-only escape hatch: exposes local functions for spec/tip_spec.lua
     -- Do not use in production addon code.
     DMX._test.tip = {
         ClassifySpellID = ClassifySpellID,
     }
     ```
     Then in `spec/tip_spec.lua`: `assert.equals("consumer", DMX._test.tip.ClassifySpellID(1264902))`.
     Note `DMX._test` is currently created once in `Core.lua:215`; `TipOfTheSpear.lua` would need
     to either extend the existing table (`DMX._test.tip = {...}` after Core.lua has already run,
     since TOC load order puts Core.lua before Modules/TipOfTheSpear.lua) or the planner should
     check load order doesn't clobber the existing `DMX._test` fields.
  2. **Full event-path test (more end-to-end, more verbose):** call
     `Tip.isSurvival = true; Tip:OnEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 1264902)`
     and assert `Tip.stacks` decremented. This proves classification transitively (if
     `ClassifySpellID` didn't recognize the ID, `FindTrackedSpell` would return nil and
     `ApplySpell` would never be called) but does not literally assert on `ClassifySpellID`'s
     return value, which is a softer match to the literal wording of Success Criterion #2.
**Warning signs:** A test file diff that only touches the existing `describe("Tip:ApplySpell", ...)`
block and adds no new `describe("ClassifySpellID", ...)` or escape-hatch code is a sign this
pitfall was not avoided.

### Pitfall 2: Silently dropping Flamefang Pitch from ROADMAP.md's stale success criteria

**What goes wrong:** `ROADMAP.md`'s Phase 7 Success Criterion #1 still literally reads "...includes
Flamefang Pitch (1251592), Moonlight Chakram (1264902), and Hatchet Toss (193265)". A verifier or
future contributor reading only `ROADMAP.md` (not `07-CONTEXT.md`) could flag this phase as
incomplete for omitting Flamefang Pitch.
**Why it happens:** `ROADMAP.md` was written before the discuss-phase session where the user
dropped the spell; nothing in this phase's scope updates `ROADMAP.md`'s stale text.
**How to avoid:** The plan/PLAN.md should explicitly note the scope reduction from 3→2 spells with
a citation to `07-CONTEXT.md` D-01, and ideally the phase's completion docs (SUMMARY.md) should
call out that `ROADMAP.md`'s original wording is superseded. Consider a small `ROADMAP.md` edit
(strike Flamefang Pitch from the criterion text) as part of the plan's cleanup, though this is
Claude's discretion, not a hard requirement.
**Warning signs:** A verifier comparing "3 spells promised" vs "2 spells delivered" without context.

### Pitfall 3: Forking a new UAT file instead of extending the existing one

**What goes wrong:** Creating `07-HUMAN-UAT.md` as a fresh file. The project currently has exactly
one *consolidated, running* human-UAT file
(`.planning/phases/01-utility-extraction-and-module-encapsulation/01-HUMAN-UAT.md`, explicitly
scoped as "full-milestone smoke test (phases 01-05)" and already tracked by project memory as *the*
UAT checklist location — see `ingame-testing-pending` memory note). Phases 03-06 did not create
their own UAT files; they either had no live-test gaps or folded them elsewhere. Creating a second,
parallel UAT file fragments tracking and risks the milestone being "closed" against only one of the
two files.
**Why it happens:** Each phase's `07-CONTEXT.md`-equivalent leaves "UAT checklist format and
location" to Claude's discretion, and file-per-phase is the more obvious default.
**How to avoid:** Append two new numbered test entries to the existing `01-HUMAN-UAT.md` (updating
its `scope:` frontmatter to mention phase 07, and its `Summary` counts), rather than creating a new
file. This is Claude's discretion per `07-CONTEXT.md`, but the research strongly recommends
consistency with the established single-file convention.
**Warning signs:** A new `*-HUMAN-UAT.md` or `*-UAT.md` file appearing under
`07-spell-coverage-add-missing-consumers/` when one is not needed.

### Pitfall 4: Forgetting Moonlight Chakram is talent-gated (Sentinel hero talent)

**What goes wrong:** Assuming Moonlight Chakram fires for all Survival Hunters at all times. It
only replaces Takedown for 15 seconds after a Takedown cast, and only for players who have chosen
the Sentinel hero talent tree (not Pack Leader or Dark Ranger).
**Why it happens:** The ability's Wowhead tooltip reads like a standalone spell, obscuring the
talent gating.
**How to avoid:** This does not require any code change (per D-03, uncast spells are harmless), but
the UAT checklist entry should instruct the tester to be speced into Sentinel and to cast Takedown
first before attempting to trigger Moonlight Chakram, or the live test will silently "pass" by
never firing the event at all (a false negative that looks like a false positive — no error, no
decrement observed, but only because the ability was never cast).
**Warning signs:** UAT tester reports "couldn't get Moonlight Chakram to appear on my action bar."

## Code Examples

### Adding a plain consumer spell ID (verified pattern from commit 9d6832b)

```lua
-- Source: Duncedmaxxing/Modules/TipOfTheSpear.lua:20-28 (current state, read 2026-07-27)
local CONSUMERS = {
    [1261193] = true, -- Boomstick
    [1250646] = true, -- Takedown
    [259495] = true,  -- Wildfire Bomb
    [186270] = true,  -- Raptor Strike
    [265189] = true,  -- Raptor Strike (Aspect of the Eagle ranged variant)
    [1262293] = true, -- Raptor Swipe
    [1262343] = true, -- Raptor Swipe (Aspect of the Eagle ranged variant)
}
```

### Existing consumer decrement test pattern (verified, spec/tip_spec.lua:211-218)

```lua
-- Source: spec/tip_spec.lua (current state, read 2026-07-27) — template for the 2 new tests
it("Aspect-of-the-Eagle Raptor Swipe (1262343) decrements 1 stack instantly", function()
    Tip.stacks = 2
    Tip:ApplySpell("consumer", 1262343)  -- Aspect-of-the-Eagle ranged Raptor Swipe
    assert.equals(1, Tip.stacks)
end)
```

### Existing test-only escape hatch pattern to mirror for ClassifySpellID (Core.lua:213-220)

```lua
-- Source: Duncedmaxxing/Core.lua:213-220 (current state, read 2026-07-27)
-- Test-only escape hatch: exposes local functions for spec/core_spec.lua
-- Do not use in production addon code.
DMX._test = {
    MergeDefaults      = MergeDefaults,
    NormalizeDB        = NormalizeDB,
    CopyDefaults       = CopyDefaults,
    SETTINGS_MIGRATION = SETTINGS_MIGRATION,
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|---------------|--------|
| Manual spell-list auditing per patch | N/A — this phase itself is the "spell audit gap closure" step referenced in the phase goal | 2026-07-27 (this phase) | No process change; just closes a known coverage gap |

**Deprecated/outdated:** None — no API or pattern changes in scope.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Spell ID 1264949 (found alongside 1264902 under the "Moonlight Chakram" name on Wowhead/WoWDB and one Warcraft Wiki page) is an internal buff/impact effect, not a player-cast ID that fires `UNIT_SPELLCAST_SUCCEEDED` | D-04 Findings | If wrong, Survival Hunters using Sentinel hero talent could cast Moonlight Chakram without the addon ever classifying it as a consumer, causing stacks to silently drift out of sync until the next aura-verify tick corrects it (existing `SyncFromAura` safety net limits blast radius, but predictive display would lag) |
| A2 | Hatchet Toss (193265) has no melee/ranged or talent-conditional alternate spell ID | D-04 Findings | If wrong, same drift risk as A1, but lower likelihood since no source hinted at a variant and the ability is inherently ranged already (no "Aspect of the Eagle"-style reason for a second ID to exist) |
| A3 | The two new spell IDs take the plain decrement branch in `ApplySpell` (not the `TAKEDOWN`+Twin-Fangs special case) | Standard Stack | Low risk — verified directly against the actual `ApplySpell` source (line 668 checks `spellID == TAKEDOWN` specifically; 1264902 and 193265 are neither the constant `TAKEDOWN` (1250646) nor `TWIN_FANGS` (1272139)) — this is HIGH confidence, listed here only for completeness of the assumptions ledger |
| A4 | `DMX._test` can be safely extended from `TipOfTheSpear.lua` without clobbering the fields Core.lua already set on it, given TOC load order (Util → Core → Options → Modules/TipOfTheSpear) | Pitfall 1 | If load order or table-reuse assumptions are wrong, tests referencing `DMX._test.tip.ClassifySpellID` could get a nil-index error; low risk since `DMX._test` is a plain table already created earlier in load order, so `DMX._test.tip = {...}` is additive, not destructive |

**A3 note:** this assumption resolves to HIGH confidence from direct code inspection, not training
data — included for ledger completeness per the required format, not because it needs user
confirmation.

## Open Questions

1. **Does Moonlight Chakram actually fire `UNIT_SPELLCAST_SUCCEEDED` with spell ID 1264902 for a
   Survival Hunter, or could the live client report a different ID (e.g., 1264949, or a per-spec
   variant not surfaced by any doc source)?**
   - What we know: Wowhead's live spell page and Warcraft Wiki's hero-talent page both name
     1264902 as "Moonlight Chakram," matching `07-CONTEXT.md`'s locked decision.
   - What's unclear: A second same-named ID (1264949) exists in the same data sources with
     ambiguous buff/proc characteristics; no live-client combat-log source was available to
     disambiguate.
   - Recommendation: Ship with 1264902 (as locked). Add an explicit UAT checklist instruction to
     watch for the actual fired spell ID during a live Takedown → Moonlight Chakram sequence
     (e.g., via `/etrace`, a combat-log addon, or a temporary debug print in `Tip:OnEvent`), and
     file a quick-task follow-up if 1264902 turns out not to be the ID the client actually sends.

2. **Should `ROADMAP.md`'s Phase 7 success-criteria text be corrected to remove Flamefang Pitch,
   given `07-CONTEXT.md` overrides it?**
   - What we know: `07-CONTEXT.md` D-01 is the authoritative, later decision; the ROADMAP text
     predates it.
   - What's unclear: Whether editing ROADMAP.md is in scope for this phase or a separate doc-only
     cleanup task.
   - Recommendation: Claude's discretion (per Pitfall 2) — a small strike-through/edit to
     ROADMAP.md's Phase 7 criterion #1 would prevent future confusion, but is not required to
     satisfy the phase's own success criteria.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Custom Node + fengari (Lua-VM-in-JS) runner — NOT plain `busted` despite `.busted` config file present; the actual entry point is `spec/run.cjs` |
| Config file | `.busted` (pattern/output config only; `spec/run.cjs` does its own file discovery, not busted's CLI) |
| Quick run command | `node spec/run.cjs` (requires local `fengari` in `node_modules`) or `npx -y -p fengari@0.1.5 node spec/run.cjs` (fetches fengari on the fly) |
| Full suite command | Same command — there is only one suite, no separate "quick" vs "full" tier; it runs all `*_spec.lua` files under `spec/` |

**Verified 2026-07-27:** ran `npx -y -p fengari@0.1.5 node spec/run.cjs` — **121 passed, 0 failed,
121 total** (current baseline before this phase's changes). No local `node_modules/fengari` is
committed to the repo, so CI/local runs depend on the `npx` fallback path documented in
`spec/run.cjs`'s own header comment.

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SC-1 | `CONSUMERS` table contains 1264902 and 193265 | unit (indirect, via SC-2/SC-3 tests) | `npx -y -p fengari@0.1.5 node spec/run.cjs` | ✅ (table exists; entries are new) |
| SC-2 | `ClassifySpellID(1264902)` and `ClassifySpellID(193265)` both return `"consumer"` | unit | same | ❌ — needs new `describe("ClassifySpellID", ...)` block + escape hatch, see Pitfall 1 |
| SC-3 | `ApplySpell("consumer", 1264902)` and `ApplySpell("consumer", 193265)` decrement stacks by 1 | unit | same | ❌ — needs 2 new `it(...)` blocks mirroring lines 205-218 |
| SC-4 | In-game verification flagged | manual-only | N/A (cannot automate live client behavior) | ❌ — needs UAT checklist entries, see Pitfall 3/4 |
| SC-5 | Full suite passes via fengari | smoke | `npx -y -p fengari@0.1.5 node spec/run.cjs` | ✅ — existing harness, currently 121/121 green |

### Sampling Rate

- **Per task commit:** `npx -y -p fengari@0.1.5 node spec/run.cjs` (full suite — there is no
  faster subset command available; the suite is small enough, ~121 tests, that this is also the
  quick-run command)
- **Per wave merge:** same command
- **Phase gate:** Full suite green before `/gsd-verify-work`; additionally the 2 new UAT checklist
  rows remain `pending`/`skipped` until the user has live game access (per project memory
  `ingame-testing-pending` — no game access currently available)

### Wave 0 Gaps

- [ ] `DMX._test.tip = { ClassifySpellID = ClassifySpellID }` (or equivalent escape hatch) in
      `Duncedmaxxing/Modules/TipOfTheSpear.lua` — required before a genuine `ClassifySpellID` unit
      test can be written (see Pitfall 1)
- [ ] No new test framework or fixture files needed — `spec/tip_spec.lua`,
      `spec/support/init.lua`, and `spec/support/wow_stubs.lua` all already support this addition
      pattern unchanged (confirmed by direct inspection; no new WoW API surface is touched since
      `UNIT_SPELLCAST_SUCCEEDED` handling and stubs already exist from Phase 02)

## Security Domain

`security_enforcement` is not explicitly disabled in `.planning/config.json`, so this section is
included per protocol, but is a deliberately thin pass — this phase has no attack surface.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-------------------|
| V2 Authentication | No | N/A — WoW addon, no auth surface |
| V3 Session Management | No | N/A |
| V4 Access Control | No | N/A |
| V5 Input Validation | No | Spell IDs are integer literals hard-coded in a static Lua table, not user- or network-supplied input; `UNIT_SPELLCAST_SUCCEEDED` args come from the trusted WoW client event bus, not an external/untrusted source |
| V6 Cryptography | No | N/A — no secrets, no crypto in this addon |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|----------------------|
| N/A — no new input surface, no new persistence, no new network calls | — | This phase's entire change surface is 2 static table entries + tests; there is no code path here that consumes untrusted data differently than the pre-existing consumer entries already in production |

## Sources

### Primary (HIGH confidence)

- Direct codebase reads (2026-07-27): `Duncedmaxxing/Modules/TipOfTheSpear.lua` (full file),
  `spec/tip_spec.lua` (full file), `Duncedmaxxing/Core.lua` (lines 200-221), `spec/support/init.lua`,
  `spec/run.cjs`, `.busted`
- `git log`/`git show` on commits `8c2a42a`, `d2fa27f`, `eaa83fd` (265189 addition),
  `9d6832b`, `d356a46`, `0435c7d` (1262343 addition) — actual prior-art commits for this exact
  pattern
- Live test run: `npx -y -p fengari@0.1.5 node spec/run.cjs` → 121/121 passing (2026-07-27, this
  session)

### Secondary (MEDIUM confidence)

- [Hatchet Toss - Spell - World of Warcraft](https://www.wowhead.com/spell=193265/hatchet-toss)
- [Survival Hunter Mythic+ Guide 12.0.7 - Maxroll](https://maxroll.gg/wow/class-guides/survival-hunter-mythic-plus-guide)
- [Moonlight Chakram (hunter hero talent) - Warcraft Wiki](https://warcraft.wiki.gg/wiki/Moonlight_Chakram_(hunter_hero_talent))
- [Moonlight Chakram - Spell - World of Warcraft](https://www.wowhead.com/spell=1264902/moonlight-chakram)

### Tertiary (LOW confidence)

- [Moonlight Chakram - Warcraft Wiki (ability page, distinct from hero-talent page)](https://warcraft.wiki.gg/wiki/Moonlight_Chakram)
- WebSearch-only synthesis for ID 1264949 (no single authoritative page conclusively describes
  its cast/proc semantics) — flagged in Assumptions Log A1
- [Survival Hunter DPS Spell List and Glossary - Icy Veins](https://www.icy-veins.com/wow/survival-hunter-pve-dps-spell-summary)

## Metadata

**Confidence breakdown:**
- Standard stack / code changes: HIGH — verified directly against current file contents and prior
  commit history for the identical pattern
- Architecture: HIGH — no new architecture; existing chain unchanged
- D-04 spell ID variants: MEDIUM (Hatchet Toss, no variant found) / LOW (Moonlight Chakram
  1264949 ambiguity unresolved offline)
- Test gap (ClassifySpellID escape hatch): HIGH — directly verified private-function visibility
  and the existing `DMX._test` precedent by reading the source

**Research date:** 2026-07-27
**Valid until:** Spell-ID claims (D-04 section): revalidate before next Hunter-affecting patch, or
immediately if the in-game UAT step reveals a mismatch. Code-pattern claims: stable until
`TipOfTheSpear.lua`'s `CONSUMERS`/`ClassifySpellID` structure changes.
