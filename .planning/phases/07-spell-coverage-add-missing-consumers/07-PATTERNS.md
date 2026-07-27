# Phase 7: Spell Coverage — Add Missing Consumers - Pattern Map

**Mapped:** 2026-07-27
**Files analyzed:** 2 (1 modified source, 1 modified test)
**Analogs found:** 2 / 2 (both are self-referential — the file being modified already contains the exact prior-art pattern twice)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|-----------------|---------------|
| `Duncedmaxxing/Modules/TipOfTheSpear.lua` (CONSUMERS table + `DMX._test` escape hatch) | model / lookup-table config | event-driven (classifies `UNIT_SPELLCAST_SUCCEEDED` spell IDs) | Same file, prior additions of `265189` and `1262343` (commits `8c2a42a`, `9d6832b`); escape-hatch pattern from `Duncedmaxxing/Core.lua:213-220` | exact |
| `spec/tip_spec.lua` (new `it(...)` blocks + new `describe("ClassifySpellID", ...)` block) | test | request-response (pure function assertions) | Same file, `265189`/`1262343` decrement tests at lines 205-218 | exact |

No new files are created. No controllers, components, services, or routes are involved — this phase touches exactly one static Lua table, one small test-only addition, and test assertions, per `07-CONTEXT.md` D-02/D-03 ("no changes to ApplySpell logic needed").

## Pattern Assignments

### `Duncedmaxxing/Modules/TipOfTheSpear.lua` (config/lookup-table + test hatch, event-driven)

**Analog:** itself — the `CONSUMERS` table already contains two prior "add a variant spell ID" commits that are the exact template (265189 in commit `8c2a42a`/`d2fa27f`/`eaa83fd`; 1262343 in `9d6832b`/`d356a46`/`0435c7d`).

**Current state — `CONSUMERS` table** (`Duncedmaxxing/Modules/TipOfTheSpear.lua:20-28`):
```lua
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

**Pattern to copy (one-line addition per spell, with descriptive comment):**
```lua
local CONSUMERS = {
    [1261193] = true, -- Boomstick
    [1250646] = true, -- Takedown
    [259495] = true,  -- Wildfire Bomb
    [186270] = true,  -- Raptor Strike
    [265189] = true,  -- Raptor Strike (Aspect of the Eagle ranged variant)
    [1262293] = true, -- Raptor Swipe
    [1262343] = true, -- Raptor Swipe (Aspect of the Eagle ranged variant)
    [1264902] = true, -- Moonlight Chakram
    [193265]  = true, -- Hatchet Toss
}
```
No changes to `ClassifySpellID` (`Duncedmaxxing/Modules/TipOfTheSpear.lua:74-82`), `FindTrackedSpell` (`:84-92`), or `Tip:ApplySpell` (`:657-688`) are needed — all three auto-discover new `CONSUMERS` entries. Verified: neither `1264902` nor `193265` collides with `TAKEDOWN` (1250646) or `TWIN_FANGS` (1272139), so both new spells take the plain decrement branch (`Duncedmaxxing/Modules/TipOfTheSpear.lua:673-678`), not the Twin-Fangs special case (`:668-672`).

**Core lookup/classify pattern** (`Duncedmaxxing/Modules/TipOfTheSpear.lua:74-92`):
```lua
local function ClassifySpellID(value)
    if value == KILL_COMMAND then
        return "generator"
    end

    if type(value) == "number" and CONSUMERS[value] then
        return "consumer"
    end
end

local function FindTrackedSpell(...)
    for i = 1, select("#", ...) do
        local id = select(i, ...)
        local kind = ClassifySpellID(id)
        if kind then
            return kind, id
        end
    end
end
```

**Test-only escape hatch pattern to mirror** (analog: `Duncedmaxxing/Core.lua:213-220`):
```lua
-- Test-only escape hatch: exposes local functions for spec/core_spec.lua
-- Do not use in production addon code.
DMX._test = {
    MergeDefaults      = MergeDefaults,
    NormalizeDB        = NormalizeDB,
    CopyDefaults       = CopyDefaults,
    SETTINGS_MIGRATION = SETTINGS_MIGRATION,
}
```
Apply the same shape in `TipOfTheSpear.lua`, near the bottom of the file before `DMX:RegisterModule("tip", Tip)` (line 766), extending the existing `DMX._test` table rather than replacing it (TOC load order is Core.lua before Modules/TipOfTheSpear.lua, so `DMX._test` already exists as a plain table by the time this file loads):
```lua
-- Test-only escape hatch: exposes local functions for spec/tip_spec.lua
-- Do not use in production addon code.
DMX._test = DMX._test or {}
DMX._test.tip = {
    ClassifySpellID = ClassifySpellID,
}
```

**Error handling pattern (context, unchanged):** `ClassifySpellID`/`FindTrackedSpell` have no error handling of their own — they are pure lookups over a static table and trusted event args (no `pcall` needed; contrast with `ReadLiveState` at `Duncedmaxxing/Modules/TipOfTheSpear.lua:94-117`, which wraps the WoW aura API in `pcall` because that call can return unexpected shapes — not applicable here since `CONSUMERS[value]` on a `number` never throws).

---

### `spec/tip_spec.lua` (test, request-response / pure-function assertions)

**Analog:** the existing 265189 and 1262343 decrement tests, and the file's own `describe`/`before_each` scaffolding.

**Imports / setup pattern** (`spec/tip_spec.lua:9-27`):
```lua
local loader = require("spec.support.init")
local stubs  = require("spec.support.wow_stubs")

