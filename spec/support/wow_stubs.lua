-- spec/support/wow_stubs.lua
-- WoW API mock layer for offline busted tests.
-- Provides full D-03 AuraData contract fidelity, controllable mock clock,
-- minimal-state CreateFrame stubs, and all D-04 required globals.

--- Mock clock — controllable time source (D-08, D-09: auto-fire on advance).
local mockClock = {
    now    = 0,
    timers = {},  -- list of { fireAt, callback, cancelled }
}

--- Advance the clock by dt seconds; auto-fires all callbacks whose fireAt <= now.
function mockClock:advance(dt)
    self.now = self.now + dt
    local fired = {}
    for i, t in ipairs(self.timers) do
        if not t.cancelled and t.fireAt <= self.now then
            fired[#fired + 1] = i
        end
    end
    -- Sort ascending so callbacks fire in scheduled order.
    table.sort(fired)
    local offset = 0
    for _, idx in ipairs(fired) do
        local t = self.timers[idx - offset]
        table.remove(self.timers, idx - offset)
        offset = offset + 1
        t.callback()
    end
end

--- Reset clock to 0 and clear all pending timers.
function mockClock:reset()
    self.now    = 0
    self.timers = {}
end

--- AuraData builder (D-03: full wiki contract fidelity).
-- Every documented Struct_AuraData field is present even if tests do not assert it.
local function makeAuraData(overrides)
    local defaults = {
        -- Core identity
        name              = "Tip of the Spear",
        spellId           = 260286,
        icon              = 132275,
        -- Stack state
        applications      = 1,
        count             = 1,
        -- Timing
        duration          = 10.0,
        expirationTime    = 0,
        timeMod           = 1.0,
        -- Metadata
        dispelType        = nil,
        source            = "player",
        sourceUnit        = "player",
        -- Flags
        isHelpful             = true,
        isHarmful             = false,
        isBossAura            = false,
        isFromPlayerOrPet     = true,
        isRaid                = false,
        isStealable           = false,
        isNameplateOnly       = false,
        canApplyAura          = true,
        nameplateShowPersonal = false,
        nameplateShowAll      = false,
        -- Instance tracking
        auraInstanceID    = 1,
        -- Extra (tooltip vararg values)
        points            = {},
    }
    if overrides then
        for k, v in pairs(overrides) do
            defaults[k] = v
        end
    end
    return defaults
end

--- Minimal-state frame factory (D-02).
-- Unknown method access returns a no-op function that returns self.
-- Tracks _visible, _text, _scripts for assertion use.
local function noopFrame()
    local frame = {}
    setmetatable(frame, {
        __index = function(t, k)
            return function(...) return t end
        end
    })
    frame._visible  = true
    frame._text     = ""
    frame._scripts  = {}
    frame.Show      = function(self) self._visible = true end
    frame.Hide      = function(self) self._visible = false end
    frame.SetShown  = function(self, v) self._visible = v end
    frame.IsShown   = function(self) return self._visible end
    frame.SetText   = function(self, t) self._text = tostring(t or "") end
    frame.GetText   = function(self) return self._text end
    frame.SetScript = function(self, event, fn) self._scripts[event] = fn end
    frame.GetCenter = function(self) return 0, 0 end
    frame.CreateTexture    = function(self) return noopFrame() end
    frame.CreateFontString = function(self) return noopFrame() end
    return frame
end

--- Install all D-04 _G stubs.
-- Must be called before loading any addon source files.
local function install(DMX)
    _G.GetTime = function() return mockClock.now end

    _G.C_Timer = {
        After = function(seconds, callback)
            table.insert(mockClock.timers, {
                fireAt   = mockClock.now + seconds,
                callback = callback,
                cancelled = false,
            })
        end,
        NewTimer = function(seconds, callback)
            local handle = { cancelled = false }
            handle.fireAt   = mockClock.now + seconds
            handle.callback = callback
            table.insert(mockClock.timers, handle)
            function handle:Cancel()
                self.cancelled = true
            end
            function handle:IsCancelled()
                return self.cancelled
            end
            return handle
        end,
    }

    _G.C_UnitAuras = {
        GetPlayerAuraBySpellID = function(spellID)
            return nil
        end,
    }

    _G.C_SpecializationInfo = {
        GetSpecialization = function() return 3 end,
    }

    _G.GetSpecialization = function() return 3 end

    _G.C_Spell = {
        GetSpellTexture = function(id) return 132275 end,
    }

    _G.GetSpellTexture = function(id) return 132275 end

    _G.UnitClass = function(unit) return "Hunter", "HUNTER" end

    _G.InCombatLockdown = function() return false end

    _G.CreateFrame = function(frameType, name, parent) return noopFrame() end

    _G.UIParent = noopFrame()

    _G.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"

    _G.DEFAULT_CHAT_FRAME = { AddMessage = function() end }

    _G.SlashCmdList         = {}
    _G.SLASH_DUNCEDMAXXING1 = nil
    _G.SLASH_DUNCEDMAXXING2 = nil
    _G.DuncedmaxxingDB      = nil
end

--- Reset per-test overrides and clock state.
local function reset()
    mockClock:reset()
    _G.C_UnitAuras.GetPlayerAuraBySpellID = function(spellID) return nil end
end

return {
    mockClock    = mockClock,
    makeAuraData = makeAuraData,
    noopFrame    = noopFrame,
    install      = install,
    reset        = reset,
}
