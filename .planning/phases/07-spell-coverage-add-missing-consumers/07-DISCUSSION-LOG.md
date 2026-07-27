# Phase 7: Spell Coverage — Add Missing Consumers - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-27
**Phase:** 07-spell-coverage-add-missing-consumers
**Areas discussed:** Spell ID verification, Consumer behavior differences, Talent gating

---

## Spell ID Verification

| Option | Description | Selected |
|--------|-------------|----------|
| Single ID each | Each spell has exactly one spell ID. No variants to track. | |
| Some have variants | One or more spells have alternate IDs that also need to be added. | |
| Not sure — researcher should check | Flag this for the researcher to verify on warcraft.wiki.gg or wowhead before implementation. | ✓ |

**User's choice:** Not sure — researcher should check
**Notes:** Flagged for researcher to verify whether Moonlight Chakram or Hatchet Toss have alternate spell IDs (similar to Raptor Strike's Eagle variant pattern).

---

## Consumer Behavior Differences

| Option | Description | Selected |
|--------|-------------|----------|
| All plain consumers | All consume exactly 1 stack. No special talent interactions or modified grant amounts. | ✓ |
| Some have special mechanics | One or more has talent interactions or unusual consumption behavior. | |
| Not sure — researcher should check | Flag for the researcher to verify consumption behavior. | |

**User's choice:** All plain consumers. Also: skip adding Flamefang Pitch.
**Notes:** User explicitly dropped Flamefang Pitch (1251592) from scope. Phase reduced from 3 spells to 2: Moonlight Chakram (1264902) and Hatchet Toss (193265).

---

## Talent Gating

| Option | Description | Selected |
|--------|-------------|----------|
| Unconditional (Recommended) | Add both IDs to CONSUMERS table statically. No talent check needed. | ✓ |
| Talent-conditional | Only track when the relevant talent is active. Adds complexity for no real benefit. | |

**User's choice:** Unconditional
**Notes:** Same approach as all existing consumers. Unused spell IDs in the table are harmless.

---

## Claude's Discretion

- Exact ordering of new entries within the CONSUMERS table.
- Test assertion style and grouping.
- UAT checklist format and location.

## Deferred Ideas

- Flamefang Pitch (1251592) — explicitly dropped by user. Can be reconsidered in future if needed.
