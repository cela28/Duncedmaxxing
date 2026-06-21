---
status: diagnosed
trigger: "On a Survival Hunter, when Aspect of the Eagle is active, casting Raptor Strike causes the Tip of the Spear stack display to update only after a noticeable delay, instead of decrementing instantly like a normal consumer cast. Without Aspect of the Eagle, Raptor Strike updates the stacks instantly."
created: 2026-06-21T22:33:44Z
updated: 2026-06-21T22:40:00Z
---

## Current Focus

hypothesis: CONFIRMED — When Aspect of the Eagle (186289) is active, the ranged Raptor Strike is reported in UNIT_SPELLCAST_SUCCEEDED under a DISTINCT spell ID (the "Aspect of the Eagle variant of Raptor Strike", a separate spell from the 186270 talent), which is NOT in the CONSUMERS table. ClassifySpellID returns nil for it, FindTrackedSpell finds nothing, ApplySpell never runs, so no instant prediction fires. The stack only updates later via the slow UNIT_AURA -> ScheduleAuraVerify -> SyncFromAura path.
test: Verified via canonical WoW sources (warcraft.wiki.gg, wowhead) plus code trace of the two update paths.
expecting: Confirmed a distinct ranged Raptor Strike spell exists; 1262293 "Raptor Swipe" is the apex AoE-upgrade talent, NOT the Aspect variant, so it does not cover this case.
next_action: Hand off to fix — capture the exact in-game ranged Raptor Strike spell ID (via /etrace or a spell-ID addon while Aspect of the Eagle is active) and add it to CONSUMERS.

reasoning_checkpoint:
  hypothesis: "The Aspect-of-the-Eagle ranged Raptor Strike fires UNIT_SPELLCAST_SUCCEEDED under a spell ID that is not in CONSUMERS, so the predictive path (ApplySpell) is skipped and only the delayed aura-sync path updates the display."
  confirming_evidence:
    - "Code: ClassifySpellID returns 'consumer' ONLY for exact ID matches in CONSUMERS (line 70); FindTrackedSpell returns nothing for unmatched IDs (lines 75-83); UNIT_SPELLCAST_SUCCEEDED handler only calls ApplySpell when FindTrackedSpell returns a kind (lines 755-764)."
    - "Code: The only other path to decrement is UNIT_AURA -> ScheduleAuraVerify (line 753), which defers via C_Timer.After by >= 0.05s and, in combat, stretches the delay up to AURA_VERIFY_DELAY = 1.25s via the quietRemaining logic (lines 438-444). This delay matches the user's 'takes a while' lag exactly."
    - "Sources: warcraft.wiki.gg / wowhead confirm Aspect of the Eagle (186289) produces a distinct 'Aspect of the Eagle variant of Raptor Strike' (referenced in 2025-05-08 and 2026-01-27 hotfix notes as a separate spell with its own damage/focus values) — i.e. a different spell ID than the 186270 talent."
    - "Sources: 1262293 'Raptor Swipe' is the apex talent AoE upgrade of Raptor Strike (wowhead 1259003 / warcraft.wiki.gg Raptor_Swipe_(hunter_talent)), NOT the Aspect-of-the-Eagle ranged variant — so its presence in CONSUMERS does not close this gap."
  falsification_test: "If, with Aspect of the Eagle active, Raptor Strike fired UNIT_SPELLCAST_SUCCEEDED with spellID == 186270 (already in CONSUMERS), the prediction would fire instantly and there would be no lag. The observed lag refutes that and confirms a different (uncovered) ID is being reported."
  fix_rationale: "Adding the ranged Raptor Strike spell ID to CONSUMERS restores the instant predictive decrement, addressing the root cause (a spell-ID coverage gap) rather than the symptom (the lag). No timing/eventing change is needed."
  blind_spots: "Exact numeric ID of the ranged Raptor Strike in 12.0.5 not confirmable from public sources (historical lineage 259271/265189; current build may differ) — must be captured in-game. Have not verified whether Mongoose Bite (the Mongoose-Bite-talent alternative to Raptor Strike) has the same gap; if a player runs Mongoose Bite, its Aspect variant likely needs the same treatment, but that is outside this specific report."

## Symptoms

expected: Casting Raptor Strike consumes a Tip of the Spear stack and the display decrements instantly (predictive), regardless of whether Aspect of the Eagle is active.
actual: "When I use raptor strike with aspect of the eagle up it seems it takes a while for the stacks to update" — the stack count lags, updating only after a delay (consistent with falling through to the slow aura-sync path rather than the instant predictive path).
errors: None reported (no Lua errors; purely a timing/lag issue).
reproduction: On a Survival Hunter, activate Aspect of the Eagle, then cast Raptor Strike and watch the Tip of the Spear stack display. Compare to casting Raptor Strike without Aspect of the Eagle.
started: Reported during follow-up testing of Phase 01. Likely a pre-existing spell-ID coverage gap, not introduced by the Phase 01 refactor.

## Eliminated

- hypothesis: "1262293 'Raptor Swipe' (already in CONSUMERS) IS the Aspect-of-the-Eagle ranged Raptor Strike variant, so the case is already covered."
  evidence: "wowhead (1259003) and warcraft.wiki.gg confirm Raptor Swipe is the apex AoE-upgrade talent — Raptor Strike has a chance to upgrade itself into a frontal cone AoE. It is unrelated to Aspect of the Eagle's ranged conversion. The Aspect variant is a separate spell ID still missing from CONSUMERS."
  timestamp: 2026-06-21T22:38:00Z

