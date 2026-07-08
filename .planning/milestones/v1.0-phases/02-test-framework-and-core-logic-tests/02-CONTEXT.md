# Phase 2: Test Framework and Core Logic Tests - Context

**Gathered:** 2026-06-17
**Status:** Ready for planning

<domain>
## Phase Boundary

A passing offline test suite exists that covers all pure-logic functions — utility functions, DB migration, stack application, and aura reconciliation — running under busted with Lua 5.1 without the WoW client. luacheck enforces zero warnings on all addon source files. This phase delivers TEST-01 through TEST-07 from REQUIREMENTS.md.

</domain>

<decisions>
## Implementation Decisions

### WoW API Mock Layer (TEST-02)
- **D-01:** Minimal stubs — WoW API functions return fixed values or nils. No behavioral simulation of frame hierarchies or event dispatch. Tests target pure logic, not WoW rendering.
- **D-02:** CreateFrame returns a table with no-op widget methods. Claude decides whether to track minimal state (e.g., `.visible` on Show/Hide, `.text` on SetText) based on what test assertions actually need.
- **D-03:** Full wiki contract fidelity — every field documented on warcraft.wiki.gg for each stubbed function must be present in the mock return values, even if tests don't use them all. This prevents tests from silently depending on absent fields and catches drift between stubs and real API.
- **D-04:** Stubs required: `C_UnitAuras.GetPlayerAuraBySpellID`, `C_Timer.After`, `C_Timer.NewTimer`, `C_SpecializationInfo.GetSpecialization`, `C_Spell.GetSpellTexture`, `UnitClass`, `GetTime`, `CreateFrame`, `InCombatLockdown`, `UIParent`, `GetSpecialization` (fallback global).

### Test Loading Strategy (TEST-01)
- **D-05:** Helper dofile approach — a `spec/support/init.lua` sets up `_G` globals (WoW stubs), creates the DMX namespace table, then `dofile()`s addon source files in TOC order. This mirrors WoW's actual load sequence.
- **D-06:** Each spec file reloads source files from scratch via the init helper. Full isolation between test files — no leaked state between specs. Catches hidden coupling at the cost of slightly slower runs.
- **D-07:** Claude decides whether to provide a `resetTipState()` helper or have tests manipulate `Tip.*` fields directly, based on what makes tests most readable and maintainable.

### Timer Simulation (TEST-03, TEST-04)
- **D-08:** Controllable mock clock — `GetTime()` returns a value from a mock clock that tests advance manually (e.g., `mockClock:advance(2.0)`). `C_Timer.After` stores callbacks and fires them when the clock passes their scheduled time. This enables testing expiry scheduling, grace period suppression, and serial-mismatch timing without real delays.
- **D-09:** Claude decides whether timers auto-fire on clock advance or require a separate flush call, based on what produces the clearest test code.

### luacheck Configuration (TEST-07)
- **D-10:** Addon-specific `read_globals` only — declare only the WoW globals the addon actually references (CreateFrame, C_UnitAuras, C_Timer, C_Spell, C_SpecializationInfo, UnitClass, GetTime, InCombatLockdown, UIParent, SlashCmdList, DEFAULT_CHAT_FRAME, etc.). This catches accidental use of WoW globals the addon doesn't intend to depend on.
- **D-11:** Lint addon source files only (`Duncedmaxxing/*.lua`, `Duncedmaxxing/Modules/*.lua`). Spec files are excluded — they have their own globals (describe, it, assert) and different rules.

### Claude's Discretion
- D-02: Whether CreateFrame stubs track minimal state (visibility, text) or are completely inert — decide based on test assertion needs.
- D-07: Whether to provide a `resetTipState()` helper or have tests manipulate Tip fields directly.
- D-09: Whether the mock clock auto-fires timers on advance or uses a separate flush step.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project Context
- `.planning/PROJECT.md` — Core value, constraints, key decisions (busted Lua 5.1 flag requirement)
- `.planning/REQUIREMENTS.md` — TEST-01 through TEST-07 define exact deliverables and acceptance criteria

### Phase 1 Output (prerequisite)
- `.planning/phases/01-utility-extraction-and-module-encapsulation/01-CONTEXT.md` — D-02 (DMX.Util.* namespace), D-06/D-08 (Tip.* frame fields), D-09 (moduleOrder). Tests target these new locations.

### Architecture & Patterns
- `.planning/codebase/TESTING.md` — Coverage gaps, recommended test priority order, manual test scenarios
- `.planning/codebase/CONVENTIONS.md` — Naming patterns, file organization, error handling conventions (tests should follow same style)
- `.planning/codebase/STRUCTURE.md` — Directory layout, TOC load order, where to add test files

### Source Files (test targets)
- `Duncedmaxxing/Util.lua` — Shared utilities: Clamp, ParseHexColor, Trim, ParseOnOff (TEST-06)
- `Duncedmaxxing/Core.lua` — NormalizeDB, MergeDefaults, module registry (TEST-05)
- `Duncedmaxxing/Modules/TipOfTheSpear.lua` — ApplySpell, SyncFromAura, ClassifySpellID, ScheduleExpiration (TEST-03, TEST-04)

### External References
- warcraft.wiki.gg — Canonical source for WoW API return contracts. Mock stubs MUST be verified against wiki pages for: `C_UnitAuras.GetPlayerAuraBySpellID`, `C_Timer.After`, `C_Timer.NewTimer`, `C_SpecializationInfo.GetSpecialization`, `C_Spell.GetSpellTexture`

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `DMX.Util.*` namespace (Phase 1 output): Clamp, ParseHexColor, Trim, ParseOnOff — pure functions, zero WoW dependencies, easiest test targets
- `Tip.*` fields (Phase 1 output): stacks, expiresAt, root, pips, borders, label, numberText — all accessible for test setup and assertion
- `DMX:RegisterModule("tip", Tip)` at file bottom: tests can call this to wire up the module after dofile
- `Tip:SetTestStacks()` existing test mode: reference for what fields the addon considers "state" worth resetting

### Established Patterns
- WoW addon private namespace via vararg: `local _, DMX = ...` — init helper must simulate this by setting globals before dofile
- Module self-registration at file bottom: test loading must handle modules registering themselves on load
- `GetCfg()` local helper pattern in each file: returns `DMX:GetDB().tip` — tests need a mock DB with `.tip` subtable
- Early-return nil-guard pattern throughout: tests should verify functions return nil/early-return on missing state, not crash

### Integration Points
- `spec/` directory at repo root (standard busted convention)
- `spec/support/wow_stubs.lua` — mock layer file (TEST-02)
- `spec/support/init.lua` — test loader/bootstrap
- `.busted` config file at repo root (busted project config)
- `.luacheckrc` at repo root (luacheck config)

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 2-Test Framework and Core Logic Tests*
*Context gathered: 2026-06-17*
