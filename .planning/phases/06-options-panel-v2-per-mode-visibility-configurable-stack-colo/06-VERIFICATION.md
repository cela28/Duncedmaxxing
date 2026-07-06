---
phase: 06-options-panel-v2-per-mode-visibility-configurable-stack-colo
verified: 2026-07-06T21:30:00Z
status: gaps_found
score: 4/7 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: human_needed
  previous_score: 7/7
  gaps_closed:
    - "UAT test 1: Border color / Scale no longer shown in Number mode (moved to bar-only group)"
    - "UAT test 2 (part): Enabled checkbox removed from the panel"
    - "UAT test 2 (part): position 'Reset' button removed; 'Reset Style' retained"
    - "UAT test 2 (part): confirmed no /dmax mode subcommand exists (already resolved pre-phase)"
    - "UAT test 3: per-stack color inputs now display real default colors (white/2ecc71/fff000/ff4c30) instead of ffffff"
    - "UAT test 5: options-panel dead-space/layout issue closed via row-sharing rebalance, window shrunk 484->400"
  gaps_remaining: []
  regressions:
    - "NEW in this cycle: the SETTINGS_MIGRATION bump used to fix the stack-color-defaults bug (06-05) triggers NormalizeDB's full-tip-wipe migration branch for every real user upgrading from the shipped v1.0.0 token ('0.3.2-fontfix'), discarding all customized tip settings except x/y/scale/optionsX/optionsY. This violates ROADMAP SC-6 ('no settings wipe') and was independently caught by 06-REVIEW.md (CR-01, classified BLOCKER) and independently reproduced by this verification (see Behavioral Spot-Checks)."
gaps:
  - truth: "SC-6: A fresh/legacy DB loads cleanly — the new color/toggle fields default correctly with no settings wipe and no Lua error"
    status: failed
    reason: "Confirmed by direct reproduction: NormalizeDB's migration branch (Core.lua:75-94) fires whenever db.settingsMigration does not match the current token. Plan 06-05 bumped SETTINGS_MIGRATION from '0.3.2-fontfix' (the token shipped in the v1.0.0 production release, confirmed via `git show v1.0.0:Duncedmaxxing/Core.lua`) to '0.3.3-stackcolorfmt' specifically to force this branch to re-seed stackColors. But the branch does CopyDefaults(DEFAULTS.tip) and overwrites every tip.* key, restoring only x, y, scale, optionsX, optionsY afterward. Every other customization (displayMode, hideWhenEmpty, width, height, borderSize, numberFontSize, fillColor, borderColor, textColor, colorByStack) is silently reset to stock defaults on the very next login for any existing user. This is not hypothetical — it is the guaranteed effect for every user who has ever opened the addon before this update ships."
    artifacts:
      - path: "Duncedmaxxing/Core.lua"
        issue: "NormalizeDB (lines 72-99) does a blanket CopyDefaults(DEFAULTS.tip) overwrite instead of a targeted re-seed of only the stackColors field whose shape changed. SETTINGS_MIGRATION bump (line 10) turns this into a live, guaranteed-to-fire migration for all real users on next load."
    missing:
      - "Replace the blanket migration-branch overwrite with a targeted fix that only re-seeds stackColors when it is in the legacy positional shape (see 06-REVIEW.md CR-01 for a concrete StackColorsAreLegacyFormat() + targeted-reseed sketch), or otherwise preserve every previously-customized tip.* field across the migration bump."
      - "Add a core_spec.lua regression test that runs NormalizeDB against a legacy DB seeded with the OLD migration token AND non-default values for fields beyond x/y/scale/optionsX/optionsY (displayMode, width, borderColor, colorByStack, etc.), asserting those values survive migration. The existing 'legacy DB gains colorByStack/stackColors with no wipe (D-11)' test (spec/core_spec.lua:212-270) does not exercise this path — it hardcodes settingsMigration to the CURRENT token, so it never actually enters the migration branch and cannot catch this regression."
    debug_session: ""

  - truth: "SC-1: Position, Enabled, Hide empty, and Border color are visible in both [Bar and Number] modes"
    status: failed
    reason: "Literal ROADMAP wording is no longer true: the Enabled checkbox was deleted from the panel entirely (Options.lua, per 06-04), and Border color was reassigned from the shared ('both') group to the bar-only group (Options.lua:349-357, per 06-04) so it is now hidden in Number mode. This is a deliberate, explicitly-requested change captured verbatim in 06-UAT.md ('We do not need border color for text or scale' / 'do not need enabled checkbox at all'), executed exactly as the user asked, and it better serves the phase's actual goal (mode-relevant-controls-only) than the original SC-1 sub-clause. No VERIFICATION.md override was ever recorded for it, though — this is a paperwork/traceability gap, not a functional defect."
    artifacts:
      - path: "Duncedmaxxing/Options.lua"
        issue: "Enabled checkbox widget block fully removed; Border color CreateInput at lines 349-357 is registered AddToGroup(\"bar\", ...) instead of \"both\"."
    missing:
      - "Add a VERIFICATION.md override entry (or update ROADMAP.md SC-1 / REQUIREMENTS.md DISP-05 text) formally recording that Enabled and Border color were intentionally removed/regrouped per explicit UAT feedback, so future verification runs don't re-flag this as a literal-wording mismatch."
    debug_session: ""

  - truth: "SC-2: Switching modes (via buttons or /dmax mode ...) updates widget visibility immediately with no Lua error"
    status: failed
    reason: "The /dmax mode bar|number slash subcommand does not exist (Core.lua's slash handler, lines 182-193, is argument-less and only opens the options window) — confirmed already removed in a prior commit before this phase, and the user explicitly reconfirmed during UAT: 'I do not want any slash commands for modes.' Button-only switching (Options:SetMode, lines 178-188) works correctly and is source-verified. Same category as the SC-1 gap above: an intentional, user-approved deviation from literal ROADMAP wording with no formal override recorded."
    artifacts:
      - path: "Duncedmaxxing/Core.lua"
        issue: "Slash handler (182-193) has no mode subcommand path — by design, per explicit user direction."
    missing:
      - "Add a VERIFICATION.md override entry (or update ROADMAP.md SC-2 text) recording that slash-command mode switching was intentionally dropped in favor of button-only switching."
    debug_session: ""
