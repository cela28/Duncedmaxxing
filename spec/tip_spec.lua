-- spec/tip_spec.lua
-- Unit tests for TipOfTheSpear.lua pure-logic methods:
--   Tip:ApplySpell, Tip:SyncFromAura, Tip:ScheduleExpiration, Tip:ScheduleCastVerify
--
-- Uses loader.load() for full isolation (D-06) and mock clock for timer simulation.
-- Aura overrides go through stubs.mockAura.impl, NOT _G.C_UnitAuras.GetPlayerAuraBySpellID,
-- because TipOfTheSpear.lua captures the function once as a module-level local on load.

local loader = require("spec.support.init")
local stubs  = require("spec.support.wow_stubs")

-- Constants mirrored from TipOfTheSpear.lua for readable assertions.
local BUFF_DURATION          = 10
local MAX_STACKS             = 3
local CONSUMER_UPSYNC_GRACE  = 2.75
local AURA_VERIFY_DELAY      = 2.0

-- ---------------------------------------------------------------------------
-- Tip:ApplySpell
-- ---------------------------------------------------------------------------
describe("Tip:ApplySpell", function()
    local DMX, Tip, clock

    before_each(function()
        DMX, Tip, clock = loader.load()
        loader.resetTipState(Tip, clock)
    end)

    -- Generator: adds BASE (2) stacks from 0 (flat-2 fallback path; Primal Surge ID unverifiable offline)
    it("adds BASE stacks on generator from zero (flat-2 fallback: BASE=2)", function()
        Tip:ApplySpell("generator")
        assert.equals(2, Tip.stacks)
    end)

    -- Generator: caps at MAX_STACKS (3) when already at 2
    it("caps stacks at 3 when already at 2 (generator)", function()
        Tip.stacks = 2
        Tip:ApplySpell("generator")
        assert.equals(MAX_STACKS, Tip.stacks)
    end)

    -- Generator: stays at MAX_STACKS when already at 3
    it("keeps stacks at 3 when already at MAX_STACKS (generator)", function()
        Tip.stacks = 3
        Tip:ApplySpell("generator")
        assert.equals(MAX_STACKS, Tip.stacks)
    end)

    -- Consumer: decrements by 1
    it("decrements stacks by 1 on consumer", function()
        Tip.stacks = 2
        Tip:ApplySpell("consumer")
        assert.equals(1, Tip.stacks)
    end)

    -- Consumer: floors at 0 (no negative stacks)
    it("floors stacks at 0 on consumer when already empty", function()
        Tip.stacks = 0
        Tip:ApplySpell("consumer")
        assert.equals(0, Tip.stacks)
    end)

    -- Generator: sets expiresAt to now + BUFF_DURATION (clock.now = 100)
    it("sets expiresAt to now + BUFF_DURATION on generator", function()
        Tip:ApplySpell("generator")
        assert.equals(100 + BUFF_DURATION, Tip.expiresAt)
    end)

    -- Consumer: clears expiresAt when draining to 0
    it("clears expiresAt when consumer drains stacks to 0", function()
        Tip.stacks = 1
        Tip:ApplySpell("consumer")
        assert.equals(0, Tip.stacks)
        assert.equals(0, Tip.expiresAt)
    end)

    -- Consumer: does NOT clear expiresAt when stacks remain above 0
    it("does not clear expiresAt when consumer leaves stacks > 0", function()
        Tip.stacks    = 2
        Tip.expiresAt = 108
        Tip:ApplySpell("consumer")
        assert.equals(1, Tip.stacks)
        -- expiresAt unchanged (consumer only clears when hitting 0)
        assert.equals(108, Tip.expiresAt)
    end)

    -- Sets lastPredictAt and lastPredictKind on generator
    it("sets lastPredictAt and lastPredictKind on generator", function()
        Tip:ApplySpell("generator")
        assert.equals(100,         Tip.lastPredictAt)
        assert.equals("generator", Tip.lastPredictKind)
    end)

    -- Sets lastPredictAt and lastPredictKind on consumer
    it("sets lastPredictAt and lastPredictKind on consumer", function()
        Tip.stacks = 2
        Tip:ApplySpell("consumer")
        assert.equals(100,      Tip.lastPredictAt)
        assert.equals("consumer", Tip.lastPredictKind)
    end)

    -- Unknown kind: no change and early return
    it("ignores unknown kind and leaves stacks unchanged", function()
        Tip.stacks = 1
        Tip:ApplySpell("unknown")
        assert.equals(1, Tip.stacks)
    end)

    -- Generator: schedules an active (non-cancelled) expireTimer
    it("schedules a non-cancelled expireTimer on generator", function()
        Tip:ApplySpell("generator")
        assert.is_not_nil(Tip.expireTimer)
        assert.is_false(Tip.expireTimer:IsCancelled())
    end)

    -- Expiry timer fires after BUFF_DURATION and zeroes stacks
    it("expiry timer fires after BUFF_DURATION and zeroes stacks", function()
        Tip:ApplySpell("generator")
        assert.equals(2, Tip.stacks)   -- BASE = 2 on flat-2 fallback path
        -- Timer scheduled at remaining(10) + 0.03 = 10.03 seconds from now=100
        clock:advance(10.1)
        assert.equals(0, Tip.stacks)
        assert.equals(0, Tip.expiresAt)
    end)

    -- Generator grant is independent of Twin Fangs (regression for kill-command-stack-overshoot)
    -- With hasTwinFangs=true, the grant must NOT reach 3 from 0 stacks.
    -- BASE = 2 (flat-2 fallback path; Primal Surge ID unverifiable offline).
    it("generator grant is independent of Twin Fangs: hasTwinFangs=true yields BASE (not 3) from 0 stacks", function()
        Tip.hasTwinFangs  = true
        Tip:ApplySpell("generator")
        assert.not_equals(3, Tip.stacks)
        assert.equals(2, Tip.stacks)   -- BASE = 2 on flat-2 fallback path
    end)

    -- BUG-03: Generator from 2 stacks caps at MAX_STACKS
    it("caps at MAX_STACKS on generator from 2 stacks (BUG-03)", function()
        Tip.stacks = 2
        Tip:ApplySpell("generator")
        assert.equals(MAX_STACKS, Tip.stacks)
    end)

    -- BUG-04: Takedown with Twin Fangs from 0 stacks: grant 3 then consume 1 = 2
    it("Takedown with Twin Fangs from 0 stacks: grant 3 then consume 1 = 2 (BUG-04)", function()
        Tip.hasTwinFangs = true
        Tip.stacks = 0
        Tip:ApplySpell("consumer", 1250646)
        assert.equals(2, Tip.stacks)
        assert.not_equals(0, Tip.expiresAt)
    end)

    -- BUG-04: Takedown with Twin Fangs from 1 stack: grant 3 then consume 1 = 2
    -- This is the D-04 distinguishing case — wrong order would give clamp(1-1+3)=3, not 2
    it("Takedown with Twin Fangs from 1 stack: grant 3 then consume 1 = 2 (BUG-04)", function()
        Tip.hasTwinFangs = true
        Tip.stacks = 1
        Tip:ApplySpell("consumer", 1250646)
        assert.equals(2, Tip.stacks)
    end)

    -- BUG-04: Takedown with Twin Fangs from 2 stacks: clamp(2+3)=3, 3-1=2
    it("Takedown with Twin Fangs from 2 stacks: grant 3 then consume 1 = 2 (BUG-04)", function()
        Tip.hasTwinFangs = true
        Tip.stacks = 2
        Tip:ApplySpell("consumer", 1250646)
        assert.equals(2, Tip.stacks)
    end)

    -- BUG-04: Takedown WITHOUT Twin Fangs consumes 1 stack normally
    it("Takedown without Twin Fangs consumes 1 stack normally (BUG-04)", function()
        Tip.hasTwinFangs = false
        Tip.stacks = 2
        Tip:ApplySpell("consumer", 1250646)
        assert.equals(1, Tip.stacks)
    end)

    -- BUG-04: Non-Takedown consumer with Twin Fangs still consumes 1 stack (Takedown-only special case)
    it("non-Takedown consumer with Twin Fangs consumes 1 stack normally (BUG-04)", function()
        Tip.hasTwinFangs = true
        Tip.stacks = 2
        Tip:ApplySpell("consumer", 186270)  -- Raptor Strike spell ID
        assert.equals(1, Tip.stacks)
    end)

    -- Aspect-of-the-Eagle Raptor Strike (265189) decrements 1 stack instantly (plain consumer path)
    -- Regression: 265189 must be in CONSUMERS so ClassifySpellID returns "consumer" for it;
    -- ApplySpell with explicit kind="consumer" exercises the same plain -1 branch as 186270.
    it("Aspect-of-the-Eagle Raptor Strike (265189) decrements 1 stack instantly", function()
        assert.equals("consumer", Tip._test.ClassifySpellID(265189))  -- D-06 hardening
        Tip.stacks = 2
        Tip:ApplySpell("consumer", 265189)  -- Aspect-of-the-Eagle ranged Raptor Strike
        assert.equals(1, Tip.stacks)
    end)

    -- Raptor Swipe (1262293) decrements 1 stack instantly (plain consumer path)
    -- Regression: 1262293 must be in CONSUMERS so ClassifySpellID returns "consumer" for it;
    -- Base Raptor Swipe, pairs with 1262343 (Aspect-of-the-Eagle ranged variant).
    it("Raptor Swipe (1262293) decrements 1 stack instantly", function()
        assert.equals("consumer", Tip._test.ClassifySpellID(1262293))  -- D-06 hardening
        Tip.stacks = 2
        Tip:ApplySpell("consumer", 1262293)  -- Base Raptor Swipe
        assert.equals(1, Tip.stacks)
    end)

    -- Aspect-of-the-Eagle Raptor Swipe (1262343) decrements 1 stack instantly (plain consumer path)
    -- Regression: 1262343 must be in CONSUMERS so ClassifySpellID returns "consumer" for it;
    -- Pairs with 1262293 (base Raptor Swipe) the same way 265189 pairs with 186270 (Raptor Strike).
    it("Aspect-of-the-Eagle Raptor Swipe (1262343) decrements 1 stack instantly", function()
        assert.equals("consumer", Tip._test.ClassifySpellID(1262343))  -- D-06 hardening
        Tip.stacks = 2
        Tip:ApplySpell("consumer", 1262343)  -- Aspect-of-the-Eagle ranged Raptor Swipe
        assert.equals(1, Tip.stacks)
    end)
end)

