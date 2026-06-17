# Project Research Summary

**Project:** Duncedmaxxing — WoW Addon Polish & Test Infrastructure
**Domain:** World of Warcraft addon (Lua 5.1 sandbox) — combat stack tracker, polish milestone
**Researched:** 2026-06-17
**Confidence:** HIGH

## Executive Summary

Duncedmaxxing is a working WoW addon that tracks Tip of the Spear stacks for Survival Hunter using predictive (pre-server-confirmation) logic. This milestone is a polish pass, not a greenfield build: the addon functions but has two active correctness bugs, zero automated test coverage, per-update performance violations, and duplicated utility code that has already diverged. The research-validated approach is to treat this as a structured refactor with a clear dependency order: extract utilities first, establish the busted test framework second, fix bugs with test coverage third, and clean up performance and code quality last. Doing these steps out of order introduces risk — tests written before module encapsulation is fixed require deep frame mocks; performance changes made before test coverage exists have no regression protection.

The principal risk in this milestone is the WoW Lua 5.1 sandbox itself. There is no `require`, no filesystem, and all WoW API globals must be stubbed for offline testing. The community consensus (busted + hand-written WoW API stubs, loaded via `dofile` inside `insulate` blocks) is the right approach; the two alternatives (wowmock, WoWUnit) are either unmaintained or require running inside the live WoW client. A second major risk is the SavedVariables migration gate: accidentally broadening the gate constant during cleanup will permanently wipe all player settings with no recovery path. Both risks are addressed by the phase order recommended below.

The differentiator this addon offers — predictive stack display before server confirmation — is already implemented and working. The test suite and refactor exist to protect it, not to rebuild it. `ApplySpell` and `SyncFromAura` are the crown-jewel functions; they are pure enough to unit-test without a full WoW environment and are the highest-value test targets in the codebase.

## Key Findings

### Recommended Stack

The test stack is narrow and appropriate: busted 2.3.0 (Lua unit test runner) with luassert spies/stubs built in, luacheck 1.2.0 for static analysis, and StyLua 2.5.2 for formatting. All three have explicit Lua 5.1 support. The critical installation constraint is that busted must be installed with `--lua-version=5.1` — installing without this flag produces a busted binary running under Lua 5.4 where `setfenv` is unavailable, causing silent test incompatibilities. No external testing framework should be added beyond these three.

**Core technologies:**
- **busted 2.3.0**: Lua unit test runner — de-facto standard; `insulate` blocks restore `_G` between tests, exactly what WoW global injection requires
- **luacheck 1.2.0**: Static analysis — only mature Lua linter; `read_globals` lets you declare the WoW API surface without false positives
- **StyLua 2.5.2**: Code formatter — deterministic, binary install, `syntax = "Lua51"` setting required

**Supporting:**
- **luassert** (bundled with busted): spies and stubs for WoW API calls
- **Lua 5.1 system runtime**: busted must run under `lua5.1`, not the system default (likely 5.4 on modern Ubuntu)

### Expected Features

This is a polish milestone. "Features" are quality characteristics the addon must have, not new capabilities to build. See `.planning/research/FEATURES.md` for the full prioritization matrix.

**Must have (table stakes — active violations exist):**
- Zero Lua errors under normal use — `auraVerifyPending` stuck-flag bug causes silent wrong state
- Correct stack display at all times — `+2` hard-code for Kill Command and stale display on mode-switch are active violations
- Predictable settings persistence — dead migration fallback is a corruption risk
- No per-frame garbage in combat — `ResolveSpellTexture` and `IsSurvivalHunter` called on every Update tick

**Should have (differentiator-protecting):**
- Unit test coverage for `ApplySpell`, `SyncFromAura`, `NormalizeDB`, and utility functions — the prediction logic is the crown jewel; tests protect confident iteration
- Spec/texture result caching — removes per-update WoW API calls without changing behavior
- Frame locals moved to `Tip.*` table fields — prerequisite for ApplySpell/SyncFromAura tests without a full frame mock

**Defer to next milestone:**
- New tracking modules (Pack Leader, etc.) — out of scope; increases test surface before test infrastructure exists
- Per-module options section convention (`BuildOptionsSection`) — architecture work only needed when a second module exists
- Ace3/LibStub adoption — intentionally dependency-free; not appropriate here

