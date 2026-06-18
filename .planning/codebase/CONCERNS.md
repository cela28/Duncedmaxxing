# Codebase Concerns

**Analysis Date:** 2026-06-18

## Tech Debt

**Duplicated utility functions across files:**
- Issue: `Clamp` and `ParseHexColor` are defined independently in both `Duncedmaxxing/Core.lua` (lines 42–70) and `Duncedmaxxing/Options.lua` (lines 17–36). Implementations differ subtly — the `Duncedmaxxing/Options.lua` version of `ParseHexColor` uses `tostring(value or "")` while `Duncedmaxxing/Core.lua` uses `Trim(value)`. These are not the same function; they will diverge further as the codebase grows.
- Files: `Duncedmaxxing/Core.lua:42`, `Duncedmaxxing/Core.lua:59`, `Duncedmaxxing/Options.lua:17`, `Duncedmaxxing/Options.lua:25`
- Impact: Bugs fixed in one copy will not be fixed in the other. Already there is a minor inconsistency in nil handling.
- Fix approach: Move shared utilities into a `Duncedmaxxing/Util.lua` file loaded before `Core.lua` and `Options.lua`, exposing them on the `DMX` table or as upvalues shared via the addon table. (Note: As of 02-01, this has been addressed by creating `Duncedmaxxing/Util.lua` with `DMX.Util.Clamp`, `DMX.Util.ParseHexColor`, `DMX.Util.Trim`, and `DMX.Util.ParseOnOff`.)

**Legacy field migration code never cleaned up:**
- Issue: `NormalizeDB` in `Duncedmaxxing/Core.lua` (lines 101–138) contains two-phase logic: an explicit version-gated migration block that writes `settingsMigration = "0.3.2-fontfix"` (line 122), followed by a second block (lines 125–133) that silently reads deprecated `barWidth`, `barHeight`, and `spacing` fields that already should have been cleared by the migration block. The second block only exists to handle saved variables from before version 0.3.2 that somehow missed the migration gate.
- Files: `Duncedmaxxing/Core.lua:101`
- Impact: Dead code that obscures the canonical field names. Any future developer adding a migration must understand whether the fallback block below should also be updated.
- Fix approach: Remove the post-migration fallback block (lines 125–133) in a future version bump, since all players will have passed the migration gate by then. Add a comment to the migration string explaining what the migration changed.

**`layoutBorderSize` is shared mutable state on the `Tip` table (in `Duncedmaxxing/Modules/TipOfTheSpear.lua`):**
- Issue: `RefreshLayout` writes `self.layoutBorderSize` (line 459) and `Update` reads it later (line 607). If `Update` is called before the first `RefreshLayout`, the value is `nil` and the `or 0` guard in `Update` masks the issue silently. More critically, `Update` can be called directly (e.g., from timer callbacks) without a preceding `RefreshLayout`, so `layoutBorderSize` may reflect a stale layout when visual settings have changed but the layout has not been re-run.
- Files: `Duncedmaxxing/Modules/TipOfTheSpear.lua:459`, `Duncedmaxxing/Modules/TipOfTheSpear.lua:607`
- Impact: In "bar" mode, borders could be drawn with the wrong size after a settings change that calls `RefreshTip → Update` but not a full `RefreshLayout`. In practice `RefreshTip` always calls `RefreshLayout` first, so this is latent rather than actively broken.
- Fix approach: Either derive `hasBorder` inside `Update` from `GetCfg()` directly (same calculation as in `RefreshLayout`), or rename `layoutBorderSize` to make the dependency explicit and add an assertion that it is not nil.

**`ForEachModule` uses unordered `pairs` iteration:**
- Issue: `DMX:ForEachModule` (line 157 in `Duncedmaxxing/Core.lua`) iterates over `self.modules` with `pairs`, which provides no guaranteed ordering in Lua. Currently only one module (`tip`) exists, so this is harmless. As more modules are added, initialization order, `ApplyLock` calls, and future cross-module interactions may behave non-deterministically.
- Files: `Duncedmaxxing/Core.lua:157`
- Impact: Low now; grows as modules are added.
- Fix approach: Maintain an ordered `moduleOrder` array alongside the `modules` table in `Duncedmaxxing/Core.lua`, and iterate that array in `ForEachModule`.

