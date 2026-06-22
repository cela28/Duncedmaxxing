# Roadmap: Duncedmaxxing — Polish Pass

## Overview

This milestone transforms a working but untested WoW addon into a structurally clean, fully tested, and performant one. The work follows a strict dependency order: clean up repo hygiene first so the working tree is canonical, extract shared utilities second so tests can load them cleanly, establish the busted test framework third so bugs get regression coverage, fix correctness bugs fourth under test protection, and clean up performance and CI last once correctness is confirmed.

## Phases

**Phase Numbering:**

- Integer phases (0, 1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 0: Repo Cleanup** - Remove NTFS junk files, stale docs, and validate folder structure against WoW addon conventions (completed 2026-06-17)
- [x] **Phase 1: Utility Extraction and Module Encapsulation** - Extract shared utilities to Util.lua and move frame locals to Tip table fields (completed 2026-06-17)
- [x] **Phase 2: Test Framework and Core Logic Tests** - Set up busted with WoW API stubs and write unit tests for all core functions (completed 2026-06-18)
- [x] **Phase 3: Bug Fixes with Test Coverage** - Fix all correctness bugs under test protection and remove dead migration fallback (completed 2026-06-18)
- [x] **Phase 4: Performance Caching and CI/CD** - Cache spec/texture state and ship the GitHub Actions release workflow (completed 2026-06-18)

## Phase Details

### Phase 0: Repo Cleanup

**Goal**: The repository contains only intentional addon files — no NTFS metadata artifacts, no stale reference docs, and a folder structure that matches standard WoW addon conventions.
**Mode:** mvp
**Depends on**: Nothing (first phase)
**Requirements**: CLN-01, CLN-02, CLN-03, CLN-04, CLN-05
**Success Criteria** (what must be TRUE):

  1. No `:Zone.Identifier` files exist anywhere in the repository
  2. `API_REFERENCES.md` and `DEVELOPMENT_NOTES.md` are absent from the repository
  3. `.gitignore` contains the `*:Zone.Identifier` pattern so these files cannot be re-committed
  4. The addon root contains `.toc` and `.lua` files, a `Modules/` directory, and a `Media/` directory — matching standard WoW addon layout

**Plans:** 1/1 plans complete

Plans:

- [x] 00-01-PLAN.md — Remove artifacts, create .gitignore, validate folder structure

### Phase 1: Utility Extraction and Module Encapsulation

**Goal**: The codebase has a clean structural foundation — shared utilities live in one place, frame references are accessible for testing, and module iteration is ordered.
**Mode:** mvp
**Depends on**: Phase 0
**Requirements**: QUAL-01, QUAL-02, QUAL-04, QUAL-05
**Success Criteria** (what must be TRUE):

  1. `DMX.Util.Clamp`, `DMX.Util.ParseHexColor`, `DMX.Util.Trim`, and `DMX.Util.ParseOnOff` exist and are callable after `/reload ui` — no duplicate definitions remain in Core.lua or Options.lua
  2. All five frame references (`root`, `pips`, `label`, `numberText`, `borders`) are accessible as `Tip.root`, `Tip.pips`, etc. — no bare upvalue references remain in TipOfTheSpear.lua function bodies
  3. `ForEachModule` iterates in the order declared in `moduleOrder`, not arbitrary hash order
  4. `ClassifySpellID` performs a plain table lookup with no `pcall` wrapper
  5. `/reload ui` in-game produces no Lua errors and the tracker display functions normally

**Plans:** 4/4 plans complete

Plans:
**Wave 1**

- [x] 01-01-PLAN.md — Extract utilities to Util.lua, wire consumer aliases, add moduleOrder

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 01-02-PLAN.md — Migrate frame references to Tip table fields, remove ClassifySpellID pcall

**Gap Closure** *(from UAT Test 3 — Kill Command stack overshoot)*

- [x] 01-03-PLAN.md — Decouple Kill Command generator grant from Twin Fangs; Primal-Surge-aware grant + regression tests

**Gap Closure** *(from UAT Test 6 — Raptor Strike + Aspect of the Eagle stack lag)*

- [x] 01-04-PLAN.md — Register Aspect-of-the-Eagle Raptor Strike (265189) as a consumer + regression test

### Phase 2: Test Framework and Core Logic Tests

**Goal**: A passing test suite exists that covers all pure-logic functions — utility functions, DB migration, stack application, and aura reconciliation — running offline without the WoW client.
**Mode:** mvp
**Depends on**: Phase 1
**Requirements**: TEST-01, TEST-02, TEST-03, TEST-04, TEST-05, TEST-06, TEST-07
**Success Criteria** (what must be TRUE):

  1. `busted` runs under Lua 5.1 and all tests pass with `busted spec/` from the project root
  2. `luacheck` reports zero warnings on all addon Lua files with `std=lua51` and the curated `read_globals` list
  3. `spec/support/wow_stubs.lua` provides accurate stubs for `C_UnitAuras`, `C_Timer`, `C_SpecializationInfo`, `C_Spell`, `UnitClass`, `GetTime`, and `CreateFrame` — verified against warcraft.wiki.gg return contracts
  4. Tests for `ApplySpell` cover stack add, cap-at-3, expiry scheduling, and talent-specific grant amounts (Kill Command, Twin Fangs)
  5. Tests for `SyncFromAura` cover grace period suppression, serial-mismatch path, and stack reconciliation — including the stuck-flag exit paths
  6. Tests for `NormalizeDB` cover migration gate, field merging, and missing/deprecated fields
  7. Tests for utility functions cover normal use and edge cases (Clamp bounds, empty string inputs, case variants for ParseOnOff)

**Plans:** 3/3 plans complete

Plans:
**Wave 1**

- [x] 02-01-PLAN.md — Install busted, create WoW API stubs and test loader, write utility function tests

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 02-02-PLAN.md — Expose Core.lua test helpers, write NormalizeDB and MergeDefaults tests

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 02-03-PLAN.md — Write ApplySpell and SyncFromAura tests, configure luacheck for zero warnings

### Phase 3: Bug Fixes with Test Coverage

**Goal**: All known correctness bugs are fixed and covered by the test suite, and the dead migration fallback is removed with idempotency confirmed by tests.
**Mode:** mvp
**Depends on**: Phase 2
**Requirements**: BUG-01, BUG-02, BUG-03, BUG-04, QUAL-03
**Success Criteria** (what must be TRUE):

  1. `auraVerifyPending` is cleared on every exit path of the timer callback — the `syncfromaura_spec.lua` serial-mismatch test passes, confirming no stuck-flag regression
  2. Switching display modes out of combat shows the correct current stack count immediately — no stale display from the previous mode
  3. Kill Command stack prediction reads talent state dynamically — hardcoded `+2` no longer appears in `ClassifySpellID` or `ApplySpell`
  4. Takedown grants 3 stacks when Twin Fangs talent is active — `ApplySpell` test covering the Twin Fangs branch passes
  5. The dead migration fallback block (Core.lua lines 125-133) is removed — `NormalizeDB` idempotency test passes confirming settings are not wiped on reload

**Plans:** 2/2 plans complete

Plans:
**Wave 1**

- [x] 03-01-PLAN.md — BUG-01 regression test, QUAL-03 dead block removal, BUG-02 mode-switch SyncFromAura fix

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 03-02-PLAN.md — BUG-03/BUG-04 Twin Fangs talent detection, talent-aware ApplySpell, regression tests

### Phase 4: Performance Caching and CI/CD

**Goal**: The addon no longer makes per-frame WoW API calls during combat, and a GitHub Actions workflow packages a distributable zip on tag push.
**Mode:** mvp
**Depends on**: Phase 3
**Requirements**: PERF-01, PERF-02, CICD-01
**Success Criteria** (what must be TRUE):

  1. The `Update` function body contains no calls to `IsSurvivalHunter` or `C_SpecializationInfo` — spec state is cached as `Tip.isSurvival` and refreshed only on `PLAYER_SPECIALIZATION_CHANGED` and `PLAYER_TALENT_UPDATE`
  2. `RefreshLayout` and `Update` contain no calls to `C_Spell.GetSpellTexture` or `ResolveSpellTexture` — texture is cached as `Tip.spellTexture` at `Initialize` time
  3. Pushing a tag matching `v*` to GitHub triggers the release workflow and produces a `.zip` artifact containing only the addon files listed in the TOC

**Plans:** 2/2 plans complete

Plans:
**Wave 1** *(parallel — no file overlap)*

- [x] 04-01-PLAN.md — Implement spec cache (PERF-01) and texture cache (PERF-02) with regression tests
- [x] 04-02-PLAN.md — Fix luacheck warnings, create GitHub Actions release workflow (CICD-01)

## Progress

**Execution Order:**
Phases execute in numeric order: 0 → 1 → 2 → 3 → 4

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 0. Repo Cleanup | 1/1 | Complete   | 2026-06-17 |
| 1. Utility Extraction and Module Encapsulation | 4/4 | Complete   | 2026-06-21 |
| 2. Test Framework and Core Logic Tests | 3/3 | Complete   | 2026-06-18 |
| 3. Bug Fixes with Test Coverage | 2/2 | Complete   | 2026-06-18 |
| 4. Performance Caching and CI/CD | 2/2 | Complete   | 2026-06-18 |

### Phase 5: Refactor display modes: remove icon mode and add a bar + text mode

**Goal:** Simplify the display-mode set. Remove the `icons` display mode entirely (rendering path, option, slash-command token, and migration alias). Add a new combined `bartext` mode that renders the stack bar with the numeric stack count overlaid as text. Net mode set after this phase: `bar`, `bartext`, `number`.

**LOCKED decisions (user-confirmed 2026-06-22):**
- Mode key string is `"bartext"` (one word, no separator).
- **No migration logic.** There are only 2 users and neither uses icon mode — do NOT write a remap for persisted `icons`/`icon` values. Validation can simply fall back to the default (`bar`) for any now-unknown stored mode, but a dedicated icon→x migration path is explicitly out of scope. Also drop the existing legacy `icon`→`icons` alias in Core.lua since `icons` is being removed.

**Scope notes (current state, pre-refactor):**
- Three modes exist today: `bar`, `icons`, `number` (NOT just bar/icon). The legacy `icon` token is already migrated to `icons` in `Core.lua`.
- Rendering branches on `cfg.displayMode` in `Duncedmaxxing/Modules/TipOfTheSpear.lua` (~lines 476, 630).
- Default + validation + slash-command parsing live in `Duncedmaxxing/Core.lua` (`DEFAULTS.tip.displayMode` ~line 30; NormalizeDB validation ~line 98; slash parser ~lines 251-255).
- Mode selector UI + `MODE_LABELS` in `Duncedmaxxing/Options.lua` (~lines 11, 176, 249, 289, 411).
- **No migration** (see LOCKED decisions). Validation falls back to default `bar` for unknown stored modes; remove the legacy `icon`→`icons` alias.
- Tests in `spec/` must be updated (remove icon-mode assertions, add `bartext` assertions). No native Lua/busted toolchain in this env — regression runs go through the fengari (Lua-VM-in-JS) harness.

**Requirements**: TBD (resolve in /gsd-plan-phase)
**Depends on:** Phase 4
**Plans:** 0 plans

Plans:

- [ ] TBD (run /gsd-plan-phase 5 to break down)