### Architecture Approach

The addon uses a shared namespace table (`DMX`) passed via the WoW vararg idiom (`local addonName, DMX = ...`) across three files loaded in TOC order. There is no `require`; TOC order is the only dependency injection mechanism. The target architecture adds a fourth file (`Duncedmaxxing/Util.lua`, inserted before `Core.lua` in the TOC) and moves module-level upvalue locals (`root`, `pips`, `label`, `numberText`, `borders`) to `Tip.*` table fields so tests can inject mock frames. A single settings setter (`DMX:SetTipConfig`) replaces the current pattern where both `Duncedmaxxing/Options.lua` and `Duncedmaxxing/Core.lua`'s slash handler directly mutate `db.tip.*` independently.

**Major components (target state):**
1. **Duncedmaxxing/Util.lua** — pure functions (Clamp, ParseHexColor, Trim, ParseOnOff); no WoW API calls, no state, fully testable without mocks
2. **Duncedmaxxing/Core.lua** — namespace, DB/migration, module registry, slash commands; settings mutations route through `DMX:SetTipConfig`
3. **Duncedmaxxing/Options.lua** — settings popup UI; uses `DMX.Util.*`; no direct `db.tip` writes
4. **Duncedmaxxing/Modules/TipOfTheSpear.lua** — stack state machine, frame rendering; all frame refs as `Tip.*` fields
5. **spec/** — busted test suite with `spec/support/wow_stubs.lua` as shared WoW API mock table

**Key data flows:**
- Combat events: `UNIT_SPELLCAST_SUCCEEDED` → `ApplySpell` (optimistic update) → `C_Timer` → `SyncFromAura` (sanity check)
- Aura events: `UNIT_AURA` → `ScheduleAuraVerify` → `SyncFromAura` (reconcile with server)
- Settings: Options UI / slash command → `DMX:SetTipConfig` → `db.tip[key]` → `RefreshTip` → `RefreshLayout` → `Update`

### Critical Pitfalls

1. **SavedVariables corruption from migration gate** — `SETTINGS_MIGRATION` constant must never change unless a destructive settings reset is intentional; the dead migration fallback block (Duncedmaxxing/Core.lua lines 125-133) must be removed cleanly with a NormalizeDB idempotency test in place first

2. **Incomplete WoW API mock causing false-passing tests** — every mocked WoW function must match the real API contract (correct return value count, correct table field names); `C_UnitAuras.GetPlayerAuraBySpellID` returns a table with `applications` AND `expirationTime`; `C_Spell.GetSpellTexture` returns two values; stub review against warcraft.wiki.gg must precede writing any test

3. **TOC load order broken after Util.lua extraction** — `Util.lua` must appear in the TOC before `Core.lua`; there is no `require`-based recovery if the order is wrong; verify immediately with `/reload ui` confirming `DMX.Util` is non-nil

4. **`auraVerifyPending` fix introducing a new stuck case** — the obvious fix (clear flag after `SyncFromAura`) misses the early-return serial-mismatch path; fix must clear the flag on ALL exit paths of the timer callback; write the test first, confirm it fails, then apply the fix

5. **Partial frame upvalue migration creating nil dereferences** — all five upvalues (`root`, `pips`, `label`, `numberText`, `borders`) must move to `Tip.*` fields in a single atomic commit; partial migration creates in-game nil dereferences; verify with grep that bare upvalue names no longer appear in function bodies

## Implications for Roadmap

Research establishes a clear dependency graph that should drive phase structure. The architecture and pitfalls research agree on the ordering.

### Phase 1: Utility Extraction and Module Encapsulation

**Rationale:** These are the two structural prerequisites for everything else. Util.lua extraction makes utility functions independently testable (zero mocks needed). Frame locals to Tip fields makes `ApplySpell`/`SyncFromAura` testable without a full WoW frame mock. Neither depends on the other and they can be done in parallel within the phase. Both are low-risk, self-contained changes.

**Delivers:** `Duncedmaxxing/Util.lua` with `Clamp`, `ParseHexColor`, `Trim`, `ParseOnOff`; TOC updated; all five frame upvalues migrated to `Tip.*` fields; `DMX:SetTipConfig` setter added

**Addresses:** Dead utility duplication, encapsulation prerequisite for tests, single settings mutation path

**Avoids:** TOC load-order pitfall (Pitfall 3), partial frame migration pitfall (Pitfall 5)

**Research flag:** Standard patterns — no additional research needed

### Phase 2: Test Framework Setup and Core Logic Tests

**Rationale:** Once Phase 1 is complete, the test surface is clean. This phase establishes the busted infrastructure and writes tests for the functions that have the highest failure cost. Tests must come before bug fixes so the bugs get regression coverage. The mock layer must be reviewed against actual WoW API docs before any test is written (Pitfall 2 prevention).

**Delivers:** busted + luacheck + StyLua installed and configured (`.busted`, `.luacheckrc`, `.stylua.toml`); `spec/support/wow_stubs.lua` with API-accurate mocks; passing test suites for `Clamp`/`ParseHexColor`/`Trim`/`ParseOnOff`, `NormalizeDB`/`MergeDefaults`, `Tip:ApplySpell`, `Tip:SyncFromAura`

**Uses:** busted 2.3.0 (lua 5.1), luacheck 1.2.0, StyLua 2.5.2

**Implements:** `spec/` directory layout from ARCHITECTURE.md; `dofile` + `insulate` loading pattern

**Avoids:** Incomplete mock pitfall (Pitfall 2) — mock review against warcraft.wiki.gg is a gate criterion for this phase

**Research flag:** Needs attention — busted Lua 5.1 installation has one specific gotcha (`--lua-version=5.1` required at LuaRocks install time); the `dofile`-based addon loading pattern in tests is non-obvious; follow STACK.md installation instructions exactly

### Phase 3: Bug Fixes with Test Coverage

**Rationale:** Both active correctness bugs are now fixable with regression tests in place. The `auraVerifyPending` fix is particularly dangerous without tests because the obvious fix misses an exit path. With the test suite from Phase 2 in place, the fix-then-verify loop is fast.

**Delivers:** `auraVerifyPending` stuck-flag bug fixed and covered by `syncfromaura_spec.lua`; stale stack display on mode-switch fixed; dead NormalizeDB migration fallback removed (with NormalizeDB idempotency test confirming safety)

**Addresses:** All P1 correctness items from FEATURES.md

**Avoids:** `auraVerifyPending` new-stuck-case pitfall (Pitfall 4) — test must cover serial-mismatch exit path; migration gate pitfall (Pitfall 1) — idempotency test must pass before fallback removal

**Research flag:** Standard patterns — bugs are fully diagnosed in CONCERNS.md; fix approach is documented in PITFALLS.md

### Phase 4: Performance Caching and Code Quality Cleanup

**Rationale:** With correctness bugs fixed and tests protecting against regressions, the performance and quality cleanup is safe. Spec/texture caching eliminates per-update API calls in combat. Removing the `pcall` from `ClassifySpellID` and adding the `moduleOrder` array are low-risk improvements that are valuable to complete while the codebase is fresh.

**Delivers:** `Tip.isSurvival` cached at `RefreshActive` (no more per-update `C_SpecializationInfo` calls); `Tip.spellTexture` cached at `Initialize` (no more per-update `C_Spell.GetSpellTexture` calls); `pcall` removed from `ClassifySpellID`; `moduleOrder` array added to `ForEachModule`; luacheck and StyLua clean (zero warnings, consistent formatting)

**Addresses:** All P2 items from FEATURES.md feature prioritization matrix

**Avoids:** Per-update spec state performance trap (confirmed by verifying `Update` body has no `RefreshActive` call)

**Research flag:** Standard patterns — caching is a mechanical change, fully specified in ARCHITECTURE.md

### Phase Ordering Rationale

- Phase 1 before Phase 2: tests cannot be written cleanly until Util.lua is extractable and frame upvalues are accessible as table fields — both are prerequisites for the test loading strategy described in ARCHITECTURE.md
- Phase 2 before Phase 3: fixing `auraVerifyPending` without a test that covers the serial-mismatch exit path risks Pitfall 4; the test is the safety net
- Phase 3 before Phase 4: performance caching changes `RefreshActive` behavior; tests from Phase 3 provide regression protection against behavioral changes during caching
- SavedVariables migration gate (Pitfall 1) spans Phases 1 and 3: the dead fallback block removal happens in Phase 3 but requires `SETTINGS_MIGRATION` to be left untouched in Phase 1 during Util extraction

### Research Flags

Phases needing attention during planning:
- **Phase 2 (Test Framework):** busted Lua 5.1 installation gotcha; `dofile`-based addon loading is non-obvious; mock accuracy review is a hard gate criterion, not a follow-up

Phases with well-established patterns (skip research-phase):
- **Phase 1 (Utility Extraction):** mechanical extraction; TOC load order is fully documented
- **Phase 3 (Bug Fixes):** bugs are fully diagnosed; fix approach documented in PITFALLS.md
- **Phase 4 (Caching/Cleanup):** caching pattern is straightforward; target state fully specified in ARCHITECTURE.md

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | busted, luacheck, StyLua all verified with explicit Lua 5.1 support; versions confirmed from LuaRocks and GitHub releases |
| Features | HIGH | Grounded in direct codebase audit (CONCERNS.md) and production WoW addon community standards; "features" are quality characteristics, not speculative user needs |
| Architecture | HIGH | Target architecture derived from the existing 3-file codebase; patterns confirmed working in analogous WoW addons |
| Pitfalls | HIGH | All 5 critical pitfalls rooted in actual codebase (line-level analysis) or confirmed community experience; not speculative |

**Overall confidence:** HIGH

### Gaps to Address

- **In-game smoke test checklist not defined:** The test suite covers pure logic; frame rendering, event registration, and combat-path behavior require in-game verification. Define a specific manual checklist (which display modes, which combat scenarios) before Phase 3 is marked complete.
- **`C_Spell.GetSpellTexture` two-return-value behavior under patch 12.0.5:** STACK.md confirms no C_Timer or C_SpecializationInfo changes in patch 12.0.5 but does not specifically confirm the `GetSpellTexture` return contract. Verify against warcraft.wiki.gg before writing the texture caching in Phase 4.
- **`moduleOrder` array interaction with a future second module:** Adding the array in Phase 4 is low-risk for current single-module state; interaction with a second module (initialization order, shared events) is deliberately deferred but should be noted in Phase 4 implementation.

## Sources

### Primary (HIGH confidence)
- `https://luarocks.org/modules/lunarmodules/busted` — busted 2.3.0, Lua 5.1 support confirmed
- `https://luarocks.org/modules/lunarmodules/luacheck` — luacheck 1.2.0, Lua 5.1 mode
- `https://github.com/JohnnyMorganz/StyLua` — StyLua 2.5.2, Lua51 syntax support
- `https://lunarmodules.github.io/busted/` — insulate block behavior, spy/stub API
- `.planning/codebase/CONCERNS.md` — direct codebase audit (line-level analysis)
- `https://warcraft.wiki.gg/wiki/Patch_12.0.5/API_changes` — API surface changes for target patch
- `https://warcraft.wiki.gg/wiki/API_C_Spell.GetSpellTexture` — two-return-value signature
- `https://warcraft.wiki.gg/wiki/SavedVariables` — SavedVariables write behavior

### Secondary (MEDIUM confidence)
- `https://github.com/dolphinspired/wow-addon-container` — busted + spec/ layout for WoW addons
- `https://warcraft.wiki.gg/wiki/Secure_Execution_and_Tainting` — taint rules, combat lockdown
- `https://github.com/WoWUIDev/Ace3/blob/master/.luacheckrc` — reference luacheckrc for WoW addons
- `https://github.com/BigWigsMods/luacheck/blob/main/.luacheckrc.example` — BigWigsMods config
- `https://github.com/emmericp/Perfy` — flame-graph profiling (not recommended for routine use)

### Tertiary (LOW confidence)
- `https://andydote.co.uk/2014/11/23/good-design-in-warcraft-addons/` — 2014, directionally correct for namespace patterns
- `https://github.com/AdamWagner/stackline/issues/26` — analogous sandboxed Lua testability problem

---
*Research completed: 2026-06-17*
*Ready for roadmap: yes*
