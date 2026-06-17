# Duncedmaxxing — Polish Pass

## What This Is

A World of Warcraft addon that tracks Tip of the Spear stacks for Survival Hunters. It shows a real-time visual indicator (bar or icon mode) of the player's current stack count with predictive tracking that updates before the server confirms aura state. This milestone is a polish pass — fixing bugs, cleaning up internals, improving performance, and adding a test suite.

## Core Value

Accurate, instant stack display during combat. If the stack count is wrong or laggy, nothing else matters.

## Requirements

### Validated

- ✓ Predictive stack tracking via spell cast events — existing
- ✓ Aura verification with delayed sanity check — existing
- ✓ Bar and icon display modes with configurable colors — existing
- ✓ Settings persistence via WoW SavedVariables — existing
- ✓ In-game options window with combat guard — existing
- ✓ Slash command interface (`/dmax`) — existing
- ✓ DB migration for settings version changes — existing
- ✓ Movable, lockable, scalable display frame — existing

### Active

- [ ] Fix auraVerifyPending stuck flag after serial mismatch
- [ ] Fix stale stack display when switching modes out of combat
- [ ] Extract duplicated utilities (Clamp, ParseHexColor) to shared Duncedmaxxing/Util.lua
- [ ] Remove dead post-migration fallback code in NormalizeDB
- [ ] Move module-level frame locals to Tip table fields
- [ ] Add ordered module iteration via moduleOrder array
- [ ] Cache spell texture resolution (resolve once, not every update)
- [ ] Cache spec state (stop calling IsSurvivalHunter on every Update)
- [ ] Remove unnecessary pcall wrapper in ClassifySpellID
- [ ] Set up busted test framework with WoW API mock layer
- [ ] Add unit tests for ApplySpell, SyncFromAura, NormalizeDB, and utility functions

### Out of Scope

- New tracking modules (e.g., Pack Leader beast tracking) — separate milestone
- OAuth/login/auth features — not applicable (WoW addon)
- Mobile or web versions — WoW client only
- Ace3 or other library adoption — intentionally dependency-free

## Context

- WoW addon running in Lua 5.1 sandbox, Midnight 12.0.5 (Interface 120005)
- Single module currently (tip), but architecture supports multiple modules
- No external dependencies — pure Lua + WoW API
- No existing tests — all validation is manual in-game
- Codebase map already completed (`.planning/codebase/`)
- Concerns audit identified specific bugs, tech debt, and perf bottlenecks

## Constraints

- **Runtime**: WoW Lua 5.1 sandbox — no `require`, no filesystem, no threads
- **Combat lockdown**: UI mutations forbidden during `InCombatLockdown()`
- **API compatibility**: Must handle both old and new WoW API surfaces (dual-path calls)
- **No build toolchain**: Lua files loaded directly by WoW client via TOC order

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Use busted for testing | Pure Lua test framework, Lua 5.1 compatible, well-established | — Pending |
| Extract utils to Duncedmaxxing/Util.lua | Eliminates duplicated code between Duncedmaxxing/Core.lua and Duncedmaxxing/Options.lua | — Pending |
| Cache spec/texture at event boundaries | Avoid per-update WoW API calls during combat | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd:complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-06-17 after initialization*
