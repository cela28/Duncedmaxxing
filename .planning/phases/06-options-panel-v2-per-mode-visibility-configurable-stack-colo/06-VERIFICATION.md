---
phase: 06-options-panel-v2-per-mode-visibility-configurable-stack-colo
verified: 2026-07-02T00:00:00Z
status: human_needed
score: 7/7 must-haves verified
behavior_unverified: 0
overrides_applied: 0
human_verification:
  - test: "Open the options window in Bar mode. Confirm Width, Height, Border size, Fill, Empty % are visible, and Text size + 'Color by stack' checkbox + the 4 per-stack color inputs + the flat Text color input are hidden. Confirm Position (X/Y/Scale), Enabled, Hide empty, and Border color are visible."
    expected: "Bar-only controls shown, Number-only controls hidden, shared controls shown in both modes — matching ROADMAP SC-1 / DISP-05."
    why_human: "spec/support/init.lua explicitly skips loading Options.lua in the fengari test harness (comment: 'Options.lua (skipped)'), so no automated test exercises Options:Refresh's widget-group Show/Hide logic. Verified only by direct source reading (Options.lua:505-514), not by a passing test."
  - test: "Switch modes via the Bar/Number buttons, then switch via '/dmax mode bar' and '/dmax mode number' while the options window is open. Confirm visibility and the highlighted button update immediately with no Lua error and no window resize."
    expected: "Both button clicks and the slash command refresh widget visibility and the active-button highlight instantly; window stays 386x484; no error in the chat/debug log."
    why_human: "Options:SetMode (Options.lua:171-181) and Options:Refresh (488-527) are source-verified to call the right functions, but Options.lua is not loaded by the test harness, so the actual runtime behavior (widget Show/Hide, LockHighlight/UnlockHighlight, no resize) is unexercised by any test — ROADMAP SC-2 / DISP-05 / DISP-07."
  - test: "In Number mode, edit each of the 4 per-stack color hex inputs and the flat Text color input to distinct colors, toggle 'Color by stack' on/off, and confirm the in-game number's color updates correctly and matches the intended source (per-stack when ON, flat Text color when OFF). Also confirm the inactive color group visibly greys out while the active one stays fully opaque."
    expected: "Editing a stack color changes only that stack's number color in-game; the toggle correctly swaps between per-stack and flat colors; the inactive picker group is visually dimmed (SetAlpha 0.4) without being hidden — ROADMAP SC-3 / SC-4 (UI wiring half) / DISP-06."
    why_human: "The render-side color logic (TipOfTheSpear.lua:613-629) IS covered by passing fengari tests (spec/tip_spec.lua colorByStack ON/OFF cases). The gap is purely on the Options.lua input/toggle-to-config write path and the visual greying (SetColorGroupEnabled, Options.lua:448-466), which the test harness does not load or exercise."
  - test: "Confirm the 'Display:' text label is gone in both modes and does not overlap the Bar button; confirm the active mode button (Bar or Number) is visually distinguishable (highlighted/brighter) from the inactive one."
    expected: "No 'Display: Bar'/'Display: Number' text anywhere in the window; the currently active mode's button looks visually different (locked highlight, full alpha) versus the inactive button (unlocked highlight, 0.75 alpha) — ROADMAP SC-5 / DISP-07."
    why_human: "grep confirms zero occurrences of 'modeText' or 'Display: ' in Options.lua (label fully removed at the source level) and HighlightModeButton (Options.lua:468-486) is present and wired into Refresh, but the actual visual highlight treatment (LockHighlight/UnlockHighlight/alpha) can only be judged by looking at the rendered UI in-game."
---

# Phase 6: Options panel v2 — per-mode visibility, configurable stack colors, layout fix Verification Report

