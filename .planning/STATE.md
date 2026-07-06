---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
current_phase: 06
current_phase_name: options-panel-v2-per-mode-visibility-configurable-stack-colo
status: executing
stopped_at: Completed 06-06-PLAN.md
last_updated: "2026-07-06T21:09:18.899Z"
last_activity: 2026-07-06
last_activity_desc: Phase 06 execution started
progress:
  total_phases: 7
  completed_phases: 7
  total_plans: 20
  completed_plans: 20
  percent: 100
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-06-17)

**Core value:** Accurate, instant stack display during combat
**Current focus:** Phase 06 — options-panel-v2-per-mode-visibility-configurable-stack-colo

## Current Position

Phase: 06 (options-panel-v2-per-mode-visibility-configurable-stack-colo) — EXECUTING
Plan: 6 of 6
Status: All plans executed
Last activity: 2026-07-06 — Phase 06 execution started

Progress: [██████████] 100%

## Performance Metrics

**Velocity:**

- Total plans completed: 12
- Average duration: 2min
- Total execution time: 2min

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 0 - Repo Cleanup | 1 | 2min | 2min |
| 01 | 2 | - | - |
| 02 | 3 | - | - |
| 03 | 2 | - | - |
| 04 | 2 | - | - |
| 05 | 2 | - | - |

**Recent Trend:**

- Last 5 plans: 00-01 (2min)
- Trend: N/A (first plan)

*Updated after each plan completion*
| Phase 02-test-framework-and-core-logic-tests P03 | 15min | 2 tasks | 4 files |
| Phase 01 P03 | 3min | - tasks | - files |
| Phase 05 P01 | 12 | 3 tasks | 3 files |
| Phase 06 P01 | 3min | 2 tasks | 2 files |
| Phase 06 P02 | 8min | 2 tasks | 1 files |
| Phase 06 P03 | 5min | 2 tasks | 2 files |
| Phase 06 P04 | 5min | 3 tasks | 2 files |
| Phase 06 P05 | 4min | 2 tasks | 2 files |
| Phase 06 P06 | 10min | 1 tasks | 1 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- [Init]: Use busted 2.3.0 with `--lua-version=5.1` — installing without flag produces Lua 5.4 binary where `setfenv` is unavailable
- [Init]: Extract Util.lua before writing any tests — prerequisite for clean `dofile`-based test loading
- [Init]: QUAL-03 (dead migration fallback removal) deferred to Phase 3 — requires NormalizeDB idempotency test to be in place first
- [Revision]: Phase 0 (Repo Cleanup) inserted — covers CLN-01 through CLN-05, executes before all other phases
- [Phase ?]: mockAura indirection in wow_stubs.lua: wrapper function captured at module-load time delegates to replaceable mockAura.impl, enabling per-test aura overrides without module reload
- [Phase ?]: luacheck 1.2.0 installed via luarocks; W432 self-shadowing suppressed for WoW SetScript closures; SlashCmdList in globals not read_globals
- [Phase ?]: Primal Surge spell ID unverifiable offline; flat-2 fallback used for Kill Command generator grant
- [Phase ?]: Generator grant decoupled from hasTwinFangs; Twin Fangs now scoped exclusively to Takedown consumer path
- [Phase ?]: hasPrimalSurge field added to Tip module table; reserved for future HasPrimalSurge() wiring when ID is confirmed
- [Phase ?]: Remove icons mode entirely — persisted icons/icon values normalize to bar via NormalizeDB
- [Phase ?]: Bar else-branch is the catch-all in RefreshLayout and Update for any unknown displayMode value
- [Phase ?]: stackColors stored as array-indexed RGBA tuples (matching STACK_COLORS shape), not r/g/b/a keys — ColorTuple reads both shapes
- [Phase ?]: cfg.colorByStack == nil treated as ON (only explicit false disables per-stack coloring)
- [Phase ?]: Kept stackColors[N] as array-indexed RGBA tuples (via ParseHexColor .r/.g/.b/.a) -- ColorTuple already reads both shapes
- [Phase ?]: Repositioned mode buttons and right-column layout to fit 4 stack-color rows in the unchanged 386x484 options window (D-10)
- [Phase ?]: Unrecognized displayMode values fall back to bar visibility in Options:Refresh, mirroring the Phase 5 bar-catch-all convention
- [Phase ?]: Used pcall + assert.is_true instead of assert.has_no.errors since the project's minimal assert shim does not implement busted's full assertion API
- [Phase ?]: Added a dedicated legacy-DB describe block for the MergeDefaults->NormalizeDB no-wipe pipeline case, isolating it from the narrower single-function NormalizeDB tests
- [Phase ?]: Scale and Border color reassigned to the existing bar-only widget group in Options.lua
- [Phase ?]: Enabled checkbox UI control removed while DEFAULTS.tip.enabled = true kept for the shouldShow gate and core_spec assertions
- [Phase ?]: Position Reset button and its sole caller Tip:ResetPosition deleted together after confirming no other references exist
- [Phase ?]: Converted DEFAULTS.tip.stackColors to named-key {r,g,b,a} form and bumped SETTINGS_MIGRATION to 0.3.3-stackcolorfmt to fix stack-color picker defaults rendering as ffffff (DISP-06)
- [Phase ?]: 06-06: Overlapped Bar-section and Number-section widgets (and their headers) at the same left-column row coordinates, and bar color fields with number text/stack color fields at the same right-column row coordinates, since each pair is mutually exclusive by displayMode
- [Phase ?]: 06-06: Shrunk options-panel window height 484 -> 400 (width unchanged) after collapsing mutually-exclusive mode sections onto shared row coordinates

