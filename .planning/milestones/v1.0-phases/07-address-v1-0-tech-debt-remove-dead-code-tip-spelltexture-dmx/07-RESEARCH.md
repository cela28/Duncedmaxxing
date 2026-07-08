# Phase 7: Address v1.0 tech debt - Research

**Researched:** 2026-07-09
**Domain:** Dead-code removal + test-hardening in a Lua 5.1 WoW addon, verified via a fengari (Lua-VM-in-JS) test harness
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Dead code: hasPrimalSurge**
- **D-01:** Remove `hasPrimalSurge` entirely. Delete the field (`TipOfTheSpear.lua:64`), its reset in `spec/support/init.lua:62`, and any other init/reset sites. Treat the flat-2 generator grant as the confirmed permanent behavior — the "reserved for future ID resolution" placeholder is being retired, not preserved.
- **D-02:** Delete the 3 tautological Primal Surge tests in `spec/tip_spec.lua` (the pair at ~139-143 and ~146-151 that vary `hasPrimalSurge` but always assert 2, plus the Twin-Fangs-independence test's `hasPrimalSurge` toggling — keep genuine BASE/Twin-Fangs coverage, just drop the `hasPrimalSurge` variable from it). Net: no test references `hasPrimalSurge` after this phase.
- **D-03:** Rewrite the generator-branch comment (`TipOfTheSpear.lua:656-659`) to remove the self-contradiction (IN-01). It should state plainly that the grant is always 2 stacks — drop the "base 1, +1 with Primal Surge" framing and the "hasPrimalSurge field reserved" note (the field no longer exists).

**Dead code: unconsumed exports**
- **D-04:** Remove `Tip.spellTexture` fully. Delete the field (`TipOfTheSpear.lua:65`), the `CacheSpellTexture` function and its `FALLBACK_ICON`, the `PLAYER_LOGIN`/`PLAYER_ENTERING_WORLD` caching call (`TipOfTheSpear.lua:696`), the reset in `spec/support/init.lua:64`, and the 2 spellTexture tests in `spec/tip_spec.lua` (~518, ~524, and the surrounding describe block if it becomes empty). No icon/texture display is planned to return.
- **D-05:** Remove `DMX.Util.ParseOnOff` fully. Delete the local function and the `Util.ParseOnOff` export in `Duncedmaxxing/Util.lua`, and the entire `DMX.Util.ParseOnOff` describe block in `spec/util_spec.lua` (~122-183). No slash on/off parsing is planned to return (slash is settings-only).

**Test hardening: 265189 regression**
- **D-06:** Harden the 265189 test by adding an explicit assertion that `ClassifySpellID(265189) == "consumer"` (so the test guards CONSUMERS membership, not just the decrement math). Apply the same classify assertion to the Raptor Swipe siblings `1262293` and `1262343`. Keep the existing direct-decrement assertions too — this is additive, not a full rewrite through the event dispatch.

**Migration side effect: db.locked**
- **D-07:** Keep the `db.locked = true` line in the `NormalizeDB` migration block (`Core.lua:123`) — it is intended behavior. The frame deliberately starts locked after every settings-migration upgrade so it can't be accidentally dragged. No code change; close the audit concern by documenting it as designed (a brief comment on that line is fine so it isn't re-flagged in a future audit).

### Claude's Discretion
- Exact test-file restructuring (whether to delete an emptied `describe` block vs. leave a trimmed one) is at the planner/executor's discretion, as long as the suite stays green and no orphaned references to removed symbols remain.
- Whether the `db.locked` intent comment is one line or a short block.

### Deferred Ideas (OUT OF SCOPE)
- **`wow_stubs.lua` makeAuraData contract verification** — the Phase 2 deferred human item (verify makeAuraData fields against warcraft.wiki.gg `Struct_AuraData`) is real but not named in this phase's roadmap title. Belongs in its own quick task or a validation follow-up, not this cleanup phase.
- **Nyquist validation coverage** — phases 00/01/02/04 have draft (non-compliant) VALIDATION.md; 05/06 have none. Backfilling via `/gsd-validate-phase` is a separate documentation/validation effort, out of scope here.
</user_constraints>

<phase_requirements>
## Phase Requirements

No formal REQUIREMENTS.md IDs map to this phase — it is a tech-debt cleanup phase surfaced entirely by `.planning/v1.0-MILESTONE-AUDIT.md`. CONTEXT.md decisions D-01 through D-07 (above) are the authoritative, complete scope contract. The planner should treat each D-ID as a pseudo-requirement for traceability purposes.

| ID | Description | Research Support |
|----|-------------|------------------|
| D-01 | Remove `hasPrimalSurge` field + all init/reset sites | Confirmed exactly 3 production/test sites; see Symbol Location Table |
| D-02 | Delete 3 tautological Primal Surge tests | Confirmed exact test names/line ranges in spec/tip_spec.lua |
| D-03 | Rewrite self-contradictory generator-branch comment | Confirmed current comment text (lines 656-659) |
| D-04 | Remove `Tip.spellTexture` + `CacheSpellTexture` + `FALLBACK_ICON` | Found a SECOND call site not listed in CONTEXT.md — see Pitfall 1 |
| D-05 | Remove `DMX.Util.ParseOnOff` | Confirmed zero production callers; 15 tests to delete |
| D-06 | Harden 265189 + Raptor Swipe sibling tests via `ClassifySpellID` | Found `ClassifySpellID` is NOT currently exposed to specs — needs new test-only export (see Pitfall 2) |
| D-07 | Document (not change) `db.locked = true` migration reset | Confirmed a passing test already locks in this behavior (core_spec.lua:141-145) |
</phase_requirements>