-- ---------------------------------------------------------------------------
-- Tip:SyncFromAura
-- ---------------------------------------------------------------------------
describe("Tip:SyncFromAura", function()
    local DMX, Tip, clock

    before_each(function()
        DMX, Tip, clock = loader.load()
        loader.resetTipState(Tip, clock)
    end)

    -- Returns false when ReadLiveState returns nil (GetPlayerAuraBySpellID errors)
    it("returns false when GetPlayerAuraBySpellID throws (ReadLiveState nil path)", function()
        stubs.mockAura.impl = function(_spellID)
            error("simulated API error")
        end
        local result = Tip:SyncFromAura()
        assert.is_false(result)
    end)

    -- Returns false when GetPlayerAuraBySpellID is nil (module-level guard)
    -- This path tests the `if not GetPlayerAuraBySpellID then return nil, nil end` guard.
    -- We cannot nil the captured local, but we can verify the error-path produces false.
    -- (already covered above; this variant uses pcall path explicitly)
    it("returns false when ReadLiveState returns nil via pcall error", function()
        stubs.mockAura.impl = function(_spellID)
            error("API unavailable")
        end
        assert.is_false(Tip:SyncFromAura())
    end)

    -- Syncs stacks from live aura when aura present
    it("syncs stacks from live aura", function()
        stubs.mockAura.impl = function(_spellID)
            return stubs.makeAuraData({ applications = 2, expirationTime = clock.now + 8 })
        end
        local result = Tip:SyncFromAura()
        assert.is_true(result)
        assert.equals(2, Tip.stacks)
    end)

    -- Syncs expiresAt from live aura
    it("syncs expiresAt from live aura", function()
        stubs.mockAura.impl = function(_spellID)
            return stubs.makeAuraData({ applications = 2, expirationTime = clock.now + 8 })
        end
        Tip:SyncFromAura()
        assert.equals(clock.now + 8, Tip.expiresAt)
    end)

    -- Zeroes stacks when aura is absent (nil return)
    it("zeroes stacks and expiresAt when aura is absent", function()
        -- mockAura.impl already returns nil from resetTipState
        Tip.stacks    = 2
        Tip.expiresAt = 108
        local result = Tip:SyncFromAura()
        -- nil aura → ReadLiveState returns 0, 0 → SyncFromAura returns true (accepted sync)
        assert.is_true(result)
        assert.equals(0, Tip.stacks)
        assert.equals(0, Tip.expiresAt)
    end)

    -- Consumer grace suppression within window: liveStacks > predicted stacks, within 2.75s
    it("suppresses consumer up-sync within CONSUMER_UPSYNC_GRACE window", function()
        Tip.inCombat       = true
        Tip.lastPredictKind = "consumer"
        Tip.stacks         = 1
        Tip.lastPredictAt  = clock.now   -- 100

        stubs.mockAura.impl = function(_spellID)
            return stubs.makeAuraData({ applications = 3, expirationTime = clock.now + 8 })
        end

        -- Advance 1 second: clock.now = 101; 101 < 100 + 2.75 = 102.75 → within grace
        clock:advance(1)
        local result = Tip:SyncFromAura()
        assert.is_false(result)
        assert.equals(1, Tip.stacks)   -- unchanged
    end)

    -- Consumer grace suppression past window: sync should proceed
    it("allows consumer up-sync past CONSUMER_UPSYNC_GRACE window", function()
        Tip.inCombat        = true
        Tip.lastPredictKind = "consumer"
        Tip.stacks          = 1
        Tip.lastPredictAt   = clock.now  -- 100

        stubs.mockAura.impl = function(_spellID)
            return stubs.makeAuraData({ applications = 3, expirationTime = clock.now + 8 })
        end

        -- Advance 3 seconds: clock.now = 103; 103 > 102.75 → past grace window
        clock:advance(3)
        local result = Tip:SyncFromAura()
        assert.is_true(result)
        assert.equals(3, Tip.stacks)   -- synced from aura
    end)

    -- Grace suppression does NOT fire for generators (only consumer predict)
    it("does not suppress up-sync when lastPredictKind is generator", function()
        Tip.inCombat        = true
        Tip.lastPredictKind = "generator"
        Tip.stacks          = 1
        Tip.lastPredictAt   = clock.now  -- 100

        stubs.mockAura.impl = function(_spellID)
            return stubs.makeAuraData({ applications = 3, expirationTime = clock.now + 8 })
        end

        -- Within what would be the grace window — but kind is "generator", so no suppression
        clock:advance(1)
        local result = Tip:SyncFromAura()
        assert.is_true(result)
        assert.equals(3, Tip.stacks)
    end)

    -- Grace suppression does NOT fire when out of combat
    it("does not suppress up-sync when out of combat", function()
        Tip.inCombat        = false
        Tip.lastPredictKind = "consumer"
        Tip.stacks          = 1
        Tip.lastPredictAt   = clock.now  -- 100

        stubs.mockAura.impl = function(_spellID)
            return stubs.makeAuraData({ applications = 3, expirationTime = clock.now + 8 })
        end

        clock:advance(1)
        local result = Tip:SyncFromAura()
        assert.is_true(result)
        assert.equals(3, Tip.stacks)
    end)
end)