### Roadmap Evolution

- Phase 5 added: Refactor display modes — remove icon mode and add a bar + text mode
- Phase 6 added: Options panel v2 — per-mode option visibility, configurable per-stack colors, and the mode-selector layout fix (surfaced by Phase 05 UAT)

### Pending Todos

None yet.

### Quick Tasks Completed

| # | Description | Date | Commit | Directory |
|---|-------------|------|--------|-----------|
| 260617-jee | Move addon files into nested Duncedmaxxing subdirectory | 2026-06-17 | ffea0ea | [260617-jee-move-addon-files-into-nested-duncedmaxxi](./quick/260617-jee-move-addon-files-into-nested-duncedmaxxi/) |
| 260621-x8n | Fix release workflow action SHA so the v1.0.0 zip asset builds and uploads | 2026-06-21 | f1e6e4d | [260621-x8n-fix-release-workflow-action-sha-so-the-v](./quick/260621-x8n-fix-release-workflow-action-sha-so-the-v/) |
| 260622-hmo | Add per-stack color coding for number display mode | 2026-06-22 | 329a69d | [260622-hmo-add-per-stack-color-coding-for-number-di](./quick/260622-hmo-add-per-stack-color-coding-for-number-di/) |
| 260622-tyy | Add spell ID 1262343 (Raptor Swipe — Aspect of the Eagle ranged variant) as a consumer | 2026-06-22 | 8b7ab8a | [260622-tyy-add-spell-id-1262343-raptor-swipe-aspect](./quick/260622-tyy-add-spell-id-1262343-raptor-swipe-aspect/) |
| 260623-x5d | Remove the showOnlyInCombat display feature so the tracker always shows regardless of combat state | 2026-06-23 | 7243c0c | [260623-x5d-remove-the-showonlyincombat-display-feat](./quick/260623-x5d-remove-the-showonlyincombat-display-feat/) |
| 260624-0hx | Reduce slash interface to settings-only (/dmax opens settings); de-bloat README | 2026-06-24 | 893c3a1 | [260624-0hx-reduce-slash-interface-to-settings-only-](./quick/260624-0hx-reduce-slash-interface-to-settings-only-/) |

### Blockers/Concerns

- **[Research flag — Phase 2]**: busted Lua 5.1 installation requires `--lua-version=5.1` at LuaRocks install time; mock accuracy must be reviewed against warcraft.wiki.gg before writing any test (hard gate, not follow-up)
- **[Research flag — Phase 4]**: `C_Spell.GetSpellTexture` two-return-value behavior under patch 12.0.5 not explicitly confirmed in STACK.md — verify against warcraft.wiki.gg before implementing texture caching

## Deferred Items

Items acknowledged and carried forward:

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| v2 | MOD-01: Pack Leader beast tracking | Deferred | Init |
| v2 | MOD-02: Per-module options section convention | Deferred | Init |
| v2 | DX-01: Test mode persistence across UI reloads | Deferred | Init |
| v2 | DX-02: StyLua pre-commit hook | Deferred | Init |

## Session Continuity

Last session: 2026-07-06T21:09:10.925Z
Stopped at: Completed 06-06-PLAN.md
Resume file: None