## Summary

This phase is a pure internal cleanup: delete three well-isolated pieces of dead code, tighten two tests that currently provide false confidence, and add a documentation comment to a migration side-effect that is already correct. There is no new dependency, no new API surface, and no runtime behavior change for `db.locked` (D-07) or the generator grant math (D-03 only changes a comment). The riskiest part of the phase is **not** the deletions themselves — grep confirms every deletion target has zero other production references — but two things the audit under-specified:

1. **`CacheSpellTexture` has two call sites, not one.** CONTEXT.md's canonical refs list only the `PLAYER_LOGIN`/`PLAYER_ENTERING_WORLD` call (line 696), but `Tip:Initialize` also calls it directly at line 743. Both must be deleted or the file won't compile (undefined function reference) after `CacheSpellTexture` is removed.
2. **`ClassifySpellID` is a private `local function` inside `TipOfTheSpear.lua` and is not currently reachable from any spec file.** D-06 requires asserting `ClassifySpellID(265189) == "consumer"` from `spec/tip_spec.lua`, but there is no existing export path (no `Tip._test` table exists, unlike Core.lua's `DMX._test`). The plan must add a minimal test-only export before D-06's assertions can be written.

Everything else is mechanical: delete field/function/comment/test in matched pairs, run the fengari suite (confirmed 125/125 passing right now via `npx -y -p fengari@0.1.5 node spec/run.cjs`), and confirm no orphaned references remain via grep.

**Primary recommendation:** Sequence the removals as (1) add `Tip._test.ClassifySpellID` export first (enables D-06 to be written/verified independently), (2) `hasPrimalSurge` removal + test edits (D-01/02/03), (3) `spellTexture`/`CacheSpellTexture`/`FALLBACK_ICON` removal + both call sites + test edits (D-04), (4) `ParseOnOff` removal (D-05, fully independent — different file, zero coupling to the others), (5) `db.locked` comment only (D-07, no logic change). Run the full fengari suite after each removal group, not just once at the end.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Dead-field removal (`hasPrimalSurge`, `spellTexture`) | Module logic (`Duncedmaxxing/Modules/TipOfTheSpear.lua`) | Test harness (`spec/support/init.lua`, `spec/tip_spec.lua`) | Field lives on the `Tip` module table; its only consumers besides production code are the per-test reset helper and the tests themselves — both must be edited in lockstep with the field deletion |
| Dead-export removal (`ParseOnOff`) | Shared utility (`Duncedmaxxing/Util.lua`) | Test harness (`spec/util_spec.lua`) | `Util.lua` is a pure-function module with no WoW API coupling; removal is fully local to this file + its spec |
| Test hardening (`ClassifySpellID` assertions) | Test harness (`spec/tip_spec.lua`) | Module logic (`Duncedmaxxing/Modules/TipOfTheSpear.lua`) | The assertion itself lives in the spec, but exposing `ClassifySpellID` requires a one-line addition to the module (a `Tip._test` table, mirroring `DMX._test` in Core.lua) |
| Migration documentation (`db.locked`) | Persistence/migration (`Duncedmaxxing/Core.lua`) | — | Comment-only change inside `NormalizeDB`; no test or module-logic impact |

## Standard Stack

Not applicable — this phase installs no new packages, libraries, or dependencies. It is a pure code-deletion and test-hardening pass within the existing Lua 5.1 / fengari toolchain already in place.

### Installation
No installation steps. `fengari@0.1.5` is already the pinned test-runner dependency (see Environment Availability below); no `package.json`/lockfile exists in this repo — `spec/run.cjs` resolves fengari local-first, falling back to `npx -y -p fengari@0.1.5`.

## Package Legitimacy Audit

Not applicable — no external packages are installed, upgraded, or referenced by this phase. Skip this section for the plan.

## Architecture Patterns

### System Architecture Diagram

```text
 [spec/*_spec.lua]                         [Duncedmaxxing/*.lua production files]
      |                                              |
      | loadfile() + WoW vararg injection            |
      v                                              v
 spec/support/init.lua --load()-->  loads Util.lua -> Core.lua -> TipOfTheSpear.lua
      |                                   (mirrors Duncedmaxxing.toc load order)
      | resetTipState(Tip, clock)  <-- per-test field reset (must match Tip's live fields)
      v
 [Tip module table]  <---- DMX:GetModule("tip")
      |
      | Tip._test.* (NEW — mirrors existing DMX._test pattern in Core.lua)
      v
 [spec/tip_spec.lua assertions]  ----> assert.equals(ClassifySpellID(265189), "consumer")

 node spec/run.cjs
      |
      +--> fengari Lua VM (busted-compatible shim: describe/it/before_each/assert)
      +--> loads every *_spec.lua in spec/ into ONE Lua state
      +--> runs all registered tests, reports PASS/FAIL, exit code 0/1
```

A reader can trace the primary use case: a spec file calls `loader.load()`, which chunk-loads the three production files in TOC order and replicates the `ADDON_LOADED` bootstrap (`MergeDefaults` -> `NormalizeDB` -> `ForEachModule("Initialize")`), producing a fresh `DMX`/`Tip`/mock-clock triple for full per-test isolation. Removed symbols must disappear from both the production chunk and this loader's reset helper, or the loader will silently keep writing to a field that no longer means anything.

### Recommended Project Structure
No structural changes — this phase edits existing files in place. No new files, directories, or modules are created except a small `Tip._test` table addition inside the existing `TipOfTheSpear.lua`.

### Pattern: Test-only escape hatch (`_test` table)
**What:** A module exposes otherwise-private `local function`s to specs via a `ModuleName._test = { FnName = FnName }` table, assigned once at the bottom of the file (see `Duncedmaxxing/Core.lua:236-241`, `DMX._test`).
**When to use:** When a spec needs to call a `local function` that is deliberately not part of the public module API (kept `local` to avoid polluting the WoW addon global surface) but whose correctness the test suite must guard directly (as opposed to only through its callers).
**Precedent already in this codebase:**
```lua
-- Source: Duncedmaxxing/Core.lua:234-241 (existing pattern, already in production)
-- Test-only escape hatch: exposes local functions for spec/core_spec.lua
-- Do not use in production addon code.
DMX._test = {
    MergeDefaults      = MergeDefaults,
    NormalizeDB        = NormalizeDB,
    CopyDefaults       = CopyDefaults,
    SETTINGS_MIGRATION = SETTINGS_MIGRATION,
}
```
**Apply this exact pattern to `TipOfTheSpear.lua`** (no equivalent currently exists in this file) so `spec/tip_spec.lua` can call `Tip._test.ClassifySpellID(265189)` for D-06:
```lua
-- Add near the bottom of Duncedmaxxing/Modules/TipOfTheSpear.lua, before
-- `DMX:RegisterModule("tip", Tip)` (mirrors Core.lua's DMX._test convention).
-- Test-only escape hatch: exposes local functions for spec/tip_spec.lua.
-- Do not use in production addon code.
Tip._test = {
    ClassifySpellID = ClassifySpellID,
}
```
Then in `spec/tip_spec.lua`, the D-06 hardened assertions become:
```lua
it("Aspect-of-the-Eagle Raptor Strike (265189) decrements 1 stack instantly", function()
    assert.equals("consumer", Tip._test.ClassifySpellID(265189))  -- D-06 hardening
    Tip.stacks = 2
    Tip:ApplySpell("consumer", 265189)
    assert.equals(1, Tip.stacks)
end)
```
(Same pattern for `1262293` and `1262343`.)

### Anti-Patterns to Avoid
- **Deleting `spellTexture` without deleting both call sites:** `CacheSpellTexture` is invoked from two places (`Tip:Initialize` at line 743 AND the `PLAYER_LOGIN`/`PLAYER_ENTERING_WORLD` branch of `Tip:OnEvent` at line 696). Deleting the function definition but leaving either call site produces a Lua "attempt to call a nil value" runtime error the first time that code path executes — the fengari suite WILL catch this (both call sites are exercised by `loader.load()` -> `ForEachModule("Initialize")`), but a plan that only lists one call site risks an executor missing the other.
- **Rewriting the 265189 test through full event dispatch:** CONTEXT.md explicitly says D-06 is additive, not a rewrite through `Tip:OnEvent("UNIT_SPELLCAST_SUCCEEDED", ...)`. Keep the existing `Tip:ApplySpell("consumer", 265189)` call and its assertion; only ADD the `ClassifySpellID` assertion above it.
- **Removing the `describe("Caching -- isSurvival and spellTexture", ...)` block entirely:** This block also contains 4 non-spellTexture tests (`isSurvival` after Initialize, `PLAYER_SPECIALIZATION_CHANGED` behavior x2, `PLAYER_TALENT_UPDATE`) that must be KEPT. Only the 2 `it(...)` blocks at ~518 and ~524 (both asserting on `Tip.spellTexture`) are deleted; the describe block itself stays (title can optionally be trimmed to just "Caching -- isSurvival" at executor discretion per CONTEXT.md).

## Symbol Location Table

Grep-verified against the current working tree (2026-07-09) — CONTEXT.md's line numbers were confirmed accurate for everything except the second `CacheSpellTexture` call site.

| Symbol | File | Line(s) | Verified? | Notes |
|--------|------|---------|-----------|-------|
| `Tip.hasPrimalSurge = false` | `Duncedmaxxing/Modules/TipOfTheSpear.lua` | 64 | ✅ exact | Field init |
| `hasPrimalSurge` comment note | `Duncedmaxxing/Modules/TipOfTheSpear.lua` | 659 | ✅ exact | `-- flat-2 fallback (hasPrimalSurge field reserved...)` — rewrite per D-03 |
| `Tip.hasPrimalSurge` reset | `spec/support/init.lua` | 62 | ✅ exact | In `resetTipState` |
| `Tip.hasPrimalSurge` in tests | `spec/tip_spec.lua` | 31, 132, 140, 147 (+ comments at 128-129, 138, 145) | ✅ exact | 4 assignment sites across 4 `it()` blocks — 3 are the tautological tests (D-02); the Twin-Fangs-independence test (line 130-136) keeps its `hasTwinFangs` assertion but drops the `hasPrimalSurge = false` line at 132 |
| `Tip.spellTexture = nil` | `Duncedmaxxing/Modules/TipOfTheSpear.lua` | 65 | ✅ exact | Field init |
| `FALLBACK_ICON` const | `Duncedmaxxing/Modules/TipOfTheSpear.lua` | 12 | ✅ exact | Only consumer is line 158 (confirmed via grep — no other reference anywhere in repo) |
| `CacheSpellTexture` function | `Duncedmaxxing/Modules/TipOfTheSpear.lua` | 147-159 (comment 147-149, def 150-159) | ✅ exact | — |
| `CacheSpellTexture(self)` call #1 | `Duncedmaxxing/Modules/TipOfTheSpear.lua` | 696 | ✅ exact | Inside `Tip:OnEvent`, `PLAYER_LOGIN`/`PLAYER_ENTERING_WORLD` branch — the only call site CONTEXT.md names |
| `CacheSpellTexture(self)` call #2 | `Duncedmaxxing/Modules/TipOfTheSpear.lua` | **743** | ⚠️ NOT in CONTEXT.md | Inside `Tip:Initialize` — **must also be deleted**; see Pitfall 1 |
| `Tip.spellTexture` reset | `spec/support/init.lua` | 64 | ✅ exact | In `resetTipState` |
| `Tip.spellTexture` in tests | `spec/tip_spec.lua` | 518-521, 524-527 | ✅ exact | 2 `it()` blocks inside the `describe("Caching -- isSurvival and spellTexture", ...)` block (starts line 482) — describe block itself is KEPT (has 4 other unrelated tests) |
| `ParseOnOff` local fn | `Duncedmaxxing/Util.lua` | 18-25 | ✅ exact | — |
| `Util.ParseOnOff` export | `Duncedmaxxing/Util.lua` | 42 | ✅ exact | — |
| `ParseOnOff` file-header comment | `Duncedmaxxing/Util.lua` | — | — | No file-header docstring in Util.lua mentioning ParseOnOff; nothing to update there |
| `DMX.Util.ParseOnOff` describe block | `spec/util_spec.lua` | 122-184 | ✅ exact | Entire block (15 `it()` tests) deleted per D-05 |
| `util_spec.lua` file-header comment | `spec/util_spec.lua` | 2 | ⚠️ minor, not in CONTEXT.md | `-- Unit tests for DMX.Util.Clamp, ParseHexColor, ParseOnOff, Trim.` — mentions ParseOnOff; cosmetic, safe to drop the word "ParseOnOff" from this comment while editing the file (discretion, not blocking) |
| `ClassifySpellID` local fn | `Duncedmaxxing/Modules/TipOfTheSpear.lua` | 74-82 | ✅ exact | Currently NOT exported anywhere — see Pitfall 2 |
| 265189 regression test | `spec/tip_spec.lua` | 202-209 | ✅ exact | `it("Aspect-of-the-Eagle Raptor Strike (265189) decrements 1 stack instantly", ...)` |
| 1262343 sibling test | `spec/tip_spec.lua` | 211-218 | ✅ exact (CONTEXT.md doesn't cite line, but it's the very next test) | `it("Aspect-of-the-Eagle Raptor Swipe (1262343) decrements 1 stack instantly", ...)` |
| 1262293 (Raptor Swipe base) | `Duncedmaxxing/Modules/TipOfTheSpear.lua` (`CONSUMERS`) | 26 | ✅ exact | **No dedicated `it()` test currently exists for 1262293** — D-06 says "apply the same classify assertion to... 1262293" but there is no existing test body to add it to. The planner must decide: add a new minimal test, or add the assertion to an existing test that already exercises 1262293 (none currently do — grep confirms 1262293 appears only in the `CONSUMERS` table, never in a spec). **Recommend:** add one new small `it()` block asserting `ClassifySpellID(1262293) == "consumer"` alongside the 265189/1262343 tests, for parity, rather than skipping coverage for that spell ID. |
| `db.locked = true` migration line | `Duncedmaxxing/Core.lua` | 123 | ✅ exact | Inside `NormalizeDB`'s migration-gate block |
| `db.locked` live reads (unaffected) | `Duncedmaxxing/Modules/TipOfTheSpear.lua` | 336, 545, 585 | ✅ confirmed live | `db.locked` drives drag-lock (336), bar-mode unlock visuals (545), general unlock/show gate (585) — confirms D-07's rationale that this is a real, actively-consumed setting, not dead code |
| Existing `db.locked` migration test | `spec/core_spec.lua` | 141-145 | ✅ confirmed passing | `it("sets db.locked = true during migration", ...)` already exists and passes — D-07 needs no test change, only the Core.lua comment |

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|--------------|-----|
| Exposing a private Lua `local function` to a test file | A new ad-hoc global, a `_G` leak, or re-implementing `ClassifySpellID` logic inline in the spec | The existing `_test` table convention (`DMX._test` in `Core.lua:236-241`) — replicate it on `Tip` | The codebase already has exactly this pattern established and documented ("Test-only escape hatch... Do not use in production addon code"); a second, differently-named mechanism would fragment the convention |
| Confirming "no production code reads a symbol" before deletion | Manual file-by-file reading and memory | `grep -rn "<symbol>" Duncedmaxxing/ spec/` across the whole tree, not just the file being edited | This research already caught a second `CacheSpellTexture` call site that CONTEXT.md's canonical refs missed by only grepping this way; a plan that skips this check risks a false "safe to delete" |

**Key insight:** In a codebase with no build step and no compiler to catch a dangling reference except at runtime (a Lua `nil` call error), grep-before-delete across the WHOLE tree (not just the target file) is the only static safety net. The fengari suite is the dynamic safety net, but it only catches paths the tests actually exercise — `Tip:Initialize` IS exercised by every `loader.load()` call, so the second `CacheSpellTexture` call site would have been caught immediately by a red suite, but it's better to know before writing the plan than to discover it mid-execution.

## Common Pitfalls

### Pitfall 1: `CacheSpellTexture` has two call sites, only one of which CONTEXT.md's canonical_refs lists
**What goes wrong:** A plan/task that deletes the `CacheSpellTexture` function definition and only the `PLAYER_LOGIN`/`PLAYER_ENTERING_WORLD` call (line 696) leaves the call inside `Tip:Initialize` (line 743) referencing a now-undefined function.
**Why it happens:** CONTEXT.md's canonical_refs section says "the `PLAYER_LOGIN`/`PLAYER_ENTERING_WORLD` caching call (696)" — singular — because the audit that produced the tech-debt list looked at PERF-02's original requirement text ("resolved and cached once at Initialize time (and on PLAYER_LOGIN)") but didn't re-grep the current file for all call sites.
**How to avoid:** Delete both line 696 (inside `Tip:OnEvent`) and line 743 (inside `Tip:Initialize`) in the same task/commit as the function definition removal.
**Warning signs:** Running the fengari suite after only removing one call site immediately fails every test that calls `loader.load()` (which is all of them, since `load()` triggers `ForEachModule("Initialize")`) with a "attempt to call a nil value (upvalue 'CacheSpellTexture')" error — this would be caught immediately, but is avoidable up front by grepping both call sites first.

### Pitfall 2: `ClassifySpellID` has no existing test-facing export
**What goes wrong:** A task that tries to write `assert.equals("consumer", ClassifySpellID(265189))` directly inside `spec/tip_spec.lua` will fail to compile/run — `ClassifySpellID` is a `local function` scoped to `Duncedmaxxing/Modules/TipOfTheSpear.lua`'s file chunk and is invisible outside it. Unlike `MergeDefaults`/`NormalizeDB` in Core.lua, TipOfTheSpear.lua has no `Tip._test` table today.
**Why it happens:** D-06 was scoped at the "what to assert" level in CONTEXT.md; the "how is it reachable" question was explicitly flagged in this research's brief as an open item, and grep confirms the answer is "it isn't, yet."
**How to avoid:** Add a `Tip._test = { ClassifySpellID = ClassifySpellID }` table near the bottom of `TipOfTheSpear.lua` (mirroring `DMX._test`'s existing pattern and comment) as a prerequisite step before/alongside D-06's test edits. Reference it in specs as `Tip._test.ClassifySpellID(...)`.
**Warning signs:** A `describe`/`it` body error surfaces in the fengari runner as `describe('...') body error: ... attempt to call a nil value (global 'ClassifySpellID')` — the runner's `pcall`-wrapped `describe` (see `spec/run.cjs` shim) makes this failure visible immediately at suite-load time rather than deep in a stack trace.

### Pitfall 3: No existing test covers spell ID 1262293 to attach a classify assertion to
**What goes wrong:** D-06 asks to apply the classify assertion to "the Raptor Swipe siblings `1262293` and `1262343`," but only `1262343` has a dedicated `it()` block in `spec/tip_spec.lua` (lines 211-218). `1262293` currently appears only in the `CONSUMERS` table (`TipOfTheSpear.lua:26`) with zero spec coverage.
**Why it happens:** `1262293` (base Raptor Swipe) was likely covered indirectly by the generic `186270`-style consumer tests at the time it was added, and a dedicated regression test was never written for it specifically (only its ranged-Aspect sibling `1262343` got one, alongside `265189`).
**How to avoid:** Add one new minimal `it()` block for `1262293` (classify-only assertion, or classify + decrement like its siblings) rather than silently dropping coverage for it. This keeps parity with the other two "regression" spell IDs and matches D-06's intent of "guard CONSUMERS membership."
**Warning signs:** If the plan doesn't call this out explicitly, an executor may assume the assertion belongs somewhere that doesn't exist and either skip it or bolt it onto an unrelated test.

### Pitfall 4: fengari is not installed locally in every environment (including this research sandbox)
**What goes wrong:** Running `node spec/run.cjs` directly fails with `Cannot find module 'fengari'` if `fengari` isn't present in a local `node_modules/` (there is currently no `node_modules/` or `package.json` committed to this repo at all).
**Why it happens:** The project deliberately has no build toolchain/lockfile (per CLAUDE.md); `spec/run.cjs`'s own header comments document the intended invocation as `node spec/run.cjs || npx -y -p fengari@0.1.5 node spec/run.cjs` specifically to handle this.
**How to avoid:** Always invoke the suite via `npx -y -p fengari@0.1.5 node spec/run.cjs` (confirmed working in this research session: 125/125 passed) unless a local `node_modules/fengari` is confirmed present first.
**Warning signs:** `[run.cjs] ERROR: fengari is not locally resolvable...` — this is a clear, actionable error message already built into the harness, not a silent failure.

### Pitfall 5: luacheck is not available in this sandbox environment
**What goes wrong:** `.luacheckrc` exists and configures `std = lua51` with curated globals, and CLAUDE.md/CONTEXT.md require "`luacheck` must stay at zero warnings" — but this research session found no `luacheck` binary, no `luarocks`, and no system Lua interpreter at all in the current sandbox (`which luacheck` / `which luarocks` / `which lua` all empty).
**Why it happens:** luacheck is a LuaRocks-installed tool (per STATE.md decision log: "luacheck 1.2.0 installed via luarocks"); it was installed in whatever environment ran Phase 2/4, not necessarily the environment executing this phase.
**How to avoid:** Before claiming "luacheck: zero warnings" as a verification step, the plan/executor must first confirm luacheck is actually installed in the current execution environment (`which luacheck`). If unavailable, this becomes an Environment Availability gap requiring either (a) an install step (`luarocks install luacheck`), or (b) a documented fallback of manual review + a `checkpoint:human-verify` task noting luacheck must be run in an environment where it's available (e.g., CI, or the developer's own machine) before merge.
**Warning signs:** `luacheck: command not found` when the verification step attempts to run it.

## Code Examples

### Existing `_test` escape-hatch pattern (to replicate on `Tip`)
```lua
-- Source: Duncedmaxxing/Core.lua:234-241 (this repo, verified 2026-07-09)
-- Test-only escape hatch: exposes local functions for spec/core_spec.lua
-- Do not use in production addon code.
DMX._test = {
    MergeDefaults      = MergeDefaults,
    NormalizeDB        = NormalizeDB,
    CopyDefaults       = CopyDefaults,
    SETTINGS_MIGRATION = SETTINGS_MIGRATION,
}
```

### Current (pre-cleanup) generator-branch comment to be rewritten per D-03
```lua
-- Source: Duncedmaxxing/Modules/TipOfTheSpear.lua:655-661 (current state, verified 2026-07-09)
if kind == "generator" then
    -- Kill Command grant derives from Primal Surge (base 1, +1 with Primal Surge).
    -- Flat-2 fallback: Primal Surge spell ID was not verified offline; grant is 2 in all cases.
    -- Twin Fangs is a Takedown (consumer) modifier only and must NOT affect the generator path.
    local grant = 2  -- flat-2 fallback (hasPrimalSurge field reserved for future ID resolution)
    self.stacks = ClampStacks(self.stacks + grant)
    self.expiresAt = now + BUFF_DURATION
```
Per D-03, replace the first two comment lines and the inline comment with a single, non-contradictory statement, e.g.:
```lua
if kind == "generator" then
    -- Kill Command (generator) always grants 2 stacks. Twin Fangs is a Takedown
    -- (consumer) modifier only and must NOT affect this generator path.
    local grant = 2
    self.stacks = ClampStacks(self.stacks + grant)
    self.expiresAt = now + BUFF_DURATION
```

### Confirmed test-harness invocation (verified working, 125/125)
```bash
# Source: this research session, run against current dev branch HEAD (2026-07-09)
npx -y -p fengari@0.1.5 node spec/run.cjs
# ...
# --- Results ---
# 125 passed, 0 failed, 125 total
```

## State of the Art

Not applicable in the "library upgrade" sense — no dependency versions change in this phase. The only "before/after" state relevant to this research is the addon's own tech-debt state:

| Old Approach | Current/Target Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `hasPrimalSurge` field reserved for future spell-ID resolution, read by nothing | Field removed; flat-2 generator grant documented as permanent | This phase (D-01/03) | Removes a source of future confusion; no runtime behavior change (field was already never read by `ApplySpell`) |
| `Tip.spellTexture` cached at Initialize/PLAYER_LOGIN for icon-mode rendering | Field, cache function, and fallback constant removed entirely | This phase (D-04) | Icon mode was already removed in Phase 5 (DISP-01); this closes the orphaned cache that outlived its consumer |
| `ParseOnOff` extracted for a slash on/off syntax that no longer exists (slash reduced to settings-only in quick task 260624-0hx) | Function and export removed entirely | This phase (D-05) | Zero behavior change; removes dead exported surface flagged by the integration checker |
| 265189/1262343 regression tests call `ApplySpell` directly, bypassing `ClassifySpellID` | Tests additionally assert `ClassifySpellID(...)  == "consumer"` via new `Tip._test` export | This phase (D-06) | Tests now actually guard `CONSUMERS` table membership, not just the decrement arithmetic (closes WR-03 from the audit) |

**Deprecated/outdated:** None of the deleted symbols were ever "current" — they were dead from the moment their consuming feature (icon mode, slash-based on/off parsing, unresolved Primal Surge spell ID) was removed or never wired in earlier phases.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Adding a `1262293`-specific `it()` block is the right way to close the D-06 coverage gap for that spell ID (rather than, e.g., extending an existing generic consumer test) | Pitfall 3 / Symbol Location Table | Low — this is a test-authoring style choice with no functional consequence either way; flagged as a recommendation, not a hard requirement, and left at planner/executor discretion consistent with CONTEXT.md's existing discretion grant for test restructuring |
| A2 | `Tip._test = { ClassifySpellID = ClassifySpellID }` (mirroring `DMX._test`) is an acceptable mechanism to satisfy D-06, since CONTEXT.md itself didn't specify HOW `ClassifySpellID` should become test-reachable | Architecture Patterns / Pitfall 2 | Low-medium — this is the only existing precedent in the codebase (`DMX._test`) and is the minimal, most consistent option; an alternative (e.g., making `ClassifySpellID` a `Tip` method instead of a file-local function) would be a larger, unrequested refactor and is NOT recommended |

**If this table is empty:** N/A — see entries above. Both assumptions are low-risk implementation-detail choices, not domain/compliance/security claims, and both are grounded in an existing in-repo precedent (`DMX._test`) rather than external/training-data knowledge.

## Open Questions

1. **Should the `Tip._test` table addition itself be treated as a distinct D-ID/task, or folded into D-06's task?**
   - What we know: It's a strict prerequisite for D-06's assertions to be writable at all.
   - What's unclear: CONTEXT.md doesn't call it out as its own decision point (it wasn't known to be missing until this research).
   - Recommendation: Fold it into the same task/commit as D-06 (adding the export and using it are naturally one unit of work), but call it out explicitly in the plan's task description so it isn't silently skipped.

2. **Does the plan need a dedicated test for `1262293` alone, or is classify-only coverage (no decrement assertion) sufficient?**
   - What we know: `1262343` and `265189` both have full decrement-behavior tests; `1262293` has none.
   - What's unclear: D-06's exact wording ("apply the same classify assertion... to the Raptor Swipe siblings 1262293 and 1262343") could be read as "just add the classify check," implying a minimal new test is fine even without a decrement assertion.
   - Recommendation: A minimal classify-only `it()` for `1262293` satisfies the literal decision text; adding the decrement assertion too costs nothing extra and closes a genuine pre-existing coverage gap — recommend doing both while the test is being touched anyway.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Node.js | Running `spec/run.cjs` | ✓ | v22.23.0 (this sandbox) | — |
| fengari (npm package) | Lua-VM-in-JS test execution | ✗ locally (no `node_modules/`) | 0.1.5 pinned in `spec/run.cjs` comments | `npx -y -p fengari@0.1.5 node spec/run.cjs` — confirmed working (125/125) |
| luacheck | Zero-warnings lint gate (CLAUDE.md/CONTEXT.md requirement) | ✗ | — (none found: no luacheck, no luarocks, no lua binary in this sandbox) | No local fallback found. Requires `luarocks install luacheck` in an environment with LuaRocks + Lua 5.1, OR defer lint verification to CI/developer machine and gate the plan's lint-check task behind `checkpoint:human-verify` if this sandbox is the execution environment |
| Lua 5.1 interpreter | Native `busted`/luacheck execution (not needed for the fengari path) | ✗ | — | Not required for running the test suite (fengari provides the VM in-process); only needed for luacheck itself |
| GitHub Actions release workflow | Not touched by this phase | ✓ (exists on `main`, per `git log`) | `.github/workflows/release.yml` | N/A — this phase doesn't touch CI/CD |

**Missing dependencies with no fallback:**
- luacheck — no local fallback exists in this sandbox; the plan must either install it, run it in a different environment, or add a `checkpoint:human-verify` task for lint verification.

**Missing dependencies with fallback:**
- fengari — use the documented `npx -y -p fengari@0.1.5 node spec/run.cjs` invocation; confirmed working.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Custom busted-compatible shim running inside fengari (Lua-VM-in-JS), NOT native busted despite the `.busted` config file present in the repo root |
| Config file | `spec/run.cjs` (the actual runner); `.busted` exists but is vestigial/unused by this harness — `spec/run.cjs` discovers `*_spec.lua` files itself via `fs.readdirSync` |
| Quick run command | `npx -y -p fengari@0.1.5 node spec/run.cjs` (full suite; there is no filtered/single-file run mode built into `run.cjs` — it always loads every `*_spec.lua` in `spec/`) |
| Full suite command | Same as above — the "quick" and "full" commands are identical in this harness; there is no faster subset mode |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| D-01/D-02/D-03 | `hasPrimalSurge` fully removed; no orphaned references; generator grant still always 2 | unit (existing, edited) + grep-absence | `npx -y -p fengari@0.1.5 node spec/run.cjs` + `grep -rn "hasPrimalSurge" Duncedmaxxing/ spec/` (expect zero matches) | ✅ `spec/tip_spec.lua` (edited, not new) |
| D-04 | `spellTexture`/`CacheSpellTexture`/`FALLBACK_ICON` fully removed; no orphaned references; both call sites gone | unit (existing tests deleted) + grep-absence | `npx -y -p fengari@0.1.5 node spec/run.cjs` + `grep -rn "spellTexture\|CacheSpellTexture\|FALLBACK_ICON" Duncedmaxxing/ spec/` (expect zero matches) | ✅ `spec/tip_spec.lua` (edited) |
| D-05 | `ParseOnOff` fully removed; no orphaned references | unit (existing describe block deleted) + grep-absence | `npx -y -p fengari@0.1.5 node spec/run.cjs` + `grep -rn "ParseOnOff" Duncedmaxxing/ spec/` (expect zero matches) | ✅ `spec/util_spec.lua` (edited) |
| D-06 | `ClassifySpellID(265189)`, `ClassifySpellID(1262293)`, `ClassifySpellID(1262343)` all return `"consumer"` | unit (new assertions + new `Tip._test` export) | `npx -y -p fengari@0.1.5 node spec/run.cjs` | ⚠️ `spec/tip_spec.lua` needs edits; `Tip._test` table needs to be added to `Duncedmaxxing/Modules/TipOfTheSpear.lua` first |
| D-07 | `db.locked = true` after migration (behavior unchanged, comment added) | unit (already exists, passing) | `npx -y -p fengari@0.1.5 node spec/run.cjs` | ✅ `spec/core_spec.lua:141-145` (no edit needed — already covers the behavior) |
| Overall | Full suite green; no new failures introduced by any deletion | full suite | `npx -y -p fengari@0.1.5 node spec/run.cjs` | ✅ baseline confirmed 125/125 passing before this phase's changes |
| Lint | luacheck zero warnings | static analysis | `luacheck Duncedmaxxing/` (requires luacheck installed — see Environment Availability gap) | ⚠️ tool unavailable in this research sandbox; verify availability in execution environment before treating as an automated gate |

### Sampling Rate
- **Per task commit:** `npx -y -p fengari@0.1.5 node spec/run.cjs` (full suite — there is no faster subset; test count is 125, runs in well under a second)
- **Per wave merge:** Same full-suite command, plus a `grep -rn "<removed-symbol>" Duncedmaxxing/ spec/` sweep for every symbol removed so far in the phase
- **Phase gate:** Full suite green (expect 125 - (deleted tests) + (new D-06 tests) total) before `/gsd-verify-work`; `luacheck` zero-warnings if the tool is available in the execution environment, otherwise a documented `checkpoint:human-verify` for lint

### Wave 0 Gaps
None — existing test infrastructure (`spec/run.cjs`, `spec/support/init.lua`, `spec/support/wow_stubs.lua`) fully covers this phase's needs. The one net-new piece of test infrastructure required is the `Tip._test` export table inside production code (`Duncedmaxxing/Modules/TipOfTheSpear.lua`), which is a one-time addition needed specifically to unblock D-06, not a gap in the harness itself.

## Security Domain

Not applicable in the traditional sense (no auth, no network, no user input parsing changes) — this is a Lua 5.1 WoW addon with no server-side component, and this phase deletes code rather than adding attack surface. Noting for completeness per the mandatory template:

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | N/A — no auth in a WoW addon |
| V3 Session Management | No | N/A |
| V4 Access Control | No | N/A |
| V5 Input Validation | No (no new input paths added; `ParseOnOff`'s removal actually reduces the addon's string-parsing surface) | N/A |
| V6 Cryptography | No | N/A |

### Known Threat Patterns for this stack
None applicable — this phase has no new user input, no network calls, no serialization of untrusted data. `db.locked`'s migration-gate logic (D-07) is a pure boolean UI-state flag with no security implication (it controls whether the frame can be dragged, not any privileged operation).

## Sources

### Primary (HIGH confidence — verified directly in this session)
- `Duncedmaxxing/Modules/TipOfTheSpear.lua` (full file read, 2026-07-09) — confirmed all D-01/02/03/04/06 symbol locations, discovered the second `CacheSpellTexture` call site (line 743) and confirmed `ClassifySpellID` has no existing export
- `Duncedmaxxing/Util.lua` (full file read, 2026-07-09) — confirmed D-05 symbol locations
- `Duncedmaxxing/Core.lua` (full file read, 2026-07-09) — confirmed D-07's `db.locked` line and the existing `DMX._test` pattern to replicate
- `spec/tip_spec.lua`, `spec/util_spec.lua`, `spec/support/init.lua`, `spec/core_spec.lua`, `spec/run.cjs` (full reads, 2026-07-09) — confirmed test coverage, harness mechanics, and the pre-existing `db.locked` migration test
- `npx -y -p fengari@0.1.5 node spec/run.cjs` (executed live, 2026-07-09) — confirmed 125/125 passing baseline before this phase's changes
- `grep -rn` sweeps across `Duncedmaxxing/` and `spec/` for every symbol slated for removal — confirmed zero unexpected production references (only the two `CacheSpellTexture` call sites required correction of CONTEXT.md's canonical_refs)
- `which luacheck / luarocks / lua` (executed live, 2026-07-09) — confirmed none present in this sandbox, informing the Environment Availability gap

### Secondary (MEDIUM confidence)
- `.planning/v1.0-MILESTONE-AUDIT.md` — the audit that surfaced every tech-debt item; cross-checked against live grep and found accurate except for the missing second `CacheSpellTexture` call site
- `.planning/phases/07-.../07-CONTEXT.md` — user decisions D-01 through D-07; treated as authoritative scope, cross-verified against the actual code

### Tertiary (LOW confidence)
None — this research required no external web sources; it is entirely a codebase-internal audit with no new libraries or APIs involved.

## Metadata

**Confidence breakdown:**
- Standard stack: N/A — no new stack/dependencies in this phase
- Symbol locations / removal safety: HIGH — every claim grep-verified against the live working tree in this session
- Test-harness mechanics (`ClassifySpellID` exposure gap, fengari invocation): HIGH — confirmed by direct execution and code reading, not inference
- luacheck availability: HIGH confidence that it's absent in THIS sandbox; MEDIUM confidence about the execution environment the plan will actually run in (flagged as an open Environment Availability item, not assumed either way)

**Research date:** 2026-07-09
**Valid until:** Effectively indefinite for the symbol-location findings (this is a point-in-time grep of the current tree — re-verify only if the branch is rebased/changed before execution). Recommend re-running the grep sweep immediately before execution if more than a few days pass, per standard practice, though no fast-moving external dependency exists here.
