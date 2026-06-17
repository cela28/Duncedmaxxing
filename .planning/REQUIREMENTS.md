# Requirements: Duncedmaxxing — Polish Pass

**Defined:** 2026-06-17
**Core Value:** Accurate, instant stack display during combat

## v1 Requirements

Requirements for the polish milestone. Each maps to roadmap phases.

### Bug Fixes

- [ ] **BUG-01**: auraVerifyPending flag is cleared on every exit path of the timer callback, including the early serial-mismatch return
- [ ] **BUG-02**: Switching display modes out of combat triggers a fresh aura read so stale stack counts are not shown
- [ ] **BUG-03**: Kill Command stack prediction reads talent state dynamically instead of hard-coding +2
- [ ] **BUG-04**: Twin Fangs talent support — Takedown grants 3 Tip of the Spear stacks when Twin Fangs talent is active

### Code Quality

- [ ] **QUAL-01**: Shared utility functions (Clamp, ParseHexColor, Trim, ParseOnOff) extracted to Util.lua loaded before Core.lua and Options.lua via TOC order
- [ ] **QUAL-02**: Module-level frame locals (root, pips, borders, label, numberText) moved to Tip table fields (Tip.root, Tip.pips, etc.)
- [ ] **QUAL-03**: Dead post-migration fallback block in NormalizeDB (lines 125-133) removed with settings migration version bump
- [ ] **QUAL-04**: ForEachModule uses ordered moduleOrder array instead of unordered pairs iteration
- [ ] **QUAL-05**: Unnecessary pcall wrapper removed from ClassifySpellID — pure table lookup needs no error protection

### Performance

- [ ] **PERF-01**: Spec state (IsSurvivalHunter result) cached and only re-checked on PLAYER_SPECIALIZATION_CHANGED and PLAYER_TALENT_UPDATE events, not on every Update call
- [ ] **PERF-02**: Spell texture resolved and cached once at Initialize time (and on PLAYER_LOGIN), not on every Update and RefreshLayout call

### Testing

- [ ] **TEST-01**: busted test framework configured for Lua 5.1 with spec/ directory structure
- [ ] **TEST-02**: WoW API mock layer (spec/support/wow_stubs.lua) providing accurate stubs for C_UnitAuras, C_Timer, C_SpecializationInfo, C_Spell, UnitClass, GetTime, CreateFrame
- [ ] **TEST-03**: Unit tests for ApplySpell covering stack add, cap at 3, expiry scheduling, and talent-specific grant amounts
- [ ] **TEST-04**: Unit tests for SyncFromAura covering grace period suppression, serial-mismatch path, and stack reconciliation
- [ ] **TEST-05**: Unit tests for NormalizeDB covering migration gate, field merging, and handling of missing/deprecated fields
- [ ] **TEST-06**: Unit tests for utility functions (Clamp, ParseHexColor, ParseOnOff, Trim) including edge cases
- [ ] **TEST-07**: luacheck configured with std=lua51 and curated read_globals for WoW API symbols

### CI/CD

- [ ] **CICD-01**: GitHub Actions release workflow that packages addon files into a distributable zip on tag push (user will provide sample workflow file)

## v2 Requirements

Deferred to future milestone. Tracked but not in current roadmap.

### New Modules

- **MOD-01**: Pack Leader beast tracking module
- **MOD-02**: Per-module options section convention (BuildOptionsSection callback)

### Developer Experience

- **DX-01**: Test mode persistence across UI reloads
- **DX-02**: StyLua formatter integration with pre-commit hook

## Out of Scope

| Feature | Reason |
|---------|--------|
| Ace3 / LibStub adoption | Intentionally dependency-free; adds upgrade coupling |
| OnUpdate polling | Event-driven architecture is correct; polling wastes frames |
| New tracking modules | Separate milestone after test suite is established |
| Global variable namespace expansion | Pollution risk; use DMX table instead |
| Defensive pcall on every function | Hides real bugs; only use at integration boundaries |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| BUG-01 | — | Pending |
| BUG-02 | — | Pending |
| BUG-03 | — | Pending |
| BUG-04 | — | Pending |
| QUAL-01 | — | Pending |
| QUAL-02 | — | Pending |
| QUAL-03 | — | Pending |
| QUAL-04 | — | Pending |
| QUAL-05 | — | Pending |
| PERF-01 | — | Pending |
| PERF-02 | — | Pending |
| TEST-01 | — | Pending |
| TEST-02 | — | Pending |
| TEST-03 | — | Pending |
| TEST-04 | — | Pending |
| TEST-05 | — | Pending |
| TEST-06 | — | Pending |
| TEST-07 | — | Pending |
| CICD-01 | — | Pending |

**Coverage:**
- v1 requirements: 19 total
- Mapped to phases: 0
- Unmapped: 19 ⚠️

---
*Requirements defined: 2026-06-17*
*Last updated: 2026-06-17 after initial definition*
