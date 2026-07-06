---
status: diagnosed
phase: 06-options-panel-v2-per-mode-visibility-configurable-stack-colo
source: [06-VERIFICATION.md]
started: 2026-07-02T00:00:00Z
updated: 2026-07-06T00:00:00Z
---

## Current Test

[testing complete]

## Tests

### 1. Per-mode widget visibility (Bar vs Number)
expected: In Bar mode, Bar-only controls (Width, Height, Border size, Fill, Empty %) are visible and Number-only controls (Text size, "Color by stack" checkbox, 4 per-stack color inputs, flat Text color input) are hidden; in Number mode the reverse holds; shared controls (Position X/Y/Scale, Enabled, Hide empty, Border color) show in both. (SC-1 / DISP-05)
result: issue
reported: "We do not need border color for text or scale"
severity: minor

### 2. Mode switching via buttons and slash command
expected: Clicking the Bar/Number buttons AND running `/dmax mode bar` / `/dmax mode number` with the panel open both refresh widget visibility and the active-button highlight immediately, with no Lua error and no window resize (window stays 386x484). (SC-2 / DISP-05 / DISP-07)
result: issue
reported: "do not need enabled checkbox at all - also we asked for the reset button to be removed; I do not want any slash commands for modes"
severity: major

### 3. Stack color editing and toggle behavior
expected: In Number mode, editing each of the 4 per-stack color hex inputs and the flat Text color input to distinct colors changes the in-game number color to match the intended source — per-stack colors when "Color by stack" is ON, the flat Text color when OFF. The inactive color group visibly greys out (dimmed, SetAlpha ~0.4) while the active group stays fully opaque. (SC-3 / SC-4 UI half / DISP-06)
result: issue
reported: "the defaults look like this which seems inaccurate [screenshot: Border 000000, Text ffffff (greyed), 0 stacks ffffff, 1 stack ffffff, 2 stacks ffffff, 3 stacks ffffff]"
severity: major

### 4. Display label removal and mode-button highlight
expected: No "Display:" text label appears anywhere in the window (in either mode) and it does not overlap the Bar button; the currently active mode button (Bar or Number) is visually distinguishable (locked highlight / full alpha) from the inactive button. (SC-5 / DISP-07)
result: pass

### 5. Options panel layout / empty space organization
expected: Panel real estate is used efficiently — no large dead gaps (e.g. the empty upper-right area beside Position in Bar mode), columns balanced, sections evenly spaced across both modes.
result: issue
reported: "organize empty space better too [screenshots: Bar mode has large empty region upper-right next to Position; overall layout has uneven gaps]"
severity: cosmetic

## Summary

total: 5
passed: 1
issues: 4
pending: 0
skipped: 0
blocked: 0

## Gaps

- truth: "In Number (text) mode, only text-relevant controls show; Border color and Scale should be hidden because text has no border and uses Text size for sizing"
  status: failed
  reason: "User reported: We do not need border color for text or scale"
  severity: minor
  test: 1
  root_cause: "Scale input and Border color input are assigned to the 'both' visibility group, so Options:Refresh() shows them in every mode. The Refresh show/hide engine (both/bar/number) is correct; the widgets are just in the wrong group."
  artifacts:
    - path: "Duncedmaxxing/Options.lua"
      issue: "Scale input added via AddToGroup('both', ...) at line 303; Border color input added via AddToGroup('both', ...) at line 363. Refresh engine at 505-514 is correct."
  missing:
    - "Move Scale (Options.lua:303) from group 'both' to 'bar'"
    - "Move Border color (Options.lua:363) from group 'both' to 'bar'"
    - "Rebalance the shared Position section (Scale leaving it) — couples with layout gap"
  debug_session: ""

- truth: "The Enabled checkbox is not wanted and should be removed from the options panel entirely"
  status: failed
  reason: "User reported: do not need enabled checkbox at all"
  severity: minor
  test: 2
  root_cause: "The Enabled checkbox widget exists and binds to tip.enabled, which has a live downstream reader in TipOfTheSpear.lua:595 (shouldShow gate). The widget can be deleted but the DB field must remain (default true)."
  artifacts:
    - path: "Duncedmaxxing/Options.lua"
      issue: "Enabled checkbox created at lines 266-269 (CreateCheckbox, group 'both')"
    - path: "Duncedmaxxing/Modules/TipOfTheSpear.lua"
      issue: "Line 595 reads cfg.enabled in shouldShow gate — only consumer"
  missing:
    - "Delete the Enabled checkbox widget block (Options.lua:266-269)"
    - "Keep DEFAULTS.tip.enabled = true in Core.lua:15 so TipOfTheSpear.lua:595 stays satisfied"
    - "Reclaim the vacated y=-80 row — couples with layout gap"
  debug_session: ""

