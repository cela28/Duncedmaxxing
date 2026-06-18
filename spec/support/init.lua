-- spec/support/init.lua
-- Test loader with loadfile() vararg injection and ADDON_LOADED bootstrap.
-- Uses loadfile() NOT dofile() — dofile() passes empty varargs causing
-- `local _, DMX = ...` to assign nil to DMX and crash everything (RESEARCH Pitfall 2).

local stubs = require("spec.support.wow_stubs")

--- Load an addon source file with WoW vararg injection.
-- Passes (addonName, dmxTable) as the chunk's varargs, mirroring what the
-- WoW engine does when it loads addon files.
local function loadAddon(path, addonName, dmxTable)
    local chunk, err = loadfile(path)
    if not chunk then
        error("Failed to load " .. path .. ": " .. tostring(err))
    end
    return chunk(addonName, dmxTable)
end

--- Load the addon from scratch with full isolation (D-06).
-- Returns DMX, Tip, mockClock.
local function load()
    -- Fresh namespace for complete isolation between test files.
    local DMX = {}
    _G.DuncedmaxxingDB = nil

    -- Install WoW API stubs into _G.
    stubs.install(DMX)

    -- Load files in TOC order (Duncedmaxxing/Duncedmaxxing.toc lines 10-13):
    --   Util.lua, Core.lua, Options.lua (skipped), Modules\TipOfTheSpear.lua
    loadAddon("Duncedmaxxing/Util.lua",                     "Duncedmaxxing", DMX)
    loadAddon("Duncedmaxxing/Core.lua",                     "Duncedmaxxing", DMX)
    loadAddon("Duncedmaxxing/Modules/TipOfTheSpear.lua",    "Duncedmaxxing", DMX)

    -- Replicate ADDON_LOADED bootstrap (Core.lua lines 338-348).
    -- coreFrame is a local inside Core.lua and cannot be reached from here.
    -- DMX._test is wired by Plan 02 for test-only access.
    _G.DuncedmaxxingDB = {}
    DMX._test.MergeDefaults(DMX.defaults, _G.DuncedmaxxingDB)
    DMX._test.NormalizeDB(_G.DuncedmaxxingDB)
    DMX.db    = _G.DuncedmaxxingDB
    DMX.ready = true
    DMX:ForEachModule("Initialize", DMX)

    local Tip = DMX:GetModule("tip")
    return DMX, Tip, stubs.mockClock
end

--- Reset Tip runtime tracking fields and clock state.
-- Zeros all fields that ApplySpell / SyncFromAura mutate.
-- Sets clock.now = 100 (non-zero base avoids Pitfall 5 grace-period collision).
local function resetTipState(Tip, clock)
    Tip.stacks            = 0
    Tip.expiresAt         = 0
    Tip.lastPredictAt     = 0
    Tip.lastPredictKind   = nil
    Tip.castVerifySerial  = 0
    Tip.auraVerifyPending = false
    Tip.expireTimer       = nil
    Tip.testMode          = false
    Tip.hasTwinFangs      = false
    clock:reset()
    clock.now = 100
    -- Reset aura dispatch via mockAura.impl (not _G.C_UnitAuras field, which the
    -- module-level local in TipOfTheSpear.lua has already captured).
    stubs.mockAura.impl = function(_spellID) return nil end
end

return {
    load           = load,
    resetTipState  = resetTipState,
}