**`ClassifySpellID` is wrapped in `pcall` unnecessarily:**
- Issue: `ClassifySpellID` in `Duncedmaxxing/Modules/TipOfTheSpear.lua` (lines 56–69) wraps a pure table-lookup and equality check in a `pcall`. Neither operation can raise a Lua error. This adds a small per-cast overhead during combat with no benefit.
- Files: `Duncedmaxxing/Modules/TipOfTheSpear.lua:56`
- Impact: Minimal performance cost on every `UNIT_SPELLCAST_SUCCEEDED` event during combat. Obscures intent.
- Fix approach: Remove the `pcall` wrapper and return directly from the function body.

---

## Known Bugs

**`auraVerifyPending` flag can become permanently stuck if `SyncFromAura` is skipped out of combat:**
- Symptoms: After `ScheduleAuraVerify` is called, `auraVerifyPending = true` is set (line 437). Inside the timer callback (line 440) the flag is cleared, but only if `self.inCombat and serial ~= self.castVerifySerial` does NOT trigger. If the serial has advanced (due to a cast-verify superseding the aura-verify), the callback returns early at line 442 without clearing `auraVerifyPending`. The next call to `ScheduleAuraVerify` will be silently skipped (line 418) until a full `SyncFromAura` path resets state.
- Files: `Duncedmaxxing/Modules/TipOfTheSpear.lua:418`, `Duncedmaxxing/Modules/TipOfTheSpear.lua:437–442`
- Trigger: A consumer spell fires, triggering `ScheduleCastVerify`, which increments `castVerifySerial`. Before the `auraVerifyPending` timer fires, `ScheduleAuraVerify` is called again (e.g., by `UNIT_AURA`). The first pending timer fires and exits early without clearing the flag.
- Workaround: The flag resets naturally on the next `PLAYER_REGEN_ENABLED` → `SyncFromAura` → `Update` cycle (end of combat), so in practice it does not persist across fights.
- Test coverage: Implicit — no explicit test for the stale-flag relock scenario. Would be caught by an integration test covering rapid serial changes during the aura-verify window.

**Kill Command +2 stack prediction is hard-coded and does not account for talent modifications:**
- Symptoms: Kill Command is predicted to always grant `+2` stacks (line 679). If a future talent or conditional interaction changes the stack grant (e.g., to `+1` or `+3`), the prediction will display an incorrect count until the aura-verify corrects it 1.25 seconds later.
- Files: `Duncedmaxxing/Modules/TipOfTheSpear.lua:679`
- Trigger: Kill Command cast when a talent modifies the stack grant amount.
- Workaround: The delayed `ScheduleCastVerify` will correct the display, but there will be a brief incorrect flash.
- Test coverage: Pending test at `spec/tip_spec.lua:127` marks this as BUG-04 (Twin Fangs talent interaction). The test is skipped pending implementation.

---

## Performance Bottlenecks

**`ResolveSpellTexture` called on every layout and every icon-mode update:**
- Problem: `ResolveSpellTexture` (line 134) calls `C_Spell.GetSpellTexture` or `_G.GetSpellTexture` on every `RefreshLayout` (icon mode, line 484) and on every `Update` in icon mode (lines 636, 638). `GetSpellTexture` is a WoW API call, not a pure Lua computation.
- Files: `Duncedmaxxing/Modules/TipOfTheSpear.lua:134`, `Duncedmaxxing/Modules/TipOfTheSpear.lua:484`, `Duncedmaxxing/Modules/TipOfTheSpear.lua:636`
- Cause: No caching of the resolved texture path.
- Improvement path: Resolve and cache the texture ID once at `Initialize` time (and on `PLAYER_LOGIN` as a safe re-check), then read the cached value in `RefreshLayout` and `Update`.

