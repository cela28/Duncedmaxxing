---
phase: 06-options-panel-v2-per-mode-visibility-configurable-stack-colo
verified: 2026-07-07T23:27:22Z
status: verified
human_verified: 2026-07-08T12:15:00Z
human_verified_by: cela28
human_verified_via: 06-UAT.md (4/4 passed)
score: 7/7 must-haves verified
behavior_unverified: 0
overrides_applied: 2
overrides:
  - must_have: "Position, Enabled, Hide empty, and Border color are visible in both modes"
    reason: "UAT feedback (06-UAT.md test 1-2) explicitly rejected both controls: border color is meaningless for text-mode rendering (no border drawn in Number mode) and the Enabled checkbox was deemed unnecessary entirely. Removed/regrouped exactly as requested."
    accepted_by: "cela28"
    accepted_at: "2026-07-06T22:09:10Z"
  - must_have: "Switching modes via /dmax mode ... slash command updates widget visibility"
    reason: "UAT feedback (06-UAT.md test 2) explicitly requested button-only mode switching with no slash-command path ('I do not want any slash commands for modes'). The subcommand was already removed prior to this phase; button-driven switching (Options:SetMode) remains fully functional."
    accepted_by: "cela28"
    accepted_at: "2026-07-06T22:09:10Z"
re_verification:
  previous_status: gaps_found
  previous_score: 4/7
  gaps_closed:
    - "SC-6 (BLOCKER): NormalizeDB's blanket CopyDefaults(DEFAULTS.tip) migration overwrite replaced with a targeted stackColors-only re-seed (06-07), then repaired again in 06-REVIEW-FIX (CR-01) so the legacy-format detection and recovery actually fire under the real production init order (MergeDefaults runs before NormalizeDB, Core.lua:233-234). Independently reproduced as fixed by this verification: a shipped-token (0.3.2-fontfix) legacy DB with non-position customizations and a custom stack-1 color now survives migration intact via the committed regression test, run as part of the full suite."
    - "SC-1 / SC-2 paperwork gap: formal overrides recorded in this file's frontmatter (06-08) and ROADMAP.md / REQUIREMENTS.md DISP-05 wording updated to match the shipped, user-approved control set (Enabled checkbox removed, Border color bar-only, button-only mode switching)."
  gaps_remaining: []
  regressions: []
---

# Phase 6: Options panel v2 — per-mode visibility, configurable stack colors, layout fix Verification Report

**Phase Goal:** The options window shows only the controls relevant to the active display mode (Bar vs Number), per-stack number colors are user-configurable, and the mode-selector layout bug is fixed.
**Verified:** 2026-07-07T23:27:22Z
**Status:** human_needed
**Re-verification:** Yes — after gap-closure plans 06-07 (SC-6 migration fix), 06-REVIEW-FIX (CR-01/WR-01/WR-02 production-order fix), and 06-08 (SC-1/SC-2 formal overrides + ROADMAP/REQUIREMENTS alignment)

## Goal Achievement

