---
status: partial
phase: 07-spell-coverage-add-missing-consumers
source: [07-VERIFICATION.md]
started: 2026-07-27
updated: 2026-07-27T17:00:00Z
---

## Current Test

[testing paused — 2 items outstanding]

## Tests

### 1. Moonlight Chakram (1264902) in-game consumption + variant check
expected: With Sentinel hero talent active, build 2+ stacks via Kill Command, cast Takedown (procs Moonlight Chakram), then cast Moonlight Chakram on target. Tracker should decrement by 1 instantly. Confirm spell ID 1264902 fires (not variant 1264949) via combat log / /etrace.
result: blocked
blocked_by: physical-device
reason: "Requires in-game testing with WoW client"

### 2. Hatchet Toss (193265) in-game consumption
expected: At 2+ stacks, cast Hatchet Toss (40yd ranged, 30 Focus). Tracker should decrement by 1 instantly. Hatchet Toss is always available to Survival Hunters (no talent gating).
result: blocked
blocked_by: physical-device
reason: "Requires in-game testing with WoW client"

## Summary

total: 2
passed: 0
issues: 0
pending: 0
skipped: 0
blocked: 2

## Gaps
