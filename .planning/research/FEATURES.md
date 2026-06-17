# Feature Research

**Domain:** WoW addon quality — polish pass for a combat aura/stack tracker
**Researched:** 2026-06-17
**Confidence:** MEDIUM-HIGH (core patterns well-established; some items from community observation rather than official standards)

---

## Context

This is a polish milestone on an existing, working addon. The feature question is not "what to build" but "what does a well-polished WoW addon look like, and which of those qualities does Duncedmaxxing need?" The addon's core value is accurate, instant stack display during combat. Every quality decision should be judged against that.

Specifically the addon runs in the WoW Lua 5.1 sandbox, targets Midnight 12.0.5, has no external dependencies, and must respect combat lockdown restrictions.

---

## Feature Landscape

### Table Stakes (Users Expect These)

Features users assume exist. Missing these = product feels incomplete or broken.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Zero Lua errors under normal use | Users see red Lua popups as addon breakage; any error in a combat tracker = loss of trust immediately | LOW | The `auraVerifyPending` stuck-flag bug and the `stale stacks out-of-combat` bug both produce silent wrong state, which is worse than a visible error. Fix both. |
| Correct stack display at all times | Core value of the addon. If count is wrong, the addon has no purpose | LOW-MEDIUM | The `+2` hard-code for Kill Command and the stale display on mode-switch are active violations of this expectation |
| Predictable settings persistence | SavedVariables must round-trip correctly across `/reload ui` and relog | LOW | DB migration code must be clean — dead fallback code risks silent data corruption on future migrations |
| No combat lockdown violations | Any taint or protected-function call during `InCombatLockdown()` breaks combat and generates Lua errors; users will uninstall immediately | LOW-MEDIUM | Options window already has a combat guard; this is about not introducing new violations during refactor |
| No per-frame garbage in combat | GC spikes during combat cause micro-freezes; users notice frame hitching immediately, especially in progression raiding | MEDIUM | The `ResolveSpellTexture` and `IsSurvivalHunter`/`UnitClass` calls on every `Update` are active violations |
| Slash command works | `/dmax` must be responsive and give useful output; broken slash command signals abandoned addon | LOW | Already implemented; protect during refactor |
| Options UI that responds correctly | Settings changes must take effect immediately and visually confirm; if a setting appears to save but doesn't, users file bugs | LOW | Mode-switch stale display is the known violation here |

### Differentiators (Competitive Advantage)

Features that set the addon apart. Not required, but add meaningful value for the target user (raiding Survival Hunters who care about optimal play).

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Predictive stack tracking (pre-server confirmation) | Eliminates the ~100–250ms server-round-trip delay; display matches intent not confirmation; nobody else does this for Tip of the Spear | MEDIUM | Already implemented as a differentiator; must be kept correct after refactor — `ApplySpell` logic is the crown jewel |
| Aura-verify sanity check with grace period | Catches prediction errors without creating false flicker; more accurate than either pure-prediction or pure-aura approaches | MEDIUM | Already implemented; the stuck-flag bug undermines reliability. Fixing it restores the differentiator |
| Unit test coverage of core prediction math | Not visible to end users but enables confident iteration without in-game testing for every change; critical for a combat-facing addon where bugs surface under fire | HIGH | No existing tests; busted + WoW API mock layer is the implementation path. The `ApplySpell`, `SyncFromAura`, and `NormalizeDB` functions are pure Lua and testable outside WoW |
| Accurate spec-gating (only active as Survival) | Does not clutter display or interfere when player switches specs; spec-aware addons feel professional | LOW | Already implemented; caching `IsSurvivalHunter` result removes per-update API calls without changing the behavior |
| Clean, readable source (no dead code, no duplication) | Makes future contributions and maintainer-self-review faster; reduces regression risk when Blizzard patches break API surfaces | MEDIUM | Tech debt items in CONCERNS.md (duplicate utilities, dead migration fallback, `pcall` on table lookup) all degrade this |

### Anti-Features (Commonly Requested, Often Problematic)

