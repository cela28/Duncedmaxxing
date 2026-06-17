# Pitfalls Research

**Domain:** WoW addon refactoring/polish — Lua 5.1 sandbox, no build toolchain
**Researched:** 2026-06-17
**Confidence:** HIGH (grounded in existing codebase audit + WoW addon community patterns)

---

## Critical Pitfalls

### Pitfall 1: SavedVariables Corruption from Migration-on-Every-Load

**What goes wrong:**
`NormalizeDB` runs on every `ADDON_LOADED`. If the migration gate check (`db.settingsMigration ~= SETTINGS_MIGRATION`) is accidentally broadened (e.g., by bumping the constant for a different reason), every player's settings are wiped and reset to defaults — permanently. Because `DuncedmaxxingDB` is a Lua file written by the game client, there is no undo.

**Why it happens:**
Developers treat `SETTINGS_MIGRATION` as a version string rather than a monotonic gate key. During refactoring, if the constant is changed to reflect "the current state of cleanup" rather than "what changed in this migration run," the gate fires for all existing saves, nuking user positions, colors, and scale settings.

The existing dead-code fallback block (lines 125–133) adds to this risk: it reads deprecated `barWidth`/`barHeight`/`spacing` fields that the migration block already nils out. If the order of operations is misread during refactoring, the fallback could overwrite freshly migrated values.

**How to avoid:**
- Never change `SETTINGS_MIGRATION` unless a destructive reset of settings is intentional and communicated.
- When removing the dead fallback block (the planned cleanup), verify in a test that the migration gate is the only path that writes to `tip.width`, `tip.height`, and `tip.borderSize`.
- Add a comment to `SETTINGS_MIGRATION` explicitly stating what it gates: "Changing this string resets all player settings. Only change when intentional."
- Write a unit test for `NormalizeDB` that runs it twice on the same DB and asserts idempotency — settings must not change on the second call.

**Warning signs:**
- Any PR that changes both `SETTINGS_MIGRATION` and `NormalizeDB` field logic simultaneously without a changelog entry.
- `NormalizeDB` tests that only assert the post-migration state, not that calling it twice is safe.

**Phase to address:** Utility extraction / bug fix phase (NormalizeDB dead code removal).

---

### Pitfall 2: Incomplete WoW API Mock Causing False-Passing Tests

**What goes wrong:**
The busted test suite runs outside WoW. Every WoW global — `GetTime`, `C_Timer`, `C_UnitAuras`, `C_Spell.GetSpellTexture`, `UnitClass`, `C_SpecializationInfo.GetSpecialization`, `InCombatLockdown`, `UnitIsUnit`, `STANDARD_TEXT_FONT` — must be explicitly mocked. If a mock returns a stub value that doesn't match what WoW actually returns (wrong type, wrong number of return values, wrong field names), the test passes in isolation but fails in-game.

The most likely victim here is `C_UnitAuras.GetPlayerAuraBySpellID`, which returns a complex table (`{applications, expirationTime, ...}`) or `nil`. A stub that returns `{applications = 3}` skips the `expirationTime` branch, giving false coverage of `SyncFromAura`.

**Why it happens:**
Developers mock "enough to not crash" rather than "enough to match the real API contract." The WoW API has multi-return functions, API-namespace tables, and Blizzard-specific constants that have no analogues in standard Lua. wowmock and similar tools explicitly state that most WoW API functions are not implemented and must be mocked manually.

Additionally, `C_Spell.GetSpellTexture` returns two values (`iconID`, `originalIconID`) — a mock that returns a single value changes how `ResolveSpellTexture` behaves, and this difference is invisible unless the test asserts the final texture path.

**How to avoid:**
- Before writing any mock, look up the actual API signature on warcraft.wiki.gg for every WoW function used in the file under test.
- Mock functions that return tables must match the actual table structure (field names and types), not just the shape your code currently reads.
- For `C_UnitAuras.GetPlayerAuraBySpellID`, the mock must cover: returns `nil` (no buff), returns `{applications = 0}`, returns `{applications = N, expirationTime = T}`.
- Add a comment at the top of each mock file linking to the warcraft.wiki.gg page for each mocked function.
- Test that `SyncFromAura` handles `pcall` returning `false` (API not yet available at addon load time) as a distinct path.

**Warning signs:**
- Mock functions that return `true` or a bare number where the real API returns a table.
- Tests that never exercise the `pcall` protection paths in `ReadLiveState` and `ClassifySpellID`.
- 100% test pass rate before the mock layer has been reviewed against actual API docs.

