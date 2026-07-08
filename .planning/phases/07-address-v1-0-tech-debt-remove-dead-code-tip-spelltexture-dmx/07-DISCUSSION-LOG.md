# Phase 7: Address v1.0 tech debt - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-08
**Phase:** 07-address-v1-0-tech-debt-remove-dead-code-tip-spelltexture-dmx
**Areas discussed:** Primal Surge dead state, Dead exports (spellTexture + ParseOnOff), Migration lock side effect, 265189 regression test hardening

---

## Primal Surge dead state

| Option | Description | Selected |
|--------|-------------|----------|
| Remove it entirely | Delete hasPrimalSurge field, init/reset, 3 tautological tests, contradictory comment; flat-2 becomes permanent. | ✓ |
| Keep field, RESERVED note | Keep field with explicit RESERVED note, delete only tautological tests, fix comment. | |

**User's choice:** Remove it entirely
**Notes:** Retires the "reserved for future ID resolution" placeholder. Flat-2 generator grant is the confirmed permanent behavior. Also drives the IN-01 comment rewrite (self-contradictory comment goes away with the field).

---

## Dead exports (Tip.spellTexture + DMX.Util.ParseOnOff)

| Option | Description | Selected |
|--------|-------------|----------|
| Remove both fully | Delete spellTexture + CacheSpellTexture + FALLBACK_ICON + PLAYER_LOGIN caching call, and ParseOnOff, plus all their tests. | ✓ |
| Remove ParseOnOff only | Remove ParseOnOff, keep spellTexture cache in case an icon/texture display returns. | |

**User's choice:** Remove both fully
**Notes:** No icon/texture display planned to return (icon mode removed Phase 5); no slash on/off parsing planned to return (slash reduced to settings-only, quick 260624-0hx).

---

## Migration lock side effect (NormalizeDB db.locked = true)

| Option | Description | Selected |
|--------|-------------|----------|
| Fix — preserve lock state | Remove `db.locked = true` from migration so user's unlock choice survives upgrades. | |
| Keep — always re-lock | Leave it; frame intentionally starts locked after every upgrade. | ✓ |

**User's choice:** Keep — always re-lock
**Notes:** Confirmed intended behavior — prevents accidental dragging after an upgrade. No code change beyond an intent comment so it isn't re-flagged by a future audit. Closes the audit's "confirm before shipping" concern.

---

## 265189 regression test hardening

| Option | Description | Selected |
|--------|-------------|----------|
| Add ClassifySpellID assertion | Assert ClassifySpellID(265189) == "consumer" (and 1262293/1262343 siblings); keep existing decrement test. Additive. | ✓ |
| Route test through dispatch | Rewrite to feed 265189 through classify→ApplySpell end-to-end. Larger rewrite. | |

**User's choice:** Add ClassifySpellID assertion
**Notes:** Additive hardening — guards CONSUMERS membership without a full dispatch rewrite. Extended to the Raptor Swipe siblings.

## Claude's Discretion

- Exact test-file restructuring (deleting emptied describe blocks vs. trimming) — planner/executor's call, suite must stay green with no orphaned references.
- Whether the db.locked intent comment is one line or a short block.

## Deferred Ideas

- Phase 2 `wow_stubs.lua makeAuraData` wiki-contract verification — real, but not in this phase's roadmap title; own follow-up.
- Nyquist validation coverage backfill for phases 00/01/02/04/05/06 — separate validation effort via `/gsd-validate-phase`.
