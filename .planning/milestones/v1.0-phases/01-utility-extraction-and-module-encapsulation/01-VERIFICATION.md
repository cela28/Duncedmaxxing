---
phase: 01-utility-extraction-and-module-encapsulation
verified: 2026-06-22T00:00:00Z
status: passed
score: 7/9 must-haves verified (2 runtime items later confirmed in-game)
behavior_unverified: 0
overrides_applied: 0
human_resolved: 2026-06-23
human_resolved_by: cela28
human_resolved_via: "01-HUMAN-UAT.md — full-milestone smoke test (7 passed, 1 skipped, 0 issues)"
human_resolved_note: >
  The 2 behavior-unverified runtime items were confirmed in-game and the phase
  is now marked passed. Kill Command with Twin Fangs shows the correct flat-2
  grant with no transient over-count (smoke Test 2); predictive spender
  decrement is instant (smoke Test 4); the addon loads with no Lua errors
  (smoke Test 1, SC-5). The Aspect-of-the-Eagle Raptor Strike / Raptor Swipe
  spell IDs (265189, 1262343, 1262293) were registered as consumers (plan
  01-04, quick 260622-tyy, Phase 7 tests) and accepted by the author; residual
  patch-12.0.5 spell-ID confirmation is an accepted low-risk item.
re_verification:
  previous_status: human_needed
  previous_score: 4/5
  gaps_closed:
    - "SC-5: In-game load verification (reported as UAT pass; Test 1, 2, 4, 5 all passed)"
    - "Gap 1 structural: old hasTwinFangs-based generator formula removed; hasPrimalSurge field added; stale generator tests removed"
    - "Gap 2 structural: 265189 registered in CONSUMERS table; regression test added"
  gaps_remaining: []
  regressions: []
behavior_unverified_items:
  - truth: "Kill Command raises displayed stack count to its correct final value with no transient over-count"
    test: "Cast Kill Command in-game with hasTwinFangs active (Twin Fangs talented)"
    expected: "Stack display goes directly to 2, never shows 3 transiently"
    why_human: "Predictive display, aura timing, and SyncFromAura correction only exercise in the live WoW client; no standalone Lua executor; grep confirms the over-predict formula is gone but cannot simulate the UNIT_SPELLCAST_SUCCEEDED -> ApplySpell -> SyncFromAura ordering at runtime"
  - truth: "With Aspect of the Eagle active, casting Raptor Strike decrements the stack display instantly"
    test: "Cast Raptor Strike with Aspect of the Eagle buff active in-game; also verify only one stack is consumed per press (no double-decrement)"
    expected: "Stack display decrements immediately on cast, no observable lag. Stack decrements by exactly 1 (not 2)."
    why_human: "Instant-vs-deferred decrement timing is a runtime property; cannot be observed by static analysis. Double-decrement risk (265189 + 186270 both in CONSUMERS) requires in-game confirmation that the WoW client does not emit two separate UNIT_SPELLCAST_SUCCEEDED events for one Raptor Strike press under Aspect of the Eagle."
human_verification:
  - test: "UAT Test 3 re-test — Kill Command with Twin Fangs"
    expected: "Casting Kill Command raises stacks to the correct value (2) with no transient 3 visible. The old formula 'self.hasTwinFangs and 3 or 2' has been replaced by a flat-2 grant, so the generator path can no longer over-predict. Confirm no flicker."
    why_human: "Runtime behavior — display timing and SyncFromAura ordering not verifiable offline"
  - test: "UAT Test 6 re-test — Raptor Strike with Aspect of the Eagle"
    expected: "Stack display decrements instantly when Raptor Strike is cast while Aspect of the Eagle is active. No visible lag compared to casting without Aspect of the Eagle."
    why_human: "Runtime timing — instant-vs-deferred decrement only observable in-game"
  - test: "Spell ID 265189 validity for patch 12.0.5"
    expected: "265189 is the correct UNIT_SPELLCAST_SUCCEEDED spell ID for Raptor Strike under Aspect of the Eagle in the current patch. If the ID is wrong, the lag will persist. Use /etrace to verify the emitted ID matches 265189 on a live cast."
    why_human: "Spell ID was captured via in-game /etrace by the user during diagnosis but was selected from historical lineage (259271 / 265189); patch 12.0.5 correctness cannot be confirmed without the game client"
  - test: "No double-decrement on Raptor Strike with Aspect of the Eagle"
    expected: "One Raptor Strike press with Aspect of the Eagle active decrements the stack display by exactly 1. Both 186270 and 265189 are now in CONSUMERS; if the WoW client emits both IDs for one logical cast, the stack would decrement twice."
    why_human: "Multi-event emission behavior is client-specific and cannot be observed offline"
  - test: "In-game load verification (SC-5 — originally from initial verification)"
    expected: "No Lua errors in chat after /reload ui. Tracker frame renders correctly. Stack count updates on Kill Command cast."
    why_human: "WoW Lua sandbox cannot be replicated outside the client"