**`Update` calls `RefreshActive` on every event, including high-frequency combat events:**
- Problem: `Update` (line 583) unconditionally calls `self:RefreshActive()`, which calls `DMX:IsSurvivalHunter()`, which calls `UnitClass("player")` and `C_SpecializationInfo.GetSpecialization()`. This runs on every `UNIT_AURA` event, `UNIT_SPELLCAST_SUCCEEDED` event, and timer callback during combat.
- Files: `Duncedmaxxing/Modules/TipOfTheSpear.lua:582`, `Duncedmaxxing/Core.lua:172`
- Cause: No caching of spec state within `Tip`. The class and spec do not change during combat.
- Improvement path: Cache `self.active` and only re-check it on `PLAYER_SPECIALIZATION_CHANGED` and `PLAYER_TALENT_UPDATE`, not on every `Update` call. The `OnEvent` handler for those events already calls `RefreshActive` explicitly. Remove the `RefreshActive` call from inside `Update`.

---

## Fragile Areas

**Options window is built lazily but its state (`checkboxes`, `inputs` lists) accumulates across all settings panels:**
- Files: `Duncedmaxxing/Options.lua:199`, `Duncedmaxxing/Options.lua:118`, `Duncedmaxxing/Options.lua:155`
- Why fragile: `Options:BuildWindow` appends to `self.checkboxes` and `self.inputs` via `table.insert` in `CreateCheckbox` and `CreateInput`. If `BuildWindow` were ever called more than once (guarded by `if self.window then return end`), these tables would not be reset. The guard is currently safe, but any refactor that clears `self.window` (e.g., for a UI reload path) without also clearing `self.checkboxes` and `self.inputs` would cause `Refresh` to iterate stale references.
- Safe modification: Any code that sets `self.window = nil` must also set `self.checkboxes = {}` and `self.inputs = {}` before calling `BuildWindow` again.
- Test coverage: **UNTESTED** — no automated tests exist for `Options.lua` or its UI state mutations.

**`EnsureFrame` is a module-level guard but `root`, `pips`, `label`, `numberText`, and `borders` are module-level upvalue variables:**
- Files: `Duncedmaxxing/Modules/TipOfTheSpear.lua:292`, `Duncedmaxxing/Modules/TipOfTheSpear.lua:32–36`
- Why fragile: If `EnsureFrame` is ever called before `Initialize` completes (e.g., from a module registered late), the frame exists but the event handler does not, leaving the tracker visually present but unresponsive. The variables are module-level, making them invisible to external code and untestable. Any new function added to `Tip` that operates on the frame must remember to call `EnsureFrame` first.
- Safe modification: Always call `EnsureFrame()` at the top of any function that reads `root`, `pips`, `label`, `numberText`, or `borders`. Currently `Update` and `RefreshLayout` do this correctly, but `ApplyLock`, `ResetPosition`, and `SavePosition` (module-internal) do not call it directly and rely on prior initialization.
- Test coverage: `Tip:ApplySpell` and `Tip:SyncFromAura` are tested via `spec/tip_spec.lua`, but frame construction paths (`Update`, `RefreshLayout`, `RefreshActive`) are not explicitly tested — only the state mutations are validated.

**`NormalizeDB` mutates the live `DuncedmaxxingDB` global in-place during addon load:**
- Files: `Duncedmaxxing/Core.lua:101`, `Duncedmaxxing/Core.lua:363–364`
- Why fragile: `DuncedmaxxingDB` is the WoW SavedVariables global. Mutations during `ADDON_LOADED` are fine, but `NormalizeDB` performs both a migration (idempotent after first run) and silent backfill of deprecated fields. If a future `NormalizeDB` call incorrectly clears a field the player set, the loss is permanent because `DuncedmaxxingDB` is the sole persisted store.
- Safe modification: Add the new migration version string as a constant before modifying field-clearing logic; never delete fields without bumping `SETTINGS_MIGRATION`.
- Test coverage: Fully tested via `spec/core_spec.lua` (migration branch, deprecated field handling, displayMode validation) — all NormalizeDB scenarios are covered.

---

## Scaling Limits

**Single-module architecture assumes only `tip` will ever exist:**
- Current capacity: The `DMX.modules` table and `ForEachModule` loop handle arbitrary modules in principle, but the entire settings UI (`Duncedmaxxing/Options.lua`) is hard-coded to the `tip` sub-table of the DB. There is no concept of per-module settings sections.
- Limit: Adding a second tracker module (e.g., Pack Leader beast tracking per `DEVELOPMENT_NOTES.md`) would require a parallel options section built manually into `Duncedmaxxing/Options.lua`, duplicating the existing pattern.
- Scaling path: Introduce a per-module `BuildOptionsSection(parent, yOffset)` callback convention so each module contributes its own section to the options window dynamically.

