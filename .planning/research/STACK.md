# Stack Research

**Domain:** WoW addon testing and polish (Lua 5.1 sandbox)
**Researched:** 2026-06-17
**Confidence:** HIGH (test framework and linter), MEDIUM (mocking strategy), HIGH (formatter)

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| busted | 2.3.0 | Lua unit test runner | The de-facto Lua test framework; explicit Lua 5.1 support; ships with luassert (spies, stubs, mocks); `insulate` blocks restore `_G` and `package.loaded` between tests, which is exactly what you need to isolate addon code that writes to globals; maintained under lunarmodules org; released 2026-01-07 |
| luacheck | 1.2.0 | Static analysis / linter | Only mature Lua linter; Lua 5.1 mode (`std = "lua51"`); `read_globals` lets you enumerate the WoW API surface without false positives; used by Ace3, BigWigsMods, and most production WoW addons as their primary CI check; last published to LuaRocks 2 years ago but fully stable — no known correctness bugs |
| StyLua | 2.5.2 | Code formatter | Deterministic Prettier-equivalent for Lua; supports Lua 5.1 explicitly; zero-configuration path is just `stylua .`; binary install (no LuaRocks dependency); used widely in WoW addon repos; released 2026-05-16 |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| luassert | 1.9.0+ (bundled with busted) | Rich assertions + spies/stubs | Comes free with busted; use `stub(WoW_MOCK, "C_UnitAuras")` to prevent real API calls; use `spy.on(tip, "ApplySpell")` to verify it was called with expected stack count |
| lua 5.1 system runtime | 5.1.5 | Execution environment for busted | busted must run under Lua 5.1, not 5.3+, because the addon uses `setfenv`-style global management; install via `sudo apt-get install lua5.1 luarocks` and then `sudo luarocks --lua-version=5.1 install busted` |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| luacheck | Catches undefined globals, unused vars, shadowed locals | Configure `.luacheckrc` with `std = "lua51"` and a `read_globals` block listing the WoW API functions the addon actually calls (see Configuration section); reference the Ace3 `.luacheckrc` as a starting-point template |
| StyLua | Enforces consistent indentation and style | Add `.stylua.toml` with `syntax = "Lua51"` and `indent_type = "Spaces"` (addon uses 4-space indent currently); run as pre-commit or CI step |
| debugprofilestop() / GetTimePreciseSec() | In-game micro-benchmarking | Built into WoW client; wrap hot paths (Update tick, ApplySpell) with `local t = debugprofilestop(); ...; print(debugprofilestop() - t)` to measure millisecond costs; no external install |
| Perfy | Flame-graph profiling for in-game addon CPU cost | Instruments addon files in-place, collects data in-game, generates SVG flame graphs; use only if micro-benchmarks suggest a non-obvious hotspot; requires Lua 5.3+ runtime for the instrumentation script (separate from test runtime) |

## Installation

```bash
# Lua 5.1 + LuaRocks (Ubuntu/WSL)
sudo apt-get install lua5.1 luarocks

# busted pinned to Lua 5.1 (CRITICAL: must specify --lua-version)
sudo luarocks --lua-version=5.1 install busted

# luacheck (version-agnostic)
sudo luarocks install luacheck

# StyLua (binary, no LuaRocks needed)
# Option A: cargo
cargo install stylua --features lua51

# Option B: grab pre-built binary from GitHub Releases
# https://github.com/JohnnyMorganz/StyLua/releases/tag/v2.5.2
# Download stylua-linux-x86_64.zip, unzip, put on PATH
```

## WoW API Mock Strategy

WoW addon code has no `require`, no filesystem, and all WoW API calls are bare globals. The test isolation pattern that works:

```lua
-- spec/helpers/wow_mock.lua
-- Minimal WoW API mock table — only stub what the code under test actually calls

local WoW = {}

-- Core
WoW.CreateFrame = function(frameType, name, parent)
  local f = {}
  f.Show = function() end
  f.Hide = function() end
  f.SetPoint = function() end
  f.SetSize = function() end
  f.RegisterEvent = function() end
  f.SetScript = function() end
  return f
end
WoW.UIParent = {}
WoW.InCombatLockdown = function() return false end
WoW.GetTime = function() return 0 end
WoW.C_Timer = { After = function(_, fn) fn() end, NewTimer = function() return { Cancel = function() end } end }
WoW.C_UnitAuras = { GetPlayerAuraBySpellID = function() return nil end }
WoW.C_SpecializationInfo = { GetSpecialization = function() return 3 end }
WoW.UnitAura = function() return nil end  -- legacy fallback path
WoW.DEFAULT_CHAT_FRAME = { AddMessage = function() end }

return WoW
```

In each spec file, inject via busted `insulate` + manual `_G` population before `dofile`:

```lua
insulate("TipOfTheSpear module", function()
  local WoW = require("spec.helpers.wow_mock")
  -- Inject WoW globals into _G before loading the addon file
  for k, v in pairs(WoW) do _G[k] = v end

  -- Stub/spy specific APIs for this test
  stub(WoW.C_UnitAuras, "GetPlayerAuraBySpellID")

  -- Load the module under test (dofile works; require does not, matching WoW's no-require sandbox)
  dofile("Modules/TipOfTheSpear.lua")

  describe("ApplySpell", function()
    it("increments stack count on Raptor Strike cast", function()
      -- ...
    end)
  end)
end)
```

The `insulate` block saves and restores `_G` automatically, so no test bleeds into another.