-- ---------------------------------------------------------------------------
-- Tip:ScheduleCastVerify — serial-mismatch guard
-- ---------------------------------------------------------------------------
describe("Tip:ScheduleCastVerify serial-mismatch", function()
    local DMX, Tip, clock

    before_each(function()
        DMX, Tip, clock = loader.load()
        loader.resetTipState(Tip, clock)
    end)

    -- Stale serial prevents SyncFromAura from being called
    it("does not call SyncFromAura when castVerifySerial has changed (stale serial)", function()
        local syncCallCount = 0
        local originalSync  = Tip.SyncFromAura
        Tip.SyncFromAura    = function(self)
            syncCallCount = syncCallCount + 1
            return originalSync(self)
        end

        -- First ApplySpell: serial increments to 1, timer fires at 100 + 2.0 = 102.0
        Tip:ApplySpell("generator")
        assert.equals(1, Tip.castVerifySerial)

        -- Second ApplySpell: serial increments to 2, now any timer with serial=1 is stale
        Tip:ApplySpell("generator")
        assert.equals(2, Tip.castVerifySerial)

        -- Reset spy count (ApplySpell may have triggered SyncFromAura via ScheduleExpiration
        -- callback in test mode — start fresh)
        syncCallCount = 0

        -- Advance past the first (AURA_VERIFY_DELAY = 2.0s) verify timer only, NOT
        -- the FINAL one (FINAL_AURA_VERIFY_DELAY = 2.25s). The gap between them is
        -- 0.25s, so the advance margin must land inside (2.0, 2.25).
        --
        -- Both ApplySpell calls happened at clock.now=100; each schedules two timers,
        -- at fireAt=102.0 (AURA_VERIFY_DELAY) and fireAt=102.25 (FINAL). Advancing to
        -- 102.02 fires only the 102.0 timers for BOTH serials — the 102.25 timers stay
        -- pending, so serial-2's SyncFromAura runs exactly once (not twice).
        -- serial-1 timer → early return (no sync). serial-2 timer → calls SyncFromAura.
        -- Net call count should be exactly 1 (the valid serial-2 call).
        clock:advance(AURA_VERIFY_DELAY + 0.02)
        assert.equals(1, syncCallCount)

        -- Restore
        Tip.SyncFromAura = originalSync
    end)

    -- Matching serial allows SyncFromAura to execute
    it("calls SyncFromAura when castVerifySerial matches", function()
        local syncCalled   = false
        local originalSync = Tip.SyncFromAura
        Tip.SyncFromAura   = function(self)
            syncCalled = true
            return originalSync(self)
        end

        -- Single ApplySpell: serial = 1; no subsequent change
        Tip:ApplySpell("generator")

        -- Advance past AURA_VERIFY_DELAY so the Verify closure fires
        clock:advance(AURA_VERIFY_DELAY + 0.1)
        assert.is_true(syncCalled)

        Tip.SyncFromAura = originalSync
    end)
end)

