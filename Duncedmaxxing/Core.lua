local addonName, DMX = ...

-- Util.lua is loaded first in TOC; DMX.Util is guaranteed populated here
local Clamp        = DMX.Util.Clamp
local ParseHexColor = DMX.Util.ParseHexColor
local Trim         = DMX.Util.Trim
local ParseOnOff   = DMX.Util.ParseOnOff

_G.Duncedmaxxing = DMX

DMX.name = addonName
DMX.version = "0.3.2"
DMX.modules     = DMX.modules     or {}
DMX.moduleOrder = DMX.moduleOrder or {}

local SETTINGS_MIGRATION = "0.3.2-fontfix"

local DEFAULTS = {
    locked = true,
    tip = {
        enabled = true,
        showOnlyInCombat = true,
        hideWhenEmpty = false,
        x = 0,
        y = -160,
        scale = 1,
        width = 247,
        height = 10,
        borderSize = 1,
        displayMode = "bar",
        iconSize = 28,
        iconSpacing = 4,
        numberFontSize = 22,
        fillColor = { r = 0.72, g = 0.55, b = 0.02, a = 1 },
        emptyColor = { r = 0, g = 0, b = 0, a = 0.5 },
        borderColor = { r = 0, g = 0, b = 0, a = 1 },
        textColor = { r = 1, g = 1, b = 1, a = 1 },
        optionsX = 360,
        optionsY = 170,
    },
}

DMX.defaults = DEFAULTS

local function CopyDefaults(defaults)
    local copy = {}
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            copy[key] = CopyDefaults(value)
        else
            copy[key] = value
        end
    end
    return copy
end

local function MergeDefaults(defaults, target)
    target = target or {}

    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = {}
            end
            MergeDefaults(value, target[key])
        elseif target[key] == nil then
            target[key] = value
        end
    end

    return target
end

local function NormalizeDB(db)
    local tip = db.tip

    if db.settingsMigration ~= SETTINGS_MIGRATION then
        local x, y, scale = tip.x, tip.y, tip.scale
        local optionsX, optionsY = tip.optionsX, tip.optionsY
        local fresh = CopyDefaults(DEFAULTS.tip)

        for key, value in pairs(fresh) do
            tip[key] = value
        end

        tip.x = x or fresh.x
        tip.y = y or fresh.y
        tip.scale = scale or fresh.scale
        tip.optionsX = optionsX or fresh.optionsX
        tip.optionsY = optionsY or fresh.optionsY
        tip.barWidth = nil
        tip.barHeight = nil
        tip.spacing = nil
        db.locked = true
        db.settingsMigration = SETTINGS_MIGRATION
    end

    if tip.displayMode ~= "bar" and tip.displayMode ~= "icons" and tip.displayMode ~= "number" then
        tip.displayMode = DEFAULTS.tip.displayMode
    end
end

function DMX:RegisterModule(key, module)
    self.modules[key] = module
    module.key = key
    table.insert(self.moduleOrder, key)

    if self.ready and module.Initialize then
        module:Initialize(self)
    end
end

function DMX:GetModule(key)
    return self.modules[key]
end

function DMX:GetDB()
    return self.db
end

function DMX:ForEachModule(method, ...)
    for _, key in ipairs(self.moduleOrder) do
        local module = self.modules[key]
        local fn = module and module[method]
        if fn then
            fn(module, ...)
        end
    end
end

