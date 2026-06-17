---
phase: 01-utility-extraction-and-module-encapsulation
verified: 2026-06-17T13:30:00Z
status: human_needed
score: 4/5 must-haves verified
overrides_applied: 0
human_verification:
  - test: "Load the addon in-game (or /reload ui with addon active) and observe the tracker display"
    expected: "No Lua errors appear in chat, tracker bar/icons mode renders at screen center, stack count updates on Kill Command cast"
    why_human: "WoW Lua sandbox execution cannot be replicated by grep. Success criterion 5 requires actual client load to confirm no nil-index crashes from EnsureFrame migration or alias resolution failures."
---

# Phase 1: Utility Extraction and Module Encapsulation — Verification Report

**Phase Goal:** The codebase has a clean structural foundation — shared utilities live in one place, frame references are accessible for testing, and module iteration is ordered.
**Verified:** 2026-06-17T13:30:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (from ROADMAP.md Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| SC-1 | `DMX.Util.Clamp`, `DMX.Util.ParseHexColor`, `DMX.Util.Trim`, `DMX.Util.ParseOnOff` exist; no duplicate definitions remain in Core.lua or Options.lua | ✓ VERIFIED | `Util.lua` exports all 4 on `DMX.Util`; `grep` of Core.lua and Options.lua for `local function Clamp/Trim/ParseOnOff/ParseHexColor` returns 0 |
| SC-2 | All five frame references accessible as `Tip.root`, `Tip.pips`, etc.; no bare upvalue references in TipOfTheSpear.lua function bodies | ✓ VERIFIED | Module-level locals `local root`, `local pips`, etc. are absent (0 count); `tip.*` assignments number 54 hits; `self.*` hits 9; local alias pattern (`local root = self.root`) present in both hot-path methods |
| SC-3 | `ForEachModule` iterates in `moduleOrder` registration order, not arbitrary hash order | ✓ VERIFIED | Core.lua line 132: `for _, key in ipairs(self.moduleOrder)`; `table.insert(self.moduleOrder, key)` at line 116; `DMX.moduleOrder = DMX.moduleOrder or {}` at line 14 |
| SC-4 | `ClassifySpellID` performs a plain table lookup with no `pcall` wrapper | ✓ VERIFIED | Function body is 3 lines: `KILL_COMMAND` check, `CONSUMERS[value]` check, implicit nil. Total `pcall` count in file is 2 — both inside `ReadLiveState` (intentional WoW API protection, unchanged) |
| SC-5 | `/reload ui` produces no Lua errors and tracker display functions normally | ? UNCERTAIN | Cannot verify programmatically — requires in-game WoW client execution |

**Score:** 4/5 truths verified (SC-5 needs human)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `Duncedmaxxing/Util.lua` | 4 functions on DMX.Util, Trim-based ParseHexColor, no ToByte/ColorToHex/CopyDefaults/MergeDefaults | ✓ VERIFIED | Exists; 4 local functions; 4 Util.X assignments; ParseHexColor uses `Trim(value):gsub("^#","")` not `tostring`; excluded functions absent (grep count 0) |
| `Duncedmaxxing/Duncedmaxxing.toc` | Util.lua listed before Core.lua | ✓ VERIFIED | Line 10: `Util.lua`, line 11: `Core.lua` — correct order |
| `Duncedmaxxing/Core.lua` | Local aliases for all 4 DMX.Util functions; `DMX.moduleOrder`; ipairs ForEachModule | ✓ VERIFIED | Lines 4–7: all 4 aliases; line 14: `DMX.moduleOrder`; line 116: `table.insert`; line 132: `ipairs(self.moduleOrder)` |
| `Duncedmaxxing/Options.lua` | 2 aliases (Clamp, ParseHexColor); no Trim/ParseOnOff aliases; no duplicate defs | ✓ VERIFIED | Lines 6–7: both aliases; zero `local function Clamp` or `local function ParseHexColor` definitions |
| `Duncedmaxxing/Modules/TipOfTheSpear.lua` | Tip table frame fields; pcall-free ClassifySpellID; tip-parameter helpers; D-08 aliases | ✓ VERIFIED | All five module-level upvalue declarations absent; EnsureFrame writes to `tip.*`; private helpers have `tip` parameter; Update/RefreshLayout/ApplyLock use `self.root`/local aliases |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `Util.lua` | `DMX` namespace | `DMX.Util = {}` assignment | ✓ WIRED | Line 3 of Util.lua; `local Util = DMX.Util` then 4 `Util.X = X` assignments |
| `Core.lua` | `Util.lua` | `local Clamp = DMX.Util.Clamp` aliases at file top | ✓ WIRED | Lines 4–7 of Core.lua; all 4 aliases present immediately after namespace open |
| `Core.lua` | `DMX.moduleOrder` | `ipairs(self.moduleOrder)` in ForEachModule | ✓ WIRED | `table.insert` at RegisterModule line 116; `ipairs(self.moduleOrder)` at ForEachModule line 132 |
| `Tip:Initialize` | `EnsureFrame` | `EnsureFrame(self)` call | ✓ WIRED | Line 751 of TipOfTheSpear.lua: `EnsureFrame(self)` |
| `EnsureFrame(tip)` | Tip table fields | `tip.root = CreateFrame(...)`, `tip.pips = {}`, `tip.borders = {}`, `tip.label`, `tip.numberText` | ✓ WIRED | EnsureFrame lines 282–317; initializes pips and borders tables before indexed use (Pitfall 4/5 prevention confirmed) |
| `Tip:Update` | Tip table fields | `local root = self.root` etc. (D-08) | ✓ WIRED | Lines 578–581 of TipOfTheSpear.lua: 4 aliases declared at function entry |
| `OnDragStop closure` | `SavePosition` | `SavePosition(tip)` capturing outer parameter | ✓ WIRED | Line 315: `SavePosition(tip)` with comment confirming `tip` = Tip module table, `self` = WoW frame |

### Data-Flow Trace (Level 4)

Not applicable — this phase is a pure structural refactor (no data sources, no UI rendering added). All rendering was pre-existing; this phase only relocated ownership of frame references.

### Behavioral Spot-Checks

Step 7b: SKIPPED — no standalone runnable entry points. WoW addon Lua executes exclusively inside the WoW client sandbox; no external Lua interpreter is available. SC-5 is routed to human verification.

### Probe Execution

Step 7c: No probe scripts declared in PLAN files or found in `scripts/*/tests/probe-*.sh`. SKIPPED.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| QUAL-01 | 01-01-PLAN.md | Shared utility functions extracted to Duncedmaxxing/Util.lua, loaded before Core.lua | ✓ SATISFIED | `Util.lua` exists with 4 functions on `DMX.Util`; `Duncedmaxxing.toc` lists it first; aliases in Core.lua and Options.lua; zero duplicate definitions |
| QUAL-02 | 01-02-PLAN.md | Module-level frame locals moved to Tip table fields | ✓ SATISFIED | All 5 upvalue locals absent; `tip.*` pattern confirmed throughout TipOfTheSpear.lua; EnsureFrame writes to `self.*`/`tip.*` |
| QUAL-04 | 01-01-PLAN.md | ForEachModule uses ordered moduleOrder array | ✓ SATISFIED | `ipairs(self.moduleOrder)` replaces `pairs(self.modules)`; `table.insert` in RegisterModule |
| QUAL-05 | 01-02-PLAN.md | Unnecessary pcall removed from ClassifySpellID | ✓ SATISFIED | ClassifySpellID is 3-line direct lookup; total pcall count in file is 2 (both in ReadLiveState only) |

No orphaned requirements: REQUIREMENTS.md maps exactly QUAL-01, QUAL-02, QUAL-04, QUAL-05 to Phase 1. All four are covered.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| — | — | — | — | None found |

Scan results: zero `TBD`, `FIXME`, `XXX`, `TODO`, `HACK`, or `PLACEHOLDER` markers across all four modified files (`Util.lua`, `Core.lua`, `Options.lua`, `TipOfTheSpear.lua`).

### Human Verification Required

#### 1. In-Game Load Verification (SC-5)

**Test:** With the addon installed, `/reload ui` in-game (or a fresh login with the addon enabled). Open the chat log and observe any Lua errors. Verify the Tip of the Spear tracker renders visibly on screen (or appears when entering combat if `showOnlyInCombat` is true).

**Expected:** No Lua error messages appear in chat. The tracker display renders without nil-index crashes. Stack count updates correctly when Kill Command is cast.

**Why human:** The WoW Lua sandbox cannot be replicated outside the client. The EnsureFrame migration (replacing bare upvalues with `tip.*` assignments) and the alias chain (`Util.lua` → `DMX.Util.Clamp` → `local Clamp = DMX.Util.Clamp`) are only exercised at runtime under the actual WoW environment. A missed reference would manifest as a `nil value` Lua error on first tracker render.

### Gaps Summary

No automated gaps found. All four programmatically-verifiable success criteria are confirmed in the codebase. The single outstanding item (SC-5, in-game load verification) requires human testing and cannot be falsified by static analysis.

---

_Verified: 2026-06-17T13:30:00Z_
_Verifier: Claude (gsd-verifier)_
