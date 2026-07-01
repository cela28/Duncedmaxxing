# Phase 6: Options panel v2 — per-mode visibility, configurable stack colors, layout fix - Context

**Gathered:** 2026-07-01
**Status:** Ready for planning

<domain>
## Phase Boundary

The options window (`Duncedmaxxing/Options.lua`) shows only the controls relevant to the active display mode (Bar vs Number), the per-stack number colors become user-configurable via a "Color by stack" toggle plus 4 color pickers, and the mode-selector layout bug (label overlapping the Bar button) is fixed.

**In scope:**
- Per-mode option visibility: gate widgets so Bar-only controls hide in Number mode and vice-versa.
- Config-driven stack colors: add a `colorByStack` toggle + 4 per-stack color fields to `DEFAULTS`/`NormalizeDB`, wire them through the number-mode render path in `TipOfTheSpear.lua`, replacing the hardcoded `STACK_COLORS`.
- Fix the mode-selector layout (the "Display:" label collides with the Bar button).
- Extend the fengari test harness coverage for config-driven stack colors + the toggle fallback.

**Out of scope:**
- Any new display mode (mode set stays exactly `bar` + `number` per Phase 5).
- Data migration for the new fields beyond default-merge (only 2 users; same no-migration philosophy as Phase 5).
- Changes to bar-mode rendering behavior.
</domain>

<decisions>
## Implementation Decisions

### Color model (LOCKED — user-confirmed 2026-07-01, from ROADMAP)
- **D-01:** Number-mode color model = a "Color by stack" toggle + 4 per-stack color pickers. Toggle defaults **ON** so current behavior is preserved out of the box.
- **D-02:** When toggle is ON, the number uses 4 configurable per-stack colors. Defaults match today's hardcoded `STACK_COLORS` in `TipOfTheSpear.lua:33-38`: stack 0 = white `{1,1,1,1}`, stack 1 = green `{0.18039,0.8,0.44314,1}`, stack 2 = yellow `{1,0.94118,0,1}`, stack 3 = red/orange `{1,0.29804,0.18824,1}`.
- **D-03:** When toggle is OFF, the number uses the single flat `textColor` (existing field), matching the current `numberText:SetFont`/`SetTextColor` fallback logic at `TipOfTheSpear.lua:493-495`.

### Per-mode option visibility mapping (LOCKED — from ROADMAP)
- **D-04:** Both modes: Position (X/Y/Scale), Enabled, Hide empty, Border color.
- **D-05:** Bar only: Width, Height, Border size, Fill, Empty %.
- **D-06:** Number only: Text size, and all stack-color controls (the toggle + the 4 pickers + the flat Text color picker — see D-08).

### Flat Text color picker + toggle interaction (discussed 2026-07-01)
- **D-07:** The flat "Text" color picker is a **Number-only** control (text color only affects number rendering) — hidden in Bar mode alongside the other number controls.
- **D-08:** Within Number mode, **always show** the flat Text picker AND all 4 stack pickers. When "Color by stack" is OFF, the 4 stack pickers render **visually disabled/greyed** (and the flat Text picker is the active one). When ON, the flat Text picker renders greyed/inactive and the 4 stack pickers are active. Both control groups are always present; the toggle governs which is greyed — no show/hide swap between them.

### Mode-selector layout fix (discussed 2026-07-01)
- **D-09:** Remove the "Display: X" text label entirely. Instead, **visually highlight** whichever mode button (Bar / Number) is active. This both fixes the overlap (by removing the colliding label) and makes the active mode self-evident. The `Options:Refresh` logic that currently updates `modeText` (`Options.lua:389-391`) is replaced by button-highlight logic.

### Panel sizing on mode switch (discussed 2026-07-01)
- **D-10:** Keep the window a **fixed size**. Hidden controls leave empty space — no reflow, no window resizing when the mode changes. Simplest and avoids a jumping window.

### Persistence / safety (carried forward from Phase 5)
- **D-11:** New fields (`colorByStack` + the 4 stack colors) are added to `DEFAULTS.tip` in `Core.lua` and merged via the existing `MergeDefaults` path. `NormalizeDB` must not wipe settings on load; a fresh/legacy DB gets the new fields by default-merge with no Lua error. No dedicated migration path.

