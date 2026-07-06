---
phase: 06-options-panel-v2-per-mode-visibility-configurable-stack-colo
reviewed: 2026-07-07T00:00:00Z
depth: standard
files_reviewed: 2
files_reviewed_list:
  - Duncedmaxxing/Core.lua
  - spec/core_spec.lua
findings:
  critical: 1
  warning: 2
  info: 2
  total: 5
status: issues_found
---

# Phase 06: Code Review Report

**Reviewed:** 2026-07-07T00:00:00Z
**Depth:** standard
**Files Reviewed:** 2
**Status:** issues_found

## Summary

Reviewed the phase 06-07 gap-closure change: the `NormalizeDB` settings-migration fix
that replaced a blanket `CopyDefaults(DEFAULTS.tip)` wipe with a targeted `stackColors`
re-seed gated by a new `StackColorsAreLegacyFormat` helper, plus the SC-6 regression test.

The migration logic reads plausibly in isolation, but it is broken **in the actual
production initialization path**. On `ADDON_LOADED` (`Core.lua:206-207`) the addon always
calls `MergeDefaults(DEFAULTS, DuncedmaxxingDB)` *before* `NormalizeDB(DuncedmaxxingDB)`.
`MergeDefaults` deep-recurses into legacy array-format `stackColors` entries and injects
`.r/.g/.b/.a` keys into them. By the time `NormalizeDB` runs, `StackColorsAreLegacyFormat`
sees a non-nil `.r` and returns `false`, so the targeted reseed at `Core.lua:90` **never
executes for any real legacy DB**. The SC-6 regression test does not catch this because it
invokes `NormalizeDB` directly and skips the mandatory `MergeDefaults` step — so it exercises
the reseed branch under conditions that never occur at runtime.

I confirmed this empirically with a fengari probe replicating the production call order:
`stackColors[1].r` came out `0.18039` (the default) with the user's custom `0.9` value
discarded, and the legacy junk array key `stackColors[1][1] = 0.9` survived untouched.

## Critical Issues

### CR-01: Targeted `stackColors` reseed is dead code in production; regression test does not reproduce the real init path

**File:** `Duncedmaxxing/Core.lua:85-98`, `Duncedmaxxing/Core.lua:206-207`, `spec/core_spec.lua:200-217`
**Issue:**
The production bootstrap runs migration in this fixed order (`Core.lua:206-207`):

```lua
DuncedmaxxingDB = MergeDefaults(DEFAULTS, DuncedmaxxingDB)  -- runs FIRST
NormalizeDB(DuncedmaxxingDB)                                -- runs SECOND
```

`MergeDefaults` deep-recurses into `stackColors` and, for each legacy array entry such as
`[0] = {1,1,1,1}`, fills the missing `.r/.g/.b/.a` keys from `DEFAULTS.tip.stackColors`
(it only skips keys that are already non-nil, and the numeric array indices `[1]..[4]` do
not collide with the string keys `r/g/b/a`). The legacy entry becomes a *mixed* table:
`{ [1]=1,[2]=1,[3]=1,[4]=1, r=1,g=1,b=1,a=1 }`.

`NormalizeDB` then evaluates `StackColorsAreLegacyFormat`:

```lua
return first.r == nil and first[1] ~= nil   -- first.r is now 1, so this is FALSE
```

so the reseed at `Core.lua:89-91` is skipped for every real legacy DB. The branch that
plan 06-07 added is therefore **dead in the production path**. Confirmed with a fengari
probe using the exact production order:

```
>>> stackColors[1].r after prod flow = 0.18039   (default green; user's custom 0.9 lost)
>>> stackColors[1][1] (junk array key) = 0.9      (legacy array index never cleaned)
>>> RESEED DID NOT RUN — junk array keys survived (dead branch confirmed)
```

The SC-6 regression test (`spec/core_spec.lua:200-217`) "passes" only because it calls
`DMX._test.NormalizeDB(db)` directly on a raw legacy table **without first calling
`MergeDefaults`** — the opposite of what production does. It therefore gives false
confidence that the migration repairs legacy `stackColors`, when in fact the reseed can
never fire at runtime. Observable production consequences:
1. The 06-07 fix does not do what the plan claims — the reseed is unreachable.
2. Legacy junk array keys (`[1]..[4]`) persist permanently in SavedVariables (the
   migration token is bumped once, so they are never cleaned on later loads).
3. Rendered colors happen to be correct-looking (defaults, filled by `MergeDefaults`),
   which masks the defect and makes it hard to notice.

