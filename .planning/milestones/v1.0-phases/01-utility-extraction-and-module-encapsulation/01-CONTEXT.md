# Phase 1: Utility Extraction and Module Encapsulation - Context

**Gathered:** 2026-06-17
**Status:** Ready for planning

<domain>
## Phase Boundary

The codebase has a clean structural foundation — shared utilities live in one place, frame references are accessible for testing, and module iteration is ordered. This phase delivers QUAL-01, QUAL-02, QUAL-04, and QUAL-05 from REQUIREMENTS.md.

</domain>

<decisions>
## Implementation Decisions

### Utility Extraction (QUAL-01)
- **D-01:** Extract exactly 4 functions to `Duncedmaxxing/Util.lua`: `Clamp`, `ParseHexColor`, `Trim`, `ParseOnOff`. Do NOT include `ToByte`, `ColorToHex`, `CopyDefaults`, or `MergeDefaults` — those are single-file helpers, not shared utilities.
- **D-02:** Expose utilities as `DMX.Util.Clamp`, `DMX.Util.ParseHexColor`, `DMX.Util.Trim`, `DMX.Util.ParseOnOff` (namespaced under a `Util` table on DMX).
- **D-03:** Consumer files that use utilities frequently should assign local aliases at file top: `local Clamp = DMX.Util.Clamp`. This is standard WoW addon practice — keeps call sites clean and avoids double table lookup overhead.
- **D-04:** The canonical `ParseHexColor` uses the Trim-based approach from Core.lua (`Trim(value)` at entry), NOT the `tostring(value or "")` approach from Options.lua. This keeps nil-handling consistent with how Trim is used everywhere else.
- **D-05:** `Util.lua` must be listed in the TOC before `Core.lua` so utilities are available when Core loads.

### Frame Reference Migration (QUAL-02)
- **D-06:** Move all 5 module-level frame locals (`root`, `pips`, `borders`, `label`, `numberText`) from bare upvalues in TipOfTheSpear.lua to `Tip.root`, `Tip.pips`, `Tip.borders`, `Tip.label`, `Tip.numberText` fields on the Tip table.
- **D-07:** `EnsureFrame()` writes frames directly to `self.root`, `self.pips`, etc. — clean ownership model where EnsureFrame creates frames and stores them on self.
- **D-08:** Hot-path functions (`Update`, `RefreshLayout`) create local aliases at function entry: `local root, pips = self.root, self.pips`. This preserves Lua 5.1 local-access performance (~30% faster than table field reads) for combat-frequency code paths.

### Module Ordering (QUAL-04)
- **D-09:** Maintain a `moduleOrder` array that appends each module key in the order `RegisterModule` is called. Since the TOC controls file load order and `RegisterModule` is called at file parse time, the order is deterministic from the TOC declaration — no explicit priority parameter needed.
- **D-10:** `ForEachModule` iterates `moduleOrder` (the ordered array) instead of using `pairs(self.modules)`.

### ClassifySpellID Cleanup (QUAL-05)
- **D-11:** Remove the `pcall` wrapper from `ClassifySpellID`. It performs a pure table lookup and equality check — neither can raise a Lua error. Return directly from the function body.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project Context
- `.planning/PROJECT.md` — Core value, constraints, and key decisions
- `.planning/REQUIREMENTS.md` — QUAL-01, QUAL-02, QUAL-04, QUAL-05 define exact deliverables

### Architecture & Patterns
- `.planning/codebase/ARCHITECTURE.md` — Module registration pattern, data flow, entry points (RegisterModule at line 140, ForEachModule at line 157, ADDON_LOADED at line 356)
- `.planning/codebase/CONCERNS.md` — Tech debt items driving this phase (duplicated utils, frame locals, unordered ForEachModule, unnecessary pcall)
- `.planning/codebase/CONVENTIONS.md` — Naming patterns, code style constraints

### Source Files (read before modifying)
- `Duncedmaxxing/Core.lua` — Contains Clamp, ParseHexColor, Trim, ParseOnOff definitions (lines 38-70), module registry (lines 140-165), ForEachModule (line 157)
- `Duncedmaxxing/Options.lua` — Contains duplicate Clamp (line 17), duplicate ParseHexColor (line 25)
- `Duncedmaxxing/Modules/TipOfTheSpear.lua` — Contains frame locals (lines 32-36), ClassifySpellID with pcall (lines 56-70), EnsureFrame (line 292)
- `Duncedmaxxing/Duncedmaxxing.toc` — File load order; Util.lua must be inserted before Core.lua (line 10)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `DMX` namespace table: shared via `local _, DMX = ...` vararg idiom in every file — Util.lua will use the same pattern
- `DEFAULTS` table in Core.lua (lines 11-34): not affected by this phase, but utilities are used by the slash command handler that reads/writes defaults
- `EnsureFrame()` in TipOfTheSpear.lua (line 292): already an idempotency guard — needs modification to write to `self.*` instead of upvalue locals

### Established Patterns
- WoW addon private namespace via vararg: `local _, DMX = ...` at file top
- Module self-registration: `DMX:RegisterModule("key", table)` at file bottom
- Local function declarations at file top before any method definitions
- `GetCfg()` helper pattern: local function returning `DMX:GetDB().tip` for config access

### Integration Points
- TOC file (`Duncedmaxxing.toc`): must add `Util.lua` as first entry (before `Core.lua`)
- Core.lua slash command handler (lines 226-353): calls Clamp, ParseHexColor, ParseOnOff — will need local aliases from DMX.Util
- Options.lua color input widgets: call Clamp and ParseHexColor — will need local aliases from DMX.Util
- All functions in TipOfTheSpear.lua that reference `root`, `pips`, `borders`, `label`, `numberText` as bare locals: must change to `self.*` access pattern

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 1-Utility Extraction and Module Encapsulation*
*Context gathered: 2026-06-17*
