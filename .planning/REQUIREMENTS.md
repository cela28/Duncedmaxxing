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

- [ ] **QUAL-01**: Shared utility functions (Clamp, ParseHexColor, Trim, ParseOnOff) extracted to Duncedmaxxing/Util.lua loaded before Core.lua and Options.lua via TOC order
- [ ] **QUAL-02**: Module-level frame locals (root, pips, borders, label, numberText) moved to Tip table fields (Tip.root, Tip.pips, etc.)
- [ ] **QUAL-03**: Dead post-migration fallback block in NormalizeDB (lines 125-133) removed with settings migration version bump
- [ ] **QUAL-04**: ForEachModule uses ordered moduleOrder array instead of unordered pairs iteration
- [ ] **QUAL-05**: Unnecessary pcall wrapper removed from ClassifySpellID — pure table lookup needs no error protection

### Performance

- [ ] **PERF-01**: Spec state (IsSurvivalHunter result) cached and only re-checked on PLAYER_SPECIALIZATION_CHANGED and PLAYER_TALENT_UPDATE events, not on every Update call
- [ ] **PERF-02**: Spell texture resolved and cached once at Initialize time (and on PLAYER_LOGIN), not on every Update and RefreshLayout call

### Testing

- [x] **TEST-01**: busted test framework configured for Lua 5.1 with spec/ directory structure
- [x] **TEST-02**: WoW API mock layer (spec/support/wow_stubs.lua) providing accurate stubs for C_UnitAuras, C_Timer, C_SpecializationInfo, C_Spell, UnitClass, GetTime, CreateFrame
- [x] **TEST-03**: Unit tests for ApplySpell covering stack add, cap at 3, expiry scheduling, and talent-specific grant amounts
- [x] **TEST-04**: Unit tests for SyncFromAura covering grace period suppression, serial-mismatch path, and stack reconciliation
- [x] **TEST-05**: Unit tests for NormalizeDB covering migration gate, field merging, and handling of missing/deprecated fields
- [x] **TEST-06**: Unit tests for utility functions (Clamp, ParseHexColor, ParseOnOff, Trim) including edge cases
- [x] **TEST-07**: luacheck configured with std=lua51 and curated read_globals for WoW API symbols

### Cleanup

- [x] **CLN-01**: All `:Zone.Identifier` NTFS alternate data stream files removed from the repository
- [x] **CLN-02**: `API_REFERENCES.md` removed from the repository
- [x] **CLN-03**: `DEVELOPMENT_NOTES.md` removed from the repository
- [x] **CLN-04**: `.gitignore` updated to prevent `:Zone.Identifier` files from being re-committed
- [x] **CLN-05**: Folder structure validated against standard WoW addon conventions

### CI/CD

- [ ] **CICD-01**: GitHub Actions release workflow that packages addon files into a distributable zip on tag push (user will provide sample workflow file)

### Display Modes

- [x] **DISP-01**: The `icons` display mode is removed entirely — both rendering branches in TipOfTheSpear.lua (`RefreshLayout` and `Update`), the Options "Icons" button and `MODE_LABELS` entry, the slash-command `icons` token, the legacy `icon`→`icons` alias, and validation acceptance of `icons`. Final mode set is exactly `bar` and `number`.
- [x] **DISP-02**: `NormalizeDB` validation falls back to the default (`bar`) for any unknown/now-invalid stored `displayMode`; no dedicated `icon`/`icons`→x migration path is added (only 2 users, neither on icon mode).
- [x] **DISP-03**: The now-orphaned `iconSize`/`iconSpacing` settings are removed from `DEFAULTS` and from the Options window — no display mode reads them after icon removal.
- [x] **DISP-04**: Test suite updated — icon-mode assertions removed; `bar` and `number` display-mode coverage retained and passing via the fengari (Lua-VM-in-JS) harness.
- [ ] **DISP-05**: The Options window gates widget visibility by active display mode — Bar-only controls (Width, Height, Border size, Fill, Empty %) hide in Number mode; Number-only controls (Text size + all stack-color controls) hide in Bar mode; Position/Enabled/Hide empty/Border color show in both. Switching modes updates visibility immediately with no Lua error and no combat-lockdown violation.
- [x] **DISP-06**: Per-stack number colors are user-configurable via a "Color by stack" toggle plus 4 per-stack color pickers (stacks 0–3), persisted in SavedVariables. Toggle ON (default) applies the 4 configurable colors (defaults byte-for-byte match today's hardcoded `STACK_COLORS`); toggle OFF applies the single flat `textColor`. The hardcoded `STACK_COLORS` read in the number-mode render path is replaced by a config read. A fresh/legacy DB default-merges the new fields with no settings wipe and no Lua error.
- [ ] **DISP-07**: The mode-selector layout bug is fixed — the "Display:" text label is removed and the active mode button (Bar/Number) is visually highlighted instead, eliminating the label/Bar-button overlap. The window stays a fixed size on mode switch (hidden controls leave empty space, no reflow).

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
| CLN-01 | Phase 0 | Complete |
| CLN-02 | Phase 0 | Complete |
| CLN-03 | Phase 0 | Complete |
| CLN-04 | Phase 0 | Complete |
| CLN-05 | Phase 0 | Complete |
| BUG-01 | Phase 3 | Pending |
| BUG-02 | Phase 3 | Pending |
| BUG-03 | Phase 3 | Pending |
| BUG-04 | Phase 3 | Pending |
| QUAL-01 | Phase 1 | Pending |
| QUAL-02 | Phase 1 | Pending |
| QUAL-03 | Phase 3 | Pending |
| QUAL-04 | Phase 1 | Pending |
| QUAL-05 | Phase 1 | Pending |
| PERF-01 | Phase 4 | Pending |
| PERF-02 | Phase 4 | Pending |
| TEST-01 | Phase 2 | Complete |
| TEST-02 | Phase 2 | Complete |
| TEST-03 | Phase 2 | Complete |
| TEST-04 | Phase 2 | Complete |
| TEST-05 | Phase 2 | Complete |
| TEST-06 | Phase 2 | Complete |
| TEST-07 | Phase 2 | Complete |
| CICD-01 | Phase 4 | Pending |
| DISP-01 | Phase 5 | Complete |
| DISP-02 | Phase 5 | Complete |
| DISP-03 | Phase 5 | Complete |
| DISP-04 | Phase 5 | Complete |
| DISP-05 | Phase 6 | Pending |
| DISP-06 | Phase 6 | Complete |
| DISP-07 | Phase 6 | Pending |

**Coverage:**

- v1 requirements: 31 total
- Mapped to phases: 31
- Unmapped: 0 ✓

---
*Requirements defined: 2026-06-17*
*Last updated: 2026-06-17 after roadmap creation*