describe("Tip:ApplySpell", function()
    local DMX, Tip, clock

    before_each(function()
        DMX, Tip, clock = loader.load()
        loader.resetTipState(Tip, clock)
    end)
    ...
```

**Decrement test pattern to copy** (`spec/tip_spec.lua:202-218`, satisfies SC-3):
```lua
-- Aspect-of-the-Eagle Raptor Swipe (1262343) decrements 1 stack instantly (plain consumer path)
-- Regression: 1262343 must be in CONSUMERS so ClassifySpellID returns "consumer" for it;
-- Pairs with 1262293 (base Raptor Swipe) the same way 265189 pairs with 186270 (Raptor Strike).
it("Aspect-of-the-Eagle Raptor Swipe (1262343) decrements 1 stack instantly", function()
    Tip.stacks = 2
    Tip:ApplySpell("consumer", 1262343)  -- Aspect-of-the-Eagle ranged Raptor Swipe
    assert.equals(1, Tip.stacks)
end)
```
New tests for `1264902` (Moonlight Chakram) and `193265` (Hatchet Toss) should mirror this exactly inside the same `describe("Tip:ApplySpell", ...)` block (append after line 218, before the closing `end)` at line 219):
```lua
it("Moonlight Chakram (1264902) decrements 1 stack instantly", function()
    Tip.stacks = 2
    Tip:ApplySpell("consumer", 1264902)  -- Moonlight Chakram
    assert.equals(1, Tip.stacks)
end)

it("Hatchet Toss (193265) decrements 1 stack instantly", function()
    Tip.stacks = 2
    Tip:ApplySpell("consumer", 193265)  -- Hatchet Toss
    assert.equals(1, Tip.stacks)
end)
```

**New classification test pattern (satisfies SC-2 — no direct analog exists yet in this file; construct from the `describe`/`before_each` scaffolding above plus the escape hatch):**
```lua
describe("ClassifySpellID", function()
    local DMX, Tip, clock

    before_each(function()
        DMX, Tip, clock = loader.load()
        loader.resetTipState(Tip, clock)
    end)

    it("returns \"consumer\" for Moonlight Chakram (1264902)", function()
        assert.equals("consumer", DMX._test.tip.ClassifySpellID(1264902))
    end)

    it("returns \"consumer\" for Hatchet Toss (193265)", function()
        assert.equals("consumer", DMX._test.tip.ClassifySpellID(193265))
    end)
end)
```
This is a genuinely new pattern (no prior `describe("ClassifySpellID", ...)` block exists) but is a direct structural clone of `describe("Tip:ApplySpell", ...)`'s scaffolding, just targeting the new `DMX._test.tip.ClassifySpellID` escape hatch instead of `Tip:ApplySpell`.

---

## Shared Patterns

### One-line static-table addition (primary pattern for this phase)
**Source:** `Duncedmaxxing/Modules/TipOfTheSpear.lua:20-28` (prior commits `8c2a42a`, `9d6832b`)
**Apply to:** `CONSUMERS` table — add `[1264902] = true, -- Moonlight Chakram` and `[193265]  = true, -- Hatchet Toss`.
No other production code changes needed; `ClassifySpellID`/`FindTrackedSpell`/`Tip:ApplySpell` are generic and auto-discover new entries.

### Test-only escape hatch for private local functions
**Source:** `Duncedmaxxing/Core.lua:213-220`
**Apply to:** `Duncedmaxxing/Modules/TipOfTheSpear.lua`, exposing `ClassifySpellID` as `DMX._test.tip.ClassifySpellID` so `spec/tip_spec.lua` can assert on classification directly (required for SC-2 — see Pitfall 1 in RESEARCH.md: calling `ApplySpell("consumer", spellID)` with a hard-coded `kind` does NOT exercise `ClassifySpellID` at all).
**Caution:** extend the existing `DMX._test` table (`DMX._test = DMX._test or {}` then `DMX._test.tip = {...}`) rather than reassigning it, since `Core.lua` already populates `DMX._test` earlier in TOC load order.

### Test scaffolding (`loader.load()` + `loader.resetTipState`)
**Source:** `spec/tip_spec.lua:9-27`, `spec/support/init.lua`
**Apply to:** Both the new `Tip:ApplySpell` decrement tests and the new `ClassifySpellID` describe block — every test in this file follows `DMX, Tip, clock = loader.load()` then `loader.resetTipState(Tip, clock)` in `before_each`.

## No Analog Found

None. Both files being modified already contain the exact prior-art pattern for this exact type of change (two previous "add a consumer spell ID variant" additions), so this phase requires no new architectural pattern beyond the escape-hatch extension, which itself has a direct analog in `Core.lua`.

## Metadata

**Analog search scope:** `Duncedmaxxing/Modules/TipOfTheSpear.lua`, `Duncedmaxxing/Core.lua`, `spec/tip_spec.lua`, `spec/support/init.lua`, `spec/support/wow_stubs.lua`
**Files scanned:** 5 (2 source, 3 test/support)
**Pattern extraction date:** 2026-07-27
</content>