-- ---------------------------------------------------------------------------
-- RefreshTip — out-of-combat aura sync (BUG-02)
-- ---------------------------------------------------------------------------
describe("RefreshTip — out-of-combat aura sync (BUG-02)", function()
    local DMX, Tip, clock

    before_each(function()
        DMX, Tip, clock = loader.load()
        loader.resetTipState(Tip, clock)
    end)

    -- Stale stacks are zeroed when aura is absent and not in combat
    it("syncs stale stacks to 0 on RefreshTip when out of combat and aura is absent", function()
        Tip.stacks    = 2
        Tip.expiresAt = clock.now + 5
        Tip.inCombat  = false
        -- mockAura.impl already returns nil by default (aura absent)
        DMX:RefreshTip()
        assert.equals(0, Tip.stacks)
        assert.equals(0, Tip.expiresAt)
    end)

    -- Live aura data is synced to Tip.stacks when not in combat
    it("syncs stale stacks to live aura on RefreshTip when out of combat", function()
        Tip.stacks   = 0
        Tip.inCombat = false
        stubs.mockAura.impl = function(_spellID)
            return stubs.makeAuraData({ applications = 2, expirationTime = clock.now + 8 })
        end
        DMX:RefreshTip()
        assert.equals(2, Tip.stacks)
    end)

    -- SyncFromAura is NOT called during combat — prediction system must not be disrupted
    it("does not call SyncFromAura during combat on RefreshTip", function()
        Tip.stacks   = 2
        Tip.inCombat = true
        -- mockAura.impl returns nil (absent) — if SyncFromAura were called, stacks would drop to 0

        local syncCalled   = false
        local originalSync = Tip.SyncFromAura
        Tip.SyncFromAura   = function(self)
            syncCalled = true
            return originalSync(self)
        end

        DMX:RefreshTip()

        assert.is_false(syncCalled)
        assert.equals(2, Tip.stacks)

        Tip.SyncFromAura = originalSync
    end)
end)

