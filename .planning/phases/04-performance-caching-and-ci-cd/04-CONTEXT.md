# Phase 4: Performance Caching and CI/CD - Context

**Gathered:** 2026-06-18
**Status:** Ready for planning

<domain>
## Phase Boundary

The addon no longer makes per-frame WoW API calls during combat, and a GitHub Actions workflow packages a distributable zip on release creation. This phase delivers PERF-01, PERF-02, and CICD-01 from REQUIREMENTS.md.

</domain>

<decisions>
## Implementation Decisions

### Spec State Caching (PERF-01)
- **D-01:** Cache `IsSurvivalHunter` result as `Tip.isSurvival` (or equivalent field on the Tip table). Refresh only on `PLAYER_SPECIALIZATION_CHANGED` and `PLAYER_TALENT_UPDATE` events — not on every `Update` call.
- **D-02:** Remove the `self:RefreshActive()` call from inside `Update`. The `OnEvent` handler for specialization/talent events already calls `RefreshActive` explicitly — that's the sole refresh path.
- **D-03:** Follows the same event-driven cache pattern established in Phase 3 D-03 (talent state cached on the same two events).

### Spell Texture Caching (PERF-02)
- **D-04:** Resolve and cache the spell texture as `Tip.spellTexture` once at `Initialize` time (and on `PLAYER_LOGIN` as a safe re-check). `RefreshLayout` and `Update` read the cached value — no calls to `C_Spell.GetSpellTexture` or `ResolveSpellTexture` in hot paths.
- **D-05:** Research flag from STATE.md: `C_Spell.GetSpellTexture` two-return-value behavior under patch 12.0.5 must be verified against warcraft.wiki.gg before implementing the caching. Researcher agent must resolve this.

### Release Workflow (CICD-01)
- **D-06:** GitHub Actions workflow triggers on `release: [created]` (not tag push). Creates a zip of the entire `Duncedmaxxing/` directory and uploads it as a release asset using `softprops/action-gh-release@v2`. Releases are marked as prerelease.
- **D-07:** Zip contains all files in the `Duncedmaxxing/` directory — TOC, all Lua files, Media/, and any future assets. Packaged with `Duncedmaxxing/` as the top-level folder so users can extract directly into `Interface/AddOns/`.
- **D-08:** Release notes auto-generated from commits using GitHub's built-in feature. No manual CHANGELOG.md maintenance.
- **D-09:** User provided a sample workflow file (from another addon) as the structural template. Adapt it for this project — replace addon name, add version injection step.

### Version Management
- **D-10:** CI workflow injects the git tag into the TOC's `## Version:` field (via sed) before creating the zip. The tag name (e.g., `v1.0.0`) is stripped of the `v` prefix and written as the version string. Users never need to manually bump the TOC version for releases.
- **D-11:** The TOC's `## Interface:` version (currently `120005`) stays manually maintained. It only changes when targeting a new WoW patch — not something CI should automate.

### Caching Test Coverage
- **D-12:** Add regression tests for both caching changes. State-based assertions: verify `Tip.isSurvival` is set after Initialize, changes correctly after `PLAYER_SPECIALIZATION_CHANGED` event, and `Tip.spellTexture` is non-nil after Initialize.
- **D-13:** Tests follow existing patterns from Phase 2 — per-test isolation via `loader.load()` in `before_each`, mock clock, mock aura infrastructure.

### CI Lint and Test Job
- **D-14:** The GitHub Actions workflow includes a lint+test job that runs `luacheck` and `busted` on every push to main and on PRs. This catches regressions before release. Separate job from the release packaging job.

### Claude's Discretion
- D-02 scope: Claude decides whether to inline the cached check in `Update` or factor it into a helper, based on code clarity.
- D-04 implementation: Claude decides whether `ResolveSpellTexture` is refactored to a cache-populating function called once, or replaced entirely with a direct API call at init time.
- D-14 details: Claude decides the exact CI job structure (matrix vs single job, Lua version pinning, caching of luarocks dependencies).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project Context
- `.planning/PROJECT.md` — Core value, constraints, key decisions
- `.planning/REQUIREMENTS.md` — PERF-01, PERF-02, CICD-01 define exact deliverables and acceptance criteria

