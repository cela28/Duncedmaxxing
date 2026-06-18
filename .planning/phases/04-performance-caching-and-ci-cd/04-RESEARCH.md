# Phase 4: Performance Caching and CI/CD - Research

**Researched:** 2026-06-18
**Domain:** WoW Lua performance optimization (event-driven caching) + GitHub Actions packaging
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Spec State Caching (PERF-01)**
- D-01: Cache `IsSurvivalHunter` result as `Tip.isSurvival` (or equivalent field on the Tip table). Refresh only on `PLAYER_SPECIALIZATION_CHANGED` and `PLAYER_TALENT_UPDATE` events — not on every `Update` call.
- D-02: Remove the `self:RefreshActive()` call from inside `Update`. The `OnEvent` handler for specialization/talent events already calls `RefreshActive` explicitly — that's the sole refresh path.
- D-03: Follows the same event-driven cache pattern established in Phase 3 D-03 (talent state cached on the same two events).

**Spell Texture Caching (PERF-02)**
- D-04: Resolve and cache the spell texture as `Tip.spellTexture` once at `Initialize` time (and on `PLAYER_LOGIN` as a safe re-check). `RefreshLayout` and `Update` read the cached value — no calls to `C_Spell.GetSpellTexture` or `ResolveSpellTexture` in hot paths.
- D-05: (Research flag — RESOLVED. See `## Critical Research Finding` section.)

**Release Workflow (CICD-01)**
- D-06: GitHub Actions workflow triggers on `release: [created]`. Creates a zip of the entire `Duncedmaxxing/` directory and uploads it as a release asset using `softprops/action-gh-release@v2`. Releases are marked as prerelease.
- D-07: Zip contains all files in the `Duncedmaxxing/` directory — TOC, all Lua files, Media/, and any future assets. Packaged with `Duncedmaxxing/` as the top-level folder so users can extract directly into `Interface/AddOns/`.
- D-08: Release notes auto-generated from commits using GitHub's built-in feature. No manual CHANGELOG.md maintenance.
- D-09: User provided a sample workflow file (from another addon) as the structural template. Adapt it for this project — replace addon name, add version injection step.

**Version Management**
- D-10: CI workflow injects the git tag into the TOC's `## Version:` field (via sed) before creating the zip. The tag name (e.g., `v1.0.0`) is stripped of the `v` prefix and written as the version string.
- D-11: The TOC's `## Interface:` version (currently `120005`) stays manually maintained.

**Caching Test Coverage**
- D-12: Add regression tests for both caching changes. State-based assertions: verify `Tip.isSurvival` is set after Initialize, changes correctly after `PLAYER_SPECIALIZATION_CHANGED` event, and `Tip.spellTexture` is non-nil after Initialize.
- D-13: Tests follow existing patterns from Phase 2 — per-test isolation via `loader.load()` in `before_each`, mock clock, mock aura infrastructure.

**CI Lint and Test Job**
- D-14: The GitHub Actions workflow includes a lint+test job that runs `luacheck` and `busted` on every push to main and on PRs. This catches regressions before release. Separate job from the release packaging job.

### Claude's Discretion
- D-02 scope: Claude decides whether to inline the cached check in `Update` or factor it into a helper, based on code clarity.
- D-04 implementation: Claude decides whether `ResolveSpellTexture` is refactored to a cache-populating function called once, or replaced entirely with a direct API call at init time.
- D-14 details: Claude decides the exact CI job structure (matrix vs single job, Lua version pinning, caching of luarocks dependencies).

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PERF-01 | Spec state (`IsSurvivalHunter` result) cached as `Tip.isSurvival`; re-checked only on `PLAYER_SPECIALIZATION_CHANGED` and `PLAYER_TALENT_UPDATE`, not on every `Update` call | Pattern established in Phase 3 `Tip.hasTwinFangs` cache; `Update` call site at line 598 confirmed; `OnEvent` already handles both events |
| PERF-02 | Spell texture resolved and cached once at `Initialize` time (and on `PLAYER_LOGIN`), not on every `Update` and `RefreshLayout` call | `ResolveSpellTexture` confirmed at lines 137–147, 493, 651; `C_Spell.GetSpellTexture` two-return-value behavior verified against warcraft.wiki.gg |
| CICD-01 | GitHub Actions release workflow that packages addon files into a distributable zip on release creation | `softprops/action-gh-release@v2` confirmed; `release: [created]` trigger syntax confirmed; version-inject-via-sed pattern confirmed |
</phase_requirements>

---

## Summary