**Fix:** Make the migration reflect the real call order. Either detect legacy format
*before* `MergeDefaults` runs, or make the helper robust to the mixed table `MergeDefaults`
produces, and have the regression test replicate production order. Minimal option — run the
reseed check against the mixed shape by testing for a lingering numeric index:

```lua
local function StackColorsAreLegacyFormat(stackColors)
    if type(stackColors) ~= "table" then
        return false
    end
    local first = stackColors[0]
    if type(first) ~= "table" then
        return false
    end
    -- After MergeDefaults, legacy entries carry BOTH .r and stale array keys.
    return first[1] ~= nil
end
```

and update the regression test to mirror `Core.lua:206-207`:

```lua
DMX._test.MergeDefaults(DMX.defaults, db)  -- production runs this first
DMX._test.NormalizeDB(db)
-- assert the stale numeric array keys are gone after reseed:
assert.is_nil(db.tip.stackColors[0][1])
assert.is_nil(db.tip.stackColors[1][1])
```

## Warnings

### WR-01: `StackColorsAreLegacyFormat` only inspects index `[0]`

**File:** `Duncedmaxxing/Core.lua:72-83`
**Issue:** The helper decides the format of the entire `stackColors` table from a single
probe of `stackColors[0]`. If a stored DB has `[0]` missing or already in new format while
`[1]`/`[2]`/`[3]` are still legacy array format (e.g. a partially hand-edited or
partially-migrated SavedVariables file), the function returns `false` and leaves the legacy
entries unrepaired. Combined with CR-01 this compounds the risk of stale mixed-format data.
**Fix:** Scan the entries that actually exist rather than trusting `[0]` alone, e.g. iterate
`for i = 0, 3 do` and treat the table as legacy if any present entry has a numeric `[1]`
element and no `.r`. Guard against `[0]` being absent.

### WR-02: Legacy user color customizations are silently discarded rather than remapped

**File:** `Duncedmaxxing/Core.lua:89-91`
**Issue:** The legacy array format stores components positionally as `{r, g, b, a}`
(`spec/core_spec.lua:188-193` shows `[1] = { 0.18039, 0.8, 0.44314, 1 }`), so the data is
fully recoverable. The reseed instead overwrites with `CopyDefaults(DEFAULTS.tip.stackColors)`,
throwing away any user-customized legacy colors. For a user who tuned their stack colors in
the old format this is a silent data loss on upgrade. (In today's broken production path the
loss happens anyway via `MergeDefaults` defaults — see CR-01 — but once CR-01 is fixed the
reseed itself will still discard recoverable data.)
**Fix:** Remap positional array entries into the new keyed shape instead of dropping them:

```lua
local function ConvertLegacyStackColors(sc)
    local out = {}
    for i = 0, 3 do
        local e = sc[i]
        if type(e) == "table" and e.r == nil then
            out[i] = { r = e[1], g = e[2], b = e[3], a = e[4] }
        else
            out[i] = e or CopyDefaults(DEFAULTS.tip.stackColors[i])
        end
    end
    return out
end
```

If discarding is a deliberate design decision, document it in a comment so the intent is clear.

## Info

### IN-01: `NormalizeDB` dereferences `db.tip` with no nil guard

**File:** `Duncedmaxxing/Core.lua:85-89`
**Issue:** `NormalizeDB` reads `db.tip` and then `tip.stackColors` / `tip.displayMode`
without checking `db` or `db.tip` for nil. In production this is safe because
`MergeDefaults` always creates `db.tip`, but the function is also exposed via `DMX._test`
and called directly in tests, so the invariant is not locally enforced. A defensive
`if not db or type(db.tip) ~= "table" then return end` guard would harden the escape hatch
and match the project's stated nil-safety conventions.
**Fix:** Add a leading guard clause before touching `db.tip`.

### IN-02: SC-6 regression test asserts only `stackColors[0]`, not `[1]`–`[3]`

**File:** `spec/core_spec.lua:213-214`
**Issue:** The regression test verifies only `db.tip.stackColors[0]` is a table with
`.r == 1`. It never asserts that indices `[1]`, `[2]`, `[3]` were repaired, nor that the
stale numeric array keys were removed. Even after CR-01 is fixed, this leaves the per-index
repair and the junk-key cleanup unverified.
**Fix:** Loop `for i = 0, 3 do` asserting each entry has `.r/.g/.b/.a` and that
`stackColors[i][1]` is nil (no leftover array key).

---

_Reviewed: 2026-07-07T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