- truth: "The Reset button should be removed from the options panel (previously requested, not yet done)"
  status: failed
  reason: "User reported: we asked for the reset button to be removed"
  severity: major
  test: 2
  root_cause: "Two reset buttons exist: 'Reset' (position reset, calls Tip:ResetPosition) and 'Reset Style'. User wants the position 'Reset' removed; 'Reset Style' stays. The Reset button is the only caller of Tip:ResetPosition, which becomes dead code."
  artifacts:
    - path: "Duncedmaxxing/Options.lua"
      issue: "'Reset' button at lines 424-429 (handler calls tip:ResetPosition). 'Reset Style' at 430-434 stays."
    - path: "Duncedmaxxing/Modules/TipOfTheSpear.lua"
      issue: "Tip:ResetPosition() at line 551 — only caller is the Reset button; becomes orphaned"
  missing:
    - "Delete the 'Reset' button block (Options.lua:424-429)"
    - "Optionally remove now-orphaned Tip:ResetPosition() (TipOfTheSpear.lua:551)"
    - "Close the gap in the button row at y=-414 — couples with layout gap"
  debug_session: ""

- truth: "Mode switching should be button-only; the /dmax mode bar|number slash commands should be removed entirely"
  status: resolved
  reason: "User reported: I do not want any slash commands for modes"
  severity: major
  test: 2
  root_cause: "ALREADY RESOLVED — no code change needed. The /dmax mode bar|number commands and PrintHelp were removed in prior commit 53b1c42. The current slash handler (Core.lua:182-193) is argument-less and only opens the options window. Button-only mode switching (Options:SetMode) is intact and independent."
  artifacts:
    - path: "Duncedmaxxing/Core.lua"
      issue: "Slash handler at 182-193 is already argument-less; no mode subcommand, no PrintHelp"
  missing:
    - "No code change required — gap already satisfied"
    - "OPTIONAL/NEW (not required): /dmax mode bar currently silently opens options rather than erroring; only address if user wants explicit rejection"
  debug_session: ""

- truth: "The per-stack color inputs should display the actual default colors (0=white, 1=green, 2=yellow, 3=red per Core.lua DEFAULTS.stackColors); instead all four render as ffffff"
  status: failed
  reason: "User reported: the defaults look like this which seems inaccurate (all 4 stack inputs show ffffff)"
  severity: major
  test: 3
  root_cause: "Format mismatch. ColorToHex (Options.lua:20-32) reads named keys color.r/.g/.b/.a, but DEFAULTS.tip.stackColors (Core.lua:30-35) are positional arrays {r,g,b,a}=[1..4]. Named keys are nil, ToByte(nil) falls back to 1.0 -> 'ff', so every stack input shows ffffff. Flat colors (fillColor/borderColor/textColor) use named keys and display correctly, confirming the mismatch. ParseHexColor writes named keys, so an edited stack color then displays correctly (defaults-only bug + inconsistent stored format). Renderer is safe: ColorTuple (TipOfTheSpear.lua:137-145) handles both formats."
  artifacts:
    - path: "Duncedmaxxing/Options.lua"
      issue: "ColorToHex at 20-32 (named-key reader); ToByte at 15-18 (nil->255); stack getValue ColorToHex(...) at 397; setValue ParseHexColor writes named at 399-401"
    - path: "Duncedmaxxing/Core.lua"
      issue: "DEFAULTS.tip.stackColors positional at 30-35 (compare named flat colors at 25-28); SETTINGS_MIGRATION at line 10"
    - path: "Duncedmaxxing/Util.lua"
      issue: "ParseHexColor at 27-38 returns named-key tables (the writer format)"
    - path: "Duncedmaxxing/Modules/TipOfTheSpear.lua"
      issue: "ColorTuple 137-145 + STACK_COLORS fallback 33-38 are format-agnostic; a fix must not break them"
  missing:
    - "Standardize DEFAULTS.tip.stackColors (Core.lua:30-35) to named-key form { r=, g=, b=, a= } per stack"
    - "Bump SETTINGS_MIGRATION (Core.lua:10) so NormalizeDB re-seeds existing persisted positional stackColors, else saved DBs still show ffffff"
    - "Optional: convert STACK_COLORS fallback (TipOfTheSpear.lua:33-38) to named form for consistency (not required — ColorTuple handles both)"
  debug_session: ""

- truth: "Options panel uses its space efficiently with no large dead gaps and balanced columns in both modes"
  status: failed
  reason: "User reported: organize empty space better too (Bar mode shows a large empty region upper-right beside Position; uneven section spacing)"
  severity: cosmetic
  test: 5
  root_cause: "Layout is fully absolute-positioned in a fixed two-column grid (left x=16, right x=204) inside a fixed 386x484 window. In Bar mode the right column's top block (Number section, group 'number') is hidden, leaving y=-120..-238 on the right empty — the reported dead region beside Position. Section spacing is also uneven. Must be rebalanced AFTER gaps 1-3 land since final coordinates depend on which widgets remain."
  artifacts:
    - path: "Duncedmaxxing/Options.lua"
      issue: "window:SetSize(386,484) at line 204; all controls absolute-positioned via SetPoint (left col x=16, right col x=204); Bar-mode right column top y=-120..-238 empty"
  missing:
    - "Execute LAST, after gaps 1-3 vacate/free grid slots"
    - "Rebalance columns/rows so Bar-mode right-column top space is used; consider shrinking window height (Options.lua:204)"
    - "Consider extracting row/column offset constants to make absolute positioning maintainable"
  debug_session: ""