-- ---------------------------------------------------------------------------
-- QUAL-02 -- frame references on Tip table
-- ---------------------------------------------------------------------------
describe("QUAL-02 -- frame references on Tip table", function()
    local DMX, Tip, clock

    before_each(function()
        DMX, Tip, clock = loader.load()
    end)

    it("populates all frame fields directly on the Tip module table after Initialize", function()
        assert.is_not_nil(Tip.root)
        assert.is_table(Tip.pips)
        assert.is_table(Tip.borders)
        assert.is_not_nil(Tip.label)
        assert.is_not_nil(Tip.numberText)
    end)
end)

-- ---------------------------------------------------------------------------
-- Caching -- isSurvival
-- ---------------------------------------------------------------------------
describe("Caching -- isSurvival", function()
    local DMX, Tip, clock

    before_each(function()
        DMX, Tip, clock = loader.load()
        loader.resetTipState(Tip, clock)
    end)

    -- After loader.load() the default C_SpecializationInfo stub returns 3 (Survival).
    -- Initialize() populates isSurvival, so it should be true at this point.
    -- Note: resetTipState sets isSurvival = false, so we only need to verify Initialize sets it.
    it("Tip.isSurvival is true after Initialize (Survival Hunter stub)", function()
        -- Reload to get a fresh Initialize result (not overridden by resetTipState)
        DMX, Tip, clock = loader.load()
        assert.is_true(Tip.isSurvival)
    end)

    -- PLAYER_SPECIALIZATION_CHANGED with non-Survival spec should update the cache.
    it("Tip.isSurvival is false after PLAYER_SPECIALIZATION_CHANGED with non-Survival spec", function()
        -- Override spec stub to return 1 (Beast Mastery)
        _G.C_SpecializationInfo.GetSpecialization = function() return 1 end
        Tip.isSurvival = true  -- set up the "before" state
        Tip:OnEvent("PLAYER_SPECIALIZATION_CHANGED", "player")
        assert.is_false(Tip.isSurvival)
        -- Restore
        _G.C_SpecializationInfo.GetSpecialization = function() return 3 end
    end)

    -- PLAYER_SPECIALIZATION_CHANGED for a non-player unit must not touch isSurvival.
    it("Tip.isSurvival stays unchanged on PLAYER_SPECIALIZATION_CHANGED for non-player unit", function()
        Tip.isSurvival = true  -- set a known state
        Tip:OnEvent("PLAYER_SPECIALIZATION_CHANGED", "target")
        assert.is_true(Tip.isSurvival)
    end)

    -- PLAYER_TALENT_UPDATE must refresh isSurvival from the spec API.
    it("Tip.isSurvival refreshes on PLAYER_TALENT_UPDATE", function()
        -- Start with Survival spec (default), then swap to non-Survival and fire event
        Tip.isSurvival = true
        _G.C_SpecializationInfo.GetSpecialization = function() return 1 end
        Tip:OnEvent("PLAYER_TALENT_UPDATE")
        assert.is_false(Tip.isSurvival)

        -- Restore to Survival and fire again
        _G.C_SpecializationInfo.GetSpecialization = function() return 3 end
        Tip:OnEvent("PLAYER_TALENT_UPDATE")
        assert.is_true(Tip.isSurvival)
    end)
end)

