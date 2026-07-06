---
quick_id: 260707-1jr
slug: raise-final-aura-verify-delay-in-duncedm
date: 2026-07-06
status: complete
---

# Summary: Raise FINAL_AURA_VERIFY_DELAY 2.05 → 2.25

## What changed

- `Duncedmaxxing/Modules/TipOfTheSpear.lua:10` — `FINAL_AURA_VERIFY_DELAY`
  2.05 → 2.25. The backstop (second) post-cast verify read now fires at 2.25s.
- `spec/tip_spec.lua:387-393` — comment arithmetic in the serial-mismatch test
  updated (2.05/102.05/0.05 → 2.25/102.25/0.25). Assertion unchanged.

## Effect

The two verify reads are now `AURA_VERIFY_DELAY = 2.0` (first correction) and
`FINAL_AURA_VERIFY_DELAY = 2.25` (backstop) — a 0.25s stagger, restored from the
near-simultaneous 0.05s spacing left by the previous task. Both remain inside the
`CONSUMER_UPSYNC_GRACE` (2.75) window, so the consumer anti-flicker guard still
covers both reads.

## Left unchanged (per scope)

- `AURA_VERIFY_DELAY = 2.0`, `CONSUMER_UPSYNC_GRACE = 2.75`.

## Verification

Full spec suite: **125 passed, 0 failed** (`node spec/run.cjs`).
Commit: 9370711.
