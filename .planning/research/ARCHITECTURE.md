# Architecture Patterns

**Domain:** WoW Addon — single-module stack tracker, polish pass
**Researched:** 2026-06-17

## Current Architecture (Baseline)

The addon uses a shared namespace table passed via the WoW vararg idiom. All three source files receive the same `DMX` table on load, add their own methods and sub-tables to it, and then WoW fires `ADDON_LOADED` to kick off runtime initialization.

```
TOC load order (sequential, compile-time):
  Core.lua
    └── defines DMX namespace, DEFAULTS, DB init/migration,
        module registry, spec helpers, slash commands
  Options.lua
    └── attaches DMX.Options; all settings UI widget factories
  Modules/TipOfTheSpear.lua
    └── attaches local Tip table, self-registers as DMX module "tip"

Runtime (event-driven after ADDON_LOADED):
  DMX.db  ←──────────────── DuncedmaxxingDB (WoW SavedVariables global)
      └─ db.tip ←──── read/write by all three layers
  Tip:Initialize() ← called by Core via ForEachModule
      └── builds WoW frame tree, registers game events
```

### Component Boundaries (As-Is)

| Component | Responsibility | Reads From | Writes To |
|-----------|---------------|------------|-----------|
| Core.lua | Namespace, DB, migration, registry, slash commands | DuncedmaxxingDB global | DMX.db, DMX.modules |
| Options.lua | Settings popup UI, all input widgets | DMX:GetDB().tip | DMX.db.tip (direct) |
| TipOfTheSpear.lua | Stack state machine, frame rendering | DMX:GetDB().tip, WoW API events | Tip.stacks/expiresAt/etc, frame textures |
| Util functions (duplicated) | Clamp, ParseHexColor, Trim, ParseOnOff | -- | -- (pure functions, no state) |

### Data Flow (As-Is)

```
Settings change path:
  Player interacts with Options UI
    → Options directly mutates db.tip
    → calls DMX:RefreshTip()
    → calls Tip:RefreshLayout()
    → rebuilds frame geometry, calls Tip:Update()

Slash command path (parallel, partially duplicated):
  /dmax scale 1.2
    → SlashCmdList handler in Core.lua
    → directly mutates db.tip.scale
    → calls RefreshTip(tip) (same destination, different code)

Combat stack tracking path:
  UNIT_SPELLCAST_SUCCEEDED event
    → Tip:OnEvent → FindTrackedSpell → ClassifySpellID
    → Tip:ApplySpell (immediate optimistic update)
    → Tip:Update (redraws frame)
    → C_Timer.After: Tip:ScheduleCastVerify (sanity check serial)
  UNIT_AURA event
    → Tip:ScheduleAuraVerify(0.05s delay)
    → Tip:SyncFromAura (reconcile aura vs predicted state)
```

---

## Target Architecture (Post-Refactor)

### New Component: Util.lua

A new `Util.lua` file inserted before `Options.lua` in the TOC declares pure utility functions on the `DMX` namespace. It has no state and no WoW API dependencies.

**Functions to move:** `Clamp`, `ParseHexColor`, `Trim`, `ParseOnOff`, `ColorTuple` (from TipOfTheSpear)

**Why a dedicated file (not inlined into Core):**
- Keeps Core focused on bootstrap/registry concerns only
- Utilities become independently testable with zero mocking
- Clear, grep-findable boundary: "pure helpers live in Util.lua"

**Boundary rule:** Util.lua may not call any WoW API function and may not read DMX.db. It receives values as arguments and returns computed results only.

### Revised Component Boundaries (Target)

| Component | Responsibility | Boundary Rule |
|-----------|---------------|---------------|
| Core.lua | Namespace, DB, migration, module registry, slash commands | No duplicate utility code; slash handler routes mutations through a setter |
| Util.lua | Pure utility functions (Clamp, ParseHexColor, Trim, ParseOnOff) | No WoW API calls, no DMX.db access, no side effects |
| Options.lua | Settings popup UI | Uses DMX.Util.*; settings mutations go through DMX:SetTipConfig() |
| Modules/TipOfTheSpear.lua | Stack state machine, frame rendering | All frame refs as Tip.* fields, no module-level upvalue locals |