**Phase to address:** Test framework setup phase (before any test is written, the mock contract must be defined).

---

### Pitfall 3: Breaking the `local _, DMX = ...` Vararg Contract During Module Extraction

**What goes wrong:**
All three files (`Core.lua`, `Options.lua`, `TipOfTheSpear.lua`) receive the addon namespace via `local addonName, DMX = ...`. When extracting utilities to a new `Util.lua`, the new file must also use this vararg pattern and be added to the TOC before its consumers. If `Util.lua` is loaded after `Core.lua`, `DMX.Util` is nil when `Core.lua` tries to use it — a silent nil table read, not an obvious load error.

There is no `require` in the WoW Lua sandbox. Load order is entirely determined by TOC file order. This is the only dependency injection mechanism available.

**Why it happens:**
Developers accustomed to `require`-based systems forget that TOC order is the build system. Adding `Util.lua` to the TOC at the end (a common default) means it loads last, after the files that depend on it have already executed their module-level code.

**How to avoid:**
- Add `Util.lua` to the TOC as the first entry after any libraries, before `Core.lua`.
- Immediately verify with `/reload ui` in-game and confirm `DMX.Util` is non-nil in the chat command handler.
- In the test suite, mock `Util.lua`-exported functions explicitly rather than relying on TOC load order.

**Warning signs:**
- `Util.lua` added to TOC but placed at the bottom.
- Any `DMX.Util.Clamp(...)` call that silently returns `nil` in-game without a Lua error (nil table index gives a Lua error, but `DMX.Util` being nil and being called gives an immediate error — the danger is if `Util.lua` does load but exports nothing, causing silent mismatch).

**Phase to address:** Utility extraction phase.

---

### Pitfall 4: `auraVerifyPending` Flag Stays Stuck After Serial Mismatch — Fix Introduces New Stuck Case

**What goes wrong:**
The existing bug (flag never cleared when `serial ~= self.castVerifySerial`) is well-understood. The danger is that the obvious fix — clearing the flag unconditionally in the timer callback — introduces a different problem: if two `ScheduleAuraVerify` calls race, the second is silently dropped (line 418 guard), and the first timer's unconditional clear at line 440 makes it look like the second verify ran when it didn't.

**Why it happens:**
The `auraVerifyPending` flag is trying to do two things: rate-limit redundant aura checks AND track whether a verify is outstanding. Fixing one concern can break the other. A naive "always clear the flag" fix passes all unit tests (because tests control timer callbacks directly) but fails under rapid `UNIT_AURA` events in combat.

**How to avoid:**
- The fix must clear the flag on all exit paths of the timer callback, including the early-return serial mismatch path.
- The unit test for `ScheduleAuraVerify` must cover: (a) flag is cleared after normal completion, (b) flag is cleared after serial mismatch exit, (c) second call while pending is correctly dropped.
- After fixing, write the test first, confirm it fails with the current code, then apply the fix, confirm it passes.

**Warning signs:**
- Fix only adds the flag clear to the "happy path" (after `SyncFromAura`) but not to the early-return path.
- No test covers the scenario where `ScheduleCastVerify` fires between two `ScheduleAuraVerify` calls.

**Phase to address:** Bug fix phase.

---

### Pitfall 5: Module-Level Upvalues (`root`, `pips`, `borders`) Are Untestable

**What goes wrong:**
`root`, `pips`, `label`, `numberText`, and `borders` are module-level local upvalues in `TipOfTheSpear.lua`. There is no way to inject mock frames into these variables from a test. Any test that loads the module and calls `EnsureFrame` will need a full WoW frame API mock (`CreateFrame`, `SetSize`, `SetPoint`, `SetTexture`, etc.) — which is a very deep mock surface.

If the refactor to move these to `Tip` table fields is done correctly, tests can inject mock frames directly (`Tip.root = mockFrame`). If done partially — leaving some as upvalues and moving others to the table — test coverage becomes inconsistent and some paths remain permanently untestable without a full frame mock.

**Why it happens:**
The refactor sounds simple ("move locals to table fields") but `EnsureFrame` is a guard function that creates frames lazily. Moving `root` to `Tip.root` means `EnsureFrame` must write to `Tip.root` rather than a local, and every function that previously captured the upvalue via closure must now read `Tip.root`. Missing any one of these read sites causes a nil dereference in-game.

