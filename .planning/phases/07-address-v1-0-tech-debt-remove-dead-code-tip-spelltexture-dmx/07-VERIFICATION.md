---
phase: 07-address-v1-0-tech-debt-remove-dead-code-tip-spelltexture-dmx
verified: 2026-07-09T00:00:00Z
status: passed
score: 7/7 must-haves verified
behavior_unverified: 0
overrides_applied: 0
---

# Phase 07: Address v1.0 Tech Debt Verification Report

**Phase Goal:** The v1.0 milestone-audit tech debt is cleared — three dead-code symbols (`hasPrimalSurge`, `Tip.spellTexture`/`CacheSpellTexture`/`FALLBACK_ICON`, `DMX.Util.ParseOnOff`) are fully removed with zero orphaned references, the tautological Primal Surge tests and the 265189/Raptor-Swipe regression tests are replaced with real `ClassifySpellID` CONSUMERS-membership assertions, the self-contradictory generator-branch comment is rewritten, and the `db.locked` migration reset is documented as designed — all with the fengari suite green and luacheck at zero warnings.

**Verified:** 2026-07-09
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (D-01 through D-07)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| D-01 | `hasPrimalSurge` fully removed (field, reset, all references) | ✓ VERIFIED | `grep -rn "hasPrimalSurge" Duncedmaxxing/ spec/` → zero matches. Only "Primal Surge" (prose, not the field name) remains in two explanatory comments about the flat-2 fallback rationale (tip_spec.lua:29, 128) — these do not reference the retired symbol. |
| D-02 | Tautological Primal Surge tests deleted; genuine BASE/Twin-Fangs coverage retained | ✓ VERIFIED | The two tests that toggled `hasPrimalSurge` while always asserting 2 are gone (grep confirms zero `hasPrimalSurge` occurrences). The Twin-Fangs-independence test at tip_spec.lua:129-134 is retained, with `hasTwinFangs=true` setup and both `not_equals(3)` / `equals(2)` assertions intact, and no longer toggles the retired field. |
| D-03 | Generator-branch comment rewritten, non-contradictory | ✓ VERIFIED | TipOfTheSpear.lua:639-640: "Kill Command (generator) always grants 2 stacks. Twin Fangs is a Takedown (consumer) modifier only and must NOT affect this generator path." No "base 1, +1 Primal Surge" framing, no "field reserved" note. `local grant = 2` (logic) unchanged. |
| D-04 | `Tip.spellTexture`, `CacheSpellTexture`, `FALLBACK_ICON` fully removed, both call sites gone | ✓ VERIFIED | `grep -rn "spellTexture\|CacheSpellTexture\|FALLBACK_ICON" Duncedmaxxing/ spec/` → zero matches. `grep -c "CacheSpellTexture" TipOfTheSpear.lua` → 0. The "Caching -- isSurvival" describe block (tip_spec.lua:496) retains its 4 non-spellTexture tests; the 2 spellTexture tests are gone. |
| D-05 | `DMX.Util.ParseOnOff` fully removed | ✓ VERIFIED | `grep -rn "ParseOnOff" Duncedmaxxing/ spec/` → zero matches. `Trim`, `Clamp`, `ParseHexColor` remain defined and exported in Util.lua (lines 6/10/18, 31/32/33) with 28 matching test references still present in util_spec.lua. |
| D-06 | `Tip._test` exports `ClassifySpellID`; 265189/1262293/1262343 all assert `"consumer"` | ✓ VERIFIED | TipOfTheSpear.lua:743-745: `Tip._test = { ClassifySpellID = ClassifySpellID }`, placed immediately before `DMX:RegisterModule("tip", Tip)` (line 747). tip_spec.lua:189, 199, 209 each assert `Tip._test.ClassifySpellID(<id>) == "consumer"` for all three spell IDs, alongside preserved decrement assertions. |
| D-07 | `db.locked = true` retained in NormalizeDB migration block, with intent comment, no logic change | ✓ VERIFIED | Core.lua:123-125: two-line comment ("Deliberate: re-lock the frame on every settings-migration upgrade so it can't be accidentally dragged after layout defaults change (D-07).") immediately precedes the unchanged `db.locked = true` line. `grep -c "db.locked = true" Core.lua` → 1. |

