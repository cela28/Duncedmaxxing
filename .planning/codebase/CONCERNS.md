# Codebase Concerns

**Analysis Date:** 2026-06-17

## Tech Debt

**Duplicated utility functions across files:**
- Issue: `Clamp` and `ParseHexColor` are defined independently in both `Core.lua` (lines 42–70) and `Options.lua` (lines 17–36). Implementations differ subtly — the `Options.lua` version of `ParseHexColor` uses `tostring(value or "")` while `Core.lua` uses `Trim(value)`. These are not the same function; they will diverge further as the codebase grows.
- Files: `Core.lua:42`, `Core.lua:59`, `Options.lua:17`, `Options.lua:25`
- Impact: Bugs fixed in one copy will not be fixed in the other. Already there is a minor inconsistency in nil handling.
- Fix approach: Move shared utilities into a `Util.lua` file loaded before `Core.lua` and `Options.lua`, exposing them on the `DMX` table or as upvalues shared via the addon table.

**Legacy field migration code never cleaned up:**
- Issue: `NormalizeDB` in `Core.lua` (lines 101–138) contains two-phase logic: an explicit version-gated migration block that writes `settingsMigration = "0.3.2-fontfix"` (line 122), followed by a second block (lines 125–133) that silently reads deprecated `barWidth`, `barHeight`, and `spacing` fields that already should have been cleared by the migration block. The second block only exists to handle saved variables from before version 0.3.2 that somehow missed the migration gate.
- Files: `Core.lua:101`
- Impact: Dead code that obscures the canonical field names. Any future developer adding a migration must understand whether the fallback block below should also be updated.
- Fix approach: Remove the post-migration fallback block (lines 125–133) in a future version bump, since all players will have passed the migration gate by then. Add a comment to the migration string explaining what the migration changed.

**`layoutBorderSize` is shared mutable state on the `Tip` table:**
- Issue: `RefreshLayout` writes `self.layoutBorderSize` (line 459) and `Update` reads it later (line 607). If `Update` is called before the first `RefreshLayout`, the value is `nil` and the `or 0` guard in `Update` masks the issue silently. More critically, `Update` can be called directly (e.g., from timer callbacks) without a preceding `RefreshLayout`, so `layoutBorderSize` may reflect a stale layout when visual settings have changed but the layout has not been re-run.
- Files: `Modules/TipOfTheSpear.lua:459`, `Modules/TipOfTheSpear.lua:607`
- Impact: In "bar" mode, borders could be drawn with the wrong size after a settings change that calls `RefreshTip → Update` but not a full `RefreshLayout`. In practice `RefreshTip` always calls `RefreshLayout` first, so this is latent rather than actively broken.
- Fix approach: Either derive `hasBorder` inside `Update` from `GetCfg()` directly (same calculation as in `RefreshLayout`), or rename `layoutBorderSize` to make the dependency explicit and add an assertion that it is not nil.

**`ForEachModule` uses unordered `pairs` iteration:**
- Issue: `DMX:ForEachModule` (line 157 in `Core.lua`) iterates over `self.modules` with `pairs`, which provides no guaranteed ordering in Lua. Currently only one module (`tip`) exists, so this is harmless. As more modules are added, initialization order, `ApplyLock` calls, and future cross-module interactions may behave non-deterministically.
- Files: `Core.lua:157`
- Impact: Low now; grows as modules are added.
- Fix approach: Maintain an ordered `moduleOrder` array alongside the `modules` table in `Core.lua`, and iterate that array in `ForEachModule`.

**`ClassifySpellID` is wrapped in `pcall` unnecessarily:**
- Issue: `ClassifySpellID` in `TipOfTheSpear.lua` (lines 56–69) wraps a pure table-lookup and equality check in a `pcall`. Neither operation can raise a Lua error. This adds a small per-cast overhead during combat with no benefit.
- Files: `Modules/TipOfTheSpear.lua:56`
- Impact: Minimal performance cost on every `UNIT_SPELLCAST_SUCCEEDED` event during combat. Obscures intent.
- Fix approach: Remove the `pcall` wrapper and return directly from the function body.

---

## Known Bugs

