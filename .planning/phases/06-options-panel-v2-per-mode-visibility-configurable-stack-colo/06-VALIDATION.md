---
phase: 06
slug: options-panel-v2-per-mode-visibility-configurable-stack-colo
status: validated
nyquist_compliant: false
wave_0_complete: true
created: 2026-07-08
partial: true
requirements:
  DISP-05: manual-only
  DISP-06: covered
  DISP-07: manual-only
---

# Phase 06 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Reconstructed retroactively (State B) by `/gsd-validate-phase 6` on 2026-07-08 during the v1.0 milestone audit.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | busted-style specs on a fengari (Lua-VM-in-JS) harness |
| **Config file** | `spec/run.cjs` (runner) + `spec/support/init.lua` (loader) |
| **Quick run command** | `npx -y -p fengari@0.1.5 node spec/run.cjs` |
| **Full suite command** | `npx -y -p fengari@0.1.5 node spec/run.cjs` |
| **Estimated runtime** | ~3 seconds (125 specs) |

**Harness constraint (material to this phase):** the loader intentionally **skips `Options.lua`** — it loads `Util.lua`, `Core.lua`, `Modules/TipOfTheSpear.lua` only (`spec/support/init.lua:30-33`). No `CreateFrame` widget Show/Hide/SetPoint/SetSize surface is modelled. Consequently the Options-panel UI behaviors (widget-group visibility and layout) cannot be exercised by this harness without a substantial expansion, and are recorded here as manual-only.

---

## Sampling Rate

- **After every task commit:** Run the quick command.
- **After every plan wave:** Run the full suite.
- **Before `/gsd-verify-work`:** Full suite must be green.
- **Max feedback latency:** ~3 seconds.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------------|-----------|-------------------|-------------|--------|
| 06-01 | 01 | 1 | DISP-06 | Number-mode render reads config `stackColors` (config-first, flat `textColor` fallback), not hardcoded `STACK_COLORS` | unit | `npx -y -p fengari@0.1.5 node spec/run.cjs` | ✅ `spec/tip_spec.lua` | ✅ green |
| 06-02 | 02 | 2 | DISP-05, DISP-06, DISP-07 | Per-mode widget gating + colorByStack greying + layout fix | manual | — | ❌ (Options.lua not loaded) | manual-only |
| 06-03 | 03 | 2 | DISP-06 | colorByStack ON/OFF number-color behavior; legacy/fresh DB default-merge no-wipe | unit | `npx -y -p fengari@0.1.5 node spec/run.cjs` | ✅ `spec/tip_spec.lua`, `spec/core_spec.lua` | ✅ green |
| 06-04 | 04 | 1 | DISP-05, DISP-07 | Widget removal (Enabled/Reset), Scale+Border color bar-only, no `/dmax mode` subcommand | manual + structural | — | ❌ (Options.lua UI); no-`mode` confirmed by grep | manual-only |
| 06-05 | 05 | 1 | DISP-06 | `DEFAULTS.tip.stackColors` named-key form + migration token bump surfaces real picker defaults | unit | `npx -y -p fengari@0.1.5 node spec/run.cjs` | ✅ `spec/core_spec.lua` | ✅ green |
| 06-06 | 06 | 2 | DISP-07 | Options panel layout rebalance / window height 484→400 | manual (visual) | — | ❌ | manual-only |
| 06-07 | 07 | 1 | DISP-06 | `NormalizeDB` migration re-seeds only `stackColors` (no blanket tip-wipe); regression on old `0.3.2-fontfix` token | unit | `npx -y -p fengari@0.1.5 node spec/run.cjs` | ✅ `spec/core_spec.lua` | ✅ green |
| 06-08 | 08 | 1 | DISP-05, DISP-07 | Paperwork-only: formal override records + ROADMAP/REQUIREMENTS alignment | docs (no code) | — | N/A | N/A |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all automatable phase requirements. DISP-06 is fully covered by the pre-existing `spec/tip_spec.lua` and `spec/core_spec.lua` describe blocks (per-stack color read, colorByStack ON/OFF fallback, format-agnostic ColorTuple, MergeDefaults→NormalizeDB no-wipe, and the `0.3.2-fontfix` legacy-token migration regression). No new Wave 0 test files were required.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Per-mode widget visibility: Bar mode shows Width/Height/Border size/Fill/Empty %/Scale/Border color and hides Text size + stack-color controls; Number mode is the inverse; Position + Hide empty in both | DISP-05 | Logic lives in `Options:Refresh`/`Options:SetMode` inside `Options.lua`, which the fengari loader deliberately skips; no widget Show/Hide surface is stubbed | In-game: `/dmax` to open the panel; toggle Bar↔Number via the mode buttons; confirm the correct control set shows/hides with no Lua error and no combat-lockdown violation. (06-UAT tests 1–2: PASS) |
| colorByStack toggle greys/enables the flat Text color picker vs the 4 per-stack pickers | DISP-05/DISP-06 (UI side) | Widget enable/disable state in `Options.lua` (skipped by harness). The underlying color *selection* logic is covered automatically by tip_spec. | In-game: toggle "Color by stack" on/off; confirm the flat picker greys when ON and the 4 stack pickers grey when OFF. (06-UAT: PASS) |
| Mode-selector layout: "Display:" label removed, active mode button highlighted, window stays fixed size on mode switch (no reflow / no overlap) | DISP-07 | Pure visual layout (pixel positions, highlight appearance, window height 400) in `Options.lua`; not meaningfully assertable even if the file were loaded | In-game: open panel in both modes; confirm no label/Bar-button overlap, active button highlighted, window does not resize. (06-UAT test 1: PASS) |

---

## Validation Sign-Off

- [x] All automatable tasks have automated verify; UI-only tasks recorded as manual-only with human-UAT evidence
- [x] Sampling continuity: no 3 consecutive tasks without automated verify (DISP-06 tasks are green across waves)
- [x] Wave 0 covers all MISSING references (none required — existing suite covers DISP-06)
- [x] No watch-mode flags
- [x] Feedback latency < 5s (~3s)
- [ ] `nyquist_compliant: true` — **not set.** DISP-05 and DISP-07 are manual-only (Options.lua UI/layout, outside the fengari harness). Verified by human 06-UAT tests 1–2. Full automation deferred as disproportionate for a 2-user addon.

**Approval:** partial — validated 2026-07-08 (DISP-06 automated & green; DISP-05/DISP-07 manual-only, human-UAT confirmed)
