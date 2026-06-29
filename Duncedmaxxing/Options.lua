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

    -- Shared controls section (visible in both modes)
    CreateText(window, "Position", 16, -80, "GameFontNormal")
    CreateInput(window, "X", 16, -108, 62,
        function() return GetCfg().x end,
        function(value)
            local x = Clamp(value, -4000, 4000)
            if not x then return false end
            GetCfg().x = x
            return true
        end)
    CreateInput(window, "Y", 16, -138, 62,
        function() return GetCfg().y end,
        function(value)
            local y = Clamp(value, -4000, 4000)
            if not y then return false end
            GetCfg().y = y
            return true
        end)
    CreateInput(window, "Scale", 16, -168, 62,
        function() return GetCfg().scale end,
        function(value)
            local scale = Clamp(value, 0.5, 2)
            if not scale then return false end
            GetCfg().scale = scale
            return true
        end)

    CreateCheckbox(window, "Hide empty", 16, -208,
        function() return GetCfg().hideWhenEmpty end,
        function(value) GetCfg().hideWhenEmpty = value end)

    -- Action row: Preview and Lock toggle pinned to bottom of window
    local previewBtn = CreateButton(window, "Preview Tracker", 0, 0, 74, 24, function()
        local tip = DMX:GetModule("tip")
        if tip and tip.SetTestStacks then
            tip:SetTestStacks(3)
        end
    end)
    previewBtn:ClearAllPoints()
    previewBtn:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", 16, 16)

    local lockBtn = CreateButton(window, "Lock", 0, 0, 76, 24, function()
        local db = DMX:GetDB()
        db.locked = not db.locked
        DMX:ForEachModule("ApplyLock")
        RefreshTracker()
    end)
    lockBtn:ClearAllPoints()
    lockBtn:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", 100, 16)
    self.lockBtn = lockBtn

    -- barSection: bar-mode-specific controls
    local barSection = CreateFrame("Frame", nil, window)
    barSection:SetSize(386, 200)
    barSection:SetPoint("TOPLEFT", window, "TOPLEFT", 0, -248)
    self.barSection = barSection

    CreateText(barSection, "Bar", 16, 0, "GameFontNormal")
    CreateInput(barSection, "Width", 16, -28, 62,
        function() return GetCfg().width end,
        function(value)
            local width = Clamp(value, 20, 2000)
            if not width then return false end
            GetCfg().width = width
            return true
        end)
    CreateInput(barSection, "Height", 16, -58, 62,
        function() return GetCfg().height end,
        function(value)
            local height = Clamp(value, 4, 200)
            if not height then return false end
            GetCfg().height = height
            return true
        end)
    CreateInput(barSection, "Border", 16, -88, 62,
        function() return GetCfg().borderSize end,
        function(value)
            local size = Clamp(value, 0, 10)
            if not size then return false end
            GetCfg().borderSize = size
            return true
        end)

    CreateText(barSection, "Colors", 204, 0, "GameFontNormal")
    CreateInput(barSection, "Fill", 204, -28, 78,
        function() return ColorToHex(GetCfg().fillColor) end,
        function(value)
            local color = ParseHexColor(value)
            if not color then return false end
            GetCfg().fillColor = color
            return true
        end)
    CreateInput(barSection, "Border", 204, -58, 78,
        function() return ColorToHex(GetCfg().borderColor) end,
        function(value)
            local color = ParseHexColor(value)
            if not color then return false end
            GetCfg().borderColor = color
            return true
        end)
    CreateInput(barSection, "Empty %", 204, -88, 62,
        function() return math.floor((GetCfg().emptyColor.a or 0) * 100 + 0.5) end,
        function(value)
            local alpha = Clamp(value, 0, 100)
            if not alpha then return false end
            GetCfg().emptyColor.a = alpha / 100
            return true
        end)

    -- numberSection: number-mode-specific controls
    local numberSection = CreateFrame("Frame", nil, window)
    numberSection:SetSize(386, 240)
    numberSection:SetPoint("TOPLEFT", window, "TOPLEFT", 0, -248)
    self.numberSection = numberSection

    CreateText(numberSection, "Number Mode", 16, 0, "GameFontNormal")
    CreateInput(numberSection, "Text size", 16, -28, 62,
        function() return GetCfg().numberFontSize end,
        function(value)
            local size = Clamp(value, 8, 96)
            if not size then return false end
            GetCfg().numberFontSize = size
            return true
        end)

    CreateText(numberSection, "Stack Colors", 16, -68, "GameFontNormal")

    local stackLabels = { "0 stacks", "1 stack", "2 stacks", "3 stacks" }
    local stackYOffsets = { -96, -126, -156, -186 }
    for i = 0, 3 do
        local idx = i
        CreateInput(numberSection, stackLabels[i + 1], 16, stackYOffsets[i + 1], 78,
            function() return ColorToHex(GetCfg().stackColors[idx]) end,
            function(value)
                local color = ParseHexColor(value)
                if not color then return false end
                GetCfg().stackColors[idx] = color
                return true
            end)
    end

    -- Reset Colors button: raw CreateFrame (not factory) to prevent auto-Refresh reverting confirm text
    local resetColorsBtn = CreateFrame("Button", nil, numberSection, "UIPanelButtonTemplate")
    resetColorsBtn:SetSize(100, 24)
    resetColorsBtn:SetPoint("TOPLEFT", numberSection, "TOPLEFT", 16, -216)
    resetColorsBtn:SetText("Reset Colors")
    self.resetColorsBtn = resetColorsBtn
    self.resetColorsPending = false
    self.resetColorsTimer = nil

    resetColorsBtn:SetScript("OnClick", function()
        if not Options:CanChange() then return end

        if not Options.resetColorsPending then
            -- First click: arm the confirm state
            Options.resetColorsPending = true
            resetColorsBtn:SetText("Confirm Reset")

            if C_Timer and C_Timer.NewTimer then
                Options.resetColorsTimer = C_Timer.NewTimer(3, function()
                    if not Options.resetColorsPending then return end
                    Options.resetColorsPending = false
                    Options.resetColorsTimer = nil
                    resetColorsBtn:SetText("Reset Colors")
                end)
            end
        else
            -- Second click: perform the reset
            Options.resetColorsPending = false
            if Options.resetColorsTimer then
                Options.resetColorsTimer:Cancel()
                Options.resetColorsTimer = nil
            end
            GetCfg().stackColors = DMX._test.CopyDefaults(DMX.defaults.tip.stackColors)
            RefreshTracker()
            Options:Refresh()
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

    -- Show/hide mode-conditional sections and adjust window height
    if self.barSection then
        if cfg.displayMode == "bar" then
            self.barSection:Show()
            self.numberSection:Hide()
            self.window:SetSize(386, 380)
        else
            self.barSection:Hide()
            self.numberSection:Show()
            self.window:SetSize(386, 484)
        end
    end

    -- Sync lock toggle text
    if self.lockBtn then
        local db = DMX:GetDB()
        self.lockBtn:SetText(db and db.locked and "Unlock" or "Lock")
    end

    -- Reset Colors: revert pending state on any Refresh
    if self.resetColorsBtn and self.resetColorsPending then
        self.resetColorsPending = false
        if self.resetColorsTimer then
            self.resetColorsTimer:Cancel()
            self.resetColorsTimer = nil
        end
        self.resetColorsBtn:SetText("Reset Colors")
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