Phase 4 is a surgical optimization pass (PERF-01, PERF-02) plus a CI/CD packaging workflow (CICD-01). The two performance fixes are straightforward cache introductions following a pattern already established in this codebase: `Tip.hasTwinFangs` (Phase 3) shows exactly how to maintain an event-invalidated field on the Tip table. The spec-state cache (`Tip.isSurvival`) replicates that pattern identically. The texture cache (`Tip.spellTexture`) is even simpler — resolve once at init, never again. The CI/CD work is standard GitHub Actions boilerplate for WoW addon packaging.

The one non-obvious research item was the `C_Spell.GetSpellTexture` return contract under patch 12.0.5: the function returns **two values** (`iconID, originalIconID`). The existing `ResolveSpellTexture` code already handles this correctly — it discards the second value implicitly. The caching implementation must do the same, capturing only the first return value. Full details in the Critical Research Finding section.

The baseline is healthy: 102 tests pass, luacheck reports 6 warnings (all `unused argument self` — pre-existing, not introduced by this phase), and the existing event-driven architecture makes both caching changes low-risk.

**Primary recommendation:** Implement PERF-01 by converting `Tip:RefreshActive` to set `self.isSurvival` (or equivalent) and removing its call from `Update`; implement PERF-02 by adding a `Tip:CacheSpellTexture` call in `Initialize` and on `PLAYER_LOGIN`; implement CICD-01 with a two-job workflow (lint+test + release). All three changes are additive and isolated.

---

## Critical Research Finding

### D-05: `C_Spell.GetSpellTexture` Two-Return-Value Behavior Under Patch 12.0.5

**Research flag from STATE.md:** "C_Spell.GetSpellTexture two-return-value behavior under patch 12.0.5 must be verified against warcraft.wiki.gg before implementing the caching."

