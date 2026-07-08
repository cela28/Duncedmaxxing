# Phase 3: Bug Fixes with Test Coverage - Context

**Gathered:** 2026-06-18
**Status:** Ready for planning

<domain>
## Phase Boundary

All known correctness bugs are fixed and covered by the test suite, and the dead migration fallback is removed with idempotency confirmed by tests. This phase delivers BUG-01, BUG-02, BUG-03, BUG-04, and QUAL-03 from REQUIREMENTS.md.

</domain>

<decisions>
## Implementation Decisions

### Talent Detection (BUG-03, BUG-04)
- **D-01:** Use dual-path talent API: `C_SpellBook.IsSpellKnown(1272139)` with fallback to `IsPlayerSpell(1272139)` for detecting Twin Fangs talent. This matches the existing dual-path pattern used for `GetSpecialization` and `GetSpellTexture` in the codebase.
- **D-02:** Twin Fangs spell ID is **1272139** (passive talent). Verified via warcraft.wiki.gg and wowhead.
- **D-03:** Cache talent state on `PLAYER_TALENT_UPDATE` and `PLAYER_SPECIALIZATION_CHANGED` events only. No per-cast API call — talent state does not change during combat.
- **D-04:** Twin Fangs + Takedown mechanic: the talent grant fires FIRST (+3 stacks, capped at MAX_STACKS), THEN the consumer effect fires (-1 stack). With Twin Fangs active, Takedown is net +2 regardless of starting stack count. Example: 1 stack → grant 3 (cap to 3) → consume 1 → 2 stacks.
- **D-05:** `IsPlayerSpell` is deprecated in patch 11.2.0 with `C_SpellBook.IsSpellKnown` as the replacement (added 11.2.0). Both are available on the addon's target (Interface 120005 = 12.0.5). Dual-path ensures forward compatibility.

### Stuck Flag Fix (BUG-01)
- **D-06:** Clear `auraVerifyPending` on every exit path of the timer callback, including the serial-mismatch early return. This is a one-line fix — add the flag clear before the early return at the serial-mismatch check. Existing `ScheduleCastVerify` serial-mismatch tests in `spec/tip_spec.lua` will be extended to cover this path.

### Mode-Switch Refresh (BUG-02)
- **D-07:** On display mode switch out of combat, trigger a fresh `SyncFromAura` call so stale stack counts from a previous fight are not displayed. Claude decides the exact trigger scope (mode changes only vs any settings change) and whether the sync is unconditional or conditional on current stack state.

### Migration Cleanup (QUAL-03)
- **D-08:** Remove the dead post-migration fallback block (Core.lua lines 98-106) that unconditionally reads deprecated `barWidth`, `barHeight`, and `spacing` fields. The migration gate above (lines 77-96) already clears these fields and sets `settingsMigration`, making the fallback unreachable for any user who has passed the migration gate.
- **D-09:** No migration version bump. This is dead code removal, not a behavior change. The `SETTINGS_MIGRATION` string stays at its current value.

### Claude's Discretion
- D-04 implementation: Claude decides how to structure the talent-aware stack grant mapping — whether ClassifySpellID returns amounts directly, or a separate function maps kind + talent state to amounts.
- D-07 scope: Claude decides whether the aura refresh triggers on mode changes only or any settings change, and whether the sync is unconditional or conditional.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project Context
- `.planning/PROJECT.md` — Core value, constraints, key decisions
- `.planning/REQUIREMENTS.md` — BUG-01 through BUG-04 and QUAL-03 define exact deliverables and acceptance criteria

### Prior Phase Context
- `.planning/phases/01-utility-extraction-and-module-encapsulation/01-CONTEXT.md` — D-02 (DMX.Util.* namespace), D-06/D-08 (Tip.* frame fields), D-11 (ClassifySpellID pcall removed). Phase 3 code changes build on Phase 1 structural changes.
- `.planning/phases/02-test-framework-and-core-logic-tests/02-CONTEXT.md` — Test infrastructure decisions (D-05 loader, D-06 isolation, D-08 mock clock). Phase 3 tests must follow these established patterns.