**Phase Goal:** The options window shows only the controls relevant to the active display mode (Bar vs Number), per-stack number colors are user-configurable, and the mode-selector layout bug is fixed.
**Verified:** 2026-07-02T00:00:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth (ROADMAP Success Criteria) | Status | Evidence |
|---|---------|--------|----------|
| 1 | SC-1: Bar mode shows Width/Height/Border size/Fill/Empty %, hides Text size + stack-color controls; Number mode shows Text size + stack-color controls, hides Bar-only controls; Position/Enabled/Hide empty/Border color show in both | ✓ VERIFIED (source) | `Options.lua:263-406` — every `BuildWindow` widget is tagged via `AddToGroup("both"\|"bar"\|"number", ...)` per the D-04/D-05/D-06 mapping; `Options:Refresh` (505-514) drives `SetWidgetShown` keyed on `cfg.displayMode`. Correctly wired at the source level; runtime visual confirmation is a human-verification item (Options.lua not loaded by test harness). |
| 2 | SC-2: Switching modes (buttons or `/dmax mode ...`) updates widget visibility immediately with no Lua error | ✓ VERIFIED (source) | `Options.lua:171-181` (`SetMode` now calls `self:Refresh()` guarded by `self.window and self.window:IsShown()`) closes the slash-path gap; `CreateButton`'s `onClick` (59-72) already calls `Options:Refresh()` after every click. Source-verified; runtime confirmation is a human-verification item. |
| 3 | SC-3: A "Color by stack" toggle + 4 per-stack color inputs exist and persist in SavedVariables; editing a stack color changes that stack's number color in-game | ✓ VERIFIED (source + partial test) | Toggle + 4 inputs exist (`Options.lua:347-350, 394-406`), read/write `GetCfg().stackColors[N]` via `ParseHexColor`/`ColorToHex`, persisted through the existing `DuncedmaxxingDB` mechanism. The render-side consumption of an edited `stackColors[N]` IS proven by a passing test (`spec/tip_spec.lua:650-658`, mutates `stackColors[2]` and asserts the render reflects it). The Options-UI write path itself (EditBox -> `ParseHexColor` -> `stackColors[N]`) is not exercised by any test — human-verification item. |
| 4 | SC-4: Toggle ON applies per-stack colors (defaults match today's green/yellow/red/white); toggle OFF applies flat `textColor` | ✓ VERIFIED (test) | `Duncedmaxxing/Modules/TipOfTheSpear.lua:621-629` branches on `cfg.colorByStack ~= false`; `spec/tip_spec.lua:608-634` (four default-color ON cases) and `650-677` (edited-color ON case + two OFF flat-fallback cases) all pass. Full behavioral proof, not just presence. |
| 5 | SC-5: The "Display:" label no longer overlaps the Bar button in either mode | ✓ VERIFIED (source) | `grep -n 'modeText\|Display: ' Duncedmaxxing/Options.lua` returns zero hits — the label and its `Options:Refresh` update block are fully removed. Bar button moved to x=16, Number button to x=82 (`Options.lua:263-264`), eliminating the collision by construction. Visual confirmation of "no overlap" and the highlight replacement is a human-verification item. |
| 6 | SC-6: A fresh/legacy DB loads cleanly — new color/toggle fields default correctly with no settings wipe and no Lua error | ✓ VERIFIED (test) | `Duncedmaxxing/Core.lua:29-38` (`DEFAULTS.tip.colorByStack`/`stackColors`, byte-for-byte the old `STACK_COLORS`); `SETTINGS_MIGRATION` unchanged at `"0.3.2-fontfix"` (no migration bump). `spec/core_spec.lua:241-269` runs the real `MergeDefaults`->`NormalizeDB` pipeline against a legacy DB missing the new fields and asserts: new fields populated, `displayMode`/`x`/`y`/`scale`/`enabled` unchanged, `settingsMigration` unchanged, no error raised (via `pcall`). |
| 7 | SC-7: The test suite passes via the fengari harness, with new coverage for config-driven stack colors and the color-by-stack toggle fallback | ✓ VERIFIED (test) | `npx -y -p fengari@0.1.5 node spec/run.cjs` → **124 passed, 0 failed, 124 total** (up from 117 pre-phase per 06-03-SUMMARY.md). New coverage confirmed present in both `spec/tip_spec.lua` and `spec/core_spec.lua` (see truths 4 and 6). |

**Score:** 7/7 truths verified at the source/behavior level. 4 of the 7 also carry an unresolved human-verification item because the underlying Options.lua UI code is not loaded or exercised by the automated test harness (see Human Verification Required below) — this routes overall status to `human_needed`, not `passed`.

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `Duncedmaxxing/Core.lua` | `DEFAULTS.tip.colorByStack` (true) + nested `stackColors` (keys 0-3, byte-for-byte defaults) | ✓ VERIFIED | Lines 29-38. Values: `[0]={1,1,1,1}`, `[1]={0.18039,0.80000,0.44314,1}`, `[2]={1,0.94118,0,1}`, `[3]={1,0.29804,0.18824,1}` — matches prior hardcoded `STACK_COLORS` byte-for-byte. `SETTINGS_MIGRATION` unchanged. |
| `Duncedmaxxing/Modules/TipOfTheSpear.lua` | Config-driven per-stack color read replacing hardcoded `STACK_COLORS` in number-mode render | ✓ VERIFIED | Lines 621-629: branches on `cfg.colorByStack ~= false`; ON reads `cfg.stackColors[stacks]` via `ColorTuple` with `STACK_COLORS` fallback; OFF reads `cfg.textColor` via `ColorTuple` with `DMX.defaults.tip.textColor` fallback (mirrors `RefreshLayout:494`). Module-local `STACK_COLORS` (33-38) retained as fallback, not deleted. |
| `Duncedmaxxing/Options.lua` | Per-mode widget visibility gating, colorByStack toggle + 4 stack color inputs + flat Text picker greying, mode-button highlight replacing Display label | ✓ VERIFIED (source), UNTESTED (no harness coverage) | `AddToGroup`/`widgetGroups` (183-190, 199, 505-514); toggle + 4 inputs + flat Text picker (347-350, 383-406); `SetColorGroupEnabled` greying (448-466); `HighlightModeButton` (468-486) wired into `Refresh` (516-518); `modeText`/"Display:" label fully removed (0 grep hits). `window:SetSize(386, 484)` unchanged (line 204, D-10). |
| `spec/tip_spec.lua` | colorByStack ON/OFF number-color assertions | ✓ VERIFIED | Lines 650-678: edited-stackColors ON case + two flat-textColor OFF cases (stacks 1 and 3). All pass. |
| `spec/core_spec.lua` | MergeDefaults/NormalizeDB no-wipe assertions for new fields | ✓ VERIFIED | Lines 51-70 (fill-missing, preserve-false, preserve-edit) + 212-270 (full legacy-DB MergeDefaults->NormalizeDB pipeline, no-wipe, no-bump, no-error). All pass. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `TipOfTheSpear.lua` render path | `Core.lua` DEFAULTS | `cfg.colorByStack`/`cfg.stackColors` read from `db.tip` populated by `MergeDefaults` | ✓ WIRED | Confirmed by passing `spec/tip_spec.lua` assertions exercising the actual render function against the actual config table. |
| `Options.lua` toggle/pickers | `Core.lua` | `GetCfg().colorByStack` / `GetCfg().stackColors[N]` read+write | ✓ WIRED (source) | `Options.lua:347-350` (checkbox get/set), `394-406` (4 inputs' get/set) directly reference `GetCfg().colorByStack`/`.stackColors[stack]`. Not exercised by any test (Options.lua unloaded by harness) — confirmed by direct source read only. |
| `Options:SetMode` | `Options:Refresh` | `SetMode` calls `self:Refresh()` when window is shown, so slash-driven and button-driven mode changes both update visibility + highlight | ✓ WIRED (source) | `Options.lua:171-181`. Not exercised by any test — confirmed by direct source read only. |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Full fengari suite passes | `npx -y -p fengari@0.1.5 node spec/run.cjs` | 124 passed, 0 failed, 124 total | ✓ PASS |
| No debt markers in phase-touched files | `grep -n -E "TBD\|FIXME\|XXX\|TODO\|HACK\|PLACEHOLDER" Core.lua Options.lua TipOfTheSpear.lua tip_spec.lua core_spec.lua` | no hits | ✓ PASS |
| `colorByStack`/`stackColors` symbols present in all expected files | `grep -n colorByStack\|stackColors Core.lua Modules/TipOfTheSpear.lua Options.lua spec/tip_spec.lua spec/core_spec.lua` | hits in all 5 files | ✓ PASS |
| Options.lua loaded by test harness | `grep -n "Options.lua" spec/support/init.lua` | comment: `Options.lua (skipped)` | ✗ CONFIRMED GAP — no Options.lua code path is exercised by any automated test |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|--------------|--------|----------|
| DISP-05 | 06-02 | Options window gates widget visibility by active display mode | ✓ SATISFIED (source), human-verify for runtime | `Options.lua` widget-group tagging + `Refresh` gating (see artifacts table). No automated test — human verification item 1/2 above. |
| DISP-06 | 06-01, 06-02, 06-03 | Per-stack number colors user-configurable via toggle + 4 pickers, config-driven render, no-wipe default-merge | ✓ SATISFIED (full test coverage for data layer + render; UI write path untested) | Data layer + render fully test-covered (`spec/tip_spec.lua`, `spec/core_spec.lua`, 124/124 passing). Options.lua UI half (toggle/pickers/greying) is source-verified only — human verification item 3 above. |
| DISP-07 | 06-02 | Mode-selector layout bug fixed — "Display:" label removed, active button highlighted, fixed window size | ✓ SATISFIED (source), human-verify for visual | `modeText`/"Display: " fully removed (grep confirms 0 hits); `HighlightModeButton` wired into `Refresh`; `window:SetSize(386, 484)` unchanged. No automated test for visual result — human verification item 4 above. |

No orphaned requirements: REQUIREMENTS.md maps exactly DISP-05, DISP-06, DISP-07 to Phase 6, and all three appear in plan frontmatter (`06-01` claims DISP-06; `06-02` claims DISP-05/06/07; `06-03` claims DISP-06). REQUIREMENTS.md marks all three `[x]` / "Complete".

### Anti-Patterns Found

None found in files modified by this phase. No `TBD`/`FIXME`/`XXX`/`TODO`/`HACK`/`PLACEHOLDER` markers, no empty stub implementations, no hardcoded-empty return values on the data/render paths.

The independent code review (`06-REVIEW.md`, `status: issues_found`, 0 critical / 3 warning / 3 info) flagged:
- **WR-01** (already captured above as the root cause of all human-verification items): Options.lua has zero automated test coverage in this phase.
- **WR-02**: `Options:Refresh()`'s color-group enable/disable recompute is gated by `mode == "number"`, so it's a no-op in bar mode — currently harmless only because the same widgets are also hidden by the visibility loop, making correctness depend on code-path ordering rather than an invariant. This does not break any observable truth today (verified by re-reading `Options.lua:500-527`) but is a fragility risk for future edits. **Not a blocker** — quality/robustness note, not a functional failure.
- **WR-03, IN-01, IN-02, IN-03**: minor code-quality/duplication notes, no functional impact, not blockers.

### Human Verification Required

### 1. Per-mode widget visibility (Bar vs Number)

**Test:** Open the options window in Bar mode; confirm Bar-only controls show and Number-only controls hide; switch to Number mode and confirm the reverse; confirm shared controls (Position, Enabled, Hide empty, Border color) show in both.
**Expected:** Matches ROADMAP SC-1 / DISP-05 exactly as coded in `Options.lua:263-406, 505-514`.
**Why human:** `spec/support/init.lua` explicitly skips loading `Options.lua` — no automated test exercises this UI code.

### 2. Mode switching via buttons and slash command

**Test:** Click Bar/Number buttons and run `/dmax mode bar` / `/dmax mode number` with the panel open; confirm immediate visibility + highlight update, no Lua error, no window resize.
**Expected:** Matches ROADMAP SC-2 / DISP-05 / DISP-07.
**Why human:** Same test-harness gap; `SetMode`/`Refresh` wiring is source-verified only.

### 3. Stack color editing and toggle behavior

**Test:** Edit each of the 4 per-stack color inputs and the flat Text input to distinct colors; toggle "Color by stack"; confirm in-game number color updates correctly; confirm the inactive picker group visibly greys out.
**Expected:** Matches ROADMAP SC-3 / SC-4 (UI half) / DISP-06.
**Why human:** Render-side logic is test-proven; the Options-UI write path (`ParseHexColor` -> `stackColors[N]`) and the visual greying treatment are not.

### 4. Display label removal and mode-button highlight

**Test:** Confirm no "Display:" text appears anywhere and the active mode button is visually distinguishable from the inactive one.
**Expected:** Matches ROADMAP SC-5 / DISP-07.
**Why human:** Label removal is grep-confirmed at the source level; the visual highlight treatment can only be judged in-game.

### Gaps Summary

No BLOCKER-level gaps. All 7 ROADMAP success criteria have source-level or test-level evidence of correct implementation, and the fengari suite is green at 124/124 with real (not just presence-based) regression coverage for the data-layer and render-path portions of DISP-06 (SC-4, SC-6, SC-7).

The phase's own code review (06-REVIEW.md) independently identified the same root cause surfaced here: Options.lua — which carries all of DISP-05, DISP-07, and the UI half of DISP-06 — has zero automated test coverage because the fengari harness intentionally does not load it. This is not a functional defect (source inspection shows the wiring is correct and matches every plan's acceptance criteria), but it means SC-1, SC-2, SC-3 (UI-write half), and SC-5 are unverified by any executable check — only by reading the Lua source. Per the task's explicit guidance, these are classified as human-verification items rather than automated failures, routing the phase to `status: human_needed`.

---

_Verified: 2026-07-02T00:00:00Z_
_Verifier: Claude (gsd-verifier)_
