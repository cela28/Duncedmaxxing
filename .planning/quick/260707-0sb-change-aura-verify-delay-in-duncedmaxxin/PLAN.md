---
quick_id: 260707-0sb
slug: change-aura-verify-delay-in-duncedmaxxin
date: 2026-07-06
status: complete
---

# Quick Task: Raise AURA_VERIFY_DELAY 1.25 → 2.0

## Goal

Slow the earliest post-cast server sync. The user observes the aura sometimes
overriding the predicted stack count too fast; `AURA_VERIFY_DELAY` is the delay
before the first cast-verify read fires, so raising it delays that correction.

## Change

1. `Duncedmaxxing/Modules/TipOfTheSpear.lua:9` — `AURA_VERIFY_DELAY = 1.25` → `2.0`.
   - This constant also gates the in-combat `UNIT_AURA` throttle in
     `ScheduleAuraVerify` (line 449), so the no-prediction fallback lag also
     rises to 2.0s. Accepted per user intent.
2. `spec/tip_spec.lua:16` — mirrored `AURA_VERIFY_DELAY = 1.25` → `2.0`.
3. `spec/tip_spec.lua:401` — the serial-mismatch test asserts exactly ONE sync
   call by advancing past the FIRST verify timer but NOT the FINAL one
   (`FINAL_AURA_VERIFY_DELAY = 2.05`, unchanged). The old `+ 0.1` margin (1.35)
   sat safely between 1.25 and 2.05. With the first timer now at 2.0 and FINAL
   at 2.05 (a 0.05 gap), `+ 0.1` would cross BOTH timers → 2 sync calls → test
   fails. Tighten that single advance to `AURA_VERIFY_DELAY + 0.02` (2.02) so it
   fires only the first timer. Update the surrounding comments' arithmetic
   (101.25/102.05 → 102.0/102.05).

## Out of scope

- `FINAL_AURA_VERIFY_DELAY` (2.05) and `CONSUMER_UPSYNC_GRACE` (2.75) unchanged.
- Other `clock:advance(AURA_VERIFY_DELAY + 0.1)` sites (lines 421, 576) assert
  booleans (`syncCalled`/`auraVerifyPending`) that remain correct whether one or
  both timers fire — no change needed.

## Verification

Run the full spec suite; expect 124 passed, 0 failed.