**How to avoid:**
- Move all five upvalues (`root`, `pips`, `label`, `numberText`, `borders`) to `Tip` table fields in a single commit — not incrementally.
- grep/search for every occurrence of `root`, `pips`, `label`, `numberText`, `borders` in the file before and after the change. The count must match.
- After the move, run `/reload ui` and exercise bar mode, icons mode, and number mode before committing.
- In tests, inject a mock frame via `Tip.root = { Show = function() end, Hide = function() end, ... }` to test `Update` logic without a full frame environment.

**Warning signs:**
- Partial refactor where `root` is moved but `pips` stays as an upvalue.
- Any use of the bare name `root` in a function body after the refactor (should be `self.root` or `Tip.root`).

**Phase to address:** Module restructuring phase (frame local migration).

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Leave dead migration fallback block in place | No migration risk | Future developers must understand two-phase logic; new migrations must update both phases | Never — remove it with a version bump comment |
| Keep `Clamp`/`ParseHexColor` duplicated | No load-order risk from Util.lua | Bug fixed in one copy silently stays broken in the other; implementations have already diverged | Never — the divergence has already caused a nil-handling inconsistency |
| Mock `C_Timer.After` as a synchronous call in tests | Simple test setup | Async timing behavior (quiet period logic in `ScheduleAuraVerify`) is never tested | Acceptable for pure logic tests; must be supplemented with timing-scenario tests |
| Skip moving frame upvalues to table fields | Less refactoring risk | `Update` and `RefreshLayout` remain untestable without a full WoW frame mock | Never for unit-tested paths; acceptable for UI-only render paths |
| Leave `pcall` wrapper on `ClassifySpellID` | No behavioral change | Obscures intent; small per-event overhead during combat; signals to readers that the function can error (it cannot) | Never — remove it |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| `C_UnitAuras.GetPlayerAuraBySpellID` | Mock returns `{applications = N}`, missing `expirationTime` | Mock must return the full aura table structure; check warcraft.wiki.gg for all fields |
| `C_Spell.GetSpellTexture` | Mock returns one value; real API returns `iconID, originalIconID` | Mock must return two values: `return iconID, originalIconID` |
| `C_Timer.After` | Mock fires callback immediately (synchronous) | For timing tests, capture the callback and fire it manually to test quiet-period logic |
| `GetTime` | Mock returns a constant; timing math produces wrong results | Advance a mock clock across test scenarios to validate expiration and quiet-period calculations |
| `InCombatLockdown` | Not mocked at all; code paths gated on combat state never execute in tests | Mock must return `false` by default, with specific tests overriding to `true` for combat-path coverage |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Calling `UnitClass` + `GetSpecialization` on every `UNIT_AURA` event | CPU spike noticeable at high-APM during combat; `/dump GetFramerate()` drops | Cache spec state in `Tip.active`; only re-check on `PLAYER_SPECIALIZATION_CHANGED` and `PLAYER_TALENT_UPDATE` | Immediately in any combat with frequent aura changes; worsens with multi-target fights |
| `C_Spell.GetSpellTexture` called on every `Update` in icon mode | Wasteful WoW API call on every frame render event | Cache result at `Initialize` time; invalidate only on `PLAYER_LOGIN` | Every Update tick in icon mode; multiplies with icon count |
| `ForEachModule` using `pairs` with multiple modules | Non-deterministic initialization order causes subtle state bugs when modules share events | Add `moduleOrder` array; iterate it in `ForEachModule` | Harmless with one module; dangerous when a second module is added |

---

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Switching display mode out of combat shows stale stack count | Player sees non-zero stacks on a fresh bar in a new mode after a previous fight | Call `SyncFromAura` synchronously when switching modes out of combat, before calling `Update` |
| Options window accumulates stale checkbox/input references if `BuildWindow` is ever cleared | `Refresh` iterates dead frame references, silently doing nothing | Reset `self.checkboxes = {}` and `self.inputs = {}` any time `self.window` is set to nil |
| `testMode` resets on every `/reload ui` | Developer must re-type `/dmax test` after every reload during visual iteration | Store `testMode` in `DuncedmaxxingDB` (or a separate ephemeral key); restore on `ADDON_LOADED` |

---

## "Looks Done But Isn't" Checklist

