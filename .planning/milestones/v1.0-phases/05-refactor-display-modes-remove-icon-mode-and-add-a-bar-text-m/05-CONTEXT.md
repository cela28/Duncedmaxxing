# Phase 5: Refactor display modes — remove icon mode, keep only bar + number — Context

**Gathered:** 2026-06-23
**Status:** Ready for planning
**Source:** Orchestrator-captured locked decisions (ROADMAP Phase 5 + user confirmation 2026-06-23)

<domain>
## Phase Boundary

This phase simplifies the display-mode set of the Tip of the Spear tracker down to exactly two modes: `bar` and `number`. It removes the `icons` display mode in full — every rendering branch, option, slash token, validation entry, legacy alias, and the now-orphaned sizing config it alone used. It is a pure removal/refactor of existing, well-understood code. No new modes are added (the previously-considered `bartext` mode is explicitly NOT part of this phase). No new features, libraries, or WoW APIs are introduced.

**In scope:**
- Remove the `icons` rendering branches in `TipOfTheSpear.lua` (`RefreshLayout` and `Update`).
- Remove the `icons` token + legacy `icon`→`icons` alias from the slash-command parser, and `icons` from the validation set, in `Core.lua`.
- Remove the "Icons" mode button and the `icons` `MODE_LABELS` entry in `Options.lua`.
- Remove the orphaned `iconSize`/`iconSpacing` `DEFAULTS` and their two Options sliders.
- Update the `/dmax` help/usage text to read `bar|number`.
- Update `spec/` tests: drop icon-mode assertions; keep bar/number coverage green.

**Out of scope:**
- Adding a `bartext` (bar + overlaid number) mode — reversed/dropped.
- Any `icon`/`icons`→other-mode data migration path.
- Changes to bar or number rendering behavior beyond what icon removal mechanically requires.
</domain>

<decisions>
## Implementation Decisions

### Final mode set
- Exactly two modes survive: `bar` and `number`. (LOCKED — user-confirmed 2026-06-23.)
- The earlier 2026-06-22 decision to add a combined `bartext` mode is REVERSED. Do NOT add `bartext`.
- Default `displayMode` stays `"bar"` (`Core.lua` DEFAULTS).

### No migration
- Do NOT write a remap for persisted `icons`/`icon` `displayMode` values. (LOCKED.)
- `NormalizeDB` validation simply falls back to the default (`bar`) for any now-unknown stored mode. The existing fallback at `Core.lua:98-99` already does this once `icons` is dropped from the accepted set — just remove `icons` from that comparison.
- Remove the legacy `icon`→`icons` slash alias at `Core.lua:251` (it only existed to upgrade into the mode being deleted).

### Orphaned config
- Remove `iconSize` and `iconSpacing` from `DEFAULTS` (`Core.lua:31-32`) and remove their two sliders from the Options window (`Options.lua:317-329`). (LOCKED — user-confirmed 2026-06-23.) No display mode reads them after icon removal.

### Tests
- Update `spec/core_spec.lua`, `spec/tip_spec.lua`, and `spec/support/wow_stubs.lua` as needed: remove icon-mode assertions; keep/adjust bar and number coverage. Add an assertion that a stored `"icons"` mode normalizes to `"bar"`.
- There is NO native Lua/busted toolchain in this environment — regression runs go through the fengari (Lua-VM-in-JS) harness. Verify via that harness, not a local `busted` binary.

### Claude's Discretion
- Exact structure of the post-removal `if mode == ... elseif ...` chains in `RefreshLayout`/`Update` (both currently branch `icons` / `number` / else=bar).
- Whether to collapse the two-branch validation comparison or keep it explicit.
- Test file organization and naming of new normalization assertions.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Source files touched
- `Duncedmaxxing/Modules/TipOfTheSpear.lua` — `icons` branches in `RefreshLayout` (~lines 489-508) and `Update` (~lines 653-677); shared pip infrastructure used by `bar` too.
- `Duncedmaxxing/Core.lua` — `DEFAULTS.tip` (`displayMode` ~30, `iconSize`/`iconSpacing` ~31-32), `NormalizeDB` validation (~98-99), help text (~160), slash parser `icon`→`icons` alias (~251) and valid-mode set (~254-259).
- `Duncedmaxxing/Options.lua` — `MODE_LABELS` (~10-13), `SetMode`, "Icons" button (~250), `iconSize`/`iconSpacing` sliders (~317-329), mode-text display (~411).

### Tests
- `spec/core_spec.lua`, `spec/tip_spec.lua`, `spec/support/wow_stubs.lua` — current icon-mode assertions to remove; bar/number assertions to retain.

### Project rules
- `CLAUDE.md` — naming conventions, combat-safety constraints, dual-path API compatibility, idempotency guards.
</canonical_refs>

<specifics>
## Specific Ideas

- The `icons` branch in `RefreshLayout` reuses the same `pips[]` frames as `bar` mode but sizes/positions them as square icons with `spellTexture` fills. Bar mode reuses these pips as horizontal segments. Confirm pip frames remain correctly initialized for bar/number after the icon branch is deleted.
- `Core.lua:98` currently reads: `if tip.displayMode ~= "bar" and tip.displayMode ~= "icons" and tip.displayMode ~= "number" then` → becomes `~= "bar" and ~= "number"`.
- Grep gate for completeness: `grep -rn -i "icons\|iconSize\|iconSpacing\|bartext" Duncedmaxxing/` should return zero hits after the phase (only `icon`-rooted words inside unrelated identifiers, if any, are acceptable — but none are expected).
</specifics>

<deferred>
## Deferred Ideas

- `bartext` combined bar+number mode — explicitly dropped from this milestone (reversal of 2026-06-22 decision). Not deferred to a tracked future requirement; revisit only if requested.
</deferred>

---

*Phase: 05-refactor-display-modes-remove-icon-mode-and-add-a-bar-text-m*
*Context captured: 2026-06-23 by /gsd-plan-phase orchestrator*