### Architecture & Testing
- `.planning/codebase/TESTING.md` — Test infrastructure details, existing coverage map, mock patterns, adding new tests guide
- `.planning/codebase/CONCERNS.md` — Detailed bug descriptions with file locations, line numbers, trigger conditions, and workaround analysis for BUG-01, BUG-02, BUG-03

### Source Files (fix targets)
- `Duncedmaxxing/Modules/TipOfTheSpear.lua` — Contains: ClassifySpellID (line 50), ApplySpell (line 675), ScheduleAuraVerify/auraVerifyPending (lines 418-442), OnEvent handler (line 697)
- `Duncedmaxxing/Core.lua` — Contains: NormalizeDB with dead fallback block (lines 74-111), SETTINGS_MIGRATION constant

### Test Files (extend for bug coverage)
- `spec/tip_spec.lua` — Existing ApplySpell, SyncFromAura, ScheduleCastVerify tests. Extend for Twin Fangs, stuck flag, and mode-switch scenarios.
- `spec/core_spec.lua` — Existing NormalizeDB tests. Extend to confirm dead fallback removal doesn't affect idempotency.
- `spec/support/wow_stubs.lua` — Mock layer. May need `C_SpellBook.IsSpellKnown` and `IsPlayerSpell` stubs for talent detection tests.
- `spec/support/init.lua` — Test loader. May need talent state reset in `resetTipState`.

### External References
- warcraft.wiki.gg — Canonical source for: `IsPlayerSpell` API (deprecated 11.2.0), `C_SpellBook.IsSpellKnown` API (added 11.2.0), Twin Fangs talent (spell ID 1272139)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `ClassifySpellID` (TipOfTheSpear.lua:50): Pure table lookup returning "generator"/"consumer" — extend or replace to support talent-aware classification
- `ClampStacks` (TipOfTheSpear.lua:43): Already handles capping at MAX_STACKS and flooring at 0
- Dual-path API pattern: `C_SpecializationInfo.GetSpecialization` / `GetSpecialization` fallback in Core.lua, `C_Spell.GetSpellTexture` / `GetSpellTexture` fallback in TipOfTheSpear.lua — reuse this pattern for `C_SpellBook.IsSpellKnown` / `IsPlayerSpell`
- `mockClock` and `mockAura` test infrastructure: reuse for timer and aura verification in new bug-fix tests
- `loader.resetTipState` (spec/support/init.lua:51): resets all mutable Tip fields — extend to include talent cache field

### Established Patterns
- Event-driven state updates: talent state should follow the same pattern as combat state (`PLAYER_REGEN_DISABLED`/`ENABLED` → `self.inCombat`)
- Per-test isolation via `loader.load()` in `before_each`: all new tests must follow this pattern
- `stubs.mockAura.impl` override pattern for controlling aura returns per test

### Integration Points
- `Tip:OnEvent` handler (line 697): needs `PLAYER_TALENT_UPDATE` event registration for talent cache refresh
- `Tip:ApplySpell` (line 675): the +2 hardcode on line 679 is the primary fix target for BUG-03/BUG-04
- `Tip:ScheduleAuraVerify` timer callback (lines 437-442): add `auraVerifyPending = false` before early return for BUG-01
- `RefreshTip` call path in Core.lua slash handler (line 285) and Options callbacks: the mode-switch entry point for BUG-02

</code_context>

<specifics>
## Specific Ideas

- Twin Fangs order of operations is critical: grant fires BEFORE consume. The prediction must model: clamp(stacks + 3, MAX_STACKS) - 1, NOT clamp(stacks - 1, 0) + 3. This produces different results when stacks are at 0.
- Existing `pending("Twin Fangs (BUG-04)")` test in spec/tip_spec.lua should be implemented as part of this phase.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 3-Bug Fixes with Test Coverage*
*Context gathered: 2026-06-18*
