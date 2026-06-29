---
phase: 06
slug: options-ui-overhaul
status: verified
threats_open: 0
asvs_level: 1
created: 2026-06-29
---

# Phase 06 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| User hex input | Hex strings entered in options color inputs; validated by ParseHexColor which returns nil for invalid input | String → RGBA color tuple (cosmetic only) |
| SavedVariables | Persisted DB read by WoW client on load; MergeDefaults + NormalizeDB enforce schema on every load | Lua table (local file, player-only) |
| C_Timer callback | Reset Colors revert timer fires asynchronously; guarded by resetColorsPending flag check | Boolean state flag |

---

## Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation | Status |
|-----------|----------|-----------|----------|-------------|------------|--------|
| T-06-01 | Tampering | db.tip.stackColors | low | accept | WoW SavedVariables are local files; tampering affects only the tamperer's UI. MergeDefaults ensures missing sub-keys get defaults. | closed |
| T-06-02 | Information Disclosure | stackColors config values | low | accept | Color values are purely cosmetic with no sensitive data. No network transmission. | closed |
| T-06-03 | Tampering | Stack color hex inputs | low | accept | ParseHexColor returns nil for invalid input; setValue returns false preventing config write. | closed |
| T-06-04 | Denial of Service | Reset Colors timer | low | accept | C_Timer.NewTimer creates at most one 3-second timer; cancelled on second click or Refresh(). | closed |
| T-06-05 | Tampering | CopyDefaults reference leak | low | mitigate | Reset Colors uses CopyDefaults (Core.lua:41) to deep-copy defaults, preventing direct reference to DEFAULTS table. Verified at Options.lua:425. | closed |

*Status: open · closed*
*Severity: critical > high > medium > low — only open threats at or above high count toward threats_open*
*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party)*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-06-01 | T-06-01 | Local-only SavedVariables; tampering is self-inflicted | plan-time | 2026-06-29 |
| AR-06-02 | T-06-02 | Cosmetic color data, no sensitive information | plan-time | 2026-06-29 |
| AR-06-03 | T-06-03 | Input validation via ParseHexColor; no network surface | plan-time | 2026-06-29 |
| AR-06-04 | T-06-04 | Single bounded timer with cancel path; no exhaustion | plan-time | 2026-06-29 |

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-06-29 | 5 | 5 | 0 | gsd-secure-phase |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-06-29
