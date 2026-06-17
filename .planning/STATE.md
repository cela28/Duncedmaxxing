# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-06-17)

**Core value:** Accurate, instant stack display during combat
**Current focus:** Phase 0 — Repo Cleanup

## Current Position

Phase: 0 of 5 (Repo Cleanup)
Plan: 0 of ? in current phase
Status: Ready to plan
Last activity: 2026-06-17 — Phase 0 inserted (Repo Cleanup), roadmap revised to 5 phases

Progress: [░░░░░░░░░░] 0%

## Performance Metrics

**Velocity:**
- Total plans completed: 0
- Average duration: —
- Total execution time: 0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| - | - | - | - |

**Recent Trend:**
- Last 5 plans: —
- Trend: —

*Updated after each plan completion*

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- [Init]: Use busted 2.3.0 with `--lua-version=5.1` — installing without flag produces Lua 5.4 binary where `setfenv` is unavailable
- [Init]: Extract Util.lua before writing any tests — prerequisite for clean `dofile`-based test loading
- [Init]: QUAL-03 (dead migration fallback removal) deferred to Phase 3 — requires NormalizeDB idempotency test to be in place first
- [Revision]: Phase 0 (Repo Cleanup) inserted — covers CLN-01 through CLN-05, executes before all other phases

### Pending Todos

None yet.

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

Last session: 2026-06-17
Stopped at: Roadmap revised (Phase 0 inserted) — ready for `/gsd:plan-phase 0`
Resume file: None