**`auraVerifyPending` flag can become permanently stuck if `SyncFromAura` is skipped out of combat:**
- Symptoms: After `ScheduleAuraVerify` is called, `auraVerifyPending = true` is set (line 437). Inside the timer callback (line 440) the flag is cleared, but only if `self.inCombat and serial ~= self.castVerifySerial` does NOT trigger. If the serial has advanced (due to a cast-verify superseding the aura-verify), the callback returns early at line 442 without clearing `auraVerifyPending`. The next call to `ScheduleAuraVerify` will be silently skipped (line 418) until a full `SyncFromAura` path resets state.
- Files: `Modules/TipOfTheSpear.lua:418`, `Modules/TipOfTheSpear.lua:437–442`
- Trigger: A consumer spell fires, triggering `ScheduleCastVerify`, which increments `castVerifySerial`. Before the `auraVerifyPending` timer fires, `ScheduleAuraVerify` is called again (e.g., by `UNIT_AURA`). The first pending timer fires and exits early without clearing the flag.
- Workaround: The flag resets naturally on the next `PLAYER_REGEN_ENABLED` → `SyncFromAura` → `Update` cycle (end of combat), so in practice it does not persist across fights.

**Kill Command +2 stack prediction is hard-coded and does not account for talent modifications:**
- Symptoms: Kill Command is predicted to always grant `+2` stacks (line 679). If a future talent or conditional interaction changes the stack grant (e.g., to `+1` or `+3`), the prediction will display an incorrect count until the aura-verify corrects it 1.25 seconds later.
- Files: `Modules/TipOfTheSpear.lua:679`
- Trigger: Kill Command cast when a talent modifies the stack grant amount.
- Workaround: The delayed `ScheduleCastVerify` will correct the display, but there will be a brief incorrect flash.

---

## Performance Bottlenecks

**`ResolveSpellTexture` called on every layout and every icon-mode update:**
- Problem: `ResolveSpellTexture` (line 134) calls `C_Spell.GetSpellTexture` or `_G.GetSpellTexture` on every `RefreshLayout` (icon mode, line 484) and on every `Update` in icon mode (lines 636, 638). `GetSpellTexture` is a WoW API call, not a pure Lua computation.
- Files: `Modules/TipOfTheSpear.lua:134`, `Modules/TipOfTheSpear.lua:484`, `Modules/TipOfTheSpear.lua:636`
- Cause: No caching of the resolved texture path.
- Improvement path: Resolve and cache the texture ID once at `Initialize` time (and on `PLAYER_LOGIN` as a safe re-check), then read the cached value in `RefreshLayout` and `Update`.

**`Update` calls `RefreshActive` on every event, including high-frequency combat events:**
- Problem: `Update` (line 583) unconditionally calls `self:RefreshActive()`, which calls `DMX:IsSurvivalHunter()`, which calls `UnitClass("player")` and `C_SpecializationInfo.GetSpecialization()`. This runs on every `UNIT_AURA` event, `UNIT_SPELLCAST_SUCCEEDED` event, and timer callback during combat.
- Files: `Modules/TipOfTheSpear.lua:582`, `Core.lua:172`
- Cause: No caching of spec state within `Tip`. The class and spec do not change during combat.
- Improvement path: Cache `self.active` and only re-check it on `PLAYER_SPECIALIZATION_CHANGED` and `PLAYER_TALENT_UPDATE`, not on every `Update` call. The `OnEvent` handler for those events already calls `RefreshActive` explicitly. Remove the `RefreshActive` call from inside `Update`.

---

## Fragile Areas

**Options window is built lazily but its state (`checkboxes`, `inputs` lists) accumulates across all settings panels:**
- Files: `Options.lua:199`, `Options.lua:118`, `Options.lua:155`
- Why fragile: `Options:BuildWindow` appends to `self.checkboxes` and `self.inputs` via `table.insert` in `CreateCheckbox` and `CreateInput`. If `BuildWindow` were ever called more than once (guarded by `if self.window then return end`), these tables would not be reset. The guard is currently safe, but any refactor that clears `self.window` (e.g., for a UI reload path) without also clearing `self.checkboxes` and `self.inputs` would cause `Refresh` to iterate stale references.
- Safe modification: Any code that sets `self.window = nil` must also set `self.checkboxes = {}` and `self.inputs = {}` before calling `BuildWindow` again.
- Test coverage: None — no automated tests exist for this addon.