---

## Missing Critical Features

**No test mode persistence across UI reloads:**
- Problem: `Tip.testMode` is a Lua upvalue that resets to `false` on every addon load. There is no way to keep test mode active across `/reload ui` or relog. This is a minor workflow issue for developers tweaking display settings.
- Blocks: Iterative visual testing without re-typing `/dmax test` after every reload.

**No out-of-combat aura refresh on display-mode change:**
- Problem: Switching display modes via the options buttons or `/dmax mode` calls `RefreshTip → RefreshLayout → Update`. `Update` reads `self.stacks`, which was last set by `SyncFromAura` or a spell cast prediction. If the player is out of combat and the buff has lapsed, `self.stacks` may be stale (non-zero from an earlier fight), and the new display mode will show an incorrect stack count until the next combat.
- Files: `Duncedmaxxing/Core.lua:285`, `Duncedmaxxing/Modules/TipOfTheSpear.lua:581`
- Blocks: Display mode changes out of combat show accurate data.

---

## Test Coverage Gaps

**Options window state not tested:**
- What's not tested: `Options:BuildWindow`, `Options:Refresh`, `Options:Open`, widget state management (checkbox toggles, input text updates), options persistence via `Refresh` callback
- Files: `Duncedmaxxing/Options.lua` — entire module untested
- Risk: Regressions in UI state mutations, widget value sync, or combat lockdown guards would not be caught until runtime in-game.
- Priority: Medium — UI code requires frame environment, but core state mutations (`Refresh` callback logic) could be unit-tested by mocking `GetCfg()` and verifying table mutations.

**Frame construction and layout code not tested:**
- What's not tested: `Tip:RefreshLayout`, `Tip:RefreshActive`, `EnsureFrame`, frame hierarchy creation, texture/font assignments, border layout logic
- Files: `Duncedmaxxing/Modules/TipOfTheSpear.lua:292–550`, `Duncedmaxxing/Modules/TipOfTheSpear.lua:580–630`
- Risk: Display glitches, frame ordering issues, or border rendering bugs would not be caught until runtime.
- Priority: Low-Medium — high complexity and heavy WoW API dependence make these harder to unit-test; integration testing in-game is more practical.

**Slash command parsing and DB mutation not tested:**
- What's not tested: `RegisterSlashCommands`, the slash command handler function, direct `db.tip` field mutations from `/dmax mode`, `/dmax lock`, `/dmax test`, etc.
- Files: `Duncedmaxxing/Core.lua:226–353`
- Risk: Typos in command parsing, incorrect field assignments, or missing `RefreshTip` calls after mutations would not be caught in tests.
- Priority: Medium — pure Lua parsing logic that could be unit-tested by invoking the command handler with mock commands.

**Module registration and initialization ordering not tested:**
- What's not tested: `DMX:RegisterModule`, initialization sequencing (`before_each` in `spec/support/init.lua` loads modules in hardcoded order but does not validate initialization logic), order-dependent module interactions
- Files: `Duncedmaxxing/Core.lua:140–155`, `Duncedmaxxing/Core.lua:356–374`
- Risk: Adding a second module in the wrong load order could cause subtle state corruption that the current test suite would not catch.
- Priority: Low-Medium — only relevant as modules multiply; test coverage improves naturally once `ForEachModule` ordering is formalized.

**No API compatibility tests:**
- What's not tested: Dual-path API calls for `GetSpecialization` / `C_SpecializationInfo`, `GetSpellTexture` / `C_Spell.GetSpellTexture` — current test stubs always provide both paths, so fallback branches never execute in tests.
- Files: `Duncedmaxxing/Core.lua:172–180` (`GetSpecialization` fallback), `Duncedmaxxing/Modules/TipOfTheSpear.lua:143–147` (`GetSpellTexture` fallback)
- Risk: Fallback branches could be silently broken in older WoW API surfaces without the modern namespace tables.
- Priority: Low — historically WoW API rarely removes functions, only adds new namespaces; fallback paths have shipped for 0.3.x without reported issues.

