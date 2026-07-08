# Project Retrospective

*A living document updated after each milestone. Lessons feed forward into future planning.*

## Milestone: v1.0 — Polish Pass

**Shipped:** 2026-07-09
**Phases:** 8 | **Plans:** 25 | **Tasks:** 39

### What Was Built
- Repo hygiene + nested addon layout, shared-utility extraction (`Util.lua`), frame refs on the `Tip` table, ordered module iteration
- Offline test suite (busted → fengari Lua-VM-in-JS harness) with accurate WoW API stubs and `.luacheckrc` — 111 passing tests
- Correctness fixes under test: Kill Command over-count flicker, Raptor Strike lag under Aspect of the Eagle, Twin Fangs grant ordering, stuck `auraVerifyPending`
- Event-driven `isSurvival`/texture caches removing per-frame WoW API calls; GitHub Actions release workflow on `main`
- Display modes collapsed to `bar` + `number`; per-mode options visibility + user-configurable per-stack colors with migration-safe defaults
- Dead-code sweep (Phase 7): removed 5 dead symbols, hardened tautological tests into real `ClassifySpellID` consumer-membership assertions

### What Worked
- **Test-first bug fixes** — Phase 2's suite meant every Phase 3 correctness fix landed with a regression test, and later refactors (5–7) could delete code aggressively behind a green suite.
- **Gap-closure via UAT feedback** — Phase 01's in-game UAT surfaced two real runtime bugs (KC over-count, Raptor Strike lag) that static analysis missed; the diagnose→plan→fix→re-UAT loop closed them cleanly.
- **Audit-then-cleanup sequencing** — the first v1.0 audit surfaced dead code as tech debt; inserting Phase 7 to burn it down (rather than shipping with it) kept the codebase honest.

### What Was Inefficient
- **Environment/toolchain churn** — the sandbox couldn't install lua5.1/luarocks, forcing a mid-milestone pivot from busted to a hand-built fengari runner (`spec/run.cjs`). Discovered during Phase 2, re-confirmed in Phase 5.
- **luacheck never actually ran** — the "0 warnings" gate was reasoned about for the whole milestone but never executed locally; the CI `lint.yml` that would run it was even left uncommitted until milestone close. Verification claims outran verification reality.
- **Requirement-wording drift** — accepted UI overrides (Enabled checkbox removal, button-only mode switching) required a dedicated paperwork plan (06-08) to realign ROADMAP/REQUIREMENTS wording after the fact.
- **SUMMARY frontmatter inconsistency** — `requirements-completed` and `status` fields were populated unevenly, which made the milestone-close artifact audit flag several already-done items.

### Patterns Established
- **fengari harness** (`spec/run.cjs`) as the canonical offline test runner when no native Lua toolchain exists
- **Config-driven over hardcoded** — `STACK_COLORS` → configurable `stackColors` with named-key `{r,g,b,a}` format and a targeted (not blanket) migration re-seed
- **`Tip._test` export** as the escape hatch for unit-testing internal functions without exposing them to the addon runtime
- **Accepted-override records** in VERIFICATION.md frontmatter for user-approved deviations from stated success criteria

### Key Lessons
1. **Verify the verifier's environment first.** A "0 warnings"/"tests pass" claim is only as good as the tool that produced it actually running — wire lint/test into committed CI early, don't defer it to reasoning.
2. **In-game/manual UAT catches what the offline harness structurally can't.** Runtime timing and Widget-UI behavior (Options.lua is never loaded by the harness) need human smoke tests; route them explicitly rather than claiming full proof.
3. **Delete dead code in its own phase, behind a green suite.** Phase 7's grep-absence + suite-green gate made an aggressive removal safe and auditable.
4. **Keep planning-artifact frontmatter statuses terminal and consistent** — stale `human_needed`/`diagnosed`/missing-`status` fields create phantom gaps at milestone close.

### Cost Observations
- Model mix: not tracked this milestone
- Notable: heavy use of gap-closure quick tasks (`260617`, `260622-*`) alongside formal phases; several phases required re-verification cycles (01, 06) driven by UAT findings.

---

## Cross-Milestone Trends

### Process Evolution

| Milestone | Phases | Plans | Key Change |
|-----------|--------|-------|------------|
| v1.0 | 8 | 25 | Established GSD workflow, offline fengari test harness, audit→cleanup sequencing |

### Cumulative Quality

| Milestone | Tests | Harness | Zero-Dep Additions |
|-----------|-------|---------|--------------------|
| v1.0 | 111 | fengari (Lua-VM-in-JS) | 0 (intentionally dependency-free) |

### Top Lessons (Verified Across Milestones)

1. _(pending a second milestone to cross-validate)_
