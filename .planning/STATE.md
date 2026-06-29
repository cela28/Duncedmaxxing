---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
current_phase: 06
current_phase_name: independent, can execute in either order
status: discussing
stopped_at: Phase 06 context gathered
last_updated: "2026-06-29T09:05:40.373Z"
last_activity: 2026-06-29
last_activity_desc: Added Phase 6 (Options UI Overhaul) and Phase 7 (Spell Coverage) to roadmap
progress:
  total_phases: 8
  completed_phases: 6
  total_plans: 14
  completed_plans: 14
  percent: 75
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-06-17)

**Core value:** Accurate, instant stack display during combat
**Current focus:** Phase 06 — Options UI Overhaul, Phase 07 — Spell Coverage

## Current Position

Phase: 06 / 07 (independent, can execute in either order)
Plan: Not started
Status: Phases scoped, ready for planning
Last activity: 2026-06-29 — Added Phase 6 (Options UI Overhaul) and Phase 7 (Spell Coverage) to roadmap

Progress: [██████░░░░] 75%

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

### Roadmap Evolution

- Phase 5 added: Refactor display modes — remove icon mode and add a bar + text mode

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

Last session: 2026-06-29T09:05:40.368Z
Stopped at: Phase 06 context gathered
Resume file: .planning/phases/06-options-ui-overhaul/06-CONTEXT.md