**Full integration tests not present:**
- What's not tested: Complete combat scenarios (multiple spell casts, aura updates, expiry, re-enter combat), stale serial edge case (BUG-01), rapid mode changes, lock/unlock interactions with combat lockdown, settings persistence across reload
- Risk: Emergent bugs from interaction of multiple components (e.g., `Update` + `SyncFromAura` + timer callbacks in sequence) would not be caught.
- Priority: Low-Medium — current unit tests cover the state machine logic; integration issues are best caught by gameplay testing. Busted cannot easily simulate the full WoW combat event loop.

---

## Test Infrastructure Concerns

**Options.lua is skipped in test loader:**
- Issue: `spec/support/init.lua:30` explicitly skips loading `Duncedmaxxing/Options.lua` during test bootstrap. The comment says "Options.lua (skipped)" but provides no rationale.
- Impact: Options module is never instantiated during tests, so its initialization path is untested.
- Reason (inferred): The options window requires `CreateFrame` and UIParent; the no-op frame stubs in `spec/support/wow_stubs.lua` are sufficient for gameplay logic but may not fully model Options' widget interactions.
- Fix approach: Either extend the no-op frame stubs to fully support Options' frame hierarchy, or add a skip guard inside `Options:Initialize` to detect test mode and bail gracefully.

**Test fixtures are hardcoded in test bodies:**
- Issue: Test databases (e.g., `migrationDB()`, `migratedDB()`) are defined inside `describe` blocks in `spec/core_spec.lua:59–80` and `spec/core_spec.lua:151–178`. These are duplicated across four describe blocks (migration, already-migrated, deprecated-field, displayMode-validation).
- Impact: Any future change to the DB schema requires edits in four places. Minimal code reuse.
- Fix approach: Extract into `spec/support/fixtures.lua` with builder functions, imported by all spec files.

**Mock aura dispatch requires per-test override:**
- Issue: Tests must override `stubs.mockAura.impl` inside each `it()` block (see `spec/tip_spec.lua:162–165`, line 199–201). This is necessary because the module-level local in `TipOfTheSpear.lua` captures the function once, but it places the burden on every test.
- Impact: Verbose test setup; easy to forget to reset the mock between tests (though `loader.resetTipState` covers this).
- Fix approach: Add a helper function `stubs.mockAura.setImpl(...)` to make the pattern explicit, and document it in `spec/support/wow_stubs.lua`.

**Clock.now base value collision with grace periods:**
- Issue: Early design tests set `clock.now = 0` at the start. The `CONSUMER_UPSYNC_GRACE` window check is `now < lastPredictAt + 2.75`. If `lastPredictAt = 0` (uninitialized) and `now = 0`, the condition is `0 < 0 + 2.75 = true`, incorrectly triggering grace suppression even for uninitialized state. This is Pitfall 5 (mentioned in `spec/support/init.lua:51`).
- Impact: Tests that rely on grace-period suppression must explicitly initialize `Tip.lastPredictAt` to avoid false-positive passes.
- Mitigation: `spec/support/init.lua:62` sets `clock.now = 100` at test startup, avoiding collision. Tests that override `lastPredictAt` must account for this non-zero base.
- Fix approach: Document this invariant in `spec/support/init.lua` and add an assertion in `resetTipState` to validate it.

---

## Linting and Configuration

**.luacheckrc correctly excludes spec files:**
- Status: The `.luacheckrc` configuration at `exclude_files = { "spec/**/*.lua" }` (line 44) prevents busted-specific globals (`describe`, `it`, `assert`, `pending`) from triggering linting errors in the addon code.
- Verification: Linting currently ignores spec files without error.

**.busted configuration is minimal and correct:**
- Status: The `.busted` file (lines 1–8) sets `pattern = "_spec"` which matches all files ending in `_spec.lua`. Verbose mode is off, output is `utfTerminal`, and `no-keep-going` is false (allowing all tests to run even if some fail).
- Observation: Configuration is standard and sufficient for the current test suite.

---

*Concerns audit: 2026-06-18*
