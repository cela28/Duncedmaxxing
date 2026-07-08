# Milestones

## v1.0 Polish Pass (Shipped: 2026-07-09)

**Phases completed:** 8 phases, 25 plans, 39 tasks
**Requirements:** 31/31 satisfied · **Tests:** 111-test fengari suite green · **Timeline:** 2026-06-17 → 2026-07-09

**Delivered:** Transformed a working-but-untested WoW addon into a structurally clean, fully tested, performant one — repo hygiene, shared-utility extraction, an offline test suite, correctness bug fixes, performance caching, a two-mode display refactor, a per-mode options panel with configurable stack colors, and a dead-code sweep.

**Key accomplishments:**

- **Repo hygiene & structure** — removed 8 `:Zone.Identifier` NTFS artifacts + 2 stale docs, added a WoW-addon `.gitignore`, and moved the addon into a nested `Duncedmaxxing/` layout matching standard conventions (Phase 0).
- **Structural foundation** — extracted shared utilities to `Util.lua` (single source), moved frame references onto the `Tip` table for testability, and made module iteration deterministic via `moduleOrder` (Phase 1).
- **Offline test suite** — stood up the busted→fengari (Lua-VM-in-JS) harness with accurate WoW API stubs and a curated `.luacheckrc`; grew to 111 passing tests covering utilities, DB migration, `ApplySpell`, and `SyncFromAura` (Phase 2).
- **Correctness fixes under test** — cleared the Kill Command 3-then-2 flicker (generator grant decoupled from Twin Fangs), the Raptor Strike lag under Aspect of the Eagle (265189 registered as a consumer), Twin Fangs Takedown grant-then-consume ordering, and the stuck `auraVerifyPending` flag (Phase 3).
- **Performance & CI/CD** — event-driven `isSurvival`/texture caches removed per-frame WoW API calls from the render hot path; added the GitHub Actions release workflow on `main` (Phase 4).
- **Display & options overhaul** — collapsed display modes to exactly `bar` + `number` (icon mode fully excised), gated options widgets per active mode, and made per-stack number colors user-configurable with a migration-safe default merge (Phases 5–6).
- **Tech-debt sweep** — removed five dead-code symbols (`hasPrimalSurge`, `Tip.spellTexture`/`CacheSpellTexture`/`FALLBACK_ICON`, `DMX.Util.ParseOnOff`), hardened tautological tests into real `ClassifySpellID` consumer-membership assertions, and documented the `db.locked` migration intent (Phase 7).

**Known deferred items at close:** none blocking. Residual: confirm the newly-committed luacheck CI job (`lint.yml`) runs green on next push; two accepted narrow Phase-06 UI edge cases (WR-01/WR-02). See `milestones/v1.0-MILESTONE-AUDIT.md`.

---
