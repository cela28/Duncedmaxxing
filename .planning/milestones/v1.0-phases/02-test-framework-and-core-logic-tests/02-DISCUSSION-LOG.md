# Phase 2: Test Framework and Core Logic Tests - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-17
**Phase:** 02-Test Framework and Core Logic Tests
**Areas discussed:** Mock depth, Test loading, Timer simulation, luacheck globals

---

## Mock Depth

### Q1: How deep should the WoW API mock layer go?

| Option | Description | Selected |
|--------|-------------|----------|
| Minimal stubs | Stubs return fixed values/nils. CreateFrame returns a table with no-op methods. C_Timer.After stores callback for manual invocation. | ✓ |
| Behavioral mocks | Stubs simulate real behavior: frame hierarchies, auto-firing timers, event dispatch. | |
| You decide | Let Claude pick. | |

**User's choice:** Minimal stubs
**Notes:** Tests target pure logic, not WoW frame rendering.

### Q2: Should CreateFrame stubs track any state at all?

| Option | Description | Selected |
|--------|-------------|----------|
| Inert tables | All widget methods are silent no-ops. No state tracked. | |
| Minimal state tracking | Track visibility and key properties like .text. | |
| You decide | Let Claude pick based on what test assertions need. | ✓ |

**User's choice:** You decide
**Notes:** Claude will decide based on actual test assertion requirements.

### Q3: How strict should wiki verification of stubs be?

| Option | Description | Selected |
|--------|-------------|----------|
| Return shape only | Verify return types and field names match wiki. Don't simulate every optional field. | |
| Full contract | Every documented field present in mocks, even if tests don't use them. | ✓ |
| You decide | Let Claude determine per function. | |

**User's choice:** Full contract
**Notes:** Prevents subtle drift between stubs and real API.

---

## Test Loading

### Q1: How should tests load addon source files?

| Option | Description | Selected |
|--------|-------------|----------|
| Helper dofile | spec/support/init.lua sets up globals, creates namespace, dofile()s in TOC order. | ✓ |
| Custom loader function | Parses TOC file, resolves load order automatically, sets up vararg per file. | |
| You decide | Let Claude pick. | |

**User's choice:** Helper dofile
**Notes:** Simple, mirrors WoW's actual load sequence.

### Q2: Should each test file reload source files or share state?

| Option | Description | Selected |
|--------|-------------|----------|
| Reload per file | Each spec dofile()s sources in setup. Full isolation. | ✓ |
| Load once, reset state | Source loaded once, state reset between tests. | |
| You decide | Let Claude pick. | |

**User's choice:** Reload per file
**Notes:** Catches hidden coupling between tests.

### Q3: How should tests handle Tip module state?

| Option | Description | Selected |
|--------|-------------|----------|
| Direct manipulation | Tests set Tip.stacks = 0 etc. directly. | |
| Reset function | Helper provides resetTipState() for before_each. | |
| You decide | Let Claude pick. | ✓ |

**User's choice:** You decide
**Notes:** Claude will pick based on readability and maintainability.

---

## Timer Simulation

### Q1: How should tests handle C_Timer and GetTime?

| Option | Description | Selected |
|--------|-------------|----------|
| Controllable mock clock | GetTime returns mock clock value. C_Timer.After stores and fires callbacks on advance. | ✓ |
| Callback capture only | C_Timer.After captures callback/delay. Tests invoke manually. | |
| You decide | Let Claude pick. | |

**User's choice:** Controllable mock clock
**Notes:** Enables testing expiry scheduling and grace periods without real delays.

### Q2: Should mock clock auto-fire timers or require flush?

| Option | Description | Selected |
|--------|-------------|----------|
| Auto-fire on advance | advance(5.0) fires all elapsed timers in one call. | |
| Advance + flush | advance moves clock, flush fires timers separately. | |
| You decide | Let Claude pick. | ✓ |

**User's choice:** You decide
**Notes:** Claude will pick based on clarity of test code.

---

## luacheck Globals

### Q1: How should read_globals be scoped?

| Option | Description | Selected |
|--------|-------------|----------|
| Addon-specific only | Only globals the addon actually references. | ✓ |
| Broad WoW API surface | Large set of common WoW API globals. | |
| You decide | Let Claude curate. | |

**User's choice:** Addon-specific only
**Notes:** Catches accidental use of unintended WoW globals.

### Q2: Should luacheck also lint spec files?

| Option | Description | Selected |
|--------|-------------|----------|
| Source only | Lint addon source files only. | ✓ |
| Both with separate rules | Source with WoW globals, spec with busted globals. | |
| You decide | Let Claude pick. | |

**User's choice:** Source only
**Notes:** Spec files have their own globals and conventions.

---

## Claude's Discretion

- **D-02:** CreateFrame stub state tracking depth — inert vs. minimal state
- **D-07:** Tip state management in tests — reset helper vs. direct manipulation
- **D-09:** Mock clock timer firing — auto-fire on advance vs. separate flush

## Deferred Ideas

None — discussion stayed within phase scope
