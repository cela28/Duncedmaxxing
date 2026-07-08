---
phase: 05-refactor-display-modes-remove-icon-mode-and-add-a-bar-text-m
plan: "02"
subsystem: testing
tags:
  - lua
  - wow-addon
  - testing
  - fengari
dependency_graph:
  requires:
    - 05-01 (two-mode display surface — bar + number only; icons removed from Core.lua, Options.lua, TipOfTheSpear.lua)
  provides:
    - fengari-based local spec runner (spec/run.cjs) — no native Lua/busted required
    - updated core_spec.lua asserting two-mode NormalizeDB validation
    - passing full suite (116 tests, 0 failures) via the fengari harness
  affects:
    - spec/run.cjs
    - spec/core_spec.lua
tech_stack:
  added:
    - fengari 0.1.5 (npm, Lua-VM-in-JS) — resolved local-first via require.resolve, npx fallback pinned to 0.1.5
  patterns:
    - Local-first resolution: require.resolve('fengari') then PATH probe for npx-supplied copy, explicit error if neither
    - busted-compatible shim injected into Lua globals (describe/it/before_each/assert.*)
    - All tests run in a single shared Lua state; loader.load() handles per-test isolation via _G resets
key_files:
  created:
    - spec/run.cjs
  modified:
    - spec/core_spec.lua
decisions:
  - title: PATH probe for npx-supplied fengari
    rationale: "npx -y -p fengari@0.1.5 prepends <cache>/node_modules/.bin to PATH but does not add the parent to NODE_PATH, so require.resolve('fengari') still fails inside the spawned node process. A PATH probe (find fengari/ sibling to the .bin dir) reliably locates the npx-supplied package without needing NODE_PATH injection."
  - title: Single shared Lua state for full suite
    rationale: "Using one state across all *_spec.lua files avoids the overhead of creating/destroying a fengari VM per file. Each spec file calls loader.load() which resets _G and returns a fresh DMX — isolation is already provided at the before_each level."
  - title: lua.lua_tojsstring over lauxlib.lua_tostring
    rationale: "lua.lua_tostring returns a Uint8Array (Lua string bytes), not a JS string. lauxlib.lua_tostring does not exist in the fengari 0.1.5 API. to_jsstring(lua.lua_tostring(...)) and lua.lua_tojsstring both work; lua_tojsstring is the idiomatic single call."
metrics:
  duration: 6m
  completed: 2026-06-23
  tasks_completed: 3
  files_changed: 2
status: complete
---

# Phase 05 Plan 02: Fengari Harness + Two-Mode Test Updates Summary

Fengari-based node runner for the Lua spec suite with busted shim, and core_spec.lua updated to assert bar/number-only NormalizeDB validation.

## What Was Built

### Task 1 — spec/run.cjs (fengari node runner)

Created a CommonJS node script that executes the `*_spec.lua` files under fengari (Lua-VM-in-JS), standing in for the `busted spec/` command that requires a native Lua installation unavailable in this environment.

**Key implementation choices:**
- **Local-first fengari resolution:** `require.resolve('fengari')` first; if that fails, probes PATH directories for a fengari package installed alongside the `.bin` dir (the pattern npx uses). Falls back to an explicit, named error message rather than an opaque failure.
- **Shim surface:** Injects `describe`, `it`, `before_each`, and an `assert` table providing all methods the specs use: `equals`, `equal`, `are.equal`, `not_equals`, `is_true`, `is_false`, `is_nil`, `is_not_nil`, `is_table`, `is_near`, `near`. Also supports bare `assert(condition)`.
- **`--self-test` / `--dry-run` mode:** Boots a fresh fengari VM with a single synthetic inline spec and exits 0 if it passes — catches a broken or no-op runner before any spec file is touched.
- **package.path:** Set to `ROOT/?.lua;ROOT/?/init.lua` so `require("spec.support.init")`, `require("spec.support.wow_stubs")`, and `loadfile("Duncedmaxxing/...")` all resolve from the project root.

### Task 2 — spec/core_spec.lua (two-mode assertions)

Updated the NormalizeDB tests to reflect the removal of `icons` display mode (DISP-02, DISP-03):

1. **Already-migrated branch fixture:** Removed `iconSize = 28` and `iconSpacing = 4` keys from `migratedDB()` (these fields are no longer in DEFAULTS).
2. **Already-migrated branch test:** Changed `"preserves icons when already migrated"` → `"stored displayMode='icons' normalizes to 'bar' (icons removed in DISP-02)"`, asserting `assert.equals("bar", ...)` instead of `"icons"`.
3. **Validation branch test:** Changed `"preserves valid displayMode 'icons'"` → `"resets stored displayMode 'icons' to default 'bar' (icons removed in DISP-02)"`, asserting `assert.equals("bar", ...)`.
4. Retained all bar/number/invalid/nil coverage unchanged.

### Task 3 — Full suite green

`npx -y -p fengari@0.1.5 node spec/run.cjs` runs the entire suite (core_spec.lua, tip_spec.lua, util_spec.lua) and exits 0:

```
116 passed, 0 failed, 116 total
```

No regressions from the Wave 1 icon removal. tip_spec.lua and spec/support/wow_stubs.lua are unchanged — their `icon` references are the WoW AuraData contract (aura icon field 132275 / spellTexture cache test), not display-mode icons.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] lauxlib.lua_tostring does not exist in fengari 0.1.5 API**
- **Found during:** Task 1 execution
- **Issue:** Initial implementation used `lauxlib.lua_tostring(L, -1)` to read strings from the Lua stack, but this function does not exist in fengari's lauxlib. `lua.lua_tostring` returns a Uint8Array, not a JS string.
- **Fix:** Switched to `to_jsstring(lua.lua_tostring(L, -1))` and `lua.lua_tojsstring(L, -1)` throughout run.cjs.
- **Files modified:** spec/run.cjs
- **Commit:** 412ce08

**2. [Rule 1 - Bug] npx-supplied fengari not resolvable via require.resolve**
- **Found during:** Task 1 self-test verification
- **Issue:** When invoked as `npx -y -p fengari@0.1.5 node spec/run.cjs`, npx prepends `<cache>/node_modules/.bin` to PATH but does not add the parent to NODE_PATH. `require.resolve('fengari')` still throws inside the spawned node process, so the runner exited with an error even when invoked via npx.
- **Fix:** Added a PATH probe: after `require.resolve` fails, scan PATH entries for a `fengari/` directory adjacent to each `.bin/` entry. If found, `require()` it directly. This covers the npx-invocation pattern without requiring NODE_PATH or a local `node_modules/`.
- **Files modified:** spec/run.cjs
- **Commit:** 412ce08

## Known Stubs

None. The spec suite exercises real NormalizeDB, MergeDefaults, ApplySpell, SyncFromAura, and Tip:Update logic with full fidelity through the fengari harness.

## Threat Flags

No new security-relevant surface introduced. spec/run.cjs is a dev-time test runner; it does not ship with the addon or execute in the WoW client.

## Self-Check

### Files created/modified

- [x] `spec/run.cjs` — FOUND (committed 412ce08)
- [x] `spec/core_spec.lua` — FOUND (committed c7fedfc)

### Commits

- [x] `412ce08` — feat(05-02): add fengari node runner
- [x] `c7fedfc` — refactor(05-02): update core_spec.lua for two-mode world

### Suite result

```
116 passed, 0 failed, 116 total
```

## Self-Check: PASSED
