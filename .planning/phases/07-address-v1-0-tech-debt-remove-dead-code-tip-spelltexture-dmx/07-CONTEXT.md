# Phase 7: Address v1.0 tech debt - Context

**Gathered:** 2026-07-08
**Status:** Ready for planning

<domain>
## Phase Boundary

Clean up the non-blocking tech debt surfaced by the v1.0 milestone audit (`.planning/v1.0-MILESTONE-AUDIT.md`). No new user-facing capability. Specifically:

1. Remove dead code left behind by earlier phase boundaries (`Tip.spellTexture`, `DMX.Util.ParseOnOff`, `hasPrimalSurge`).
2. Fix misleading test scaffolding (3 tautological Primal Surge tests; the 265189 regression test that bypasses `ClassifySpellID`).
3. Fix the self-contradictory generator-branch comment (IN-01).
4. Confirm/document the `NormalizeDB` `db.locked = true` migration side effect.

The full test suite (fengari harness, `spec/run.cjs`) must stay green throughout, and `luacheck` must stay at zero warnings.

**Explicitly OUT of scope for this phase** (listed in the audit but not named in the roadmap phase title): the Phase 2 `wow_stubs.lua makeAuraData` wiki-contract verification, and the Nyquist validation-coverage backfill for phases 00/01/02/04/05/06. Those are separate follow-ups — see Deferred Ideas.
</domain>

<decisions>
## Implementation Decisions

### Dead code: hasPrimalSurge
- **D-01:** Remove `hasPrimalSurge` entirely. Delete the field (`TipOfTheSpear.lua:64`), its reset in `spec/support/init.lua:62`, and any other init/reset sites. Treat the flat-2 generator grant as the confirmed permanent behavior — the "reserved for future ID resolution" placeholder is being retired, not preserved.
- **D-02:** Delete the 3 tautological Primal Surge tests in `spec/tip_spec.lua` (the pair at ~139-143 and ~146-151 that vary `hasPrimalSurge` but always assert 2, plus the Twin-Fangs-independence test's `hasPrimalSurge` toggling — keep genuine BASE/Twin-Fangs coverage, just drop the `hasPrimalSurge` variable from it). Net: no test references `hasPrimalSurge` after this phase.
- **D-03:** Rewrite the generator-branch comment (`TipOfTheSpear.lua:656-659`) to remove the self-contradiction (IN-01). It should state plainly that the grant is always 2 stacks — drop the "base 1, +1 with Primal Surge" framing and the "hasPrimalSurge field reserved" note (the field no longer exists).

### Dead code: unconsumed exports
- **D-04:** Remove `Tip.spellTexture` fully. Delete the field (`TipOfTheSpear.lua:65`), the `CacheSpellTexture` function and its `FALLBACK_ICON`, the `PLAYER_LOGIN`/`PLAYER_ENTERING_WORLD` caching call (`TipOfTheSpear.lua:696`), the reset in `spec/support/init.lua:64`, and the 2 spellTexture tests in `spec/tip_spec.lua` (~518, ~524, and the surrounding describe block if it becomes empty). No icon/texture display is planned to return.
- **D-05:** Remove `DMX.Util.ParseOnOff` fully. Delete the local function and the `Util.ParseOnOff` export in `Duncedmaxxing/Util.lua`, and the entire `DMX.Util.ParseOnOff` describe block in `spec/util_spec.lua` (~122-183). No slash on/off parsing is planned to return (slash is settings-only).

### Test hardening: 265189 regression
- **D-06:** Harden the 265189 test by adding an explicit assertion that `ClassifySpellID(265189) == "consumer"` (so the test guards CONSUMERS membership, not just the decrement math). Apply the same classify assertion to the Raptor Swipe siblings `1262293` and `1262343`. Keep the existing direct-decrement assertions too — this is additive, not a full rewrite through the event dispatch.

### Migration side effect: db.locked
- **D-07:** Keep the `db.locked = true` line in the `NormalizeDB` migration block (`Core.lua:123`) — it is intended behavior. The frame deliberately starts locked after every settings-migration upgrade so it can't be accidentally dragged. No code change; close the audit concern by documenting it as designed (a brief comment on that line is fine so it isn't re-flagged in a future audit).

