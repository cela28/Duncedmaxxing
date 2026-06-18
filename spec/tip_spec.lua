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
local AURA_VERIFY_DELAY      = 1.25

-- ---------------------------------------------------------------------------
-- Tip:ApplySpell
-- ---------------------------------------------------------------------------
describe("Tip:ApplySpell", function()
    local DMX, Tip, clock

    before_each(function()
        DMX, Tip, clock = loader.load()
        loader.resetTipState(Tip, clock)
    end)

    -- Generator: adds 2 stacks from 0
    it("adds 2 stacks on generator from zero", function()
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
        assert.equals(2, Tip.stacks)
        -- Timer scheduled at remaining(10) + 0.03 = 10.03 seconds from now=100
        clock:advance(10.1)
        assert.equals(0, Tip.stacks)
        assert.equals(0, Tip.expiresAt)
    end)

    -- BUG-03: Kill Command grants 2 stacks without Twin Fangs (baseline)
    it("grants 2 stacks on generator without Twin Fangs (BUG-03 baseline)", function()
        Tip.hasTwinFangs = false
        Tip:ApplySpell("generator")
        assert.equals(2, Tip.stacks)
    end)

    -- BUG-03: Kill Command grants 3 stacks with Twin Fangs active
    it("grants 3 stacks on generator with Twin Fangs active (BUG-03)", function()
        Tip.hasTwinFangs = true
        Tip:ApplySpell("generator")
        assert.equals(3, Tip.stacks)
    end)

    -- BUG-03: Kill Command with Twin Fangs from 1 stack caps at MAX_STACKS
    it("caps at MAX_STACKS on generator with Twin Fangs from 1 stack (BUG-03)", function()
        Tip.hasTwinFangs = true
        Tip.stacks = 1
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

        -- First ApplySpell: serial increments to 1, timer fires at 100 + 1.25 = 101.25
        Tip:ApplySpell("generator")
        assert.equals(1, Tip.castVerifySerial)

        -- Second ApplySpell: serial increments to 2, now any timer with serial=1 is stale
        Tip:ApplySpell("generator")
        assert.equals(2, Tip.castVerifySerial)

        -- Reset spy count (ApplySpell may have triggered SyncFromAura via ScheduleExpiration
        -- callback in test mode — start fresh)
        syncCallCount = 0

        -- Advance past the first ApplySpell timer's AURA_VERIFY_DELAY (1.25s).
        -- The timer with serial=1 fires but sees castVerifySerial=2 → early return.
        -- The timer with serial=2 has not yet fired (it was scheduled at a later clock.now).
        -- We advance just enough to fire the first serial-1 timer but not the serial-2 one.
        --
        -- Both ApplySpell calls happened at clock.now=100; both timers fire at ~101.25 and ~102.05.
        -- After the two ApplySpell calls the clock is still at 100 (no advance yet).
        -- Advance to 101.3: the AURA_VERIFY_DELAY timers (fireAt=101.25) for BOTH serials fire.
        -- We cannot selectively fire only the first without a more granular clock.
        --
        -- Use a simpler approach: advance past AURA_VERIFY_DELAY then count calls.
        -- Advancing 1.3s fires the 1.25-delay timers for both ApplySpell calls (serial 1 and 2).
        -- serial-1 timer → early return (no sync). serial-2 timer → calls SyncFromAura.
        -- Net call count should be exactly 1 (the valid serial-2 call).
        clock:advance(AURA_VERIFY_DELAY + 0.1)
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
-- Caching -- isSurvival and spellTexture
-- ---------------------------------------------------------------------------
describe("Caching -- isSurvival and spellTexture", function()
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

    -- spellTexture should be populated (non-nil) after Initialize.
    it("Tip.spellTexture is non-nil after Initialize", function()
        DMX, Tip, clock = loader.load()
        assert.is_not_nil(Tip.spellTexture)
    end)

    -- C_Spell.GetSpellTexture stub returns 132275; that must be stored.
    it("Tip.spellTexture equals expected icon ID after Initialize", function()
        DMX, Tip, clock = loader.load()
        assert.equals(132275, Tip.spellTexture)
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