### Claude's Discretion
- Exact naming/shape of the new color fields in `DEFAULTS` (e.g., a `stackColors` sub-table keyed 0–3, mirroring the current `STACK_COLORS` structure, vs. flat named fields). Prefer a structure that `MergeDefaults` handles cleanly (nested tables are merged recursively).
- Labeling and pixel layout of the 4 stack pickers (e.g., "0 / 1 / 2 / 3 stacks"), reusing the existing hex `CreateInput` + `ColorToHex`/`ParseHexColor` convention.
- The visibility-gating mechanism (per-widget `:Show()`/`:Hide()` driven from `Options:Refresh`/`SetMode` vs. grouping widgets into per-mode containers) — as long as switching updates visibility immediately with no combat-lockdown violation.
- The "disabled/greyed" rendering technique for inactive color inputs (EditBox `:Disable()` + dimmed text vs. alpha) — pick what reads clearly and is combat-safe.
- Test file organization for the new stack-color / toggle-fallback assertions.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Source files touched
- `Duncedmaxxing/Options.lua` — `MODE_LABELS` (~10-13), `Options:SetMode` (~171-177), `Options:BuildWindow` widget construction (~179-383), `Options:Refresh` mode-text + widget refresh (~385-400). Mode-selector row with the overlap bug is at ~247-249 (label at x=16, Bar button at x=108). Existing color-input pattern: `CreateInput` + `ColorToHex`/`ParseHexColor` (~104-139, ~320-352).
- `Duncedmaxxing/Modules/TipOfTheSpear.lua` — `STACK_COLORS` hardcoded table (33-38), number-mode render path applying it (~607-626, specifically 620-622), and the `textColor` fallback in `RefreshLayout` (~493-495).
- `Duncedmaxxing/Core.lua` — `DEFAULTS.tip` (12-32), `MergeDefaults` (48-63), `NormalizeDB` including the displayMode validation + no-wipe migration gate (65-92).

### Tests
- `spec/core_spec.lua`, `spec/tip_spec.lua` — add coverage for config-driven stack colors and the color-by-stack OFF→flat-`textColor` fallback.
- `spec/run.cjs` — the fengari (Lua-VM-in-JS) harness; regression runs go through `npx -y -p fengari@0.1.5 node spec/run.cjs` (no native busted in this environment).
- `spec/support/wow_stubs.lua` — WoW API stubs; extend if new widget/API surfaces are exercised.

### Project rules
- `CLAUDE.md` — naming conventions, combat-safety constraints (no UI mutation during `InCombatLockdown`), dual-path API compatibility, idempotency guards.
- `.planning/phases/05-refactor-display-modes-remove-icon-mode-and-add-a-bar-text-m/05-CONTEXT.md` — Phase 5 no-migration philosophy, bar-branch-as-catch-all, fengari harness workflow (directly carried forward here).
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `CreateInput` + `ColorToHex` + `ParseHexColor` (`Options.lua:104-139`, `24-36`): the exact pattern for adding the 4 stack-color hex inputs and the flat Text picker — reuse verbatim.
- `CreateCheckbox` (`Options.lua:78-102`): the pattern for the "Color by stack" toggle; it already registers into `Options.checkboxes` and refreshes on click.
- `MergeDefaults` (`Core.lua:48-63`): recursively merges nested tables, so a nested `stackColors` sub-table in `DEFAULTS` gets populated on legacy DBs automatically — no bespoke migration needed.
- `ColorTuple` (used in `TipOfTheSpear.lua` render paths) + `STACK_COLORS` structure: the number render path already resolves per-stack colors; swap the hardcoded table read for a config read.

### Established Patterns
- `GetCfg()` reads live config each call (`Options.lua:38-41`); all widgets read/write `db.tip` through it. New color/toggle widgets follow the same get/set closure pattern.
- `Options:Refresh` (`Options.lua:385-400`) iterates registered checkboxes/inputs to sync display — the natural place to also drive per-mode widget visibility and the active-button highlight.
- Combat guard: `Options:CanChange()` (`141-148`) blocks all mutations in combat; visibility/highlight updates must stay off the combat-restricted path (they run in `Refresh`/`SetMode`, out of combat).

### Integration Points
- `Options:SetMode` (`171-177`) is called by both the mode buttons and the `/dmax mode ...` slash path — driving visibility + highlight from here (or from `Refresh` which `SetMode`→`RefreshTracker` does not currently call) ensures slash-driven mode changes update the panel too. Verify the slash path re-triggers a panel refresh when the window is open.
- Number-mode render in `TipOfTheSpear.lua:620-622` is the single point where `colorByStack` branches: ON → per-stack config color; OFF → flat `textColor`.
</code_context>

<specifics>
## Specific Ideas

- Stack values are 0–3 (four pickers, including the empty/0 state) — mirror the current `STACK_COLORS` keys `[0]..[3]`.
- Default stack colors must be byte-for-byte the current hardcoded values so existing users see no visual change when the toggle stays ON.
- The "Display:" text label is being removed, not repositioned — the active-mode signal moves entirely to button highlighting.
</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.
</deferred>

---

*Phase: 06-options-panel-v2-per-mode-visibility-configurable-stack-colo*
*Context gathered: 2026-07-01*
