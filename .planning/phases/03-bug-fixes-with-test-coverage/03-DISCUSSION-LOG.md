# Phase 3: Bug Fixes with Test Coverage - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-18
**Phase:** 03-bug-fixes-with-test-coverage
**Areas discussed:** Talent detection, Mode-switch refresh, Migration cleanup

---

## Talent Detection

### Q1: How should the addon detect whether Twin Fangs talent is active?

| Option | Description | Selected |
|--------|-------------|----------|
| Dual-path check | C_SpellBook.IsSpellKnown(1272139) with fallback to IsPlayerSpell(1272139). Future-proof, matches existing dual-path pattern. | ✓ |
| IsPlayerSpell only | IsPlayerSpell(1272139). Most battle-tested for passive talents. Deprecated but still works on 12.0.5. | |
| You decide | Let Claude pick based on codebase patterns. | |

**User's choice:** Dual-path check
**Notes:** User requested research on what other addons do before deciding. Research found: WeakAuras2, SpellFlash, LiteMount, LibSpellbook use IsPlayerSpell; LibSpellbook migrating to C_SpellBook.IsSpellKnown; TrueShot (Hunter addon) uses C_ClassTalents.GetActiveHeroTalentSpec with IsPlayerSpell fallback.

### Q2: How should talent state map to stack grant amounts in ApplySpell?

| Option | Description | Selected |
|--------|-------------|----------|
| Classify returns amount | ClassifySpellID returns grant amount directly. Talent check inside ClassifySpellID. | |
| Separate talent table | Keep generator/consumer kinds. New GetStackGrant function maps kind + talent state to amount. | |
| You decide | Let Claude pick whichever produces cleanest code. | ✓ |

**User's choice:** You decide (Claude discretion)

### Q3: When should the addon refresh its cached Twin Fangs talent state?

| Option | Description | Selected |
|--------|-------------|----------|
| Talent events only | Cache on PLAYER_TALENT_UPDATE and PLAYER_SPECIALIZATION_CHANGED. No per-cast check. | ✓ |
| Per-cast check | Call talent API on every UNIT_SPELLCAST_SUCCEEDED. Simplest, avoids stale cache. | |
| You decide | Let Claude pick. | |

**User's choice:** Talent events only

### Q4: Twin Fangs + Takedown stack mechanics

| Option | Description | Selected |
|--------|-------------|----------|
| Pure grant (+3) | Takedown becomes generator granting 3, replacing consumer behavior. Net +3. | |
| Grant + consume (net +2) | Takedown still consumes 1, talent grants 3. Net +2. | ✓ |
| Not sure | Need to verify in-game. | |

**User's choice:** Grant + consume (net +2)
**Notes:** User corrected Claude's understanding of the order of operations. The grant fires FIRST (cap at 3), THEN the consume fires (-1). Example: 1 stack → grant 3 (cap to 3) → consume 1 → 2 stacks. NOT consume first then grant.

---

## Mode-Switch Refresh

### Q1: When switching display modes out of combat, always sync or conditional?

| Option | Description | Selected |
|--------|-------------|----------|
| Always sync | Call SyncFromAura unconditionally on every mode switch. | |
| Conditional sync | Only sync if out of combat AND stacks > 0. | |
| You decide | Let Claude pick based on code structure. | ✓ |

**User's choice:** You decide (Claude discretion)

### Q2: Should refresh apply to mode changes only or any settings change?

| Option | Description | Selected |
|--------|-------------|----------|
| Mode changes only | Only trigger aura refresh on displayMode changes. | |
| Any settings change | Trigger aura refresh on any settings mutation out of combat. | |
| You decide | Let Claude decide the scope. | ✓ |

**User's choice:** You decide (Claude discretion)

---

## Migration Cleanup

### Q1: Should removing dead fallback block also bump SETTINGS_MIGRATION?

| Option | Description | Selected |
|--------|-------------|----------|
| Just remove | Delete lines 98-106 only. No version bump. Dead code removal. | ✓ |
| Remove + bump version | Delete lines 98-106 AND bump SETTINGS_MIGRATION. Forces full settings reset. | |
| You decide | Let Claude decide. | |

**User's choice:** Just remove

---

## Claude's Discretion

- Stack grant mapping structure (D-04 implementation): how ClassifySpellID and ApplySpell interact with talent-aware amounts
- Mode-switch sync trigger scope: mode changes only vs any settings change
- Mode-switch sync condition: unconditional vs conditional on current stack state

## Deferred Ideas

None — discussion stayed within phase scope
