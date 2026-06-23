local _, DMX = ...

local Options = {}
DMX.Options = Options

local Clamp        = DMX.Util.Clamp
local ParseHexColor = DMX.Util.ParseHexColor

local WHITE_TEX = "Interface\\Buttons\\WHITE8X8"
local MODE_LABELS = {
    bar = "Bar",
    number = "Number",
}

local function InCombat()
    return InCombatLockdown and InCombatLockdown()
end

local function ToByte(value)
    value = Clamp(value or 1, 0, 1) or 1
    return math.floor(value * 255 + 0.5)
end

local function ColorToHex(color)
    color = color or {}
    local r = ToByte(color.r)
    local g = ToByte(color.g)
    local b = ToByte(color.b)
    local a = ToByte(color.a == nil and 1 or color.a)

    if a < 255 then
        return string.format("%02x%02x%02x%02x", r, g, b, a)
    end

    return string.format("%02x%02x%02x", r, g, b)
end

local function GetCfg()
    local db = DMX:GetDB()
    return db and db.tip
end

local function RefreshTracker()
    if DMX.RefreshTip then
        DMX:RefreshTip()
    end
end

local function ColorTexture(parent, layer, r, g, b, a)
    local texture = parent:CreateTexture(nil, layer)
    texture:SetTexture(WHITE_TEX)
    texture:SetVertexColor(r, g, b, a)
    return texture
end

local function CreateText(parent, text, x, y, template)
    local fontString = parent:CreateFontString(nil, "ARTWORK", template or "GameFontNormalSmall")
    fontString:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    fontString:SetText(text)
    return fontString
end

local function CreateButton(parent, text, x, y, width, height, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, height)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    button:SetText(text)
    button:SetScript("OnClick", function()
        if not Options:CanChange() then
            return
        end
        onClick()
        Options:Refresh()
    end)
    return button
end

local function CreateCheckbox(parent, text, x, y, getValue, setValue)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetSize(24, 24)
    check:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)

    local label = check:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    label:SetPoint("LEFT", check, "RIGHT", 2, 0)
    label:SetText(text)

    check:SetScript("OnClick", function(self)
        if not Options:CanChange() then
            self:SetChecked(getValue())
            return
        end

        setValue(self:GetChecked() and true or false)
        RefreshTracker()
        Options:Refresh()
    end)

    table.insert(Options.checkboxes, {
        check = check,
        get = getValue,
    })
end

local function CreateInput(parent, text, x, y, width, getValue, setValue)
    CreateText(parent, text, x, y - 2)

    local editBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    editBox:SetSize(width, 22)
    editBox:SetPoint("TOPLEFT", parent, "TOPLEFT", x + 90, y)
    editBox:SetAutoFocus(false)

    local function Apply()
        if not Options:CanChange() then
            editBox:SetText(tostring(getValue()))
            return
        end

        local ok = setValue(editBox:GetText())
        if ok then
            RefreshTracker()
        end
        Options:Refresh()
    end

    editBox:SetScript("OnEnterPressed", function(self)
        Apply()
        self:ClearFocus()
    end)
    editBox:SetScript("OnEscapePressed", function(self)
        self:SetText(tostring(getValue()))
        self:ClearFocus()
    end)
    editBox:SetScript("OnEditFocusLost", Apply)

    table.insert(Options.inputs, {
        editBox = editBox,
        get = getValue,
    })
end

function Options:CanChange()
    if InCombat() then
        DMX:Print("Settings cannot be opened or changed in combat.")
        return false
    end

    return true
end

function Options:SavePosition()
    if not self.window then return end

    local cfg = GetCfg()
    local centerX, centerY = self.window:GetCenter()
    local parentX, parentY = UIParent:GetCenter()

    if cfg and centerX and centerY and parentX and parentY then
        cfg.optionsX = centerX - parentX
        cfg.optionsY = centerY - parentY
    end
end

function Options:ApplyPosition()
    if not self.window then return end

    local cfg = GetCfg() or DMX.defaults.tip
    self.window:ClearAllPoints()
    self.window:SetPoint("CENTER", UIParent, "CENTER", cfg.optionsX or 360, cfg.optionsY or 80)
end