-- ---------------------------------------------------------------------------
-- Tip:ScheduleAuraVerify — auraVerifyPending flag (BUG-01)
-- ---------------------------------------------------------------------------
describe("Tip:ScheduleAuraVerify — auraVerifyPending flag (BUG-01)", function()
    local DMX, Tip, clock

    before_each(function()
        DMX, Tip, clock = loader.load()
        loader.resetTipState(Tip, clock)
    end)

    -- auraVerifyPending must be cleared even when serial-mismatch causes early return
    it("clears auraVerifyPending on serial-mismatch early return", function()
        -- Trigger ScheduleAuraVerify via ApplySpell (which calls ScheduleCastVerify ->
        -- ScheduleAuraVerify). Set inCombat=true so the serial guard is exercised.
        Tip.inCombat = true

        -- First ApplySpell: serial=1, auraVerifyPending set to true inside timer
        Tip:ApplySpell("generator")
        assert.equals(1, Tip.castVerifySerial)

        -- Second ApplySpell: serial=2; any pending timer with serial=1 is now stale
        Tip:ApplySpell("generator")
        assert.equals(2, Tip.castVerifySerial)

        -- Advance past AURA_VERIFY_DELAY so the stale serial=1 timer fires.
        -- The timer closure sets auraVerifyPending = false BEFORE the serial check,
        -- so the flag must be false regardless of the early return.
        clock:advance(AURA_VERIFY_DELAY + 0.1)

        assert.is_false(Tip.auraVerifyPending)
    end)
end)

