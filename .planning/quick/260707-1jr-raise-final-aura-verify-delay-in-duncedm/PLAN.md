---
quick_id: 260707-1jr
slug: raise-final-aura-verify-delay-in-duncedm
date: 2026-07-06
status: complete
---

# Quick Task: Raise FINAL_AURA_VERIFY_DELAY 2.05 → 2.25

## Goal

Widen the stagger between the two post-cast verify reads. `AURA_VERIFY_DELAY`
(2.0) stays put — the first correction still fires at 2.0s — and the backstop
read moves from 2.05 to 2.25, restoring a real 0.25s gap (was 0.05s).

## Change

1. `Duncedmaxxing/Modules/TipOfTheSpear.lua:10` — `FINAL_AURA_VERIFY_DELAY` 2.05 → 2.25.
   - 2.25 < `CONSUMER_UPSYNC_GRACE` (2.75), so both reads still fire inside the
     consumer-grace window — the anti-flicker invariant is preserved.
2. `spec/tip_spec.lua:387-393` — comment arithmetic in the serial-mismatch test
   references the FINAL timer at 2.05 / fireAt=102.05 / a 0.05s gap. Update to
   2.25 / 102.25 / 0.25s. The assertion itself is unaffected: the advance is
   `AURA_VERIFY_DELAY + 0.02` = 2.02, which fires only the 2.0 timer — now with
   even more headroom below the 2.25 FINAL timer.

## Out of scope

- `AURA_VERIFY_DELAY` (2.0) and `CONSUMER_UPSYNC_GRACE` (2.75) unchanged.
- No mirrored FINAL constant exists in the test (only comments reference it).

## Verification

Run the full spec suite; expect 124 passed, 0 failed.