---

# Phase 01: Utility Extraction and Module Encapsulation — Verification Report (Re-verification)

**Phase Goal:** The codebase has a clean structural foundation — shared utilities live in one place, frame references are accessible for testing, and module iteration is ordered.
**Verified:** 2026-06-22T00:00:00Z
**Status:** passed (2 runtime items confirmed in-game via 01-HUMAN-UAT.md, 2026-06-23)
**Re-verification:** Yes — gap-closure plans 01-03 (Kill Command stack-overshoot) and 01-04 (Raptor Strike + Aspect of the Eagle lag) added since initial verification.

---

## Scope of This Re-Verification

This re-verification focuses on the two UAT gaps closed by plans 01-03 and 01-04. The four original structural must-haves (SC-1 through SC-4) were VERIFIED in the initial pass and are confirmed not regressed. SC-5 (in-game load) is carried forward as a human verification item. The new must-haves are the nine observable truths below, which replace the prior 4/5 score with a 7/9 score covering both the original SCs and the gap-closure truths.

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| SC-1 | `DMX.Util.Clamp`, `DMX.Util.ParseHexColor`, `DMX.Util.Trim`, `DMX.Util.ParseOnOff` exist; no duplicate definitions remain in Core.lua or Options.lua | ✓ VERIFIED | Carried from initial verification; gap-closure plans did not touch Util.lua or Core.lua |
| SC-2 | All five frame references accessible as `Tip.root`, `Tip.pips`, etc.; no bare upvalue references in TipOfTheSpear.lua function bodies | ✓ VERIFIED | Carried from initial verification; gap-closure changes are limited to CONSUMERS table, ApplySpell generator grant, and field initializers |
| SC-3 | `ForEachModule` iterates in `moduleOrder` registration order, not arbitrary hash order | ✓ VERIFIED | Carried from initial verification; Core.lua untouched by gap-closure plans |
| SC-4 | `ClassifySpellID` performs a plain table lookup with no `pcall` wrapper | ✓ VERIFIED | Carried from initial verification; ClassifySpellID body unchanged by gap-closure plans |
| SC-5 | `/reload ui` produces no Lua errors and tracker display functions normally | ? UNCERTAIN | Requires in-game execution; UAT Tests 1, 2, 4, 5 passed in 01-UAT.md but the runtime check must still be confirmed after gap-closure changes |
| GAP-1a | The Kill Command (generator) stack grant is independent of the Twin Fangs talent flag | ✓ VERIFIED | `hasTwinFangs and 3 or 2` is completely absent from TipOfTheSpear.lua (grep count = 0). Generator branch at line 700 is `local grant = 2`. `self.hasTwinFangs` not referenced anywhere in the generator path. |
| GAP-1b | `hasPrimalSurge` detection field/helper present in TipOfTheSpear.lua | ✓ VERIFIED (with WARNING) | `Tip.hasPrimalSurge = false` at line 57; present in spec/tip_spec.lua and spec/support/init.lua. However: the field is initialized and reset but NEVER read by ApplySpell and NEVER set to true by any event handler — it is dead state. Unlike `hasTwinFangs` (refreshed at lines 746, 753, 782 on talent/spec events), `hasPrimalSurge` has no event-driven updater. The three Primal Surge tests in spec/tip_spec.lua (lines 139-151) are tautological: they vary `hasPrimalSurge` but all assert 2 regardless, because the code ignores the field. The genuinely protective test is at line 130 (`assert.not_equals(3, Tip.stacks)` with `hasTwinFangs=true`). |
| GAP-1c | Twin Fangs affects ONLY the Takedown consumer path | ✓ VERIFIED | Takedown+TwinFangs branch at line 704 (`if spellID == TAKEDOWN and self.hasTwinFangs then`) is intact and unchanged. Generator path has zero references to `self.hasTwinFangs`. |
| GAP-1d | Kill Command raises displayed stack count to correct value with no transient over-count | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | Code structure is correct (formula removed, flat-2 grant). Runtime behavior — no visible flicker — requires in-game UAT Test 3 re-test. |
| GAP-2a | Spell ID 265189 registered in CONSUMERS table, classifies as consumer | ✓ VERIFIED | Line 25: `[265189] = true, -- Raptor Strike (Aspect of the Eagle ranged variant)`. Node table-scope check confirms 265189 is inside the `local CONSUMERS = { ... }` block. `ClassifySpellID` at line 72 uses `CONSUMERS[value]` lookup, so 265189 will return `"consumer"`. |
| GAP-2b | With Aspect of the Eagle active, casting Raptor Strike decrements the stack display instantly | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | 265189 is in CONSUMERS; the code path to instant decrement is now wired. Runtime instantness and absence of lag require in-game UAT Test 6 re-test. Spell ID correctness for patch 12.0.5 also requires in-game confirmation. |

**Score:** 7/9 truths verified (2 present, behavior-unverified; 1 uncertain)

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `Duncedmaxxing/Modules/TipOfTheSpear.lua` | Generator grant decoupled from hasTwinFangs; 265189 in CONSUMERS; hasPrimalSurge field | ✓ VERIFIED | Line 700: `local grant = 2` (no hasTwinFangs ref); line 25: `[265189] = true`; line 57: `Tip.hasPrimalSurge = false` |
| `spec/tip_spec.lua` | hasPrimalSurge tests present; 265189 regression test present; stale Twin-Fangs-generator tests removed | ✓ VERIFIED (with WARNING) | hasPrimalSurge appears at lines 31, 120, 132, 140, 147; 265189 regression test at lines 198-202; zero hits for removed stale tests. WARNING: 265189 test bypasses ClassifySpellID dispatch (WR-03 — see Anti-Patterns). |
| `spec/support/init.lua` | `resetTipState` zeros hasPrimalSurge | ✓ VERIFIED | Line 62: `Tip.hasPrimalSurge = false` |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `ApplySpell generator branch` | `flat grant = 2` | `local grant = 2` (line 700) | ✓ WIRED | hasTwinFangs not referenced in generator path |
| `CONSUMERS table` | `ClassifySpellID` | `CONSUMERS[value]` at line 72 | ✓ WIRED | 265189 entry at line 25 causes ClassifySpellID to return "consumer" |
| `ClassifySpellID` | `FindTrackedSpell` → `OnEvent` → `ApplySpell` | `kind, spellID = FindTrackedSpell(...)` at line 765 | ✓ WIRED | Full event dispatch chain intact and unmodified |
| `hasPrimalSurge field` | `ApplySpell generator branch` | `self.hasPrimalSurge` read in grant calculation | ✗ NOT WIRED | hasPrimalSurge is initialized (line 57) and reset (init.lua:62) but never read by ApplySpell (line 700 ignores it) and never updated by any event handler — dead state (WR-01) |

---

### Behavioral Spot-Checks

Step 7b: SKIPPED — no standalone Lua interpreter; WoW Lua sandbox only. Behavioral truths routed to human verification.

---

### Probe Execution

Step 7c: No probe scripts declared or found. SKIPPED.

---

### Requirements Coverage

The gap-closure plans (01-03, 01-04) declare `requirements: []`. They address UAT gaps, not requirements changes. The four Phase 1 requirements were verified in the initial pass:

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| QUAL-01 | 01-01-PLAN.md | Shared utilities in Util.lua | ✓ SATISFIED | Carried from initial verification; untouched by gap-closure |
| QUAL-02 | 01-02-PLAN.md | Frame locals moved to Tip table fields | ✓ SATISFIED | Carried from initial verification; untouched by gap-closure |
| QUAL-04 | 01-01-PLAN.md | ForEachModule uses ordered moduleOrder | ✓ SATISFIED | Carried from initial verification; untouched by gap-closure |
| QUAL-05 | 01-02-PLAN.md | pcall removed from ClassifySpellID | ✓ SATISFIED | Carried from initial verification; ClassifySpellID body unchanged |

No orphaned requirements. REQUIREMENTS.md maps exactly QUAL-01, QUAL-02, QUAL-04, QUAL-05 to Phase 1.

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `Duncedmaxxing/Modules/TipOfTheSpear.lua` | 57, 700 | `hasPrimalSurge` initialized and referenced in comment but never read by ApplySpell and never updated by any event handler — dead state | WARNING | Three Primal Surge tests in spec/tip_spec.lua are tautological (WR-01/WR-02 from 01-REVIEW.md): they vary hasPrimalSurge but always assert 2 because the code ignores it. Does not cause a runtime defect but gives false confidence. |
| `spec/tip_spec.lua` | 198-202 | 265189 regression test calls `ApplySpell("consumer", 265189)` directly, bypassing ClassifySpellID | WARNING | Test would pass even if 265189 were removed from CONSUMERS. Does not guard the actual fix (WR-03 from 01-REVIEW.md). |
| `Duncedmaxxing/Modules/TipOfTheSpear.lua` | 697-700 | Self-contradictory comment: "base 1, +1 with Primal Surge" vs "grant is 2 in all cases" on adjacent lines | INFO | Misleading to maintainers; a future developer wiring hasPrimalSurge per the "base 1" comment would silently break the flat-2 contract (IN-01 from 01-REVIEW.md) |

No `TBD`, `FIXME`, `XXX`, `TODO`, `HACK`, or `PLACEHOLDER` debt markers found in any gap-closure modified file.

---

### Human Verification Required

#### 1. UAT Test 3 Re-test — Kill Command with Twin Fangs (GAP-1d)

**Test:** On a Survival Hunter with Twin Fangs talented, cast Kill Command from 0 stacks.
**Expected:** Stack display goes directly to 2. No transient "3 for one instant then 2" flicker. The old formula `self.hasTwinFangs and 3 or 2` is confirmed removed by grep; in-game confirms no over-predict occurs.
**Why human:** Display timing and SyncFromAura correction ordering only exercise in the live WoW client.

#### 2. UAT Test 6 Re-test — Raptor Strike with Aspect of the Eagle (GAP-2b)

**Test:** With Aspect of the Eagle active, cast Raptor Strike and observe the Tip of the Spear stack display.
**Expected:** Stack decrements instantly on cast, identical to casting Raptor Strike without Aspect of the Eagle. No observable lag.
**Why human:** Instant-vs-deferred timing is a runtime property; grep confirms the code path is wired but cannot simulate timing.

#### 3. Spell ID 265189 Patch 12.0.5 Confirmation

**Test:** With Aspect of the Eagle active, use `/etrace` (or equivalent) to capture the UNIT_SPELLCAST_SUCCEEDED spell ID emitted when casting Raptor Strike.
**Expected:** Emitted spell ID is 265189. If the ID is different (e.g., 259271 or another), the lag will persist despite the code fix.
**Why human:** 265189 was selected from historical lineage during diagnosis. Patch 12.0.5 correctness cannot be confirmed without the game client. This is the highest-risk human item.

#### 4. Double-Decrement Check — 265189 + 186270 Both in CONSUMERS (IN-03)

**Test:** With Aspect of the Eagle active, cast Raptor Strike from 2 stacks and observe the final stack count.
**Expected:** Stack count becomes 1, not 0. One decrement per press.
**Why human:** If the WoW client emits both 186270 and 265189 as separate UNIT_SPELLCAST_SUCCEEDED events for one logical press, FindTrackedSpell would dispatch twice and decrement twice. Cannot be observed offline.

#### 5. In-Game Load Verification (SC-5 — carried from initial verification)

**Test:** `/reload ui` with addon enabled. Observe chat for Lua errors.
**Expected:** No Lua errors. Tracker renders correctly. Stack count updates on Kill Command cast.
**Why human:** WoW Lua sandbox cannot be replicated outside the client.

---

### Gaps Summary

No automated gaps (no FAILED must-haves). Two must-haves are PRESENT_BEHAVIOR_UNVERIFIED — code is present and correctly wired but runtime behavior cannot be confirmed without the WoW client.

**Notable quality concerns from 01-REVIEW.md (not gap-level but require attention):**

1. **WR-01 / WR-02 — hasPrimalSurge dead state with tautological tests.** The field is never read by the runtime path and never updated by event handlers. The three tests that vary it give false confidence. The only genuine regression guard is the `assert.not_equals(3, ...)` check at spec/tip_spec.lua:134. Recommend: either remove the field and its tautological tests until the Primal Surge spell ID is resolved, or add a clear "RESERVED — not yet wired" comment and collapse the tautological tests into a single flat-2 test.

2. **WR-03 — 265189 regression test bypasses ClassifySpellID.** The test calls `ApplySpell("consumer", 265189)` directly and would pass even without the CONSUMERS table entry. The structural grep (`OK_265189_IN_CONSUMERS_TABLE`) is currently the only check that actually protects the fix. Recommend: rewrite the test to route through `OnEvent("UNIT_SPELLCAST_SUCCEEDED", ...)` so it fails if 265189 is removed from CONSUMERS.

3. **IN-01 — Self-contradictory generator-branch comment.** Reconcile "base 1, +1 with Primal Surge" vs "grant is 2 in all cases" before a future maintainer misreads it.

---

_Verified: 2026-06-22T00:00:00Z_
_Verifier: Claude (gsd-verifier)_
_Re-verification: gap-closure plans 01-03 and 01-04_