- [ ] **Util.lua extraction:** `Clamp` and `ParseHexColor` removed from both `Core.lua` and `Options.lua` — verify with grep that no private copies remain.
- [ ] **Dead migration fallback removal:** Lines 125–133 of `Core.lua` removed, version comment added — verify `NormalizeDB` unit test still passes for a DB at migration version `"0.3.2-fontfix"`.
- [ ] **Frame upvalue migration:** All five frame variables read from `Tip` table fields — verify by grepping for bare `root`, `pips`, `label`, `numberText`, `borders` in function bodies.
- [ ] **`auraVerifyPending` bug fix:** Flag is cleared on ALL exit paths of the timer callback — verify with a unit test that exercises the serial-mismatch early-return path.
- [ ] **Caching spec state:** `RefreshActive` is NOT called inside `Update` — verify by reading `Update`'s body; `RefreshActive` must only appear in `OnEvent` handlers.
- [ ] **Test mock completeness:** Every WoW global referenced in tested files has a mock entry — verify by searching for `C_`, `UnitClass`, `GetTime`, `GetPlayerAuraBySpellID`, `InCombatLockdown` in each test file's setup.
- [ ] **TOC load order:** `Util.lua` appears before `Core.lua` in the `.toc` file — verify by reading the TOC directly.
- [ ] **`pcall` removal from `ClassifySpellID`:** Function returns `kind` directly without `pcall` wrapping — verify no `pcall` remains in the function.

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| SavedVariables wiped by incorrect migration gate | HIGH — user settings gone permanently | Document: inform user to re-configure display position and colors; no automated recovery possible |
| Broken frame upvalue reference after partial migration | MEDIUM — in-game Lua error on login | Revert the frame migration commit entirely; redo as a single atomic change |
| False-passing tests from incomplete mock | MEDIUM — catch it in in-game testing | Build a "smoke test" checklist of in-game manual verifications run after every refactor commit |
| `auraVerifyPending` fix introduces new stuck case | LOW — flag resets at end of combat | Add unit test coverage for the race scenario; revert fix to the original behavior and try again |
| TOC load order wrong for Util.lua | LOW — immediate Lua error on addon load | Move `Util.lua` entry above `Core.lua` in the TOC; `/reload ui` confirms fix |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| SavedVariables corruption from migration gate | Bug fix phase (dead code removal) | Unit test: `NormalizeDB` called twice on same DB produces identical output |
| Incomplete WoW API mock | Test framework setup phase | Mock review checklist: every WoW global in tested files has a mock with correct return signature |
| Broken vararg/TOC load order for Util.lua | Utility extraction phase | TOC load order confirmed; `/reload ui` shows no Lua errors; `DMX.Util` non-nil |
| `auraVerifyPending` fix creates new stuck case | Bug fix phase | Unit test: serial mismatch path clears flag; second pending call correctly dropped |
| Partial frame upvalue migration | Module restructuring phase | grep for bare upvalue names in function bodies; in-game test of all three display modes |
| False-passing tests from mock inaccuracy | Test framework setup phase (before tests written) | Each mock links to warcraft.wiki.gg source; multi-return mocks verified against docs |
| Per-update spec state API calls | Caching phase | `Update` body contains no `RefreshActive` call; confirmed by code review |
| `ResolveSpellTexture` called on every Update | Caching phase | `Update` reads `self.spellTexture`; no `C_Spell.GetSpellTexture` call inside Update |

---

## Sources

- Codebase audit: `.planning/codebase/CONCERNS.md` (HIGH confidence — direct code analysis)
- WoW addon taint and secure execution: [Secure Execution and Tainting — Warcraft Wiki](https://warcraft.wiki.gg/wiki/Secure_Execution_and_Tainting) (MEDIUM confidence)
- `C_Spell.GetSpellTexture` API: [warcraft.wiki.gg](https://warcraft.wiki.gg/wiki/API_C_Spell.GetSpellTexture) (HIGH confidence — official docs)
- wowmock project (incomplete mock surface): [GitHub — Adirelle/wowmock](https://github.com/Adirelle/wowmock) (HIGH confidence — explicit statement from project)
- Refactoring-for-testability chicken-egg problem: [stackline issue #26](https://github.com/AdamWagner/stackline/issues/26) (MEDIUM confidence — analogous sandboxed Lua environment)
- WoW SavedVariables write behavior: [SavedVariables — Warcraft Wiki](https://warcraft.wiki.gg/wiki/SavedVariables) (HIGH confidence — official docs)
- Patch 12.0.0 API changes: [Patch 12.0.0/Planned API changes — Warcraft Wiki](https://warcraft.wiki.gg/wiki/Patch_12.0.0/Planned_API_changes) (MEDIUM confidence — pre-release planned list)

---
*Pitfalls research for: WoW addon refactoring/polish (Duncedmaxxing)*
*Researched: 2026-06-17*