Features that seem valuable but should be deliberately avoided.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Ace3 / LibStub dependency adoption | Reduces boilerplate for options UI and event handling; many popular addons use it | Adds an external dependency to what is intentionally dependency-free; creates upgrade coupling to a third-party library release cycle; out of scope per PROJECT.md | Keep custom implementation; extract shared utilities to Util.lua instead |
| OnUpdate polling for stack display | Seems simpler than event-driven design; some older addons use it | Runs every frame (60+/sec); generates per-frame garbage if any table allocation occurs; creates GC pressure in combat; completely unnecessary when UNIT_AURA and UNIT_SPELLCAST_SUCCEEDED already fire at the right moments | Keep the existing event-driven architecture; fix the caching gaps instead |
| Persistent test mode across reloads | Convenient for iterative visual testing during development | Adds a saved variable that has no player-facing value; can cause confusing state for end users if test mode activates unexpectedly on login | Accept test mode as session-only; document the `/dmax test` command clearly in the options window |
| Global variable namespace expansion | Quick way to share state between modules | Global namespace pollution; risk of collision with Blizzard or other addons; taint surface increases | Expose shared state on the `DMX` table or as explicit module function parameters |
| Defensive pcall around every function call | Seems to improve robustness; prevents any error from propagating | Hides real bugs; adds per-call overhead in combat; obscures intent; the existing `pcall` on `ClassifySpellID` is already an example of this going wrong | Remove unnecessary pcalls; use pcall only at true integration boundaries (e.g., when calling potentially-nil WoW API functions on old interface versions) |
| New tracking modules in this milestone | Tempting to add Pack Leader tracking while already refactoring | Out of scope per PROJECT.md; increases test surface before test infrastructure exists; risks scope creep that delays the polish work | Defer to next milestone after test suite is established |

---

## Feature Dependencies

```
[Util.lua extraction]
    └──enables──> [Unit tests for ParseHexColor, Clamp]
    └──enables──> [Consistent nil-handling across Core and Options]

[busted test framework + WoW API mock layer]
    └──requires──> [Util.lua extraction] (tests need stable shared utility surface)
    └──enables──> [ApplySpell unit tests]
    └──enables──> [SyncFromAura unit tests]
    └──enables──> [NormalizeDB unit tests]

[Fix auraVerifyPending stuck flag]
    └──requires no other fix, but should be──> [validated by SyncFromAura unit test]

[Fix stale display on mode-switch out of combat]
    └──requires──> [understanding of Update/SyncFromAura call graph]
    └──enables──> [options UI behaving correctly: table stakes]

[Spec/texture caching]
    └──requires──> [moduleOrder array or ordered iteration] (if RefreshActive is moved to event boundaries, ordering matters for initialization)
    └──eliminates──> [per-update WoW API calls during combat]

[Remove dead NormalizeDB fallback]
    └──safe only after──> [DB migration version bump]
    └──enables──> [clean NormalizeDB unit tests]

[moduleOrder array]
    └──enables──> [deterministic ForEachModule iteration]
    └──enables──> [safe multi-module future]
```

### Dependency Notes

- **Util.lua extraction must precede unit tests:** Tests need to import utilities directly; if they live in Core.lua and Options.lua they cannot be loaded in isolation in a busted environment without pulling in the full WoW frame environment.
- **busted + mock layer must precede any test authoring:** The mock layer defines what WoW API surface the tests can call; tests written before the mock exists would require constant retrofitting.
- **auraVerifyPending fix is independent:** It touches only TipOfTheSpear.lua and requires no other change. Fix first, validate manually, then write the regression test once the test framework exists.
- **Spec/texture caching conflicts with calling RefreshActive from Update:** These changes must be coordinated — removing `RefreshActive()` from `Update()` requires ensuring every event that could change spec state is already registered to call `RefreshActive()` explicitly. Confirm event coverage before removing the call.

---

## MVP Definition for This Milestone

This is not a greenfield MVP — the addon already works. "MVP" here means: minimum set of polish work that makes the addon genuinely reliable and maintainable.

### Must Complete (blocks release of polished version)

- [ ] Fix `auraVerifyPending` stuck flag — active bug that silently suppresses aura verification
- [ ] Fix stale stack display on mode-switch out of combat — visible correctness failure
- [ ] Extract Util.lua with `Clamp` and `ParseHexColor` — prerequisite for testable utilities
- [ ] Set up busted + WoW API mock layer — prerequisite for all unit tests
- [ ] Unit tests for `ApplySpell`, `SyncFromAura`, `NormalizeDB`, utility functions — without these, the refactor has no regression protection

### Should Complete (meaningfully improves maintainability)