### Observable Truths (ROADMAP Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | SC-1: Bar mode shows Width/Height/Border size/Fill/Empty %, hides Text size + stack-color controls; Number mode shows Text size + stack-color controls, hides Bar-only controls; Border color is Bar-only; no Enabled checkbox | ✓ PASSED (override) | Per-mode gating engine correct (`Options.lua:190-197, 509-518`). `grep -n "enabled\|Enabled" Options.lua` returns 0 checkbox hits (only an unrelated local `SetColorGroupEnabled` helper). `Border color` is `AddToGroup("bar", ...)` at line 373; `Scale` is `AddToGroup("bar", ...)` at line 315. ROADMAP.md and REQUIREMENTS.md DISP-05 text updated (06-08) to state this as the accepted shape. Override recorded in frontmatter. |
| 2 | SC-2: Switching modes (buttons; slash-command switching intentionally dropped) updates widget visibility immediately with no Lua error | ✓ PASSED (override) | `Options:SetMode` (`Options.lua:178-188`) wired to both mode buttons (`Options.lua:270-271`); `grep -n "mode" Duncedmaxxing/Core.lua` returns 0 hits — confirmed no `/dmax mode` subcommand exists. ROADMAP.md SC-2 updated (06-08) to describe button-only switching as the accepted shape. Override recorded in frontmatter. |
| 3 | SC-3: A "Color by stack" toggle + 4 per-stack color inputs exist and persist in SavedVariables; editing a stack color changes that stack's number color in-game | ✓ VERIFIED (source + test) | Toggle + 4 inputs present (`Options.lua:338, 404-415`), read/write `GetCfg().stackColors[N]` / `.colorByStack` via named-key `ColorToHex`/`ParseHexColor`. Render-side consumption of an edited stack color is test-covered: `spec/tip_spec.lua:646-654` ("colorByStack ON: reflects an edited db.tip.stackColors[2] entry ... proving config-driven color") passes. The Options-UI write path itself (clicking into the panel and typing a hex value) remains untested by the fengari harness — `Options.lua` is explicitly not loaded in `spec/support/init.lua` (WR-03, structural/pre-existing) — see Human Verification. |
| 4 | SC-4: Toggle ON applies per-stack colors (defaults match today's green/yellow/red/white); toggle OFF applies flat `textColor` | ✓ VERIFIED (test) | `TipOfTheSpear.lua:613-619` reads `cfg.colorByStack` and branches between `cfg.stackColors` and flat `cfg.textColor`. Both branches directly test-covered and passing: `spec/tip_spec.lua:656-663` (OFF at 1 stack) and `:666-673` (OFF at 3 stacks), plus the ON case at `:646-654`. |
| 5 | SC-5: The "Display:" label no longer overlaps the Bar button in either mode | ✓ VERIFIED (source + prior UAT pass) | `grep -n "Display:" Duncedmaxxing/Options.lua` returns 0 hits. `HighlightModeButton` (`Options.lua:472-490`) wired into `Refresh` (`521-522`). 06-UAT.md test 4 explicitly passed ("result: pass") and this code path was not touched by any subsequent gap-closure plan (06-04 through 06-08 touched widget grouping, migration, and docs — not the label/highlight logic), so no regression risk. |
| 6 | SC-6: A fresh/legacy DB loads cleanly — the new color/toggle fields default correctly with no settings wipe and no Lua error | ✓ VERIFIED (test, behavior-dependent — production order reproduced) | Independently confirmed by reading `Core.lua`: `NormalizeDB`'s migration branch (`Core.lua:112-126`) no longer does a blanket `CopyDefaults(DEFAULTS.tip)`; it calls `StackColorsAreLegacyFormat` (scans all 4 slots for a lingering numeric `[1]` key, which survives `MergeDefaults` — `Core.lua:72-91`) and, if legacy, `ConvertLegacyStackColors` to recover the user's positional r/g/b/a values in place (`Core.lua:93-110`). This detection is robust to the real production init order (`Core.lua:233-234`: `MergeDefaults` runs before `NormalizeDB`), which is the exact defect CR-01 caught and 06-REVIEW-FIX (commit `8c87070`) repaired. The committed regression test (`spec/core_spec.lua:166-243`) mirrors the real order exactly (`DMX._test.MergeDefaults` then `DMX._test.NormalizeDB`), seeds the shipped v1.0.0 token (`"0.3.2-fontfix"`) with realistic non-position customizations plus a custom stack-1 color, and asserts every customization (`displayMode`, `hideWhenEmpty`, `width`, `borderSize`, `numberFontSize`, `borderColor.r`, `colorByStack`) and the custom color (`stackColors[1].r ≈ 0.9`, not the `0.18039` default) survive migration — this test passes in the full suite run below. Only `DMX:ResetTipStyle` (the unrelated, user-triggered "Reset to Defaults" button) still does a blanket `CopyDefaults(DEFAULTS.tip)`, confirmed by `grep -n "CopyDefaults(DEFAULTS.tip)" Core.lua` → line 207 only (inside `ResetTipStyle`, not `NormalizeDB`). |
| 7 | SC-7: The test suite passes via the fengari harness, with new coverage for config-driven stack colors and the color-by-stack toggle fallback | ✓ VERIFIED (test) | `npx -y -p fengari@0.1.5 node spec/run.cjs`, run directly by this verification → **125 passed, 0 failed, 125 total.** Matches SUMMARY/REVIEW-FIX claims independently. |

**Score:** 7/7 truths verified (2 via accepted override, 5 via direct source + passing test evidence). 0 truths failed. 0 behavior-unverified.

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `Duncedmaxxing/Core.lua` | Named-key `stackColors` defaults; targeted (not blanket) migration re-seed that survives the real `MergeDefaults` → `NormalizeDB` production order | ✓ VERIFIED | `DEFAULTS.tip.stackColors` named-key at lines 30-35; `StackColorsAreLegacyFormat` (72-91) and `ConvertLegacyStackColors` (93-110) implement the CR-01-fixed detection; `NormalizeDB` (112-126) contains no `CopyDefaults(DEFAULTS.tip)` blanket overwrite; `MergeDefaults` (233) precedes `NormalizeDB` (234) exactly as production requires. |
| `Duncedmaxxing/Options.lua` | Scale + Border color bar-only; no Enabled checkbox; no position Reset button/handler; per-mode gating; mode-button highlight; no "Display:" label | ✓ VERIFIED | All confirmed by direct read (see Truths 1, 2, 5 evidence above); 567 lines, no debt markers. |
| `Duncedmaxxing/Modules/TipOfTheSpear.lua` | Config-driven per-stack color render with flat-textColor fallback; no orphaned `Tip:ResetPosition` | ✓ VERIFIED | `grep -c "function Tip:ResetPosition"` = 0; render branch at 613-619 reads `cfg.colorByStack`/`cfg.stackColors`/`cfg.textColor`. |
| `spec/core_spec.lua` | Regression test exercising the real migration path with non-position customizations and a recoverable custom color | ✓ VERIFIED | `describe("NormalizeDB — migration branch preserves user customizations (SC-6 regression)", ...)` at lines 166-243 mirrors production order and asserts recovery of a custom `0.9` red value, not just defaults. |
| `spec/tip_spec.lua` | ON/OFF render coverage for config-driven stack colors | ✓ VERIFIED | Lines 646-673, both toggle states covered and passing. |
| `.planning/ROADMAP.md`, `.planning/REQUIREMENTS.md` | SC-1/SC-2/DISP-05 wording aligned with accepted overrides | ✓ VERIFIED | ROADMAP.md Phase 6 SC-1/SC-2 (lines 225-226) and REQUIREMENTS.md DISP-05 (line 58) both explicitly state the accepted deviations and cross-reference this VERIFICATION.md's overrides. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `Options.lua` stack/flat color inputs | `Core.lua` DEFAULTS.tip.stackColors | `ColorToHex(GetCfg().stackColors[stack])` reads named `r/g/b/a` keys | ✓ WIRED | Named-key format consistent on both read and write side (`ParseHexColor` in `Util.lua` writes named keys). |
| `Options:Refresh` visibility engine | `widgetGroups.bar` / `widgetGroups.number` | `SetWidgetShown` keyed on `cfg.displayMode` | ✓ WIRED | `Options.lua:509-518`; group membership correctly reflects the accepted Bar/Number split (Scale + Border color now bar-only). |
| `NormalizeDB` migration branch | `DEFAULTS.tip.stackColors` (targeted) | `StackColorsAreLegacyFormat` → `ConvertLegacyStackColors`, gated on the real `MergeDefaults`-then-`NormalizeDB` production order | ✓ WIRED (fixed) | Previously ⚠️ WIRED BUT HARMFUL / then ✗ dead-code (CR-01); now confirmed correctly detects and repairs legacy data under the actual init order, verified via a regression test that fails without the fix (per 06-REVIEW-FIX narration) and passes with it (independently reproduced: 125/125 in this verification's own run). |
| `Core.lua:233-234` bootstrap | `MergeDefaults` → `NormalizeDB` | Direct sequential call | ✓ WIRED | Matches the exact order the CR-01 fix and its regression test assume. |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Full fengari suite passes (includes SC-6 regression test under real production order) | `npx -y -p fengari@0.1.5 node spec/run.cjs` | 125 passed, 0 failed, 125 total | ✓ PASS |
| No debt markers in phase-touched files | `grep -n -E "TBD\|FIXME\|XXX\|TODO\|HACK\|PLACEHOLDER" Core.lua Options.lua TipOfTheSpear.lua core_spec.lua tip_spec.lua` | no hits | ✓ PASS |
| No `/dmax mode` subcommand exists | `grep -n "mode" Duncedmaxxing/Core.lua` | 0 hits | ✓ PASS |
| No Enabled checkbox / no position Reset button / no orphaned ResetPosition | `grep -n "enabled\|Enabled" Options.lua` (0 checkbox hits), `grep -c "function Tip:ResetPosition" TipOfTheSpear.lua` (0) | 0 / 0 | ✓ PASS |
| Migration branch no longer does a blanket `CopyDefaults(DEFAULTS.tip)` overwrite | `grep -n "CopyDefaults(DEFAULTS.tip)" Core.lua` | 1 hit, at line 207 inside `ResetTipStyle` only (not inside `NormalizeDB`) | ✓ PASS |
| Production bootstrap order matches what the SC-6 regression test assumes | `grep -n "MergeDefaults(DEFAULTS\|NormalizeDB(Duncedmaxxing" Core.lua` | `MergeDefaults` at line 233, `NormalizeDB` at line 234 (sequential, correct order) | ✓ PASS |

### Requirements Coverage

| Requirement | Source Plan(s) | Description | Status | Evidence |
|-------------|-----------------|--------------|--------|----------|
| DISP-05 | 06-02, 06-04, 06-08 | Options window gates widget visibility by active display mode; Enabled removed / Border color bar-only accepted as overrides | ✓ SATISFIED | Per-mode gating engine correct; REQUIREMENTS.md text (line 58) now matches shipped reality and cites the override. |
| DISP-06 | 06-01, 06-02, 06-03, 06-05, 06-07 | Per-stack number colors user-configurable, config-driven render, no-wipe default-merge | ✓ SATISFIED | Data layer, render, and (as of 06-07 + 06-REVIEW-FIX) the migration-preservation path are all test-covered and passing under the real production order. |
| DISP-07 | 06-02, 06-04, 06-06, 06-08 | Mode-selector layout bug fixed | ✓ SATISFIED | Label removed, highlight wired, layout rebalanced (`SetSize(386, 400)`), UAT test 4 passed. |

No orphaned requirements: REQUIREMENTS.md maps exactly DISP-05, DISP-06, DISP-07 to Phase 6, and all three appear across the eight plans' frontmatter (`06-01`: DISP-06; `06-02`: DISP-05/06/07; `06-03`: DISP-06; `06-04`: DISP-05/07; `06-05`: DISP-06; `06-06`: DISP-07; `06-07`: DISP-06; `06-08`: DISP-05/07).

### Anti-Patterns Found

None of the standard debt-marker / stub patterns found in phase-touched files (see Behavioral Spot-Checks). Two non-blocking, pre-existing observations carried forward from `06-REVIEW.md` for awareness (neither fails a must-have, neither is new):

- **WR-01 (carried forward, not a blocker):** `cfg.scale` still applies unconditionally to Number-mode rendering (`TipOfTheSpear.lua:492, 516`), but the Scale control is now hidden in Number mode (moved to bar-only per 06-04). A user who sets a non-1.0 scale in Bar mode and switches to Number mode sees the effect with no UI path to see/correct it from that mode. Does not fail any stated must-have (06-04's must-have only requires Scale to be hidden in Number mode, which it is).
- **WR-02 (Options.lua, carried forward, not a blocker):** Any returning user whose SavedVariables already has `tip.enabled = false` has no UI path left to re-enable the tracker (checkbox deleted, slash subcommand already gone). Narrow edge case, not exercised by this phase's must-haves.
- **WR-03 (Options.lua, structural, unchanged):** `Options.lua` remains untested by the fengari harness (`spec/support/init.lua` does not load it) — all UI-level behavior in this phase is source-verified only. This is why Truths 1, 2, and 3 route a live-panel check to Human Verification below rather than claiming full behavioral proof.

### Human Verification Required

### 1. Per-mode widget visibility and button-only mode switching, live in-game

**Test:** Open the options window in Bar mode; confirm Width, Height, Border size, Fill, Empty %, and Scale are visible; confirm Text size, "Color by stack", and the 4 stack-color inputs are hidden; confirm there is no Enabled checkbox anywhere and no position "Reset" button (only "Reset Style"). Switch to Number mode via the button; confirm the reverse, AND confirm Border color and Scale are now hidden. Confirm Position (X/Y) and Hide empty show in both modes. Type `/dmax mode bar` in chat and confirm it does NOT change the mode (should just no-op / open options like a normal `/dmax`).
**Expected:** Matches the ROADMAP SC-1/SC-2 text as updated by 06-08 (accepted overrides).
**Why human:** `spec/support/init.lua` does not load `Options.lua` (WR-03); no automated test exercises this UI code or the live combat-lockdown guard.

### 2. Stack color editing, toggle, and default display, live in-game

**Test:** Open Number mode on a DB already on `settingsMigration = "0.3.3-stackcolorfmt"` (or fresh) and confirm the 4 stack inputs read `ffffff`, `2ecc71`, `fff000`, `ff4c30`. Edit each stack input and the flat Text input to distinct colors; toggle "Color by stack" on/off; confirm the in-game number color updates to match; confirm the inactive color group visibly greys out (SetAlpha ~0.4).
**Expected:** Matches ROADMAP SC-3/SC-4.
**Why human:** Options-UI write path (typing into a hex input, seeing the picker grey out) is source-verified only; the render-side response to a changed value is test-covered but the panel interaction itself is not.

### 3. Options-panel layout — no dead space, both modes

**Test:** Open the panel in Bar mode; confirm no large empty region remains in the upper-right. Switch to Number mode; confirm the layout is compact with no large empty region. Confirm the window is 386x400 (not the old 386x484) and still drags/saves position correctly.
**Expected:** Matches ROADMAP SC-5 / the 06-06 layout rebalance intent.
**Why human:** Visual "looks balanced" judgment can only be made in-game; source trace confirms `SetSize(386, 400)` and no coordinate collisions but cannot confirm subjective layout quality.

### 4. Settings-migration fix — confirm against a real captured SavedVariables file (nice-to-have, not blocking)

**Test:** If a real `WTF/Account/.../SavedVariables/Duncedmaxxing.lua` file still on `settingsMigration = "0.3.2-fontfix"` is available, load it and confirm all previously-customized `tip.*` fields (display mode, colors, sizes) survive, and that the 4 stack-color inputs display the recovered/expected colors afterward.
**Expected:** No settings wipe — matches ROADMAP SC-6.
**Why human:** The automated regression test (`spec/core_spec.lua:166-243`) already reproduces the real production order and a realistic customization set synthetically and passes; this item is an optional real-world confirmation, not a blocker, since the code-level fix and its test evidence are already strong (SC-6 is marked VERIFIED above, not held open on this item).

## Gaps Summary

No gaps remain. All three prior blocking/paperwork issues from the previous verification cycle are resolved:

1. **SC-6 (previously BLOCKER):** Fixed in two steps — 06-07 replaced the blanket migration wipe with a targeted `stackColors` re-seed, then an independent code review (`06-REVIEW.md`, CR-01) caught that the targeted detection was dead code under the real `MergeDefaults`-then-`NormalizeDB` production order; `06-REVIEW-FIX.md` (commit `8c87070`) repaired the detection to work against the post-merge mixed shape and rewrote the regression test to run in the real order. This verification independently confirmed the fix by reading the current code and by running the full suite (125/125, including the rewritten regression test).
2. **SC-1 and SC-2 (previously paperwork gaps):** Closed by 06-08, which recorded formal `overrides:` entries in this file's frontmatter and updated ROADMAP.md / REQUIREMENTS.md wording to match the shipped, user-approved control set.

The remaining items are routed to Human Verification (not gaps) because they are live in-game/visual UI behaviors that the project's fengari test harness structurally cannot exercise (`Options.lua` is not loaded by `spec/support/init.lua`) — this is a pre-existing, unchanged limitation (WR-03), not a defect introduced by this phase.

---

_Verified: 2026-07-07T23:27:22Z_
_Verifier: Claude (gsd-verifier)_
