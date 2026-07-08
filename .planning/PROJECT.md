# Duncedmaxxing — Polish Pass

## What This Is

A World of Warcraft addon that tracks Tip of the Spear stacks for Survival Hunters. It shows a real-time visual indicator (bar or number mode) of the player's current stack count with predictive tracking that updates before the server confirms aura state. The v1.0 polish pass shipped a structurally clean, fully tested, and performant version — bugs fixed, internals cleaned up, per-frame API calls eliminated, and an offline test suite added.

## Current State

**Shipped:** v1.0 Polish Pass (2026-07-09) — 8 phases, 25 plans, 31/31 requirements satisfied.

- Codebase: ~1,585 LOC Lua across `Core.lua`, `Util.lua`, `Options.lua`, `Modules/TipOfTheSpear.lua`
- Two display modes (`bar`, `number`); icon mode removed entirely
- Test suite: 111 tests via the fengari (Lua-VM-in-JS) harness, all green
- CI: GitHub Actions release workflow on `main`; luacheck lint workflow committed (first green run pending)
- Structurally clean: shared utilities in `Util.lua`, frame refs on the `Tip` table, dead code removed

**Next milestone:** not yet defined — run `/gsd-new-milestone`. Candidate v2 work is tracked below under Out of Scope / deferred.

## Core Value

Accurate, instant stack display during combat. If the stack count is wrong or laggy, nothing else matters.

## Requirements

### Validated

- ✓ Predictive stack tracking via spell cast events — existing
- ✓ Aura verification with delayed sanity check — existing
- ✓ Settings persistence via WoW SavedVariables — existing
- ✓ In-game options window with combat guard — existing
- ✓ Slash command interface (`/dmax`) — existing
- ✓ DB migration for settings version changes — existing
- ✓ Movable, lockable, scalable display frame — existing
- ✓ Repo hygiene: NTFS/stale-doc cleanup, `.gitignore`, nested addon layout — v1.0 (Phase 0)
- ✓ Shared utilities extracted to `Util.lua` — v1.0 (Phase 1)
- ✓ Frame locals moved to `Tip` table fields — v1.0 (Phase 1)
- ✓ Ordered module iteration via `moduleOrder` — v1.0 (Phase 1)
- ✓ `pcall` wrapper removed from `ClassifySpellID` — v1.0 (Phase 1)
- ✓ Offline test suite (busted→fengari) with WoW API mock layer — v1.0 (Phase 2)
- ✓ Unit tests for ApplySpell, SyncFromAura, NormalizeDB, utilities — v1.0 (Phase 2)
- ✓ Fix `auraVerifyPending` stuck flag after serial mismatch — v1.0 (Phase 3)
- ✓ Fix stale stack display when switching modes out of combat — v1.0 (Phase 3)
- ✓ Kill Command / Twin Fangs talent-aware grant logic — v1.0 (Phase 3)
- ✓ Remove dead post-migration fallback in `NormalizeDB` — v1.0 (Phase 3)
- ✓ Cache spec state and spell texture at event boundaries — v1.0 (Phase 4)
- ✓ GitHub Actions release workflow (lint+test gate, zip on tag) — v1.0 (Phase 4)
- ✓ Display modes collapsed to `bar` + `number` (icon mode removed) — v1.0 (Phase 5)
- ✓ Per-mode options visibility + configurable per-stack number colors — v1.0 (Phase 6)
- ✓ Dead-code sweep + test hardening — v1.0 (Phase 7)

### Active

_(none — v1.0 complete; define the next milestone with `/gsd-new-milestone`)_

### Out of Scope

- New tracking modules (e.g., Pack Leader beast tracking, `MOD-01`) — separate milestone
- Per-module options section convention (`MOD-02`) — deferred to v2
- Test-mode persistence across UI reloads (`DX-01`) — deferred to v2
- StyLua formatter + pre-commit hook (`DX-02`) — deferred to v2
- OAuth/login/auth features — not applicable (WoW addon)
- Mobile or web versions — WoW client only
- Ace3 or other library adoption — intentionally dependency-free

## Context

- WoW addon running in Lua 5.1 sandbox, Midnight 12.0.5 (Interface 120005)
- Single module currently (`tip`), but architecture supports multiple modules
- No external dependencies — pure Lua + WoW API
- Test suite: 111 fengari tests (util, core, tip, caching, per-stack colors); busted retired in favor of the fengari harness since the sandbox lacks a native Lua 5.1/luarocks toolchain
- luacheck configured (`.luacheckrc`); runs in CI via committed `lint.yml` (first green run pending a push)
- Release model: `main` = production addon code, `dev` = working branch; release by pushing a `v*` tag on `main`
- Codebase map completed (`.planning/codebase/`)

## Constraints

- **Runtime**: WoW Lua 5.1 sandbox — no `require`, no filesystem, no threads
- **Combat lockdown**: UI mutations forbidden during `InCombatLockdown()`
- **API compatibility**: Must handle both old and new WoW API surfaces (dual-path calls)
- **No build toolchain**: Lua files loaded directly by WoW client via TOC order

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Use busted for testing, then fengari harness | Pure Lua 5.1 test framework; switched to fengari (Lua-VM-in-JS) when the sandbox couldn't install luarocks/lua5.1 | ✓ Phase 2 / 5 |
| Extract utils to `Util.lua` | Eliminates duplicated code between `Core.lua` and `Options.lua` | ✓ Phase 1 |
| Cache spec/texture at event boundaries | Avoid per-update WoW API calls during combat | ✓ Phase 4 |
| GitHub Actions release workflow | Automate lint+test gate and zip packaging on release | ✓ Phase 4 |
| Remove icon display mode | Only bar/number are used; two users, neither on icon mode; no migration path needed | ✓ Phase 5 |
| Per-mode option visibility + button-only mode switching | Options window shows only controls relevant to active mode; Enabled checkbox removed, Border color/Scale bar-only, no `/dmax mode` subcommand (user-accepted overrides) | ✓ Phase 6 |
| Named-key `stackColors` + targeted migration re-seed | Fix stack-color picker defaults and avoid settings wipe on token bump under real MergeDefaults→NormalizeDB order | ✓ Phase 6 |
| Dead-code sweep (Phase 7) | Remove `hasPrimalSurge`/`spellTexture`/`ParseOnOff` dead symbols surfaced by the v1.0 audit; harden tautological tests | ✓ Phase 7 |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-07-09 after v1.0 Polish Pass milestone*