- [ ] Cache spec state — removes per-update WoW API calls during combat; correctness-preserving change
- [ ] Cache spell texture — removes per-update WoW API call during combat; correctness-preserving change
- [ ] Remove `pcall` from `ClassifySpellID` — eliminates per-cast overhead with no functional change
- [ ] Move frame locals to `Tip` table fields — makes frame state testable and inspectable
- [ ] Add `moduleOrder` array for deterministic iteration — low risk, prevents non-determinism as addon grows

### Defer (worthwhile but not this milestone)

- [ ] Remove dead NormalizeDB fallback — safe only after version bump; low practical risk today
- [ ] Per-module options section convention (`BuildOptionsSection` callback) — architecture work for multi-module future; not needed until second module exists
- [ ] Test mode persistence — developer convenience only; no end-user value

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Fix auraVerifyPending bug | HIGH (correctness) | LOW | P1 |
| Fix stale display on mode-switch | HIGH (correctness) | LOW | P1 |
| busted + mock layer setup | HIGH (enables all regression tests) | MEDIUM | P1 |
| Unit tests for ApplySpell, SyncFromAura | HIGH (protects crown-jewel logic) | MEDIUM | P1 |
| Unit tests for NormalizeDB, utilities | MEDIUM (protects data integrity) | LOW | P1 |
| Extract Util.lua | MEDIUM (prerequisite; reduces bug divergence) | LOW | P1 |
| Cache spec state | MEDIUM (removes per-update API calls) | LOW | P2 |
| Cache spell texture | MEDIUM (removes per-update API calls) | LOW | P2 |
| Remove pcall from ClassifySpellID | LOW-MEDIUM (minor perf + clarity) | LOW | P2 |
| Move frame locals to Tip fields | MEDIUM (testability) | MEDIUM | P2 |
| moduleOrder array | LOW now, HIGH later | LOW | P2 |
| Remove dead NormalizeDB fallback | LOW (dead code only) | LOW | P3 |

---

## Competitor Feature Analysis

The primary competitors for Duncedmaxxing are WeakAuras (general aura display framework) and custom spec-tracker addons. This addon's differentiator is not feature breadth but precision for Survival Hunter specifically.

| Feature | WeakAuras | Generic Stack Trackers | Duncedmaxxing Approach |
|---------|-----------|------------------------|------------------------|
| Predictive tracking | No (aura-based only) | No (aura-based only) | Yes — pre-confirms cast before server response |
| Spec-specific logic | User must configure | Varies | Built-in; only active as Survival |
| Setup burden | High (user builds everything) | Low (works out of box) | Low (zero configuration required) |
| Test coverage | Extensive CI/CD | None typically | Target: busted unit tests for pure logic |
| Error handling | Mature (Ace3 safecall) | Minimal | Target: no errors; no unnecessary pcalls |
| Performance | Heavy (general framework) | Varies | Target: event-driven, cached, zero per-frame work |
| Dependencies | Many (embedded libs) | None or Ace3 | None — intentional constraint |

---

## Sources

- [WoW UI Best Practices — AddOn Studio](https://addonstudio.org/wiki/WoW:UI_best_practices) — local variables, hook patterns, memory management
- [Secure Execution and Tainting — Wowpedia](https://wowpedia.fandom.com/wiki/Secure_Execution_and_Tainting) — taint rules, combat lockdown behavior
- [wowmock — Adirelle/wowmock](https://github.com/Adirelle/wowmock) — WoW API mock approach for busted/luaunit testing
- [OnUpdate throttling example — Choonster/gist](https://gist.github.com/Choonster/eb07bbd750776d1254fc) — event-driven vs polling patterns
- [busted GitHub Action](https://github.com/marketplace/actions/lua-busted) — Lua 5.1 compatible busted test runner
- [Luacheck boilerplate for WoW addons — LenweSaralonde/gist](https://gist.github.com/LenweSaralonde/13a217b5d7186f9218ae62736e2bff90) — standard luacheck config patterns
- [AdiButtonAuras — AdiAddons](https://github.com/AdiAddons/AdiButtonAuras) — reference for polished aura-display addon with tests directory and CI
- [CurseForge OnUpdate throttling discussion](https://authors.curseforge.com/forums/world-of-warcraft/general-chat/lua-code-discussion/225689-newbie-tip-for-onupdate-performance)
- Project context: `.planning/PROJECT.md`, `.planning/codebase/CONCERNS.md`

---

*Feature research for: WoW addon polish (combat tracker quality standards)*
*Researched: 2026-06-17*
