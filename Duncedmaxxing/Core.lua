local addonName, DMX = ...

_G.Duncedmaxxing = DMX

DMX.name = addonName
DMX.version = "0.3.2"
DMX.modules     = DMX.modules     or {}
DMX.moduleOrder = DMX.moduleOrder or {}

local SETTINGS_MIGRATION = "0.3.3-stackcolorfmt"

local DEFAULTS = {
    locked = true,
    tip = {
        enabled = true,
        hideWhenEmpty = false,
        x = 0,
        y = -160,
        scale = 1,
        width = 247,
        height = 10,
        borderSize = 1,
        displayMode = "bar",
        numberFontSize = 22,
        fillColor = { r = 0.72, g = 0.55, b = 0.02, a = 1 },
        emptyColor = { r = 0, g = 0, b = 0, a = 0.5 },
        borderColor = { r = 0, g = 0, b = 0, a = 1 },
        textColor = { r = 1, g = 1, b = 1, a = 1 },
        colorByStack = true,
        stackColors = {
            [0] = { r = 1, g = 1, b = 1, a = 1 },
            [1] = { r = 0.18039, g = 0.80000, b = 0.44314, a = 1 },
            [2] = { r = 1, g = 0.94118, b = 0, a = 1 },
            [3] = { r = 1, g = 0.29804, b = 0.18824, a = 1 },
        },
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

local function StackColorsAreLegacyFormat(stackColors)
    if type(stackColors) ~= "table" then
        return false
    end

    -- Legacy entries store components positionally as { [1]=r, [2]=g, [3]=b, [4]=a }.
    -- In production MergeDefaults runs before NormalizeDB and injects .r/.g/.b/.a default
    -- keys into these tables, but it leaves the numeric indices intact -- so a lingering
    -- numeric [1] is the reliable legacy signal (a check on .r == nil would miss the
    -- post-merge mixed shape). Scan every slot (0-3) so a partially-migrated table is
    -- still detected and repaired.
    for i = 0, 3 do
        local entry = stackColors[i]
        if type(entry) == "table" and entry[1] ~= nil then
            return true
        end
    end

    return false
end

local function ConvertLegacyStackColors(stackColors)
    local converted = {}

    for i = 0, 3 do
        local entry = stackColors[i]
        if type(entry) == "table" and entry[1] ~= nil then
            -- Recover the user's customized colors from the positional data and drop the
            -- stale numeric keys (plus any default .r/.g/.b/.a that MergeDefaults injected).
            converted[i] = { r = entry[1], g = entry[2], b = entry[3], a = entry[4] }
        elseif type(entry) == "table" then
            converted[i] = entry
        else
            converted[i] = CopyDefaults(DEFAULTS.tip.stackColors[i])
        end
    end

    return converted
end

local function NormalizeDB(db)
    local tip = db.tip

    if db.settingsMigration ~= SETTINGS_MIGRATION then
        if StackColorsAreLegacyFormat(tip.stackColors) then
            tip.stackColors = ConvertLegacyStackColors(tip.stackColors)
        end

        tip.barWidth = nil
        tip.barHeight = nil
        tip.spacing = nil
        db.locked = true
        db.settingsMigration = SETTINGS_MIGRATION
    end

    if tip.displayMode ~= "bar" and tip.displayMode ~= "number" then
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

local function RegisterSlashCommands()
    SLASH_DUNCEDMAXXING1 = "/duncedmaxxing"
    SLASH_DUNCEDMAXXING2 = "/dmax"

    SlashCmdList.DUNCEDMAXXING = function()
        if DMX.OpenOptions then
            DMX:OpenOptions()
        else
            DMX:Print("Settings window unavailable — try reloading the UI.")
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