- hypothesis: "Aspect of the Eagle introduces a second mechanism (e.g. it suppresses or alters UNIT_SPELLCAST_SUCCEEDED eventing) beyond the spell-ID gap."
  evidence: "Aspect of the Eagle (186289) is purely a range/aura-extension buff; it does not change cast-success eventing. A cast still fires UNIT_SPELLCAST_SUCCEEDED — just under the ranged-variant spell ID. The handler logic (lines 755-764) is otherwise correct and isSurvival-gated. No evidence of a second mechanism; the spell-ID coverage gap fully explains the symptom."
  timestamp: 2026-06-21T22:39:00Z

## Evidence

- timestamp: 2026-06-21T22:33:44Z
  checked: CONSUMERS table and UNIT_SPELLCAST_SUCCEEDED handler in Duncedmaxxing/Modules/TipOfTheSpear.lua
  found: CONSUMERS = {1261193 Boomstick, 1250646 Takedown, 259495 Wildfire Bomb, 186270 Raptor Strike, 1262293 Raptor Swipe}. ClassifySpellID returns "consumer" only for exact ID matches in CONSUMERS. UNIT_SPELLCAST_SUCCEEDED -> FindTrackedSpell -> ApplySpell is the ONLY instant predictive path. UNIT_AURA -> ScheduleAuraVerify is the slow path (delay >= 0.05s, often stretched to AURA_VERIFY_DELAY=1.25s in combat via quietRemaining logic).
  implication: If Raptor Strike fires under a non-matching spell ID when Aspect of the Eagle is up, no prediction occurs and the user sees lag matching the AURA_VERIFY_DELAY (~1.25s) path.

- timestamp: 2026-06-21T22:36:00Z
  checked: warcraft.wiki.gg + wowhead for Aspect of the Eagle and Raptor Strike spell IDs (WoW Midnight 12.0.x)
  found: Aspect of the Eagle = 186289; base Raptor Strike talent = 186270; Aspect of the Eagle produces a distinct "Aspect of the Eagle variant of Raptor Strike" (referenced as a separate spell in 2025-05-08 and 2026-01-27 hotfix notes with its own damage/focus values). Historical ranged-Raptor-Strike lineage spell IDs include 259271 (Shadowlands) / 265189 (BfA); the exact 12.0.5 ID is not published on these sites.
  implication: A separate spell ID is reported when casting Raptor Strike under Aspect of the Eagle, and it is not in CONSUMERS — confirming the coverage gap. The precise current-build ID must be captured in-game for the fix.

- timestamp: 2026-06-21T22:38:00Z
  checked: wowhead 1259003 / warcraft.wiki.gg for "Raptor Swipe" (code uses 1262293)
  found: Raptor Swipe is the apex talent that upgrades Raptor Strike into a frontal-cone AoE (25% chance). It is the AoE/cleave proc variant, NOT the Aspect-of-the-Eagle ranged variant.
  implication: 1262293 in CONSUMERS covers the Raptor Swipe proc correctly, but leaves the Aspect-of-the-Eagle ranged Raptor Strike uncovered. The fix must target the ranged-variant ID, not Raptor Swipe.

## Resolution

root_cause: |
  Spell-ID coverage gap in the CONSUMERS table (Duncedmaxxing/Modules/TipOfTheSpear.lua:20-26).
  When Aspect of the Eagle (186289) is active, casting Raptor Strike fires UNIT_SPELLCAST_SUCCEEDED
  under a DISTINCT "ranged Raptor Strike" spell ID rather than the melee talent ID 186270. That
  ranged-variant ID is absent from CONSUMERS, so ClassifySpellID (line 65) returns nil,
  FindTrackedSpell (line 75) finds no tracked spell, and ApplySpell (line 691) — the only instant
  predictive decrement path — never runs. The stack count is then corrected only by the delayed
  fallback: UNIT_AURA -> Tip:ScheduleAuraVerify (line 426) -> Tip:SyncFromAura, which defers by at
  least 0.05s and, in combat, stretches up to AURA_VERIFY_DELAY = 1.25s via the quietRemaining
  logic (lines 438-444). That deferral is exactly the "takes a while to update" lag the user sees.
  Without Aspect of the Eagle, Raptor Strike fires under 186270 (which IS in CONSUMERS), so the
  prediction fires instantly — matching the reported difference. 1262293 "Raptor Swipe" is the
  apex AoE-upgrade talent and does NOT cover this case.
fix: |
  Add the Aspect-of-the-Eagle ranged Raptor Strike spell ID to the CONSUMERS table so it is
  classified as a "consumer" and decrements a stack instantly via ApplySpell, identical to the
  melee Raptor Strike (186270). The exact numeric ID for the current 12.0.5 client must be captured
  in-game first (e.g. /etrace or a spell-ID display addon while Aspect of the Eagle is active and
  casting Raptor Strike) — public databases do not publish the current-build ID (historical lineage:
  259271 / 265189). Consider also covering the Mongoose Bite Aspect variant if Mongoose Bite is the
  active talent, since it has the same structure. NOTE: diagnose-only mode — fix not applied.
verification: Not applied (goal: find_root_cause_only). Verification will occur after the fix adds the captured ID and the user confirms instant decrement with Aspect of the Eagle active.
files_changed: []