### Encapsulation Fix: Module-Level Locals → Table Fields

**Problem:** `root`, `pips`, `borders`, `label`, `numberText` are module-level upvalue locals in TipOfTheSpear.lua. This means the `Tip` table cannot be cleanly inspected or reset from outside the file — tests cannot verify frame construction state.

**Fix:** Move all frame references to `Tip.root`, `Tip.pips`, `Tip.borders`, `Tip.label`, `Tip.numberText`. This is consistent with how `Tip.stacks`, `Tip.expiresAt`, etc. are already stored.

**Impact on testability:** Once frame refs are table fields, a test can inject a mock frame table and assert on `Tip.root` after calling `Tip:Initialize()`, without needing a real WoW `CreateFrame`.

### Settings Mutation: Add Setter

**Problem:** `db.tip.*` is written directly in both `Core.lua`'s slash command handler and `Options.lua`. Any new field requires updating both.

**Fix:** Add `DMX:SetTipConfig(key, value)` that writes to `db.tip[key]` and calls `DMX:RefreshTip()`. Both Options and the slash handler call this one function.

### Spec / Aura Caching

**Problem:** `IsSurvivalHunter` calls `C_SpecializationInfo.GetSpecialization` on every `Update` tick. `ResolveSpellTexture` calls `C_Spell.GetSpellTexture` on every layout refresh.

**Fix:** Cache both values at event boundaries.
- `Tip.isSurvival` set in `RefreshActive` (called on spec change events)
- `Tip.spellTexture` set once in `Initialize` and on `TRAIT_CONFIG_UPDATED`

**Impact on testability:** Once spec state is a field, tests can set `Tip.isSurvival = true` without mocking the WoW API.

---

## Test Infrastructure Layout

### The Core Challenge

WoW addons run inside the WoW client's sandboxed Lua 5.1 environment. There is no `require`, no filesystem API, and WoW globals (`CreateFrame`, `C_UnitAuras`, `GetTime`, `UIParent`, etc.) do not exist outside the client. Tests must run in a standard Lua 5.1 environment (busted) with those globals stubbed.

### Recommended Approach: busted + handwritten WoW API stubs

**Rationale for busted:**
- Pure Lua, works with Lua 5.1, no WoW client required
- Standard `describe`/`it`/`before_each` syntax
- Built-in spy/stub support via luassert
- Widely used in WoW addon community (wow-addon-container uses it)
- Installable via LuaRocks: `luarocks install busted`

**Why not wowmock/wowunit:**
- wowmock uses luaunit (not busted) and setfenv — adds framework churn
- wowunit runs inside the WoW client — no CI pipeline possible
- wowless is pre-alpha, incomplete API coverage

**Why not a full WoW API emulation layer:**
- WeakAuras2 attempted a full API wrapper in 2014 and the maintainers rejected it as too invasive
- For a small addon like this, targeted stubs per test file are lower cost and clearer

### File Layout (Target)

```
Duncedmaxxing/
├── Core.lua
├── Util.lua                        ← new
├── Options.lua
├── Modules/
│   └── TipOfTheSpear.lua
├── spec/
│   ├── support/
│   │   └── wow_stubs.lua           ← shared WoW API mock table
│   ├── util_spec.lua               ← Clamp, ParseHexColor, Trim, ParseOnOff
│   ├── normalizedb_spec.lua        ← NormalizeDB, MergeDefaults
│   ├── applyspell_spec.lua         ← Tip:ApplySpell state machine
│   └── syncfromaura_spec.lua       ← Tip:SyncFromAura reconciliation logic
└── .busted                         ← busted config (lpath, lua version)
```

### WoW Stubs Pattern

`spec/support/wow_stubs.lua` returns a table of minimal WoW API stubs used as globals in tests. Key stubs needed for the testable functions:

```lua
-- spec/support/wow_stubs.lua
return {
    GetTime = function() return 0 end,
    InCombatLockdown = function() return false end,
    CreateFrame = function() return { SetScript = function() end, ... } end,
    C_UnitAuras = {
        GetPlayerAuraBySpellID = function() return nil end,
    },
    C_SpecializationInfo = {
        GetSpecialization = function() return 3 end,
    },
    UnitClass = function() return "Hunter", "HUNTER" end,
    DEFAULT_CHAT_FRAME = { AddMessage = function() end },
}
```

Tests that exercise pure logic (Util, NormalizeDB) need no stubs at all. Tests for ApplySpell/SyncFromAura need only `GetTime` and `C_UnitAuras`. The frame-construction path (Initialize, RefreshLayout) needs `CreateFrame` stubs and is tested less exhaustively — those paths are integration-tested in-game.

### Loading Addon Code in Tests

WoW addon files expect `local addonName, DMX = ...` from the WoW vararg. In busted, you load the file with a minimal adapter:

```lua
-- inside a spec file
local DMX = {}
local chunk = loadfile("Core.lua")
chunk("Duncedmaxxing", DMX)   -- simulates WoW load
-- DMX now has all Core methods, can assert on them
```

For TipOfTheSpear: load Core first (to set up `DMX`), inject stubs for `GetTime`/`C_UnitAuras` as globals, then load the module file. The `Tip` table is accessible via `DMX:GetModule("tip")` after load.

### What Is and Is Not Tested

**Unit-testable (pure or near-pure logic):**
- Util functions: Clamp, ParseHexColor, Trim, ParseOnOff — no mocks needed
- NormalizeDB, MergeDefaults — table manipulation only
- Tip:ApplySpell — state machine on Tip.stacks/expiresAt, needs GetTime stub
- Tip:SyncFromAura — aura reconciliation, needs C_UnitAuras stub
- ClassifySpellID — pure table lookup (remove the unnecessary pcall first)

**In-game only (WoW frame API required):**
- Frame construction (EnsureFrame, RefreshLayout, Update visual output)
- Event registration (RegisterEvent, RegisterUnitEvent)
- Timer scheduling (C_Timer.After)
- Options UI widgets

This boundary is the right tradeoff for a dependency-free addon: test the logic, accept that rendering is verified in-game.

---

## Component Data Flow (Target)

```
WoW API Events
  └─► Tip:OnEvent
        ├── UNIT_SPELLCAST_SUCCEEDED → FindTrackedSpell → Tip:ApplySpell
        │     └── mutates Tip.stacks, Tip.expiresAt
        │     └── schedules C_Timer → Tip:SyncFromAura (sanity check)
        ├── UNIT_AURA → Tip:ScheduleAuraVerify → Tip:SyncFromAura
        │     └── reads C_UnitAuras.GetPlayerAuraBySpellID
        │     └── reconciles Tip.stacks if server disagrees
        └── spec/combat events → Tip:RefreshActive (caches Tip.isSurvival)

Settings Path:
  Player action
    └─► Options UI  ──┐
    └─► /dmax command ┘
              ↓
         DMX:SetTipConfig(key, value)   ← single setter (target state)
              ↓
         db.tip[key] = value
         DMX:RefreshTip()
              └─► Tip:RefreshLayout() → Tip:Update()

Util Layer (pure, no arrows going in):
  Util.Clamp, Util.ParseHexColor, Util.Trim
    ← called by Core (slash), Options (inputs), Tip (color parsing)
    → return computed values only
```

---

## Build Order (Dependency Graph for Phases)

The phased work has clear dependency ordering driven by the above architecture:

1. **Util.lua extraction first** — removes duplication and makes utility tests trivially easy. No other component depends on completing this before it can start, but subsequent refactors will call `DMX.Util.*` instead of local copies.

2. **Module encapsulation (frame locals → table fields)** — prerequisite for ApplySpell/SyncFromAura tests, because tests need to inspect `Tip.root` etc. without actually calling WoW frame APIs. Can proceed in parallel with Util extraction.

3. **Spec/texture caching** — prerequisite for testing `RefreshActive` and spec-dependent behavior without mocking `C_SpecializationInfo` on every assertion. Depends on nothing else.

