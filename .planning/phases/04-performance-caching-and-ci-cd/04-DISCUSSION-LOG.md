# Phase 4: Performance Caching and CI/CD - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-18
**Phase:** 4-Performance Caching and CI/CD
**Areas discussed:** Release distribution, Version management, Caching test coverage

---

## Release Distribution

| Option | Description | Selected |
|--------|-------------|----------|
| GitHub Release (Recommended) | Creates a tagged GitHub Release page with the zip as a downloadable asset | ✓ |
| Workflow artifact only | Zip is stored as a CI artifact — expires after 90 days | |
| You decide | Claude picks the approach | |

**User's choice:** GitHub Release
**Notes:** None

| Option | Description | Selected |
|--------|-------------|----------|
| All addon files (Recommended) | Everything in Duncedmaxxing/ directory, packaged with top-level folder | ✓ |
| TOC-listed files only | Only files explicitly listed or referenced in the TOC | |
| You decide | Claude determines file list | |

**User's choice:** All addon files
**Notes:** None

| Option | Description | Selected |
|--------|-------------|----------|
| Auto-generate from commits | GitHub's built-in auto-generate release notes feature | ✓ |
| Static changelog template | Workflow reads from a CHANGELOG.md file | |
| You decide | Claude picks based on project size | |

**User's choice:** Auto-generate from commits
**Notes:** None

| Option | Description | Selected |
|--------|-------------|----------|
| Design from scratch | Claude creates the workflow from standard patterns | |
| I'll provide one | User supplies a sample .yml for adaptation | ✓ |

**User's choice:** Provided a sample workflow file from SimpleCursorRing addon
**Notes:** Workflow triggers on `release: [created]`, uses `softprops/action-gh-release@v2`, zips addon directory, marks releases as prerelease. User pasted the full YAML contents inline.

---

## Version Management

| Option | Description | Selected |
|--------|-------------|----------|
| CI injects tag version (Recommended) | Workflow runs sed to replace ## Version: in TOC with tag name | ✓ |
| Manual version only | User updates ## Version: before tagging | |
| You decide | Claude picks the approach | |

**User's choice:** CI injects tag version
**Notes:** None

| Option | Description | Selected |
|--------|-------------|----------|
| Keep manual (Recommended) | Interface version only changes when targeting a new WoW patch | ✓ |
| CI updates from env var | Store interface version in a GitHub variable | |
| You decide | Claude picks based on project needs | |

**User's choice:** Keep manual
**Notes:** None

---

## Caching Test Coverage

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, add tests (Recommended) | State-based tests for caching behavior, consistent with test-first approach | ✓ |
| No tests for caching | Caching is straightforward, tests would assert implementation details | |
| You decide | Claude judges complexity | |

**User's choice:** Yes, add tests
**Notes:** None

| Option | Description | Selected |
|--------|-------------|----------|
| State-based (Recommended) | Verify cached fields are populated and change on correct events | ✓ |
| Call-count spy | Mock with spy, assert zero calls during Update | |
| Both | Belt and suspenders approach | |
| You decide | Claude picks based on existing test patterns | |

**User's choice:** State-based
**Notes:** None

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, add lint+test job (Recommended) | Run luacheck + busted on every push to main and PRs | ✓ |
| Release workflow only | Keep CI scope to just release packaging | |
| You decide | Claude determines fit | |

**User's choice:** Yes, add lint+test job
**Notes:** None

---

## Claude's Discretion

- D-02 scope: whether to inline cached check in Update or factor into helper
- D-04 implementation: whether to refactor ResolveSpellTexture or replace entirely
- D-14 details: CI job structure (matrix vs single, Lua version pinning, luarocks caching)

## Deferred Ideas

None — discussion stayed within phase scope