function Options:SetMode(mode)
    local cfg = GetCfg()
    if not cfg then return end

    cfg.displayMode = mode
    RefreshTracker()
end

function Options:BuildWindow()
    if self.window then
        return
    end

    self.inputs = {}
    self.checkboxes = {}

    local window = CreateFrame("Frame", "DuncedmaxxingOptionsWindow", UIParent)
    window:SetSize(386, 484)
    window:SetFrameStrata("DIALOG")
    window:SetFrameLevel(90)
    window:SetClampedToScreen(true)
    window:EnableMouse(true)
    window:SetMovable(true)
    window:RegisterForDrag("LeftButton")
    self.window = window

    local bg = ColorTexture(window, "BACKGROUND", 0.03, 0.03, 0.03, 0.88)
    bg:SetAllPoints()

    local header = ColorTexture(window, "BORDER", 0.10, 0.09, 0.08, 0.95)
    header:SetPoint("TOPLEFT", window, "TOPLEFT", 1, -1)
    header:SetPoint("TOPRIGHT", window, "TOPRIGHT", -1, -1)
    header:SetSize(1, 30)

    local borderTop = ColorTexture(window, "BORDER", 0, 0, 0, 1)
    borderTop:SetPoint("TOPLEFT")
    borderTop:SetPoint("TOPRIGHT")
    borderTop:SetSize(1, 1)
    local borderBottom = ColorTexture(window, "BORDER", 0, 0, 0, 1)
    borderBottom:SetPoint("BOTTOMLEFT")
    borderBottom:SetPoint("BOTTOMRIGHT")
    borderBottom:SetSize(1, 1)
    local borderLeft = ColorTexture(window, "BORDER", 0, 0, 0, 1)
    borderLeft:SetPoint("TOPLEFT")
    borderLeft:SetPoint("BOTTOMLEFT")
    borderLeft:SetSize(1, 1)
    local borderRight = ColorTexture(window, "BORDER", 0, 0, 0, 1)
    borderRight:SetPoint("TOPRIGHT")
    borderRight:SetPoint("BOTTOMRIGHT")
    borderRight:SetSize(1, 1)

    window:SetScript("OnDragStart", function(self)
        if not InCombat() then
            self:StartMoving()
        end
    end)
    window:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        Options:SavePosition()
    end)
    window:SetScript("OnShow", function()
        if InCombat() then
            window:Hide()
            DMX:Print("Settings cannot be opened in combat.")
            return
        end

        Options:ApplyPosition()
        Options:Refresh()
    end)

    CreateText(window, "Duncedmaxxing", 14, -9, "GameFontNormal")
    CreateButton(window, "X", 348, -6, 24, 20, function()
        window:Hide()
    end)

    self.modeText = CreateText(window, "Display: Bar", 16, -48, "GameFontNormal")
    CreateButton(window, "Bar", 108, -43, 62, 22, function() self:SetMode("bar") end)
    CreateButton(window, "Number", 244, -43, 72, 22, function() self:SetMode("number") end)

    CreateCheckbox(window, "Enabled", 14, -80,
        function() return GetCfg().enabled end,
        function(value) GetCfg().enabled = value end)
    CreateCheckbox(window, "Hide empty", 260, -80,
        function() return GetCfg().hideWhenEmpty end,
        function(value) GetCfg().hideWhenEmpty = value end)

    CreateText(window, "Position", 16, -120, "GameFontNormal")
    CreateInput(window, "X", 16, -148, 62,
        function() return GetCfg().x end,
        function(value)
            local x = Clamp(value, -4000, 4000)
            if not x then return false end
            GetCfg().x = x
            return true
        end)
    CreateInput(window, "Y", 16, -178, 62,
        function() return GetCfg().y end,
        function(value)
            local y = Clamp(value, -4000, 4000)
            if not y then return false end
            GetCfg().y = y
            return true
        end)
    CreateInput(window, "Scale", 16, -208, 62,
        function() return GetCfg().scale end,
        function(value)
            local scale = Clamp(value, 0.5, 2)
            if not scale then return false end
            GetCfg().scale = scale
            return true
        end)

    CreateText(window, "Bar", 16, -248, "GameFontNormal")
    CreateInput(window, "Width", 16, -276, 62,
        function() return GetCfg().width end,
        function(value)
            local width = Clamp(value, 20, 2000)
            if not width then return false end
            GetCfg().width = width
            return true
        end)
    CreateInput(window, "Height", 16, -306, 62,
        function() return GetCfg().height end,
        function(value)
            local height = Clamp(value, 4, 200)
            if not height then return false end
            GetCfg().height = height
            return true
        end)
    CreateInput(window, "Border", 16, -336, 62,
        function() return GetCfg().borderSize end,
        function(value)
            local size = Clamp(value, 0, 10)
            if not size then return false end
            GetCfg().borderSize = size
            return true
        end)

    CreateText(window, "Other Modes", 204, -120, "GameFontNormal")
    CreateInput(window, "Text size", 204, -148, 62,
        function() return GetCfg().numberFontSize end,
        function(value)
            local size = Clamp(value, 8, 96)
            if not size then return false end
            GetCfg().numberFontSize = size
            return true
        end)

    CreateText(window, "Colors", 204, -248, "GameFontNormal")
    CreateInput(window, "Fill", 204, -276, 78,
        function() return ColorToHex(GetCfg().fillColor) end,
        function(value)
            local color = ParseHexColor(value)
            if not color then return false end
            GetCfg().fillColor = color
            return true
        end)
    CreateInput(window, "Border", 204, -306, 78,
        function() return ColorToHex(GetCfg().borderColor) end,
        function(value)
            local color = ParseHexColor(value)
            if not color then return false end
            GetCfg().borderColor = color
            return true
        end)
    CreateInput(window, "Text", 204, -336, 78,
        function() return ColorToHex(GetCfg().textColor) end,
        function(value)
            local color = ParseHexColor(value)
            if not color then return false end
            GetCfg().textColor = color
            return true
        end)
    CreateInput(window, "Empty %", 204, -366, 62,
        function() return math.floor((GetCfg().emptyColor.a or 0) * 100 + 0.5) end,
        function(value)
            local alpha = Clamp(value, 0, 100)
            if not alpha then return false end
            GetCfg().emptyColor.a = alpha / 100
            return true
        end)

    CreateButton(window, "Unlock Bar", 16, -414, 86, 24, function()
        DMX:GetDB().locked = false
        DMX:ForEachModule("ApplyLock")
        RefreshTracker()
    end)
    CreateButton(window, "Lock Bar", 108, -414, 76, 24, function()
        DMX:GetDB().locked = true
        DMX:ForEachModule("ApplyLock")
        RefreshTracker()
    end)
    CreateButton(window, "Preview", 190, -414, 74, 24, function()
        local tip = DMX:GetModule("tip")
        if tip and tip.SetTestStacks then
            tip:SetTestStacks(3)
        end
    end)
    CreateButton(window, "Reset", 270, -414, 70, 24, function()
        local tip = DMX:GetModule("tip")
        if tip and tip.ResetPosition then
            tip:ResetPosition()
        end
    end)
    CreateButton(window, "Reset Style", 16, -444, 96, 24, function()
        if DMX.ResetTipStyle then
            DMX:ResetTipStyle()
        end
    end)

    window:Hide()
end

function Options:Refresh()
    local cfg = GetCfg()
    if not cfg then return end

    if self.modeText then
        self.modeText:SetText("Display: " .. (MODE_LABELS[cfg.displayMode] or "Bar"))
    end

    for _, item in ipairs(self.checkboxes or {}) do
        item.check:SetChecked(item.get() and true or false)
    end

    for _, item in ipairs(self.inputs or {}) do
        item.editBox:SetText(tostring(item.get()))
    end
end

function Options:Initialize()
    if self.initialized then
        return
    end
    self.initialized = true

    self:BuildWindow()

    self.combatFrame = CreateFrame("Frame")
    self.combatFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    self.combatFrame:SetScript("OnEvent", function()
        if self.window then
            self.window:Hide()
        end
    end)
end

function Options:Open()
    if InCombat() then
        DMX:Print("Settings cannot be opened in combat.")
        return
    end

    self:Initialize()
    self:ApplyPosition()
    self:Refresh()
    self.window:Show()
end

function DMX:InitializeOptions()
    Options:Initialize()
end

function DMX:OpenOptions()
    Options:Open()
end