---

# Phase 6: Options panel v2 — per-mode visibility, configurable stack colors, layout fix Verification Report

**Phase Goal:** The options window shows only the controls relevant to the active display mode (Bar vs Number), per-stack number colors are user-configurable, and the mode-selector layout bug is fixed.
**Verified:** 2026-07-06T21:30:00Z
**Status:** gaps_found
**Re-verification:** Yes — after gap-closure plans 06-04, 06-05, 06-06 addressed 06-UAT.md tests 1, 2, 3, 5

## Goal Achievement

### Observable Truths (ROADMAP Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | SC-1: Bar mode shows Width/Height/Border size/Fill/Empty %, hides Text size + stack-color controls; Number mode shows Text size + stack-color controls, hides Bar-only controls; Position/Enabled/Hide empty/Border color show in both | ✗ FAILED (literal wording) | Per-mode gating itself is correctly wired (`Options.lua:190-197, 273-416, 509-518`; the Bar/Number split is genuinely mutually exclusive with no coordinate collisions — verified by reading every `AddToGroup` call). BUT the "Enabled + Border color show in both" sub-clause no longer holds: the Enabled checkbox was deleted outright, and Border color was moved to the bar-only group (`Options.lua:349-357`), per explicit UAT feedback ("We do not need border color for text or scale", "do not need enabled checkbox at all" — `06-UAT.md` tests 1-2). Deliberate, user-approved deviation; no formal override recorded. See Gaps. |
| 2 | SC-2: Switching modes (buttons or `/dmax mode ...`) updates widget visibility immediately with no Lua error | ✗ FAILED (literal wording) | Button-driven switching is correctly wired (`Options.lua:178-188, 270-271`). The `/dmax mode bar\|number` slash path does not exist — confirmed via `grep -n "mode" Duncedmaxxing/Core.lua` (0 hits); the current handler (`Core.lua:182-193`) is argument-less. User explicitly reconfirmed this is wanted during UAT ("I do not want any slash commands for modes" — `06-UAT.md` test 2). Deliberate, user-approved deviation; no formal override recorded. See Gaps. |
| 3 | SC-3: A "Color by stack" toggle + 4 per-stack color inputs exist and persist in SavedVariables; editing a stack color changes that stack's number color in-game | ✓ VERIFIED (source + partial test) | Toggle + 4 inputs unchanged from cycle 1 (`Options.lua:335-338, 405-416`), read/write `GetCfg().stackColors[N]`/`.colorByStack`. UAT gap 3 (all 4 stack inputs rendering as `ffffff` due to a positional-vs-named-key format mismatch) is now closed: `DEFAULTS.tip.stackColors` converted to named-key form (`Core.lua:30-35`); hand-computed `ColorToHex` output against the new defaults now yields `ffffff` (0), `2ecc71` (1), `fff000` (2), `ff4c30` (3) — matching the SUMMARY's claim and the tracker's actual hardcoded fallback colors. Render-side consumption of an edited color is still proven by a passing test (`spec/tip_spec.lua:650-658`); the Options-UI write path itself remains untested by the harness (`Options.lua` explicitly skipped — pre-existing, tracked gap, not new). |
| 4 | SC-4: Toggle ON applies per-stack colors (defaults match today's green/yellow/red/white); toggle OFF applies flat `textColor` | ✓ VERIFIED (test) | Unchanged by this gap-closure cycle — `TipOfTheSpear.lua:621-629` (renderer untouched by 06-04/05/06); `spec/tip_spec.lua` ON/OFF cases still pass in the current 124/124 run. |
| 5 | SC-5: The "Display:" label no longer overlaps the Bar button in either mode | ✓ VERIFIED (source + UAT pass) | `grep -n 'modeText\|Display: ' Duncedmaxxing/Options.lua` returns zero hits. `HighlightModeButton` (`Options.lua:472-490`) wired into `Refresh` (520-523). UAT test 4 explicitly passed ("result: pass" — `06-UAT.md`) and was not touched by the gap-closure plans, so no regression risk. |
| 6 | SC-6: A fresh/legacy DB loads cleanly — new color/toggle fields default correctly with no settings wipe and no Lua error | ✗ FAILED (confirmed regression, BLOCKER) | Reproduced directly: a simulated legacy DB on the v1.0.0-shipped `settingsMigration = "0.3.2-fontfix"` token, with realistic non-default customizations (`displayMode="number"`, `hideWhenEmpty=true`, `width=400`, `borderSize=3`, `numberFontSize=40`, custom `fillColor`/`textColor`, `colorByStack=false`), loses every one of those customizations after `MergeDefaults`+`NormalizeDB` — only `x`, `y`, `scale` (and `optionsX`/`optionsY`) survive. Independently flagged as a BLOCKER by `06-REVIEW.md` (CR-01). See Gaps and Behavioral Spot-Checks. |
| 7 | SC-7: The test suite passes via the fengari harness, with new coverage for config-driven stack colors and the color-by-stack toggle fallback | ✓ VERIFIED (test) | `node spec/run.cjs` (fengari-backed) → **124 passed, 0 failed, 124 total**, run directly by this verification. Matches SUMMARY claims. Note: the suite is green despite the SC-6 regression because no existing test exercises a legacy DB with non-position customizations going through the real migration branch (see Gaps → SC-6 → missing). |

**Score:** 4/7 truths verified. 2 truths (SC-1, SC-2) fail only on literal ROADMAP wording due to deliberate, UAT-documented, user-approved deviations that lack a formal override record — not functional defects. 1 truth (SC-6) is a confirmed, reproducible regression that will wipe real users' settings on next login and blocks the phase from passing.

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `Duncedmaxxing/Options.lua` | Scale + Border color reassigned to bar-only group; Enabled checkbox removed; position Reset button + handler removed; layout rebalanced with no dead regions | ✓ VERIFIED | Confirmed by direct read: `AddToGroup("bar", ...)` count for Scale/Border color (lines 315, 373); `grep -c 'GetCfg().enabled = value'` = 0; `grep -c 'tip:ResetPosition'` = 0; `grep -c 'Reset Style'` = 1; window shrunk to `SetSize(386, 400)` (line 211); `LEFT_X`/`RIGHT_X` constants added (lines 15-16); mutually-exclusive bar/number widgets confirmed sharing rows with no runtime overlap (traced every `AddToGroup` + coordinate pair). |
| `Duncedmaxxing/Modules/TipOfTheSpear.lua` | Orphaned `Tip:ResetPosition` removed; render logic otherwise untouched | ✓ VERIFIED | `grep -c 'function Tip:ResetPosition'` = 0. `cfg.colorByStack`/`cfg.stackColors` render path (lines 621-629) unchanged and still test-covered. |
| `Duncedmaxxing/Core.lua` | `DEFAULTS.tip.stackColors` in named-key form; `SETTINGS_MIGRATION` bumped | ✓ VERIFIED (artifact), ✗ side-effect FAILS SC-6 | Named-key conversion at lines 30-35 is correct and matches Options.lua's `ColorToHex` reader — this part of the artifact does what it claims. However, the accompanying `SETTINGS_MIGRATION` bump (line 10) activates the pre-existing blanket-wipe migration branch (lines 75-94) for all real users, which is the direct cause of the SC-6 failure above. The artifact is "complete" but its side effect breaks a roadmap contract truth. |
| `spec/core_spec.lua` | Assertions updated for named-key stackColors + new migration token | ✓ VERIFIED (as far as it goes) | Named-key comparisons present (lines 51-58, 66-71, 253-258); migration-token literals updated. Gap: none of the updated assertions exercise the actual migration branch with non-position customizations present (see SC-6 gap `missing`), so the suite passing does not prove "no wipe." |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `Options.lua` stack/flat color inputs | `Core.lua` DEFAULTS.tip.stackColors | `ColorToHex(GetCfg().stackColors[stack])` reads named `r/g/b/a` keys | ✓ WIRED | Confirmed by hand-computing `ColorToHex` against the new named-key defaults — produces the intended hex strings, closing UAT gap 3. |
| `Options:Refresh` visibility engine | `widgetGroups.bar` / `widgetGroups.number` | `SetWidgetShown` keyed on `cfg.displayMode` | ✓ WIRED | Engine unchanged and correct (`Options.lua:509-518`); only group *membership* changed for Scale/Border color, which is exactly what 06-04 intended. |
| `NormalizeDB` migration branch | `DEFAULTS.tip` | `CopyDefaults(DEFAULTS.tip)` blanket overwrite, restoring only 5 fields | ⚠️ WIRED BUT HARMFUL | This link is technically "wired" (it does re-seed stackColors into named-key form, which was the intent), but the mechanism is untargeted and destroys every other customized field. This is the root cause of the SC-6 failure. |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Full fengari suite passes | `node spec/run.cjs` (fell back to local `node_modules`, no npx needed) | 124 passed, 0 failed, 124 total | ✓ PASS |
| No debt markers in phase-touched files | `grep -n -E "TBD\|FIXME\|XXX\|TODO\|HACK\|PLACEHOLDER" Core.lua Options.lua TipOfTheSpear.lua core_spec.lua tip_spec.lua` | no hits | ✓ PASS |
| No `/dmax mode` subcommand exists | `grep -n "mode" Duncedmaxxing/Core.lua` | 0 hits | ✓ PASS (matches UAT gap 4 resolution) |
| Enabled checkbox setter removed, DB default preserved | `grep -c 'GetCfg().enabled = value' Options.lua` = 0; `grep -c 'enabled = true' Core.lua` = 1 | 0 / 1 | ✓ PASS |
| **Migration-wipe reproduction (verifier-added, ad hoc, not part of the committed suite)** | Constructed a temporary spec (`spec/zzz_migration_check_spec.lua`, added and removed within this verification run only — confirmed via `git status --porcelain spec/` showing no stray files afterward) that runs `MergeDefaults`+`NormalizeDB` against a DB on the shipped `"0.3.2-fontfix"` token with realistic non-default customizations | `displayMode` reverted `"number"` -> `"bar"`; `hideWhenEmpty` reverted `true` -> `false`; `width` reverted `400` -> `247`; `borderSize` reverted `3` -> `1`; `numberFontSize` reverted `40` -> `22`; `fillColor.r` reverted `1` -> `0.72`; `colorByStack` reverted `false` -> `true`. Only `x`/`y`/`scale` survived. | ✗ FAIL — confirms SC-6 regression (CR-01) |
| `git show v1.0.0:Duncedmaxxing/Core.lua` — confirm the pre-bump token is what real users actually have | `grep SETTINGS_MIGRATION` | `"0.3.2-fontfix"` | Confirms the migration branch is guaranteed to fire for every real-world user on next update |

### Requirements Coverage

| Requirement | Source Plan(s) | Description | Status | Evidence |
|-------------|-----------------|--------------|--------|----------|
| DISP-05 | 06-02, 06-04 | Options window gates widget visibility by active display mode | ⚠️ PARTIALLY SATISFIED | Per-mode gating engine correct and improved by gap closure (Scale/Border color now correctly bar-only). Literal "Enabled + Border color show in both modes" sub-clause no longer holds by design (see SC-1 gap) — recommend REQUIREMENTS.md text update or override. No automated test coverage of Options.lua (pre-existing, tracked gap, WR-03 in 06-REVIEW.md). |
| DISP-06 | 06-01, 06-02, 06-03, 06-05 | Per-stack number colors user-configurable, config-driven render, no-wipe default-merge | ✗ BLOCKED (SC-6 failure) | Data layer + render fully test-covered and correct in isolation (stack colors now display correctly, closing UAT gap 3). BUT the "no settings wipe" sub-clause of this requirement is directly violated by the `SETTINGS_MIGRATION` bump adopted to fix the color-display bug — a real regression, not a paperwork gap. |
| DISP-07 | 06-02, 06-04, 06-06 | Mode-selector layout bug fixed | ✓ SATISFIED (source + UAT pass) | Label removal + highlight confirmed and UAT-passed; layout dead-space closed per 06-06 with no widget collisions found by source trace. |

No orphaned requirements: REQUIREMENTS.md maps exactly DISP-05, DISP-06, DISP-07 to Phase 6, and all three appear across the six plans' frontmatter (`06-01`: DISP-06; `06-02`: DISP-05/06/07; `06-03`: DISP-06; `06-04`: DISP-05/07; `06-05`: DISP-06; `06-06`: DISP-07).

### Anti-Patterns Found

None of the standard debt-marker / stub patterns found in phase-touched files (see Behavioral Spot-Checks). The independent code review (`06-REVIEW.md`, `status: issues_found`, 1 critical / 5 warning / 2 info) flagged, and this verification independently confirms:

- **CR-01** (BLOCKER, confirmed above): `SETTINGS_MIGRATION` bump triggers a full-tip wipe for real users. Root gap driving `status: gaps_found`.
- **WR-01** (not a blocker, but worth carrying forward): `cfg.scale` still applies to Number-mode rendering (`TipOfTheSpear.lua:492, 516` — confirmed both branches call `root:SetScale(cfg.scale or 1)` unconditionally), but the Scale control is now hidden whenever Number mode is active (moved to bar-only group per 06-04). A user who sets a non-1.0 scale in Bar mode and switches to Number mode sees the effect but has no way to see or correct it from that mode's UI. Does not fail any stated must-have truth (06-04's must-have only requires Scale to be *hidden* in Number mode, which it is) but is a genuine UX inconsistency worth a follow-up.
- **WR-02** (not a blocker): any returning user whose SavedVariables already has `tip.enabled = false` has no UI path left to re-enable the tracker (checkbox deleted, slash subcommand already gone). Narrow edge case (only affects users who previously disabled the addon), not exercised by this phase's must-haves.
- **WR-03** (pre-existing, not new): `Options.lua` remains untested by the fengari harness — all UI wiring in this phase (including 06-04/05/06's changes) is source-verified only, same category as cycle 1's findings.
- **WR-04, WR-05, IN-01, IN-02**: minor code-quality notes, no functional impact, not blockers.

## Human Verification Required

### 1. Per-mode widget visibility after the gap-closure regrouping

**Test:** Open the options window in Bar mode; confirm Width, Height, Border, Fill, Empty %, and Scale are visible; confirm Text size, Color-by-stack, and the 4 stack-color inputs are hidden. Switch to Number mode; confirm the reverse, AND confirm Border color and Scale are now hidden (not just Text-mode controls appearing). Confirm Position (X/Y), Hide empty are visible in both, and that there is no Enabled checkbox anywhere.
**Expected:** Matches the corrected/updated intent from 06-UAT.md (not the original literal ROADMAP SC-1 wording — see gap above).
**Why human:** `spec/support/init.lua` still skips loading `Options.lua`; no automated test exercises this UI code (WR-03, unchanged from cycle 1).

### 2. Mode switching, button-only

**Test:** Click Bar/Number buttons with the panel open; confirm immediate visibility + highlight update, no Lua error, no window resize (window should now be 386x400, not 386x484). Confirm `/dmax mode bar` / `/dmax mode number` no longer exist as recognized subcommands (typing them should just open the options window like any other `/dmax` invocation, not silently no-op a mode change).
**Expected:** Matches 06-UAT.md's corrected SC-2 intent.
**Why human:** Same test-harness gap as above.

### 3. Stack color editing, toggle, and now-correct defaults

**Test:** Open Number mode on a *fresh* DB (or one already on `"0.3.3-stackcolorfmt"`) and confirm the 4 stack inputs read `ffffff`, `2ecc71`, `fff000`, `ff4c30` (not all `ffffff` as before). Edit each input and the flat Text input to distinct colors; toggle "Color by stack"; confirm in-game number color updates correctly; confirm the inactive picker group visibly greys out.
**Expected:** Matches 06-UAT.md test 3's corrected intent; UAT gap 3 should now be closed.
**Why human:** Options.lua UI write path is source-verified only (this verification confirmed the *default color values* compute correctly via hand-calculation, but did not open the actual in-game panel).

### 4. Options-panel layout — no dead space, both modes

**Test:** Open the panel in Bar mode; confirm no large empty region remains in the upper-right. Switch to Number mode; confirm the left column is compact with no large empty region below the Number-mode controls. Confirm the window is visually smaller (400 tall vs the old 484) and still drags/saves position correctly.
**Expected:** Matches 06-UAT.md test 5's corrected intent.
**Why human:** Visual layout result can only be judged in-game; source trace found no coordinate collisions but cannot confirm subjective "looks balanced."

### 5. Settings-migration data-loss fix (BLOCKING — must be re-verified after CR-01 is fixed)

**Test:** Once CR-01 is addressed, load the addon with a SavedVariables file captured from the v1.0.0 release (or any DB still on `settingsMigration = "0.3.2-fontfix"`) that has non-default customizations (a non-"bar" display mode, custom colors, custom width/height, `colorByStack = false`, etc.). Confirm those customizations survive the load, and confirm the 4 stack-color inputs still display correctly afterward.
**Expected:** No settings wipe — matches ROADMAP SC-6 literally.
**Why human:** Requires an actual persisted SavedVariables snapshot from a real prior session; this verification reproduced the failure with a synthetic equivalent DB via the exposed `DMX._test` harness, which is sufficient to prove the bug but the fix should also be confirmed against a real captured file if one is available.

## Gaps Summary

**Phase 06 does not yet achieve its goal.** Three of the seven ROADMAP success criteria fail as literally worded:

1. **SC-6 (BLOCKER):** The stack-color-defaults fix (06-05) bumped `SETTINGS_MIGRATION`, which triggers `NormalizeDB`'s pre-existing blanket-wipe migration branch. This is not hypothetical — every real user is on the v1.0.0-shipped `"0.3.2-fontfix"` token (confirmed via `git show v1.0.0`), so every one of them will have all `tip.*` customizations beyond position/scale silently reset to defaults on next login. This was independently caught by the phase's own code review (`06-REVIEW.md` CR-01) and independently reproduced by this verification with a synthetic legacy DB. **This must be fixed with a targeted re-seed of only the `stackColors` field (or an equivalent fix that preserves other customizations) before this phase can be considered complete.** A regression test that actually exercises the real migration-branch path with non-position customizations present should be added, since the current suite (124/124 green) does not catch this — the existing "no wipe" test bypasses the migration branch entirely by pre-setting the current token.

2. **SC-1 and SC-2 (paperwork gaps, not functional defects):** Both fail only on literal ROADMAP wording because the user explicitly requested, during UAT, changes that intentionally contradict the original success-criteria text (removing Enabled and slash-command mode switching; moving Border color to bar-only). The implementation correctly reflects what was asked for and re-confirmed in `06-UAT.md`. These should be closed by adding formal `overrides:` entries to this VERIFICATION.md (or updating ROADMAP.md/REQUIREMENTS.md text) rather than by further code changes — see the suggested override blocks below.

All other success criteria (SC-3, SC-4, SC-5, SC-7) are verified, and the four UAT-closure targets (tests 1, 2, 3, 5) are functionally addressed at the source level, pending the human-verification items above.

**This looks intentional (SC-1).** To accept this deviation, add to VERIFICATION.md frontmatter:

```yaml
overrides:
  - must_have: "Position, Enabled, Hide empty, and Border color are visible in both modes"
    reason: "UAT feedback (06-UAT.md test 1-2) explicitly rejected both controls: border color is meaningless for text-mode rendering (no border drawn in Number mode) and the Enabled checkbox was deemed unnecessary entirely. Removed/regrouped exactly as requested."
    accepted_by: "{your name}"
    accepted_at: "{current ISO timestamp}"
```

**This looks intentional (SC-2).** To accept this deviation, add to VERIFICATION.md frontmatter:

```yaml
overrides:
  - must_have: "Switching modes via /dmax mode ... slash command updates widget visibility"
    reason: "UAT feedback (06-UAT.md test 2) explicitly requested button-only mode switching with no slash-command path ('I do not want any slash commands for modes'). The subcommand was already removed prior to this phase; button-driven switching (Options:SetMode) remains fully functional."
    accepted_by: "{your name}"
    accepted_at: "{current ISO timestamp}"
```

---

_Verified: 2026-07-06T21:30:00Z_
_Verifier: Claude (gsd-verifier)_
