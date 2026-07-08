---
phase: 07-address-v1-0-tech-debt-remove-dead-code-tip-spelltexture-dmx
reviewed: 2026-07-08T21:42:13Z
depth: standard
files_reviewed: 6
files_reviewed_list:
  - Duncedmaxxing/Modules/TipOfTheSpear.lua
  - Duncedmaxxing/Util.lua
  - Duncedmaxxing/Core.lua
  - spec/tip_spec.lua
  - spec/util_spec.lua
  - spec/support/init.lua
findings:
  critical: 0
  warning: 0
  info: 1
  total: 1
status: issues_found
---

# Phase 07: Code Review Report

**Reviewed:** 2026-07-08T21:42:13Z
**Depth:** standard
**Files Reviewed:** 6
**Status:** issues_found

## Summary

This phase is a surgical tech-debt deletion: `hasPrimalSurge` (dead field), `Tip.spellTexture` / `CacheSpellTexture` / `FALLBACK_ICON` (dead since icon mode was removed in Phase 5), and `DMX.Util.ParseOnOff` (dead since the slash command surface was reduced to settings-only) were all removed, alongside a matching test-export addition (`Tip._test.ClassifySpellID`) and new `ClassifySpellID` consumer-membership assertions.

I traced every removed symbol (`hasPrimalSurge`, `spellTexture`, `CacheSpellTexture`, `FALLBACK_ICON`, `C_Spell.GetSpellTexture`/`GetSpellTexture` call sites, `ParseOnOff`) across the full repository, not just the six listed files, and found no dangling callers, no stale comments referencing icon mode, and no leftover module-level locals in the production Lua files. `Tip._test` is added in the same unconditional, always-loaded style as the existing `DMX._test` in `Core.lua`, correctly matching that established convention (project instructions explicitly call this out as the pattern to match), and it only exposes a pure, read-only local function reference — no production behavior change, no combat-lockdown implication (no frame mutation), no Lua 5.1 compatibility concern.

The generator-branch comment rewrite in `Tip:ApplySpell` (`Duncedmaxxing/Modules/TipOfTheSpear.lua:638-640`) accurately reflects the code below it: `grant` is now unconditionally `2` with no remaining reference to Primal Surge or `hasPrimalSurge`. The `NormalizeDB` intent comment added in `Duncedmaxxing/Core.lua:123-124` is a comment-only change and accurately describes the `db.locked = true` line it precedes.

The one finding below is outside the six files formally in scope for this review, but it is a direct, provable consequence of this phase's deletions (`CacheSpellTexture` removal) and matches the explicit "orphaned references to removed symbols" focus area for this review, so it is reported for completeness.

## Info

### IN-01: Orphaned `GetSpellTexture` mock stubs left in test support after `CacheSpellTexture` removal

**File:** `spec/support/wow_stubs.lua:175-179` (not in this phase's formal file list, but directly orphaned by the removal of `CacheSpellTexture` from `Duncedmaxxing/Modules/TipOfTheSpear.lua`)
**Issue:** `wow_stubs.lua` still installs `_G.C_Spell.GetSpellTexture` and `_G.GetSpellTexture` mocks (both returning `132275`). These stubs existed solely to backstop `Tip:CacheSpellTexture`'s dual-path API call. Now that `CacheSpellTexture`, `Tip.spellTexture`, and `FALLBACK_ICON` have all been deleted from `TipOfTheSpear.lua`, nothing in the addon or in `spec/tip_spec.lua`/`spec/util_spec.lua` calls `C_Spell.GetSpellTexture` or `GetSpellTexture` anymore — these two stub entries are now dead test fixture code with no exerciser.
**Fix:** Remove the now-unused stub entries for consistency with the rest of this cleanup pass:
```lua
-- Duncedmaxxing/wow_stubs.lua — delete these lines (no longer exercised):
-- _G.C_Spell = {
--     GetSpellTexture = function(id) return 132275 end,
-- }
-- _G.GetSpellTexture = function(id) return 132275 end
```
Note: `makeAuraData`'s `icon = 132275` field (line 58) is a legitimate `Struct_AuraData.icon` fixture value unrelated to `GetSpellTexture` and should be left in place.

---

_Reviewed: 2026-07-08T21:42:13Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