4. **Busted + wow_stubs.lua setup** — can be done alongside step 1, but the spec files for Tip:ApplySpell and Tip:SyncFromAura should be written after step 2 (encapsulation) is done, otherwise test setup requires more complex frame stubs.

5. **Bug fixes** (auraVerifyPending stuck flag, stale display on mode switch) — can be done at any point; tests written in step 4 will catch regressions.

6. **Slash command cleanup** (add DMX:SetTipConfig, remove direct db.tip mutations) — last, because it touches Core + Options + any tests that exercise the settings path.

**Summary dependency chain:**
```
Util.lua extraction
    ↕ (parallel)
Frame locals → Tip.* fields
    ↕ (parallel)
Spec/texture caching
    ↓ (after encapsulation is done)
busted + wow_stubs + spec files
    ↓
Bug fixes verified by tests
    ↓
SetTipConfig setter + slash command cleanup
```

---

## Anti-Patterns to Avoid in Refactor

### Wrapping Every WoW API in a Proxy Layer

**What:** Creating `DMX.API.GetTime()`, `DMX.API.CreateFrame()` etc. — an abstraction layer in front of the entire WoW API.
**Why bad:** WeakAuras2 tried this in 2014; maintainers rejected it as too invasive. For a 3-file addon, the overhead of the abstraction exceeds the benefit. Tests only need GetTime and C_UnitAuras stubs.
**Instead:** Inject stubs as globals in the busted environment per test file using `_G.GetTime = stub_fn`.

### Testing Frame Rendering Logic

**What:** Writing busted specs that assert on pixel layout, vertex colors, texture coordinates.
**Why bad:** Frame API requires too many stubs (CreateTexture, SetVertexColor, SetAllPoints, etc.), and visual correctness cannot be verified without the actual GPU pipeline.
**Instead:** Accept frame rendering as in-game test territory. Test state (Tip.stacks, Tip.expiresAt) not frame properties.

### Keeping pcall Around Pure Logic

**What:** ClassifySpellID wraps a simple table lookup in `pcall`. NormalizeDB-adjacent validation uses it defensively.
**Why bad:** pcall hides logic errors from both readers and tests. A table lookup cannot throw unless the table is nil, which is a programming error not an API error.
**Instead:** Remove pcall from ClassifySpellID (pure lookup). Keep pcall in ReadLiveState (actual WoW API call that can fail on API version mismatches).

---

## Scalability Considerations

This addon is single-player, single-module, and runs in a Lua sandbox with no network and no threading. Scalability concerns are:

| Concern | Now | After Refactor |
|---------|-----|----------------|
| Per-update API calls | IsSurvivalHunter + GetSpellTexture on every Update | Cached at event boundaries — zero API calls in Update |
| Module iteration order | `pairs()` — non-deterministic, matters when ForEachModule matters | `moduleOrder` array for deterministic initialization order |
| Test coverage regression | Zero (all manual) | Unit tests for state machine + utils gate PRs |

---

## Sources

- Current codebase: `/home/cela/random-projects/Duncedmaxxing/Core.lua`, `Options.lua`, `Modules/TipOfTheSpear.lua`
- Existing architecture analysis: `.planning/codebase/ARCHITECTURE.md` (2026-06-17)
- [lunarmodules/busted — Elegant Lua unit testing](https://lunarmodules.github.io/busted/) — HIGH confidence (official docs)
- [dolphinspired/wow-addon-container](https://github.com/dolphinspired/wow-addon-container) — MEDIUM confidence (demonstrates busted + spec/ layout for WoW addons)
- [Adirelle/wowmock — WoW environment mock](https://github.com/Adirelle/wowmock) — MEDIUM confidence (verified: uses setfenv + luaunit, not busted; cited to explain why not recommended)
- [WeakAuras2 PR #100 — Wrapping WoW API for testability](https://github.com/WeakAuras/WeakAuras2/pull/100) — MEDIUM confidence (rejected PR, cited as evidence that full API wrapper is impractical)
- [Good Design in Warcraft Addons/Lua — Andy Dote](https://andydote.co.uk/2014/11/23/good-design-in-warcraft-addons/) — LOW confidence (2014, still directionally correct for namespace sharing patterns)