**Verified against warcraft.wiki.gg:** [VERIFIED: warcraft.wiki.gg — https://warcraft.wiki.gg/wiki/API_C_Spell.GetSpellTexture]

**Finding:** `C_Spell.GetSpellTexture` returns **two values**:

```lua
iconID, originalIconID = C_Spell.GetSpellTexture(spellIdentifier)
```

- `iconID` — the current icon file ID (number / fileID)
- `originalIconID` — the original icon file ID (number / fileID)
- Returns nothing if the spell is not found ("MayReturnNothing" annotation)
- This signature is stable across 12.0.7 (Midnight, current), and has been unchanged since at least 11.0.0

**Implication for PERF-02 implementation:**

The existing `ResolveSpellTexture` function (TipOfTheSpear.lua:138) is:

```lua
local function ResolveSpellTexture()
    if C_Spell and C_Spell.GetSpellTexture then
        return C_Spell.GetSpellTexture(TIP_OF_THE_SPEAR) or FALLBACK_ICON
    end
    if _G.GetSpellTexture then
        return _G.GetSpellTexture(TIP_OF_THE_SPEAR) or FALLBACK_ICON
    end
    return FALLBACK_ICON
end
```

When `C_Spell.GetSpellTexture` returns two values, Lua discards the second value at a call site that only captures the first — so `return C_Spell.GetSpellTexture(TIP_OF_THE_SPEAR)` silently returns only `iconID`. The `or FALLBACK_ICON` guard then applies only to the first value. **This is already correct behavior.** The cache population must follow the same pattern:

```lua
-- Correct: only captures first return value
self.spellTexture = (C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(TIP_OF_THE_SPEAR))
                   or (GetSpellTexture and GetSpellTexture(TIP_OF_THE_SPEAR))
                   or FALLBACK_ICON
```

**Old `GetSpellTexture` (deprecated):** Returns only one value (`icon`). Deprecated since 11.0.0, removed in 11.0.2. [VERIFIED: warcraft.wiki.gg — https://warcraft.wiki.gg/wiki/API_GetSpellTexture]. The fallback path in `ResolveSpellTexture` is already dead for patch 12.0.5, but the dual-path pattern must be preserved per CLAUDE.md API compatibility constraint.

**Mock stub alignment:** `spec/support/wow_stubs.lua` stubs `C_Spell.GetSpellTexture = function(id) return 132275 end` — returns only one value, not two. This is fine for tests that only test `isSurvival` caching and only need a non-nil texture. If a test needs to assert the exact texture value, the stub is correct — it returns the expected `FALLBACK_ICON` value (132275). No stub changes needed for the caching tests in D-12.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Spec state caching (PERF-01) | Addon module (Tip table) | Event handler (OnEvent) | Lua state lives on the Tip table; events trigger invalidation |
| Texture caching (PERF-02) | Addon module (Tip table) | Initialize / PLAYER_LOGIN | WoW API call result cached at load time, stable for session |
| Release packaging (CICD-01) | GitHub Actions runner | GitHub release system | No addon code changes; all CI logic lives in `.github/workflows/` |
| CI lint + test (D-14) | GitHub Actions runner | — | Runs luacheck + busted against the source |

---

## Standard Stack

### Core (this phase — no new packages)

This phase installs **no new packages**. The addon has no package manager. Tools already present on the dev machine are used for CI:

| Tool | Version (confirmed) | Purpose |
|------|---------------------|---------|
| `luacheck` | 1.2.0 [VERIFIED: local install] | Lua linting — already installed |
| `busted` | 2.3.0 [VERIFIED: local install] | Lua test runner — already installed |

### GitHub Actions (CI/CD)

| Action | Version | Purpose | Source |
|--------|---------|---------|--------|
| `actions/checkout` | v4 | Checkout repo in CI | [VERIFIED: github.com/actions/checkout] |
| `softprops/action-gh-release` | v2 | Upload zip as release asset | [CITED: github.com/marketplace/actions/gh-release] |

**Version notes:**
- `softprops/action-gh-release@v3` requires Node 24 runner; `@v2` (v2.6.2) works with Node 20 (ubuntu-latest default). Use `@v2` per D-06. [CITED: GitHub Marketplace]
- `actions/checkout@v4` is the current stable release. [ASSUMED — not explicitly verified against GitHub Marketplace changelog, but v4 is widely documented as current]

### CI Installation for Lua Tools

The lint+test job needs luacheck and busted. Both are luarocks packages. The standard CI approach:

```yaml
- name: Install Lua and LuaRocks
  uses: leafo/gh-actions-lua@v10
  with:
    luaVersion: "5.1"

- name: Install LuaRocks
  uses: leafo/gh-actions-luarocks@v4

- name: Install dependencies
  run: luarocks install luacheck && luarocks install busted
```

[ASSUMED — `leafo/gh-actions-lua` and `leafo/gh-actions-luarocks` are widely-used community actions for Lua CI; not verified against their GitHub repositories in this session. The planner must verify these action names before use.]

**Alternative (simpler, lower risk):** Use `ubuntu-latest` with `apt-get install lua5.1 luarocks` then `luarocks install luacheck busted`. Avoids community actions entirely. [ASSUMED — apt package availability not confirmed in this session]

**Recommendation for D-14 (Claude's discretion):** Single job (not matrix) — only one Lua version (5.1) and one OS (ubuntu-latest) is needed. No luarocks dependency caching needed for a package set this small (two packages, fast install).

---

## Package Legitimacy Audit

This phase installs no npm, PyPI, or Cargo packages. GitHub Actions referenced (`actions/checkout`, `softprops/action-gh-release`, and optionally `leafo/gh-actions-lua` / `leafo/gh-actions-luarocks`) are GitHub-native — slopcheck does not cover GitHub Actions. Verification is manual (check that the actions exist at the referenced GitHub org and have recent maintenance activity).

| Action | GitHub Org | Legitimacy Signal | Disposition |
|--------|-----------|-------------------|-------------|
| `actions/checkout@v4` | `actions` (GitHub official) | Official GitHub-maintained | Approved |
| `softprops/action-gh-release@v2` | `softprops` | 3k+ stars, widely used in open-source addon packaging | Approved |
| `leafo/gh-actions-lua@v10` | `leafo` (Leafo Moonscript author) | Standard in Lua CI community | [ASSUMED] — planner should verify before use |
| `leafo/gh-actions-luarocks@v4` | `leafo` | Same org as above | [ASSUMED] — planner should verify before use |

**Packages removed due to slopcheck verdict:** none  
**Packages flagged as suspicious:** none with hard flags; `leafo/*` actions are tagged `[ASSUMED]` — planner must verify their GitHub URLs are active before adding to workflow.

---

## Architecture Patterns

### System Architecture Diagram

```
PERF-01 Fix (spec caching):

OnEvent("PLAYER_SPECIALIZATION_CHANGED" | "PLAYER_TALENT_UPDATE")
    └─► RefreshActive()           ← sole write path for Tip.isSurvival
            └─► Tip.isSurvival = DMX:IsSurvivalHunter()

Update()
    └─► reads Tip.isSurvival      ← no call to IsSurvivalHunter()
    └─► shouldShow computation
    └─► render

───────────────────────────────────────────────────────────

PERF-02 Fix (texture caching):

Initialize() / PLAYER_LOGIN
    └─► CacheSpellTexture()       ← sole write path for Tip.spellTexture
            └─► C_Spell.GetSpellTexture(TIP_OF_THE_SPEAR) → iconID
            └─► fallback to GetSpellTexture or FALLBACK_ICON
            └─► Tip.spellTexture = iconID

RefreshLayout() / Update() (icon mode)
    └─► reads Tip.spellTexture    ← no API call
    └─► pip.fill:SetTexture(self.spellTexture)

───────────────────────────────────────────────────────────

CICD-01 Workflow:

GitHub release created
    └─► Job: lint-and-test
    │       └─► checkout
    │       └─► install lua5.1 + luarocks
    │       └─► luacheck Duncedmaxxing/
    │       └─► busted spec/
    │
    └─► Job: package-release (needs: lint-and-test)
            └─► checkout
            └─► strip 'v' from tag → VERSION
            └─► sed -i "s/^## Version: .*/## Version: $VERSION/" Duncedmaxxing/Duncedmaxxing.toc
            └─► zip -r Duncedmaxxing-$VERSION.zip Duncedmaxxing/
            └─► softprops/action-gh-release@v2 (upload zip, prerelease=true)
```

### Recommended Project Structure Changes

```
.github/
└── workflows/
    └── release.yml      # New — triggers on release:created
```

No changes to Lua source structure. No new spec files — extend `spec/tip_spec.lua`.

### Pattern 1: Event-Driven Cache Invalidation (already in codebase)

**What:** A field on the Tip table is populated at `Initialize` time and invalidated only on specific events. The hot path (Update, RefreshLayout) reads the cached value without making API calls.

**When to use:** Any value derived from WoW API calls that is stable across combat and only changes on discrete player-state events (spec change, talent change, login).

**Established example (Phase 3):**
```lua
-- Field initialized at startup
Tip.hasTwinFangs = HasTwinFangs()   -- in Initialize()

-- Refreshed only on talent/spec events (in OnEvent)
elseif event == "PLAYER_TALENT_UPDATE" or event == "TRAIT_CONFIG_UPDATED" then
    self.hasTwinFangs = HasTwinFangs()
    ...

-- Hot path reads field, never calls API
local grant = self.hasTwinFangs and 3 or 2   -- in ApplySpell()
```

**PERF-01 follows the same pattern** for `Tip.isSurvival`:
```lua
-- Field declaration (alongside existing Tip fields, lines 45–55)
Tip.isSurvival = false

-- Initialize() — populate on first load
self.isSurvival = DMX:IsSurvivalHunter()

-- OnEvent for PLAYER_SPECIALIZATION_CHANGED, PLAYER_TALENT_UPDATE
self.isSurvival = DMX:IsSurvivalHunter()

-- Update() — reads field, does NOT call RefreshActive()
local shouldShow = unlocked or self.testMode or (cfg.enabled and self.isSurvival)
```

**Note on RefreshActive:** `Tip:RefreshActive()` currently sets `self.active`. With PERF-01, the field name changes to `self.isSurvival` (per D-01) OR the method is retained but no longer called from `Update`. CONTEXT.md D-01 uses `Tip.isSurvival`; the method `RefreshActive` can be repurposed to set `self.isSurvival` instead of `self.active`, keeping it as a convenience wrapper for the `OnEvent` paths that already call it.

### Pattern 2: One-Time Texture Cache Initialization

**What:** Texture ID resolved once at addon init; stored as `Tip.spellTexture`. Cache is refreshed on `PLAYER_LOGIN` as a safety re-check (in case API is unavailable at `Initialize` time before login completes).

**PERF-02 implementation:**
```lua
-- Field declaration
Tip.spellTexture = nil

-- New cache-populating function (replaces or wraps ResolveSpellTexture)
local function CacheSpellTexture(tip)
    local tex
    if C_Spell and C_Spell.GetSpellTexture then
        tex = C_Spell.GetSpellTexture(TIP_OF_THE_SPEAR)  -- first return value only
    end
    if not tex and _G.GetSpellTexture then
        tex = _G.GetSpellTexture(TIP_OF_THE_SPEAR)
    end
    tip.spellTexture = tex or FALLBACK_ICON
end

-- Initialize()
CacheSpellTexture(self)

-- PLAYER_LOGIN handler in OnEvent
elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
    CacheSpellTexture(self)   -- add before existing logic
    self:RefreshActive()
    ...

-- RefreshLayout() icon mode (replaces ResolveSpellTexture() calls)
pip.fill:SetTexture(self.spellTexture)

-- Update() icon mode (replaces ResolveSpellTexture() calls)
pip.fill:SetTexture(self.spellTexture)
```

**Two call sites to replace in TipOfTheSpear.lua:**
- Line 493: `pip.fill:SetTexture(ResolveSpellTexture())` inside `RefreshLayout` icon mode
- Line 651: `pip.fill:SetTexture(ResolveSpellTexture())` inside `Update` icon mode

The local function `ResolveSpellTexture` can be removed after both call sites are replaced.

### Pattern 3: GitHub Actions Release Workflow

**What:** Two-job workflow. The lint+test job runs first; the package job only runs if lint+test passes.

```yaml
# .github/workflows/release.yml
name: Release

on:
  release:
    types: [created]

jobs:
  lint-and-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install Lua and tools
        run: |
          sudo apt-get install -y lua5.1 luarocks
          luarocks install luacheck
          luarocks install busted
      - name: Lint
        run: luacheck Duncedmaxxing/
      - name: Test
        run: busted spec/

  package-release:
    needs: lint-and-test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Inject version into TOC
        run: |
          TAG="${{ github.ref_name }}"
          VERSION="${TAG#v}"
          sed -i "s/^## Version: .*/## Version: $VERSION/" Duncedmaxxing/Duncedmaxxing.toc
      - name: Create zip
        run: |
          TAG="${{ github.ref_name }}"
          VERSION="${TAG#v}"
          zip -r "Duncedmaxxing-$VERSION.zip" Duncedmaxxing/
      - name: Upload release asset
        uses: softprops/action-gh-release@v2
        with:
          files: Duncedmaxxing-*.zip
          prerelease: true
          generate_release_notes: true
```

[ASSUMED — apt package names `lua5.1` and `luarocks` on ubuntu-latest not explicitly confirmed in this session; this is a well-known pattern but the planner should verify the apt package availability]

### Anti-Patterns to Avoid

- **Calling IsSurvivalHunter() in Update():** Current bug (line 598). After PERF-01, `Update` must read `self.isSurvival` only.
- **Calling RefreshActive() in Update():** Current bug (line 598). The `OnEvent` handler is the sole refresh path post-PERF-01.
- **Calling ResolveSpellTexture() in RefreshLayout() or Update():** Current bug (lines 493, 651). After PERF-02, both call sites read `self.spellTexture`.
- **Populating spellTexture in RefreshLayout/Update:** Texture must be cached at Initialize/PLAYER_LOGIN, not on each layout pass.
- **Forgetting `nil` guard on spellTexture:** If `CacheSpellTexture` is called before `PLAYER_LOGIN` and the API returns nil, `self.spellTexture` should be `FALLBACK_ICON`, not nil, so downstream code never receives nil.
- **Version injection without stripping 'v' prefix:** `github.ref_name` for a tag `v1.0.0` returns the full `v1.0.0`; the sed command must strip the leading `v` before writing into the TOC.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| GitHub release asset upload | Custom upload script with curl | `softprops/action-gh-release@v2` | Handles auth, retries, asset deduplication, prerelease flags |
| Lua CI environment | Custom Dockerfile or shell installation script | `apt-get install lua5.1 luarocks` on ubuntu-latest | Standard path; maintained by Ubuntu/GitHub |
| Zip packaging | tar, manual file listing | `zip -r` with directory argument | WoW addon installers expect `.zip` with directory structure |

**Key insight:** Both performance fixes are pure Lua state additions — no WoW API knowledge gap here. The only "don't hand-roll" concern is the CI/CD layer: use the standard GitHub Actions release action rather than hand-writing upload logic.

---

## Common Pitfalls

### Pitfall 1: `self.active` vs `self.isSurvival` naming consistency

**What goes wrong:** `RefreshActive` currently sets `self.active`. If the planner renames the field to `isSurvival` (per D-01) but leaves some call sites reading `self.active`, the tracker silently stops working for non-Survival specs.

**Why it happens:** Three places read `self.active`: `Update` (line 605), `OnEvent UNIT_SPELLCAST_SUCCEEDED` (lines 754–758). A rename without auditing all read sites breaks spec-gating.

**How to avoid:** Search `TipOfTheSpear.lua` for every occurrence of `self.active` before the rename. All four occurrences (1 write in `RefreshActive`, 1 in `Update`, 2 in `OnEvent`) must be updated atomically.

**Warning signs:** Tracker shows stacks for non-Survival specs in testing.

### Pitfall 2: `spellTexture` nil before first PLAYER_LOGIN

**What goes wrong:** `Initialize()` is called at `ADDON_LOADED`. If `C_Spell.GetSpellTexture` is unavailable at that moment (unlikely but possible), `Tip.spellTexture` would be nil. `RefreshLayout` and `Update` call `pip.fill:SetTexture(self.spellTexture)` — passing nil to `SetTexture` is a Lua error in older WoW surfaces.

**Why it happens:** `CacheSpellTexture` must always produce a non-nil value. The `FALLBACK_ICON = 132275` constant exists precisely for this case.

**How to avoid:** The cache-populate function must always fall through to `FALLBACK_ICON`. Pattern: `tip.spellTexture = tex or FALLBACK_ICON`.

**Warning signs:** Nil texture crash in icon mode on fresh install.

### Pitfall 3: `sed` version injection breaks TOC field names

**What goes wrong:** The `sed` pattern `^## Version: .*` replaces the entire `## Version:` line. If the TOC has trailing whitespace or Windows line endings (CRLF), the pattern may fail to match.

**Why it happens:** The repository may have CRLF line endings in the TOC after Phase 0 cleanup. `sed -i` on Linux treats `\r\n` as part of the line content.

**How to avoid:** The TOC currently has Unix line endings (confirmed: Phase 0 CLN-01 stripped Zone.Identifier files; `.gitattributes` not inspected but repo is Linux-native). The `sed` command is standard. Add `echo "Injected version: $VERSION"` after the sed step so CI logs confirm the injection succeeded.

**Warning signs:** Release zip contains `## Version: 0.3.2` instead of the tag-derived version.

### Pitfall 4: luacheck warns treated as errors block release

**What goes wrong:** The existing codebase has 6 luacheck warnings (`unused argument self` in Core.lua and Options.lua). If the CI lint step uses `luacheck --no-cache` without an error-exit-code guard, these warnings will fail the job.

**Why it happens:** `luacheck` exits with code 1 when there are warnings (not just errors). GitHub Actions treats non-zero exit as failure.

**How to avoid:** Either fix the 6 pre-existing warnings before adding the CI job, or configure the CI lint step to only fail on errors (exit code ≥ 2): `luacheck Duncedmaxxing/ || [ $? -lt 2 ]`. The pre-existing warnings are non-blocking style issues; the planner should decide whether to fix them (preferable) or gate on exit code.

**Warning signs:** `lint-and-test` job fails immediately on the existing codebase before any caching changes are made.

### Pitfall 5: `isSurvival` not reset in `loader.resetTipState`

**What goes wrong:** Tests for caching behavior check `Tip.isSurvival` after specific events. If `resetTipState` does not zero `isSurvival`, tests may see stale cache state from the previous `loader.load()` call.

**Why it happens:** `loader.resetTipState` in `spec/support/init.lua` zeroes a fixed list of fields (lines 53–67). New fields added to Tip must be added to this list.

**How to avoid:** Add `Tip.isSurvival = false` and `Tip.spellTexture = nil` to `resetTipState`. Also verify that `loader.load()` bootstraps Initialize() — it does (line 43: `DMX:ForEachModule("Initialize", DMX)`) — so `isSurvival` and `spellTexture` will be populated immediately after load, making `resetTipState` the only place to reset them for isolated tests.

---

## Code Examples

### Example 1: isSurvival field declaration and initialization

```lua
-- Source: Phase 3 Tip.hasTwinFangs pattern (TipOfTheSpear.lua:55, :779)
-- Add alongside existing Tip field declarations
Tip.isSurvival = false

-- In Initialize()
self.isSurvival = DMX:IsSurvivalHunter()

-- In OnEvent for spec/talent events
elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
    local unit = ...
    if unit == "player" then
        self.stacks = 0
        self.hasTwinFangs = HasTwinFangs()
        self.isSurvival = DMX:IsSurvivalHunter()  -- cache refresh
        self:SyncFromAura()
        self:Update()
    end
    return
elseif event == "PLAYER_TALENT_UPDATE" or event == "TRAIT_CONFIG_UPDATED" then
    self.hasTwinFangs = HasTwinFangs()
    self.isSurvival = DMX:IsSurvivalHunter()  -- cache refresh
    self:Update()
    return
```

### Example 2: Update() with isSurvival (line 598 fix)

```lua
-- BEFORE (current, TipOfTheSpear.lua:598):
--   self:RefreshActive()
--   local shouldShow = unlocked or self.testMode or (cfg.enabled and self.active)

-- AFTER (PERF-01):
-- Remove self:RefreshActive() call entirely.
-- Replace self.active with self.isSurvival in the visibility check:
local shouldShow = unlocked or self.testMode or (cfg.enabled and self.isSurvival)
```

### Example 3: spellTexture cache population

```lua
-- Source: warcraft.wiki.gg verified two-return-value contract
-- New local function replacing ResolveSpellTexture (to be called once, not per-frame)
local function CacheSpellTexture(tip)
    local tex
    if C_Spell and C_Spell.GetSpellTexture then
        tex = C_Spell.GetSpellTexture(TIP_OF_THE_SPEAR)  -- captures first return value only
    end
    if not tex and _G.GetSpellTexture then
        tex = _G.GetSpellTexture(TIP_OF_THE_SPEAR)
    end
    tip.spellTexture = tex or FALLBACK_ICON
end
```

### Example 4: RefreshLayout icon mode (PERF-02 hot-path fix)

```lua
-- BEFORE (TipOfTheSpear.lua:493):
--   pip.fill:SetTexture(ResolveSpellTexture())

-- AFTER:
pip.fill:SetTexture(self.spellTexture)
```

### Example 5: Test stubs — spellTexture cache test

```lua
-- New describe block in spec/tip_spec.lua, following D-12/D-13 pattern
describe("Caching — isSurvival and spellTexture", function()
    local DMX, Tip, clock

    before_each(function()
        DMX, Tip, clock = loader.load()
        loader.resetTipState(Tip, clock)
    end)

    it("Tip.isSurvival is true after Initialize (Survival Hunter stub)", function()
        -- stubs return spec 3 (Survival) by default
        assert.is_true(Tip.isSurvival)
    end)

    it("Tip.spellTexture is non-nil after Initialize", function()
        assert.is_not_nil(Tip.spellTexture)
    end)

    it("Tip.isSurvival updates on PLAYER_SPECIALIZATION_CHANGED", function()
        -- Override stub to return a non-Survival spec
        _G.C_SpecializationInfo.GetSpecialization = function() return 1 end
        Tip:OnEvent("PLAYER_SPECIALIZATION_CHANGED", "player")
        assert.is_false(Tip.isSurvival)
    end)
end)
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `GetSpellTexture()` (one return value) | `C_Spell.GetSpellTexture()` (two return values: iconID, originalIconID) | Patch 11.0.0 | Old API removed in 11.0.2; dual-path needed for compatibility |
| `GetSpecialization()` (global) | `C_SpecializationInfo.GetSpecialization()` | Patch 10.0 | Old global deprecated; dual-path needed for compatibility |
| Tag-triggered workflows (`on: push: tags:`) | Release-triggered workflows (`on: release: types: [created]`) | GitHub Actions matured 2021+ | Release-triggered allows draft releases without CI runs |

**Deprecated/outdated:**
- `_G.GetSpellTexture`: Removed in 11.0.2. The fallback path in `ResolveSpellTexture` is dead for 12.0.5 but must be preserved per CLAUDE.md API compatibility constraint.
- `GetSpecialization` (global): Same situation — dual-path preserved in `DMX:IsSurvivalHunter()`.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `leafo/gh-actions-lua@v10` and `leafo/gh-actions-luarocks@v4` are the correct current action names and versions | Standard Stack / CI Installation | CI workflow fails on first run; planner must verify GitHub URLs |
| A2 | `apt-get install lua5.1 luarocks` installs Lua 5.1 on ubuntu-latest runners | Standard Stack / CI Installation | CI lint+test job fails; alternative is leafo actions |
| A3 | `actions/checkout@v4` is the current stable version | Standard Stack | Minor version pin issue; functionally correct regardless |
| A4 | `softprops/action-gh-release@v2` (v2.6.2) is Node 20 compatible and works on ubuntu-latest | Standard Stack | Release job fails; fix is pin to specific version or upgrade to @v3 |
| A5 | The TOC file has Unix line endings, making the sed version injection reliable | Common Pitfalls | Version injection fails silently; add echo verification step to detect |

**If this table is empty:** Not applicable — five assumptions present.

---

## Open Questions

1. **Pre-existing luacheck warnings: fix or gate?**
   - What we know: 6 warnings exist (`unused argument self` in Core.lua lines 131, 137 and Options.lua lines 142, 172, 452, 456). All are pre-existing, not introduced by this phase.
   - What's unclear: D-14 says "runs `luacheck` and `busted`" but doesn't specify whether warnings are acceptable.
   - Recommendation: Fix the warnings as Wave 0 of the CI plan (trivial: remove unused `self` parameters from function signatures or suppress with `--ignore 212`). This keeps the CI gate clean.

2. **`Tip.active` vs `Tip.isSurvival`: two-field migration or rename?**
   - What we know: `self.active` is the current field written by `RefreshActive()` and read in `Update()` (line 605) and `OnEvent()` (lines 754–758). D-01 calls the new field `Tip.isSurvival`.
   - What's unclear: Should `RefreshActive` be refactored to set `self.isSurvival` (and `self.active` removed), or should it remain and update the new field?
   - Recommendation: Rename `self.active` to `self.isSurvival` globally. Update `RefreshActive` to set `self.isSurvival`. This is cleaner than maintaining both fields and matches D-01's naming.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `luacheck` | D-14 CI lint job (local dev run) | ✓ | 1.2.0 | — |
| `busted` | D-12/D-13 caching tests, D-14 CI test job | ✓ | 2.3.0 | — |
| GitHub Actions runner | CICD-01 | ✓ (GitHub-hosted) | ubuntu-latest | — |
| `softprops/action-gh-release` | CICD-01 release asset upload | ✓ (GitHub Marketplace) | v2 | Manual upload |
| `actions/checkout` | CICD-01 workflow | ✓ (GitHub official) | v4 | — |

**Missing dependencies with no fallback:** None — all required tools are available.

**Missing dependencies with fallback:** None.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | busted 2.3.0 |
| Config file | `.busted` (root) |
| Quick run command | `busted spec/tip_spec.lua` |
| Full suite command | `busted spec/` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PERF-01 | `Tip.isSurvival` is `true` after Initialize with Survival stub | unit | `busted spec/tip_spec.lua` | ❌ Wave 0 — new describe block in tip_spec.lua |
| PERF-01 | `Tip.isSurvival` updates correctly on `PLAYER_SPECIALIZATION_CHANGED` | unit | `busted spec/tip_spec.lua` | ❌ Wave 0 |
| PERF-01 | `Update()` body has no call to `RefreshActive()` or `IsSurvivalHunter()` | code-review (static) | `grep -n "RefreshActive\|IsSurvivalHunter" Duncedmaxxing/Modules/TipOfTheSpear.lua` | — |
| PERF-02 | `Tip.spellTexture` is non-nil after Initialize | unit | `busted spec/tip_spec.lua` | ❌ Wave 0 |
| PERF-02 | `RefreshLayout` and `Update` body have no call to `ResolveSpellTexture` | code-review (static) | `grep -n "ResolveSpellTexture\|GetSpellTexture" Duncedmaxxing/Modules/TipOfTheSpear.lua` | — |
| CICD-01 | Workflow file exists and triggers on release:created | manual | Push a test release tag | ❌ Wave 0 — `.github/workflows/release.yml` |

### Sampling Rate

- **Per task commit:** `busted spec/tip_spec.lua`
- **Per wave merge:** `busted spec/`
- **Phase gate:** Full suite green (`busted spec/`) before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] New `describe("Caching — isSurvival and spellTexture", ...)` block in `spec/tip_spec.lua` — covers PERF-01 and PERF-02 regression assertions
- [ ] `loader.resetTipState` in `spec/support/init.lua` — add `Tip.isSurvival = false` and `Tip.spellTexture = nil`
- [ ] `.github/workflows/release.yml` — covers CICD-01
- [ ] Fix pre-existing 6 luacheck warnings before CI job goes live (or add `|| [ $? -lt 2 ]` gate in workflow)

---

## Security Domain

This phase adds a GitHub Actions workflow and Lua module-level field additions only. No authentication, session management, cryptography, or user input handling is introduced.

The CI workflow uses `GITHUB_TOKEN` (auto-provided by GitHub Actions) for `softprops/action-gh-release` — this is the standard zero-configuration token for release asset upload and does not require additional secret management.

No ASVS categories apply to the Lua caching changes. The CI/CD workflow has no attack surface beyond standard GitHub Actions supply-chain hygiene (pinned action versions).

---

## Sources

### Primary (HIGH confidence)
- warcraft.wiki.gg/wiki/API_C_Spell.GetSpellTexture — verified two-return-value contract (iconID, originalIconID), MayReturnNothing annotation, version support through 12.0.7
- warcraft.wiki.gg/wiki/API_GetSpellTexture — confirmed deprecated since 11.0.0, removed 11.0.2
- TipOfTheSpear.lua (codebase) — confirmed call sites: lines 137–147, 493, 598, 651
- spec/support/wow_stubs.lua (codebase) — confirmed existing C_Spell.GetSpellTexture stub
- spec/support/init.lua (codebase) — confirmed loader and resetTipState patterns
- .planning/codebase/CONCERNS.md — confirmed bottleneck descriptions (lines 59–69)

### Secondary (MEDIUM confidence)
- GitHub Marketplace (softprops/action-gh-release) — v3 requires Node 24; v2 works on Node 20 ubuntu-latest
- WebSearch (GitHub Actions release trigger syntax) — `on: release: types: [created]` confirmed pattern, with note that draft releases are excluded

### Tertiary (LOW confidence / ASSUMED)
- leafo/gh-actions-lua and leafo/gh-actions-luarocks action names and versions — confirmed as widely-used community standard but not verified against their GitHub repositories in this session
- ubuntu-latest apt package names (lua5.1, luarocks) — standard assumption, not explicitly confirmed for current ubuntu-latest runner image

---

## Metadata

**Confidence breakdown:**
- PERF-01 caching implementation: HIGH — pattern directly established by Phase 3; all source locations confirmed; no unknowns
- PERF-02 texture caching + `C_Spell.GetSpellTexture` contract: HIGH — verified against warcraft.wiki.gg; two-return-value behavior confirmed
- CICD-01 workflow structure: MEDIUM — release trigger and softprops/action-gh-release confirmed; Lua install mechanism (leafo vs apt) carries ASSUMED tags
- Test additions: HIGH — existing test infrastructure thoroughly documented and confirmed working (102 tests pass)

**Research date:** 2026-06-18
**Valid until:** 2026-09-18 (stable WoW API + stable GitHub Actions — 90-day window)
