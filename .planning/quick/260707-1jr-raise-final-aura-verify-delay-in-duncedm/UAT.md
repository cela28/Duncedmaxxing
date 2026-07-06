---
status: partial
scope: quick
source: [260707-0sb-SUMMARY.md, 260707-1jr-SUMMARY.md]
started: 2026-07-06T22:15:00Z
updated: 2026-07-06T22:15:00Z
---

## Current Test

number: 1
name: Instant prediction still fires with no delay
expected: |
  In combat on Survival Hunter, cast a stack-generating ability (Kill Command).
  The bar/number jumps to the new stack count immediately on cast — the timing
  change must NOT have added any lag to the predictive display.
awaiting: user response

## Tests

Covers the aura-sync timing changes: AURA_VERIFY_DELAY 1.25→2.0 (260707-0sb)
and FINAL_AURA_VERIFY_DELAY 2.05→2.25 (260707-1jr). Net behavior: prediction is
instant; the server-confirmed aura reconciles at ~2.0s (first read) and ~2.25s
(backstop read); consumer up-sync stays suppressed for 2.75s to prevent flicker.

### 1. Instant prediction still fires with no delay
expected: In combat, cast Kill Command. The stack display jumps to the new count immediately on cast — no perceptible delay. Confirms the delay bump did not slow the predictive path.
result: [pending]

### 2. Consumer prediction holds — no bounce-back flicker
expected: At 2+ stacks in combat, cast a consumer (Raptor Strike / Takedown). The display drops by 1 instantly and STAYS at the lower count — it must NOT briefly bounce back up to the old value before settling. This is the core reason the sync was slowed.
result: [pending]

### 3. Mispredicted count self-corrects within ~2s
expected: If the displayed count ever diverges from the real Tip of the Spear buff (e.g. an untracked interaction), the bar corrects itself to the true server value within roughly 2 seconds — later than before, but it does converge. No permanent wrong count.
result: [pending]

### 4. Buff expiry clears the display
expected: Build stacks, then stop casting. When the 10s Tip of the Spear buff expires, the display returns to 0 (or hides if Hide-when-empty is on). No stuck stacks.
result: [pending]

### 5. Out-of-combat sync is prompt
expected: Leave combat with stacks showing. The display reconciles to the real aura state quickly (the out-of-combat path is unchanged and near-instant) — it does not wait ~2s.
result: [pending]

### 6. No Lua errors
expected: Across all of the above — casting, expiry, entering/leaving combat, and a /reload — no Lua error is thrown (test with Lua errors visible / an error display addon enabled).
result: [pending]

### 7. Test suite green (dev machine)
expected: Running `node spec/run.cjs` (or `npx -y -p fengari@0.1.5 node spec/run.cjs`) from the repo root reports all tests passing with 0 failures.
result: pass

## Summary

total: 7
passed: 1
issues: 0
pending: 6
skipped: 0
blocked: 0

## Gaps

[none yet]