### Claude's Discretion
- Exact test-file restructuring (whether to delete an emptied `describe` block vs. leave a trimmed one) is at the planner/executor's discretion, as long as the suite stays green and no orphaned references to removed symbols remain.
- Whether the `db.locked` intent comment is one line or a short block.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Source of scope
- `.planning/v1.0-MILESTONE-AUDIT.md` — the audit that surfaced every item in this phase; frontmatter `tech_debt` block is the authoritative item list. Read before planning.

### Code touched
- `Duncedmaxxing/Modules/TipOfTheSpear.lua` — `hasPrimalSurge` (line 64), `Tip.spellTexture` (line 65), `CacheSpellTexture` + `FALLBACK_ICON` (~147-158), generator branch + comment (652-659), `PLAYER_LOGIN` caching call (696), `CONSUMERS` table incl. 265189 (line 25).
- `Duncedmaxxing/Util.lua` — `ParseOnOff` local + export (lines 18, 42).
- `Duncedmaxxing/Core.lua` — `NormalizeDB` migration block incl. `db.locked = true` (112-130).
- `spec/tip_spec.lua` — Primal Surge tests (~128-151), spellTexture tests (~480-527), 265189 regression test (~202-213).
- `spec/util_spec.lua` — ParseOnOff describe block (~122-183).
- `spec/support/init.lua` — per-test resets for `hasPrimalSurge` (62) and `spellTexture` (64).

### Test harness
- `spec/run.cjs` — fengari (Lua-VM-in-JS) runner; the suite runs here, not native busted. Must stay green (was 125/125 at audit time).

No external ADRs/specs beyond the audit — decisions above fully capture the intent.
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `ClassifySpellID` (TipOfTheSpear.lua) — already returns "consumer"/"generator"/nil via plain table lookup on `CONSUMERS`/`GENERATORS`; D-06 just asserts against it, no change to the function.
- `spec/support/init.lua` per-test reset harness — the single place that zeroes Tip module state between tests; removing a field means removing its reset line here too.

### Established Patterns
- Dead-code removal precedent: Phase 3 (QUAL-03) removed the dead migration fallback under test protection; Phase 5 removed icon mode. Same pattern — delete production symbol + its tests together, confirm suite green.
- Flat-2 generator grant is the deliberate offline-safe fallback (STATE.md decision log: "Primal Surge spell ID unverifiable offline; flat-2 fallback"). D-01 makes it permanent rather than provisional.

### Integration Points
- Removing `CacheSpellTexture` touches the `PLAYER_LOGIN`/`PLAYER_ENTERING_WORLD` event handler — verify no other line reads `tip.spellTexture` after removal (grep confirmed only the definition, comment, one assignment, and tests reference it).
- `Util.lua` load order is early in the TOC; removing an export is safe because grep confirms zero production callers.
</code_context>

<specifics>
## Specific Ideas

- The migration lock (D-07) confirmation came with a clear rationale from the user: the frame should start locked after upgrades to prevent accidental dragging. Preserve that intent in a comment so it survives future audits.
- Prefer additive test hardening (D-06) over large rewrites — keep existing passing assertions, add the classify guard alongside.
</specifics>

<deferred>
## Deferred Ideas

- **`wow_stubs.lua` makeAuraData contract verification** — the Phase 2 deferred human item (verify makeAuraData fields against warcraft.wiki.gg `Struct_AuraData`) is real but not named in this phase's roadmap title. Belongs in its own quick task or a validation follow-up, not this cleanup phase.
- **Nyquist validation coverage** — phases 00/01/02/04 have draft (non-compliant) VALIDATION.md; 05/06 have none. Backfilling via `/gsd-validate-phase` is a separate documentation/validation effort, out of scope here.

</deferred>

---

*Phase: 7-address-v1-0-tech-debt-remove-dead-code-tip-spelltexture-dmx*
*Context gathered: 2026-07-08*
