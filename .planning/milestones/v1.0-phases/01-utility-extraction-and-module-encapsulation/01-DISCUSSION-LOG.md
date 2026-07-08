# Phase 1: Utility Extraction and Module Encapsulation - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-17
**Phase:** 1-Utility Extraction and Module Encapsulation
**Areas discussed:** ParseHexColor divergence, Extraction scope, Frame ref hot-path perf, Module ordering

---

## ParseHexColor Divergence

| Option | Description | Selected |
|--------|-------------|----------|
| Trim-based | Use Trim(value) like Core.lua. Nil-safe via Trim's (text or "") guard, handles whitespace. Simpler, consistent with the other utils. | ✓ |
| tostring-based | Use tostring(value or "") like Options.lua. Explicit type coercion. Slightly more defensive but adds a step Trim already covers. | |
| You decide | Let the implementer pick whichever is cleaner. | |

**User's choice:** Trim-based
**Notes:** No additional notes — straightforward preference for consistency with existing Trim usage.

---

## Extraction Scope

### Which functions to extract

| Option | Description | Selected |
|--------|-------------|----------|
| Only the 4 | Extract exactly what QUAL-01 specifies. ToByte and ColorToHex are only used in Options.lua — not duplicated. Keep Util.lua minimal. | ✓ |
| Include color helpers too | Pull ToByte and ColorToHex into Util.lua as well. Groups all color-related utilities together. | |
| You decide | Let the implementer judge based on what feels cleanest. | |

**User's choice:** Only the 4 (Clamp, ParseHexColor, Trim, ParseOnOff)
**Notes:** None.

### How consumers access utilities

| Option | Description | Selected |
|--------|-------------|----------|
| Local aliases | Each file assigns locals at top: `local Clamp = DMX.Util.Clamp`. Standard WoW addon pattern. | ✓ |
| Always DMX.Util.X | Always call DMX.Util.Clamp directly. More explicit but verbose. | |
| You decide | Let implementer pick per-file based on usage frequency. | |

**User's choice:** Local aliases
**Notes:** None.

---

## Frame Ref Hot-Path Perf

### Local aliases in hot-path functions

| Option | Description | Selected |
|--------|-------------|----------|
| Local aliases in hot path | Update() and RefreshLayout() start with `local root, pips = self.root, self.pips`. Preserves Lua 5.1 local-access performance. | ✓ |
| Always use self.field | Use self.root everywhere for consistency. Perf difference negligible for a single addon. | |
| You decide | Let implementer judge per-function. | |

**User's choice:** Local aliases in hot path
**Notes:** None.

### EnsureFrame ownership

| Option | Description | Selected |
|--------|-------------|----------|
| EnsureFrame writes to self | EnsureFrame() sets self.root, self.pips, etc. directly. Clean ownership model. | ✓ |
| You decide | Let implementer work out EnsureFrame internals. | |

**User's choice:** EnsureFrame writes to self
**Notes:** None.

---

## Module Ordering

| Option | Description | Selected |
|--------|-------------|----------|
| Registration order | Maintain moduleOrder array appending keys in RegisterModule call order. TOC controls file load, so order is deterministic from TOC declaration. | ✓ |
| Explicit priority param | Add optional priority number to RegisterModule. More flexible but over-engineered for single-module case. | |
| You decide | Let implementer pick simplest approach. | |

**User's choice:** Registration order
**Notes:** None.

---

## Claude's Discretion

No areas were deferred to Claude's discretion — user made explicit choices on all decisions.

## Deferred Ideas

None — discussion stayed within phase scope.
