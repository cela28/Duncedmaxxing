---
quick_id: 260707-0sb
slug: change-aura-verify-delay-in-duncedmaxxin
date: 2026-07-06
status: complete
---

# Summary: Raise AURA_VERIFY_DELAY 1.25 → 2.0

## What changed

- `Duncedmaxxing/Modules/TipOfTheSpear.lua:9` — `AURA_VERIFY_DELAY` 1.25 → 2.0.
  Delays the first post-cast server sync (and, via `ScheduleAuraVerify`, the
  in-combat `UNIT_AURA` throttle) so the aura corrects the predicted stack count
  ~0.75s later than before.
- `spec/tip_spec.lua:16` — mirrored constant 1.25 → 2.0.
- `spec/tip_spec.lua:401` — serial-mismatch test advance margin `+ 0.1` → `+ 0.02`.
  Required because the first verify timer (now 2.0s) and FINAL (2.05s) are only
  0.05s apart; the old margin would have fired both and produced 2 sync calls
  instead of the asserted 1. Comment arithmetic updated to match.

## Left unchanged (per scope)

- `FINAL_AURA_VERIFY_DELAY = 2.05` and `CONSUMER_UPSYNC_GRACE = 2.75`.

## Verification

Full spec suite: **124 passed, 0 failed** (`node spec/run.cjs`).

## Note

With the first read at 2.0 and FINAL at 2.05, the two cast-verify reads now fire
almost together (~50ms apart) rather than staggered. Functionally fine; the only
loss is the spacing between the two backstop reads. Flagged to the user before
implementing.