function DMX:Print(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffaad372Duncedmaxxing|r: " .. tostring(message))
    end
end

function DMX:IsHunter()
    local _, class = UnitClass("player")
    return class == "HUNTER"
end

function DMX:IsSurvivalHunter()
    if not self:IsHunter() then
        return false
    end

    local spec
    if C_SpecializationInfo and C_SpecializationInfo.GetSpecialization then
        spec = C_SpecializationInfo.GetSpecialization()
    elseif GetSpecialization then
        spec = GetSpecialization()
    end

    return spec == 3
end

local function PrintHelp()
    DMX:Print("/dmax opens settings. /dmax help shows commands.")
    DMX:Print("/dmax lock, unlock, reset, show, hide, test, 0-3, scale <0.5-2>")
    DMX:Print("/dmax mode bar|icons|number, size 247 10, border 1, combat on|off")
end

local function RefreshTip(tip)
    if tip and not tip.inCombat then
        tip:SyncFromAura()
    end
    if tip and tip.RefreshLayout then
        tip:RefreshLayout()
    elseif tip and tip.Update then
        tip:Update()
    end
end

function DMX:RefreshTip()
    RefreshTip(self:GetModule("tip"))
end

function DMX:ResetTipStyle()
    local db = self:GetDB()
    if not db then return end

    local x, y, scale = db.tip.x, db.tip.y, db.tip.scale
    local optionsX, optionsY = db.tip.optionsX, db.tip.optionsY
    db.tip = CopyDefaults(DEFAULTS.tip)
    db.tip.x, db.tip.y, db.tip.scale = x, y, scale
    db.tip.optionsX, db.tip.optionsY = optionsX, optionsY
    self:RefreshTip()
end

local function RegisterSlashCommands()
    SLASH_DUNCEDMAXXING1 = "/duncedmaxxing"
    SLASH_DUNCEDMAXXING2 = "/dmax"

    SlashCmdList.DUNCEDMAXXING = function(input)
        input = Trim(input)

        local command, rest = input:match("^(%S*)%s*(.-)$")
        command = string.lower(command or "")
        rest = Trim(rest)

        local db = DMX:GetDB()
        local tip = DMX:GetModule("tip")

        if command == "" or command == "options" or command == "config" then
            if DMX.OpenOptions then
                DMX:OpenOptions()
            else
                PrintHelp()
            end
        elseif command == "help" or command == "commands" then
            PrintHelp()
        elseif command == "lock" then
            db.locked = true
            DMX:ForEachModule("ApplyLock")
            DMX:Print("Locked.")
        elseif command == "unlock" or command == "move" then
            db.locked = false
            DMX:ForEachModule("ApplyLock")
            DMX:Print("Unlocked. Drag the tracker, then use /dmax lock.")
        elseif command == "reset" then
            if tip and tip.ResetPosition then
                tip:ResetPosition()
                DMX:Print("Tip tracker position reset.")
            end
        elseif command == "show" then
            db.tip.enabled = true
            RefreshTip(tip)
            DMX:Print("Tip tracker enabled.")
        elseif command == "hide" then
            db.tip.enabled = false
            RefreshTip(tip)
            DMX:Print("Tip tracker disabled.")
        elseif command == "test" then
            if tip and tip.SetTestStacks then
                tip:SetTestStacks(3)
                DMX:Print("Showing a short 3-stack preview.")
            end
        elseif command == "scale" then
            local scale = tonumber(rest)
            if scale then
                if scale < 0.5 then scale = 0.5 end
                if scale > 2 then scale = 2 end
                db.tip.scale = scale
                RefreshTip(tip)
                DMX:Print("Scale set to " .. scale .. ".")
            else
                DMX:Print("Usage: /dmax scale 1.2")
            end
        elseif command == "mode" then
            local mode = string.lower(rest)
            if mode == "icon" then mode = "icons" end
            if mode == "text" then mode = "number" end

            if mode == "bar" or mode == "icons" or mode == "number" then
                db.tip.displayMode = mode
                RefreshTip(tip)
                DMX:Print("Display mode set to " .. mode .. ".")
            else
                DMX:Print("Usage: /dmax mode bar|icons|number")
            end
        elseif command == "size" or command == "barsize" then
            local width, height = rest:match("^(%S+)%s*(%S*)")
            width = Clamp(width, 20, 2000)
            height = Clamp(height, 4, 200)
            if width and height then
                db.tip.width = width
                db.tip.height = height
                RefreshTip(tip)
                DMX:Print("Bar size set to " .. width .. "x" .. height .. ".")
            else
                DMX:Print("Usage: /dmax size 247 10")
            end
        elseif command == "border" then
            local size = Clamp(rest, 0, 10)
            if size then
                db.tip.borderSize = size
                RefreshTip(tip)
                DMX:Print("Border set to " .. size .. "px.")
            else
                DMX:Print("Usage: /dmax border 1")
            end
        elseif command == "color" or command == "fill" then
            local color = ParseHexColor(rest)
            if color then
                db.tip.fillColor = color
                RefreshTip(tip)
                DMX:Print("Fill color updated.")
            else
                DMX:Print("Usage: /dmax color b88c03")
            end
        elseif command == "empty" or command == "emptyalpha" then
            local alpha = Clamp(rest, 0, 100)
            if alpha then
                db.tip.emptyColor.a = alpha / 100
                RefreshTip(tip)
                DMX:Print("Empty segment opacity set to " .. alpha .. "%.")
            else
                DMX:Print("Usage: /dmax empty 50")
            end
        elseif command == "combat" or command == "combatonly" then
            local enabled = ParseOnOff(rest)
            if enabled ~= nil then
                db.tip.showOnlyInCombat = enabled
                RefreshTip(tip)
                DMX:Print("Combat-only display " .. (enabled and "enabled." or "disabled."))
            else
                DMX:Print("Usage: /dmax combat on|off")
            end
        elseif command == "resetstyle" or command == "defaultstyle" then
            DMX:ResetTipStyle()
            DMX:Print("Tip tracker style reset.")
        else
            local stacks = tonumber(command)
            if stacks and tip and tip.SetTestStacks then
                tip:SetTestStacks(stacks)
                DMX:Print("Previewing " .. stacks .. " stack(s).")
            else
                PrintHelp()
            end
        end
    end
end

local coreFrame = CreateFrame("Frame")
coreFrame:RegisterEvent("ADDON_LOADED")
coreFrame:SetScript("OnEvent", function(_, _, loadedAddon)
    if loadedAddon ~= addonName then
        return
    end

    DuncedmaxxingDB = MergeDefaults(DEFAULTS, DuncedmaxxingDB)
    NormalizeDB(DuncedmaxxingDB)
    DMX.db = DuncedmaxxingDB
    DMX.ready = true

    if DMX.InitializeOptions then
        DMX:InitializeOptions()
    end

    RegisterSlashCommands()
    DMX:ForEachModule("Initialize", DMX)
end)

-- Test-only escape hatch: exposes local functions for spec/core_spec.lua
-- Do not use in production addon code.
DMX._test = {
    MergeDefaults      = MergeDefaults,
    NormalizeDB        = NormalizeDB,
    CopyDefaults       = CopyDefaults,
    SETTINGS_MIGRATION = SETTINGS_MIGRATION,
}