### Prior Phase Context
- `.planning/phases/03-bug-fixes-with-test-coverage/03-CONTEXT.md` — D-03 (talent state cached on PLAYER_TALENT_UPDATE/PLAYER_SPECIALIZATION_CHANGED). PERF-01 integrates with this same event-driven cache pattern.
- `.planning/phases/01-utility-extraction-and-module-encapsulation/01-CONTEXT.md` — D-06/D-08 (Tip.* frame fields, hot-path local aliases). New cached fields follow the same Tip.* pattern.
- `.planning/phases/02-test-framework-and-core-logic-tests/02-CONTEXT.md` — Test infrastructure decisions (D-05 loader, D-06 isolation, D-08 mock clock). New caching tests must follow these established patterns.

### Architecture & Performance
- `.planning/codebase/CONCERNS.md` — Performance Bottlenecks section: detailed description of `ResolveSpellTexture` per-update calls (lines 60-63) and `RefreshActive` per-event calls (lines 65-69) with exact file locations and fix approaches
- `.planning/codebase/STACK.md` — Technology stack, runtime constraints, no build toolchain

### Testing
- `.planning/codebase/TESTING.md` — Test infrastructure details, existing coverage map, mock patterns

### Source Files (modification targets)
- `Duncedmaxxing/Modules/TipOfTheSpear.lua` — Contains: `ResolveSpellTexture` (line 134), `RefreshActive` call in `Update` (line 582), `OnEvent` handler for event registration, `Initialize` for cache population
- `Duncedmaxxing/Core.lua` — Contains: `IsSurvivalHunter` (line 172), spec detection helpers

### Test Files (extend for caching tests)
- `spec/tip_spec.lua` — Extend with caching state-based assertions
- `spec/support/wow_stubs.lua` — May need spy/tracking support for C_SpecializationInfo and C_Spell stubs
- `spec/support/init.lua` — May need cache field resets in `resetTipState`

### CI/CD
- User-provided sample workflow (inline in discussion): triggers on `release: [created]`, uses `softprops/action-gh-release@v2`, zips addon directory, marks prerelease

### External References
- warcraft.wiki.gg — Canonical source for: `C_Spell.GetSpellTexture` return contract (research flag — verify two-return-value behavior under 12.0.5)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `ResolveSpellTexture` (TipOfTheSpear.lua:134): Dual-path API call (`C_Spell.GetSpellTexture` / `_G.GetSpellTexture`) — refactor to cache-populating function called once
- `DMX:IsSurvivalHunter` (Core.lua:172): Spec detection with dual-path API — result becomes the cached `Tip.isSurvival` value
- `Tip.hasTwinFangs` cache (Phase 3 output): Talent cache pattern already established on the same events — spec cache follows identical structure
- Existing `mockClock` and `mockAura` test infrastructure: reuse for caching verification tests
- `loader.resetTipState` (spec/support/init.lua): extend to include `isSurvival` and `spellTexture` cache fields

### Established Patterns
- Event-driven state updates: `PLAYER_REGEN_DISABLED/ENABLED` → `self.inCombat`, `PLAYER_TALENT_UPDATE` → `self.hasTwinFangs`. Spec cache follows the same pattern.
- Hot-path local aliases (Phase 1 D-08): `local root, pips = self.root, self.pips` at function entry. Cached fields may also benefit from local aliases in `Update`.
- Per-test isolation via `loader.load()` in `before_each`: all new caching tests must follow this pattern.

### Integration Points
- `Tip:OnEvent` handler: needs `PLAYER_SPECIALIZATION_CHANGED` event registration (may already exist from Phase 3 talent work)
- `Tip:Initialize`: add texture resolution and spec state population
- `Tip:Update` (line 582): remove `self:RefreshActive()` call — the primary PERF-01 fix
- `Tip:RefreshLayout` (line 484): replace `ResolveSpellTexture()` call with cached `self.spellTexture` read
- `.github/workflows/release.yml`: new file — GitHub Actions workflow

</code_context>

<specifics>
## Specific Ideas

- User provided a sample workflow from another addon (SimpleCursorRing) as the structural template. The adapted workflow should follow the same pattern: trigger on release created, zip the addon directory, upload with softprops/action-gh-release@v2, mark as prerelease.
- Version injection step: `sed -i "s/^## Version: .*/## Version: ${TAG}/" Duncedmaxxing/Duncedmaxxing.toc` before zipping, where TAG is the release tag with `v` prefix stripped.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 4-Performance Caching and CI/CD*
*Context gathered: 2026-06-18*
