---
phase: 04-performance-caching-and-ci-cd
plan: 02
subsystem: ci-cd
tags: [ci, luacheck, github-actions, release-automation]
dependency_graph:
  requires: []
  provides: [release-workflow, luacheck-clean]
  affects: [.luacheckrc, .github/workflows/release.yml]
tech_stack:
  added: [GitHub Actions, softprops/action-gh-release@v2]
  patterns: [lint-gate-before-release, version-injection-via-sed]
key_files:
  created:
    - .github/workflows/release.yml
  modified:
    - .luacheckrc
decisions:
  - "Suppressed W212/self globally in .luacheckrc (not inline per function) — standard WoW addon approach for colon-syntax methods where self is unused"
  - "Used sudo luarocks install on ubuntu-latest — apt-installed luarocks defaults to system-wide, sudo required"
  - "package-release gated by if: github.event_name == 'release' so lint+test fires on every push but packaging only on releases"
metrics:
  duration: 5min
  completed: "2026-06-18T12:43:25Z"
  tasks: 2
  files_changed: 2
---

# Phase 04 Plan 02: CI/CD Release Workflow and Luacheck Clean Summary

GitHub Actions release workflow with lint+test gate and automated zip packaging. Luacheck suppresses W212/self so the CI lint step passes on the existing codebase.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Fix pre-existing luacheck warnings for clean CI gate | 01c1f9a | .luacheckrc |
| 2 | Create GitHub Actions release workflow | 5437a90 | .github/workflows/release.yml |

## What Was Built

### Task 1 — Luacheck clean gate

Added `"212/self"` to the `ignore` list in `.luacheckrc` alongside the existing `"432"` suppression. This silences W212 (unused argument) on `self` in colon-method definitions throughout `Core.lua` and `Options.lua` — the standard WoW addon approach where `:` syntax is used for API consistency even when `self` is not accessed in the body.

Result: `luacheck Duncedmaxxing/` reports **0 warnings / 0 errors in 4 files**. No source code changes to `Core.lua` or `Options.lua` were needed.

### Task 2 — GitHub Actions release workflow

Created `.github/workflows/release.yml` with two jobs per D-14:

**lint-and-test job:**
- Triggers on: `release: types: [created]`, `push: branches: [main]`, `pull_request: branches: [main]`
- Installs `lua5.1 liblua5.1-0-dev luarocks` via apt, then `luacheck` and `busted` via luarocks
- Runs `luacheck Duncedmaxxing/` (0 warnings gate) and `busted spec/` (102-test suite)

**package-release job:**
- `needs: lint-and-test` — never runs if lint or tests fail
- `if: github.event_name == 'release'` — skips on push/PR events
- Extracts `github.ref_name`, strips `v` prefix via `${TAG#v}`, injects `VERSION` into `## Version:` field in `Duncedmaxxing/Duncedmaxxing.toc` via sed
- Creates `Duncedmaxxing-VERSION.zip` preserving the `Duncedmaxxing/` top-level folder for direct AddOns extraction
- Uploads via `softprops/action-gh-release@v2` with `prerelease: true` and `generate_release_notes: true`

## Verification Evidence

```
luacheck Duncedmaxxing/ → Total: 0 warnings / 0 errors in 4 files
busted spec/ → 102 successes / 0 failures / 0 errors / 0 pending
python3 yaml.safe_load → YAML valid
```

All D-06 through D-11, D-14 decisions satisfied:
- D-06: release trigger with softprops/action-gh-release@v2, prerelease: true
- D-07: zip -r preserves Duncedmaxxing/ top-level folder
- D-08: generate_release_notes: true
- D-09: workflow adapted from research YAML template
- D-10: sed injects git tag (v-prefix stripped) into TOC ## Version:
- D-11: ## Interface: 120005 not touched by CI
- D-14: separate lint-and-test job fires on every push/PR to main

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None — no stub patterns introduced.

## Threat Flags

No new security surface beyond what the plan's threat model covers (T-04-04 through T-04-SC).

## Self-Check: PASSED

- `.github/workflows/release.yml` exists: FOUND
- `.luacheckrc` contains "212/self": FOUND
- Task 1 commit `01c1f9a`: FOUND
- Task 2 commit `5437a90`: FOUND
- luacheck 0 warnings: CONFIRMED
- busted 102/0/0: CONFIRMED
- YAML valid: CONFIRMED
