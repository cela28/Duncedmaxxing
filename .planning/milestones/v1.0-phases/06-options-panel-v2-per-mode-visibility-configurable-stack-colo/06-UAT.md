---
status: complete
phase: 06-options-panel-v2-per-mode-visibility-configurable-stack-colo
source: [06-VERIFICATION.md]
started: 2026-07-08T00:00:00Z
updated: 2026-07-08T12:15:00Z
---

## Current Test

[testing complete]

## Tests

### 1. Per-mode widget visibility and button-only mode switching (SC-1 / SC-2 / DISP-05)
expected: Bar mode shows Width/Height/Border size/Fill/Empty %/Scale/Border color and hides Text size + stack-color controls; Number mode shows Text size + stack-color controls and hides Bar-only controls incl. Border color and Scale; Position and Hide empty in both; no Enabled checkbox, no position Reset button, no Reset Style button; `/dmax` and `/duncedmaxxing` only open options (no sub-commands — `/dmax mode bar` does not switch mode). Matches ROADMAP SC-1/SC-2 as updated by 06-08 (accepted overrides).
result: pass

### 2. Stack color editing, toggle, and default display (SC-3 / SC-4 / DISP-06)
expected: On a migrated/fresh DB the 4 stack inputs read ffffff, 2ecc71, fff000, ff4c30. Editing each stack input and the flat Text input to distinct colors, and toggling "Color by stack" on/off, updates the in-game number color to match; the inactive color group visibly greys out (SetAlpha ~0.4).
result: pass

### 3. Options-panel layout — no dead space, both modes (SC-5 / DISP-07)
expected: No large empty region in upper-right in Bar mode; compact layout in Number mode; window is 386x370 (shrunk from 386x400 after removing Reset Style row) and still drags/saves position correctly.
result: pass
note: 06-UAT re-run — Reset Style button removed and window shrunk 386x400 → 386x370 per user request (2026-07-08).

### 4. Settings-migration fix vs a real captured SavedVariables file (SC-6) — OPTIONAL, non-blocking
expected: If a real SavedVariables file still on settingsMigration = "0.3.2-fontfix" is available, loading it preserves all customized tip.* fields and the 4 stack-color inputs show the recovered/expected colors. Nice-to-have only — SC-6 is already VERIFIED via the automated regression test (spec/core_spec.lua:166-243, 125/125). Skipping this does not block phase completion.
result: pass

## Summary

total: 4
passed: 4
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps
