---
status: resolved
trigger: "When the Survival Hunter casts Kill Command, the Tip of the Spear stack display briefly shows 3 for one instant, then drops back to 2 (the correct value)."
created: 2026-06-22T00:00:00Z
updated: 2026-06-23T00:00:00Z
---

## Current Focus

hypothesis: ApplySpell generator path predicts grant=3 (because hasTwinFangs is true) when the player's actual Kill Command grant is 2 (Primal Surge, no Twin Fangs). SyncFromAura later reads the real aura (2 applications) and corrects 3 -> 2.
test: Trace ApplySpell("generator") arithmetic + SyncFromAura reconciliation against the real WoW mechanic for Kill Command stack grants.
expecting: A prediction-vs-truth mismatch where the only way to reach a transient 3 with a final 2 is grant=3 at predict time.
next_action: Report root cause (diagnose-only mode).

reasoning_checkpoint:
  hypothesis: "The generator grant formula `self.hasTwinFangs and 3 or 2` over-predicts Kill Command's stack gain. Twin Fangs modifies Takedown, not Kill Command, so when hasTwinFangs is true the predictive code adds 3 on a Kill Command cast that actually grants only 2 (Primal Surge). The transient 3 is the wrong prediction; the drop to 2 is SyncFromAura reading the true aura count."
  confirming_evidence:
    - "Symptom is exactly +1-then-correct: shows 3, settles at 2. Final value 2 == Primal Surge Kill Command grant (no Twin Fangs)."
    - "ApplySpell generator path (line 695) is the ONLY code that adds stacks on a Kill Command cast; the only way it yields 3 from a 0-stack open is grant==3, i.e. hasTwinFangs==true."
    - "WoW mechanic (warcraft.wiki.gg / wowhead): Twin Fangs grants its 3 stacks via TAKEDOWN, not Kill Command. Kill Command grants 1 base, 2 with Primal Surge. The addon never models Primal Surge and wrongly ties Kill Command's grant to hasTwinFangs."
    - "SyncFromAura (line 353) unconditionally writes liveStacks for generators (the grace window at 347 only protects consumer up-syncs), so a real aura read of 2 immediately overwrites the predicted 3 -> the observed correction."
  falsification_test: "If the player genuinely had Twin Fangs AND the aura settled at 3 (not 2), there would be no overshoot. Conversely, if a non-Twin-Fangs player still saw 3-then-2, that confirms grant=3 fired with hasTwinFangs effectively true / mis-derived."
  fix_rationale: "Kill Command's grant must be derived from the player's actual Kill-Command-affecting talents (base 1, +1 Primal Surge), independent of Twin Fangs. Twin Fangs should only affect the Takedown consumer path (where it is already applied at line 699-703). Decoupling the generator grant from hasTwinFangs removes the over-prediction."
  blind_spots: "Cannot run WoW; relying on web sources for the exact stack numbers and on the assumption that HasTwinFangs() currently returns true for this user. The user's precise talent loadout (Primal Surge yes/no) is inferred from the final value 2, not directly observed."

## Symptoms

expected: Casting Kill Command increments the Tip of the Spear stack display to the correct count (e.g. 2) with no transient wrong value.
actual: "when I press Kill command the stacks go to 3 for one instant before dropping back to 2" - predictive display momentarily shows one stack too many, then corrects when the server/aura confirms.
errors: None reported (no Lua errors; purely a wrong-value flicker).
reproduction: Test 3 in 01-UAT.md - on a Survival Hunter, cast Kill Command and watch the stack count.
started: Discovered during UAT of Phase 01. Predictive grant logic was changed in commit 0cf4776 (Phase 03-02) which introduced `self.hasTwinFangs and 3 or 2`.

## Eliminated

- hypothesis: "Two separate handlers (UNIT_SPELLCAST_SUCCEEDED and UNIT_AURA) both increment the count, causing a double-count."
  evidence: "UNIT_AURA only calls ScheduleAuraVerify -> SyncFromAura, which SETS stacks from the aura read; it never increments. Only ApplySpell adds stacks. No additive double path exists."
  timestamp: 2026-06-22T00:00:00Z

- hypothesis: "Overcap/clamp: existing stacks + grant exceeds 3, clamps to 3, then aura corrects."
  evidence: "Final value is 2, which is below MAX_STACKS. A clamp to 3 cannot decay to 2 on its own; the correction to 2 requires the aura genuinely reading 2, which means the grant itself (not a clamp) produced the transient 3."
  timestamp: 2026-06-22T00:00:00Z

## Evidence

- timestamp: 2026-06-22T00:00:00Z
  checked: ApplySpell generator branch (TipOfTheSpear.lua:694-697)
  found: "grant = self.hasTwinFangs and 3 or 2; self.stacks = ClampStacks(self.stacks + grant). Only two outcomes modeled: +3 (Twin Fangs) or +2 (otherwise). No base-1 / Primal-Surge-aware path."
  implication: "Kill Command stack grant is hard-coupled to hasTwinFangs."

- timestamp: 2026-06-22T00:00:00Z
  checked: WoW mechanic via warcraft.wiki.gg, wowhead, icy-veins, maxroll
  found: "Tip of the Spear caps at 3 stacks. Base Kill Command grants 1 stack. Primal Surge talent adds +1 (Kill Command grants 2). Twin Fangs grants 3 stacks via TAKEDOWN (the consumer), NOT via Kill Command."
  implication: "Tying Kill Command's grant to hasTwinFangs is mechanically wrong. Kill Command's grant depends on Primal Surge, which the addon does not detect at all."

- timestamp: 2026-06-22T00:00:00Z
  checked: SyncFromAura (TipOfTheSpear.lua:341-366) and the consumer up-sync grace (347-351)
  found: "For generators, SyncFromAura writes liveStacks unconditionally (line 353). The CONSUMER_UPSYNC_GRACE guard only suppresses up-syncs when lastPredictKind == 'consumer'. So after a generator over-prediction, the next aura read immediately overwrites the inflated value."
  implication: "Explains the instant correction: predicted 3 -> aura read 2 -> display snaps to 2."

- timestamp: 2026-06-22T00:00:00Z
  checked: HasTwinFangs (TipOfTheSpear.lua:35-43) and git blame (commit 0cf4776, Phase 03-02)
  found: "HasTwinFangs checks IsSpellKnown(TWIN_FANGS=1272139). The grant formula `hasTwinFangs and 3 or 2` was added in 0cf4776. Before that, generators always granted +2."
  implication: "The regression source. Even the pre-0cf4776 flat +2 was wrong for non-Primal-Surge players (should be 1), but 0cf4776 introduced the active 3-vs-2 over-prediction observed in UAT."

## Resolution

root_cause: |
  ApplySpell's generator branch (Duncedmaxxing/Modules/TipOfTheSpear.lua:695) predicts the
  Kill Command stack grant as `self.hasTwinFangs and 3 or 2`. This is mechanically incorrect:
  Twin Fangs is a TAKEDOWN modifier (it grants 3 stacks on Takedown, the consumer), NOT a
  Kill Command modifier. Kill Command's actual grant is 1 (base) or 2 (with the Primal Surge
  talent) and caps at 3 total.

  When the player has Twin Fangs but NOT a 3-stack Kill Command effect, the predictive path
  adds 3 stacks on a Kill Command cast that really grants 2. The display jumps to the predicted
  3, then SyncFromAura (line 353) reads the true aura (2 applications) and snaps the display
  back to 2 - producing the observed "3 for one instant, then 2" overshoot.

  Root cause is over-prediction in the generator grant formula, compounded by the addon never
  detecting Primal Surge (so it cannot distinguish the base-1 vs +1 Kill Command cases).
fix: |
  Decoupled the Kill Command generator grant from Twin Fangs in
  Duncedmaxxing/Modules/TipOfTheSpear.lua (ApplySpell generator branch). The grant is now a
  flat `local grant = 2` regardless of hasTwinFangs; Twin Fangs is scoped exclusively to the
  Takedown consumer path (`if spellID == TAKEDOWN and self.hasTwinFangs`). A `hasPrimalSurge`
  field was reserved for a future base-1/+1 split once the Primal Surge spell ID is confirmed
  in-game (it was unverifiable offline, so flat-2 is the fallback). Applied in commit 975cb6e
  (Phase 01-03). Covered by the predictive-grant unit tests in spec/core_spec.lua (116/116 pass).
verification: |
  Code verified 2026-06-23 during /gsd-audit-uat: TipOfTheSpear.lua line 663 reads
  `local grant = 2  -- flat-2 fallback`, and the hasTwinFangs reference at line 667 is gated on
  `spellID == TAKEDOWN`. The over-prediction path that produced the transient 3 no longer exists.
  Final in-game confirmation (no flicker on Kill Command) is folded into 01-HUMAN-UAT.md test 2.
files_changed: [Duncedmaxxing/Modules/TipOfTheSpear.lua]