**`EnsureFrame` is a module-level guard but `root`, `pips`, `label`, `numberText`, and `borders` are module-level upvalue variables:**
- Files: `Modules/TipOfTheSpear.lua:292`, `Modules/TipOfTheSpear.lua:32–36`
- Why fragile: If `EnsureFrame` is ever called before `Initialize` completes (e.g., from a module registered late), the frame exists but the event handler does not, leaving the tracker visually present but unresponsive. The variables are module-level, making them invisible to external code and untestable. Any new function added to `Tip` that operates on the frame must remember to call `EnsureFrame` first.
- Safe modification: Always call `EnsureFrame()` at the top of any function that reads `root`, `pips`, `label`, `numberText`, or `borders`. Currently `Update` and `RefreshLayout` do this correctly, but `ApplyLock`, `ResetPosition`, and `SavePosition` (module-internal) do not call it directly and rely on prior initialization.

**`NormalizeDB` mutates the live `DuncedmaxxingDB` global in-place during addon load:**
- Files: `Core.lua:101`, `Core.lua:363–364`
- Why fragile: `DuncedmaxxingDB` is the WoW SavedVariables global. Mutations during `ADDON_LOADED` are fine, but `NormalizeDB` performs both a migration (idempotent after first run) and silent backfill of deprecated fields. If a future `NormalizeDB` call incorrectly clears a field the player set, the loss is permanent because `DuncedmaxxingDB` is the sole persisted store.
- Safe modification: Add the new migration version string as a constant before modifying field-clearing logic; never delete fields without bumping `SETTINGS_MIGRATION`.

---

## Scaling Limits

**Single-module architecture assumes only `tip` will ever exist:**
- Current capacity: The `DMX.modules` table and `ForEachModule` loop handle arbitrary modules in principle, but the entire settings UI (`Options.lua`) is hard-coded to the `tip` sub-table of the DB. There is no concept of per-module settings sections.
- Limit: Adding a second tracker module (e.g., Pack Leader beast tracking per `DEVELOPMENT_NOTES.md`) would require a parallel options section built manually into `Options.lua`, duplicating the existing pattern.
- Scaling path: Introduce a per-module `BuildOptionsSection(parent, yOffset)` callback convention so each module contributes its own section to the options window dynamically.

---

## Missing Critical Features

**No test mode persistence across UI reloads:**
- Problem: `Tip.testMode` is a Lua upvalue that resets to `false` on every addon load. There is no way to keep test mode active across `/reload ui` or relog. This is a minor workflow issue for developers tweaking display settings.
- Blocks: Iterative visual testing without re-typing `/dmax test` after every reload.

**No out-of-combat aura refresh on display-mode change:**
- Problem: Switching display modes via the options buttons or `/dmax mode` calls `RefreshTip → RefreshLayout → Update`. `Update` reads `self.stacks`, which was last set by `SyncFromAura` or a spell cast prediction. If the player is out of combat and the buff has lapsed, `self.stacks` may be stale (non-zero from an earlier fight), and the new display mode will show an incorrect stack count until the next combat.
- Files: `Core.lua:285`, `Modules/TipOfTheSpear.lua:581`
- Blocks: Display mode changes out of combat show accurate data.

---

## Test Coverage Gaps

**No automated tests of any kind:**
- What's not tested: Stack prediction math (`ApplySpell`), aura-verify grace period suppression (`SyncFromAura`), DB migration (`NormalizeDB`), hex color parsing (`ParseHexColor`), settings validation bounds (`Clamp`), options window state (`Options:Refresh`), module registration and initialization ordering (`RegisterModule`).
- Files: All `.lua` files — there are no `*.test.lua` or spec files.
- Risk: Regressions in stack counting logic or migration code would not be caught until runtime in-game.
- Priority: High for `ApplySpell`, `SyncFromAura`, and `NormalizeDB` (pure Lua logic that can be unit-tested outside WoW). Medium for UI code that requires a WoW frame environment.

---

*Concerns audit: 2026-06-17*