## luacheckrc Configuration

Seed `.luacheckrc` with the WoW API functions this specific addon calls — do not dump the entire WoW API (that defeats the purpose of checking undefined globals):

```lua
-- .luacheckrc
std = "lua51"
max_line_length = false
codes = true

-- Addon namespace globals (writable)
globals = {
  "DMX",         -- main addon table, set in Core.lua
  "DuncedmaxxingDB",  -- SavedVariable
}

-- WoW API surface used by this addon (read-only from addon perspective)
read_globals = {
  -- Frame / UI
  "CreateFrame", "UIParent", "hooksecurefunc",
  -- Timing / scheduling
  "GetTime", "C_Timer",
  -- Aura APIs
  "C_UnitAuras", "UnitAura",
  -- Spec detection
  "C_SpecializationInfo", "GetSpecialization",
  -- Combat lockdown
  "InCombatLockdown",
  -- Slash commands
  "SlashCmdList", "SLASH_DMAX1",
  -- Chat
  "DEFAULT_CHAT_FRAME",
  -- Bit ops (Lua 5.1 WoW ships the bit library)
  "bit",
  -- String extras
  "strsplit", "strtrim",
}
```

## .stylua.toml Configuration

```toml
syntax = "Lua51"
column_width = 100
indent_type = "Spaces"
indent_width = 4
quote_style = "AutoPreferDouble"
```

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| busted (offline, external) | WoWUnit (in-game test runner) | Only if you need to test rendering/widget behavior that cannot be mocked; WoWUnit runs inside the actual WoW client, which means no CI; it has not been meaningfully updated since Dragonflight |
| Hand-rolled `wow_mock.lua` stub table | wowmock (Adirelle/wowmock) | wowmock is 3-star, 21-commit, no recent activity; designed for LuaUnit not busted; the setfenv approach it uses is available to you directly in busted's insulate blocks; not worth the dependency |
| busted 2.3.0 | lua-busted (resty variant) | Only if running inside OpenResty/nginx Lua context; not applicable here |
| luacheck 1.2.0 | selene | selene is Rust-based and has no WoW-specific standard library config; luacheck's `stds` table is exactly what you need for declaring WoW globals |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| WoWUnit / QhunUnitTest (in-game frameworks) | Run inside the WoW client — no CI, no automation, no diff output; test results are shown as in-game chat messages | busted (offline) |
| wowmock | Effectively unmaintained (3 stars, 21 commits, no recent activity); tight coupling to LuaUnit and mockagne; the busted+insulate pattern replaces it entirely | Hand-rolled `wow_mock.lua` + busted spies |
| `luarocks install busted` without `--lua-version=5.1` | LuaRocks will install for the system default Lua (likely 5.4 on modern Ubuntu), producing a busted binary that ignores Lua 5.1 semantics; `setfenv` is not available in 5.4 | `sudo luarocks --lua-version=5.1 install busted` |
| Running busted with `--lua=lua5.3` or newer | WoW Lua 5.1 uses `setfenv` and the `bit` library; testing with a different interpreter masks real incompatibilities | Ensure the interpreter is lua5.1 via `busted --lua=lua5.1` or set in `.busted` config |
| Perfy for routine profiling | Perfy instruments files in-place (modifies your source); it's for diagnosing unknown hotspots, not routine perf awareness | `debugprofilestop()` for targeted micro-benchmarks; revert Perfy instrumentation before committing |

## Version Compatibility

| Package | Compatible With | Notes |
|---------|----------------|-------|
| busted 2.3.0 | lua 5.1.5 | Works; requires `--lua-version=5.1` at install time and `lua5.1` interpreter at run time |
| luacheck 1.2.0 | lua 5.1–5.4 | Version-agnostic; `std = "lua51"` activates 5.1 grammar rules |
| StyLua 2.5.2 | Lua 5.1 | Requires `syntax = "Lua51"` in `.stylua.toml`; without it, defaults to "All" which is fine but less precise |

## Sources

- https://luarocks.org/modules/lunarmodules/busted — version 2.3.0-1, published 2026-01-07, lua >= 5.1 confirmed (HIGH confidence)
- https://luarocks.org/modules/lunarmodules/luacheck — version 1.2.0-1, lua >= 5.1 confirmed (HIGH confidence)
- https://github.com/JohnnyMorganz/StyLua — version 2.5.2, released 2026-05-16, Lua 5.1 support confirmed (HIGH confidence)
- https://github.com/lunarmodules/busted — insulate block behavior, spy/stub API documented in official README (HIGH confidence)
- https://github.com/WoWUIDev/Ace3/blob/master/.luacheckrc — reference for real WoW addon luacheckrc with read_globals (MEDIUM confidence — production addon, curated list)
- https://github.com/BigWigsMods/luacheck/blob/main/.luacheckrc.example — BigWigsMods example config (MEDIUM confidence)
- https://github.com/emmericp/Perfy — Perfy profiler; uses GetTimePreciseSec() internally; low activity but documented (MEDIUM confidence)
- https://github.com/Adirelle/wowmock — investigated and rejected; 3 stars, unmaintained (LOW confidence, not recommended)
- https://warcraft.wiki.gg/wiki/Patch_12.0.5/API_changes — C_UnitAuras aura instance ID re-randomization; no C_Timer or C_SpecializationInfo changes (HIGH confidence)

---
*Stack research for: WoW addon (Duncedmaxxing) — testing and polish milestone*
*Researched: 2026-06-17*