-- ---------------------------------------------------------------------------
-- Tip:Update number mode color coding
-- ---------------------------------------------------------------------------
describe("Tip:Update number mode color coding", function()
    local DMX, Tip, clock

    before_each(function()
        DMX, Tip, clock = loader.load()
        loader.resetTipState(Tip, clock)
        local db = DMX:GetDB()
        db.tip.displayMode = "number"
        db.tip.enabled = true
        db.locked = true
        Tip.isSurvival = true
        Tip:RefreshLayout()
    end)

    -- Helper: assert RGBA components within tolerance
    local function assertColor(actual, expected, msg)
        assert.is_not_nil(actual, msg .. " (_textColor is nil)")
        for i = 1, 4 do
            assert.near(expected[i], actual[i], 0.001,
                msg .. " component " .. i)
        end
    end

    it("sets white text color at 0 stacks", function()
        Tip.stacks = 0
        Tip:Update()
        assertColor(Tip.numberText._textColor, { 1, 1, 1, 1 },
            "0 stacks should be white")
    end)

    it("sets green text color at 1 stack", function()
        Tip.stacks = 1
        Tip:Update()
        assertColor(Tip.numberText._textColor, { 0.18039, 0.80000, 0.44314, 1 },
            "1 stack should be green")
    end)

    it("sets yellow text color at 2 stacks", function()
        Tip.stacks = 2
        Tip:Update()
        assertColor(Tip.numberText._textColor, { 1, 0.94118, 0, 1 },
            "2 stacks should be yellow")
    end)

    it("sets red/orange text color at 3 stacks", function()
        Tip.stacks = 3
        Tip:Update()
        assertColor(Tip.numberText._textColor, { 1, 0.29804, 0.18824, 1 },
            "3 stacks should be red/orange")
    end)

    it("does not set numberText color in bar mode", function()
        local db = DMX:GetDB()
        db.tip.displayMode = "bar"
        Tip:RefreshLayout()
        -- Reset _textColor to nil after RefreshLayout to isolate Update() behavior.
        -- Use rawset to clear so rawget can detect absence (metatable __index returns
        -- a noop function for missing keys, so normal nil access is intercepted).
        rawset(Tip.numberText, "_textColor", nil)
        Tip.stacks = 2
        Tip:Update()
        assert.is_nil(rawget(Tip.numberText, "_textColor"),
            "bar mode should not set numberText color")
    end)

    it("colorByStack ON: reflects an edited db.tip.stackColors[2] entry rather than a hardcoded value", function()
        local db = DMX:GetDB()
        db.tip.colorByStack = true
        db.tip.stackColors[2] = { 0.5, 0.25, 0.75, 1 }
        Tip.stacks = 2
        Tip:Update()
        assertColor(Tip.numberText._textColor, { 0.5, 0.25, 0.75, 1 },
            "edited stackColors[2] should be reflected in the render, proving config-driven color")
    end)

    it("colorByStack OFF: applies the flat textColor fallback at 1 stack instead of the per-stack color", function()
        local db = DMX:GetDB()
        db.tip.colorByStack = false
        db.tip.textColor = { r = 0.2, g = 0.4, b = 0.6, a = 1 }
        Tip.stacks = 1
        Tip:Update()
        assertColor(Tip.numberText._textColor, { 0.2, 0.4, 0.6, 1 },
            "1 stack with colorByStack OFF should use the flat textColor, not the per-stack green")
    end)

    it("colorByStack OFF: applies the same flat textColor fallback at 3 stacks", function()
        local db = DMX:GetDB()
        db.tip.colorByStack = false
        db.tip.textColor = { r = 0.2, g = 0.4, b = 0.6, a = 1 }
        Tip.stacks = 3
        Tip:Update()
        assertColor(Tip.numberText._textColor, { 0.2, 0.4, 0.6, 1 },
            "3 stacks with colorByStack OFF should use the flat textColor, not the per-stack red")
    end)
end)
