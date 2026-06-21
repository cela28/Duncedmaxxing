---
quick_id: 260621-x8n
description: Fix release workflow action SHA so the v1.0.0 zip asset builds and uploads
date: 2026-06-21
status: complete
one_liner: Corrected the softprops/action-gh-release pin from a non-existent SHA to the real verified v2.3.2 commit so the package-release job can resolve the action.
commit: f1e6e4d
key-files:
  modified:
    - .github/workflows/release.yml
---

# Quick Task 260621-x8n: Fix release workflow action SHA — Summary

## One-liner

Corrected the `softprops/action-gh-release` pin in the release workflow from a
non-existent commit SHA to the real, verified v2.3.2 SHA so the
`package-release` job can resolve the action and upload the release zip.

## What Changed

- `.github/workflows/release.yml` line 56: replaced the 40-char SHA
  `c062e08bd532815e2082a07b400ef65ab24e279c` with the verified v2.3.2 SHA
  `72f2c25fcb47643c292f7107632f7a47c1df5cd8`.
- Indentation, the `uses:` key, and the `# v2.3.2` comment were preserved
  byte-for-byte. Exactly one line changed.

## Verification

- `grep -n "softprops/action-gh-release@72f2c25fcb47643c292f7107632f7a47c1df5cd8" .github/workflows/release.yml`
  → `56:        uses: softprops/action-gh-release@72f2c25fcb47643c292f7107632f7a47c1df5cd8  # v2.3.2`
- `grep -c "c062e08" .github/workflows/release.yml` → `0`
- `git diff` → exactly one changed line.

## Deviations from Plan

None — plan executed exactly as written.

## Scope Notes

Re-cutting the GitHub release (moving the `v1.0.0` tag and recreating the
release) was explicitly out of scope and is handled separately by the
orchestrator with user confirmation. No `gh`/release commands were run.

## Self-Check: PASSED

- FOUND: .github/workflows/release.yml (new SHA present, old SHA absent)
- FOUND: commit f1e6e4d