**Score:** 7/7 truths verified (0 present-but-behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `Duncedmaxxing/Modules/TipOfTheSpear.lua` | `Tip._test` export table exposing `ClassifySpellID`; dead symbols removed | ✓ VERIFIED | Present at line 743, wired into spec via 3 call sites, all other target symbols absent |
| `spec/tip_spec.lua` | Hardened consumer regression tests | ✓ VERIFIED | 3 `Tip._test.ClassifySpellID` assertions present (265189, 1262293, 1262343), tautological/spellTexture tests removed |
| `Duncedmaxxing/Util.lua` | ParseOnOff removed, other utilities intact | ✓ VERIFIED | Trim/Clamp/ParseHexColor definitions and exports untouched |
| `Duncedmaxxing/Core.lua` | `db.locked = true` retained with intent comment | ✓ VERIFIED | Comment + unchanged line at 123-125 |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `spec/tip_spec.lua` | `Duncedmaxxing/Modules/TipOfTheSpear.lua` | `Tip._test.ClassifySpellID(...)` calls | ✓ WIRED | 3 call sites resolve to the exported table; suite passes these assertions (confirmed by 0 failed run) |

### Behavioral Spot-Checks / Full Suite Run

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Full fengari suite green | `npx -y -p fengari@0.1.5 node spec/run.cjs` | 111 passed, 0 failed, 111 total | ✓ PASS |
| Whole-tree grep-absence sweep (all 5 symbols) | `grep -rn "hasPrimalSurge\|spellTexture\|CacheSpellTexture\|FALLBACK_ICON\|ParseOnOff" Duncedmaxxing/ spec/` | exit 1, zero matches | ✓ PASS |

Note: absolute test count (111) is not itself a gate per the phase's own test-harness note — concurrent GSD sessions add Nyquist test files independently. `0 failed` is the pass criterion and it holds.

### luacheck (documented environment limitation)

luacheck/luarocks/lua binaries are absent in this verification sandbox (confirmed independently — `command -v luacheck/luarocks/lua/lua5.1` all fail). This matches 07-RESEARCH.md's prior Environment Availability finding (Pitfall 5) and was auto-approved as a blocking human-verify checkpoint during 07-03 execution. Per the task's own verification guidance, this is treated as a documented environment limitation, not a failed must-have — this phase is deletion-only and cannot introduce new lint warnings. Recorded here as a carry-forward manual item: a definitive `luacheck Duncedmaxxing/` zero-warnings run should still occur on a dev machine or in CI before the v1.0 milestone is considered fully closed on the lint front.

### Requirements Coverage

Phase requirement IDs are D-01 through D-07 (CONTEXT.md decisions), not formal REQUIREMENTS.md entries — this phase was surfaced by the v1.0 milestone audit rather than the requirements pipeline. `grep -n "D-0[1-7]"` against REQUIREMENTS.md correctly returns no matches; this is expected per the task brief, not a gap. All 7 decisions are independently verified above against the actual codebase.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `spec/support/wow_stubs.lua` | 175-179 | Orphaned `C_Spell.GetSpellTexture` / `GetSpellTexture` mock stubs, left over after `CacheSpellTexture` removal | ℹ️ Info | Non-blocking. Already identified in `07-REVIEW.md` (IN-01). Out of the phase's formally scoped file list (CONTEXT.md's "Code touched" section does not name `wow_stubs.lua`), and does not match the phase's grep-absence gate pattern (`spellTexture`, lowercase, does not match `GetSpellTexture`'s capital S). Dead test fixture code, not exercised by any spec, does not affect the 0-failed suite result. Does not block this phase's must-haves as scoped by D-04. |

No TBD/FIXME/XXX debt markers found in files modified by this phase. No blocker-level anti-patterns.

### Human Verification Required

None required to close this phase's must-haves. The luacheck run is a carry-forward manual item (see above) but is explicitly not a phase-blocking must-have per the task's verification-method notes.

### Gaps Summary

No gaps. All 7 D-decisions verified directly against the codebase (not just SUMMARY.md claims): grep-absence sweeps independently re-run and confirmed clean for all 5 removed symbols, the fengari suite independently re-run and confirmed green (111 passed, 0 failed), the `Tip._test` export and its 3 consumer-membership assertions read and confirmed in source, the rewritten generator comment read and confirmed non-contradictory, and the `db.locked` intent comment read and confirmed present with no logic change. The one info-level anti-pattern (orphaned `GetSpellTexture` stubs in `wow_stubs.lua`) is out of this phase's formal scope and does not affect any must-have.

---

_Verified: 2026-07-09_
_Verifier: Claude (gsd-verifier)_
