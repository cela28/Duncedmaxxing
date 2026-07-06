local _, DMX = ...

local Options = {}
DMX.Options = Options

local Clamp        = DMX.Util.Clamp
local ParseHexColor = DMX.Util.ParseHexColor

local WHITE_TEX = "Interface\\Buttons\\WHITE8X8"

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

    return check, label
end

local function CreateInput(parent, text, x, y, width, getValue, setValue)
    local label = CreateText(parent, text, x, y - 2)

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

    return editBox, label
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

    if self.window and self.window:IsShown() then
        self:Refresh()
    end
end

local function AddToGroup(group, ...)
    for i = 1, select("#", ...) do
        local widget = select(i, ...)
        if widget then
            table.insert(Options.widgetGroups[group], widget)
        end
    end
end

function Options:BuildWindow()
    if self.window then
        return
    end

    self.inputs = {}
    self.checkboxes = {}
    self.widgetGroups = { both = {}, bar = {}, number = {} }
    self.modeButtons = {}
    self.colorGroups = { flat = {}, stack = {} }

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

    self.modeButtons.bar = CreateButton(window, "Bar", 16, -43, 62, 22, function() self:SetMode("bar") end)
    self.modeButtons.number = CreateButton(window, "Number", 82, -43, 72, 22, function() self:SetMode("number") end)

    local hideEmptyCheck, hideEmptyLabel = CreateCheckbox(window, "Hide empty", 260, -80,
        function() return GetCfg().hideWhenEmpty end,
        function(value) GetCfg().hideWhenEmpty = value end)
    AddToGroup("both", hideEmptyCheck, hideEmptyLabel)

    local positionHeader = CreateText(window, "Position", 16, -120, "GameFontNormal")
    AddToGroup("both", positionHeader)
    local xInput, xLabel = CreateInput(window, "X", 16, -148, 62,
        function() return GetCfg().x end,
        function(value)
            local x = Clamp(value, -4000, 4000)
            if not x then return false end
            GetCfg().x = x
            return true
        end)
    AddToGroup("both", xInput, xLabel)
    local yInput, yLabel = CreateInput(window, "Y", 16, -178, 62,
        function() return GetCfg().y end,
        function(value)
            local y = Clamp(value, -4000, 4000)
            if not y then return false end
            GetCfg().y = y
            return true
        end)
    AddToGroup("both", yInput, yLabel)
    local scaleInput, scaleLabel = CreateInput(window, "Scale", 16, -208, 62,
        function() return GetCfg().scale end,
        function(value)
            local scale = Clamp(value, 0.5, 2)
            if not scale then return false end
            GetCfg().scale = scale
            return true
        end)
    AddToGroup("bar", scaleInput, scaleLabel)

    local barHeader = CreateText(window, "Bar", 16, -248, "GameFontNormal")
    AddToGroup("bar", barHeader)
    local widthInput, widthLabel = CreateInput(window, "Width", 16, -276, 62,
        function() return GetCfg().width end,
        function(value)
            local width = Clamp(value, 20, 2000)
            if not width then return false end
            GetCfg().width = width
            return true
        end)
    AddToGroup("bar", widthInput, widthLabel)
    local heightInput, heightLabel = CreateInput(window, "Height", 16, -306, 62,
        function() return GetCfg().height end,
        function(value)
            local height = Clamp(value, 4, 200)
            if not height then return false end
            GetCfg().height = height
            return true
        end)
    AddToGroup("bar", heightInput, heightLabel)
    local borderSizeInput, borderSizeLabel = CreateInput(window, "Border", 16, -336, 62,
        function() return GetCfg().borderSize end,
        function(value)
            local size = Clamp(value, 0, 10)
            if not size then return false end
            GetCfg().borderSize = size
            return true
        end)
    AddToGroup("bar", borderSizeInput, borderSizeLabel)

    local numberHeader = CreateText(window, "Number", 204, -120, "GameFontNormal")
    AddToGroup("number", numberHeader)
    local fontSizeInput, fontSizeLabel = CreateInput(window, "Text size", 204, -148, 62,
        function() return GetCfg().numberFontSize end,
        function(value)
            local size = Clamp(value, 8, 96)
            if not size then return false end
            GetCfg().numberFontSize = size
            return true
        end)
    AddToGroup("number", fontSizeInput, fontSizeLabel)

    local colorByStackCheck, colorByStackLabel = CreateCheckbox(window, "Color by stack", 204, -178,
        function() return GetCfg().colorByStack end,
        function(value) GetCfg().colorByStack = value end)
    AddToGroup("number", colorByStackCheck, colorByStackLabel)

    local colorsHeader = CreateText(window, "Colors", 204, -238, "GameFontNormal")
    AddToGroup("bar", colorsHeader)
    AddToGroup("number", colorsHeader)
    local borderColorInput, borderColorLabel = CreateInput(window, "Border", 204, -264, 78,
        function() return ColorToHex(GetCfg().borderColor) end,
        function(value)
            local color = ParseHexColor(value)
            if not color then return false end
            GetCfg().borderColor = color
            return true
        end)
    AddToGroup("bar", borderColorInput, borderColorLabel)
    local fillInput, fillLabel = CreateInput(window, "Fill", 204, -292, 78,
        function() return ColorToHex(GetCfg().fillColor) end,
        function(value)
            local color = ParseHexColor(value)
            if not color then return false end
            GetCfg().fillColor = color
            return true
        end)
    AddToGroup("bar", fillInput, fillLabel)
    local emptyPctInput, emptyPctLabel = CreateInput(window, "Empty %", 204, -320, 62,
        function() return math.floor((GetCfg().emptyColor.a or 0) * 100 + 0.5) end,
        function(value)
            local alpha = Clamp(value, 0, 100)
            if not alpha then return false end
            GetCfg().emptyColor.a = alpha / 100
            return true
        end)
    AddToGroup("bar", emptyPctInput, emptyPctLabel)

    local textInput, textLabel = CreateInput(window, "Text", 204, -292, 78,
        function() return ColorToHex(GetCfg().textColor) end,
        function(value)
            local color = ParseHexColor(value)
            if not color then return false end
            GetCfg().textColor = color
            return true
        end)
    AddToGroup("number", textInput, textLabel)
    table.insert(self.colorGroups.flat, { widget = textInput, label = textLabel })

    local stackLabels = { [0] = "0 stacks", [1] = "1 stack", [2] = "2 stacks", [3] = "3 stacks" }
    for stack = 0, 3 do
        local stackInput, stackLabel = CreateInput(window, stackLabels[stack], 204, -320 - (stack * 22), 78,
            function() return ColorToHex(GetCfg().stackColors[stack]) end,
            function(value)
                local color = ParseHexColor(value)
                if not color then return false end
                GetCfg().stackColors[stack] = color
                return true
            end)
        AddToGroup("number", stackInput, stackLabel)
        table.insert(self.colorGroups.stack, { widget = stackInput, label = stackLabel })
    end

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

local function SetWidgetShown(widget, shown)
    if not widget then return end
    if shown then
        widget:Show()
    else
        widget:Hide()
    end
end

local function SetColorGroupEnabled(items, enabled)
    for _, item in ipairs(items or {}) do
        local widget = item.widget
        local label = item.label
        if widget then
            if widget.Disable and widget.Enable then
                if enabled then
                    widget:Enable()
                else
                    widget:Disable()
                end
            end
            widget:SetAlpha(enabled and 1 or 0.4)
        end
        if label then
            label:SetAlpha(enabled and 1 or 0.4)
        end
    end
end

local function HighlightModeButton(button, active)
    if not button then return end

    if active then
        if button.LockHighlight then
            button:LockHighlight()
        end
        if button.SetAlpha then
            button:SetAlpha(1)
        end
    else
        if button.UnlockHighlight then
            button:UnlockHighlight()
        end
        if button.SetAlpha then
            button:SetAlpha(0.75)
        end
    end
end

function Options:Refresh()
    local cfg = GetCfg()
    if not cfg then return end

    for _, item in ipairs(self.checkboxes or {}) do
        item.check:SetChecked(item.get() and true or false)
    end

    for _, item in ipairs(self.inputs or {}) do
        item.editBox:SetText(tostring(item.get()))
    end

    local mode = cfg.displayMode
    if mode ~= "bar" and mode ~= "number" then
        mode = "bar"
    end

    local groups = self.widgetGroups or {}
    for _, widget in ipairs(groups.both or {}) do
        SetWidgetShown(widget, true)
    end
    for _, widget in ipairs(groups.bar or {}) do
        SetWidgetShown(widget, mode == "bar")
    end
    for _, widget in ipairs(groups.number or {}) do
        SetWidgetShown(widget, mode == "number")
    end

    if self.modeButtons then
        HighlightModeButton(self.modeButtons.bar, mode == "bar")
        HighlightModeButton(self.modeButtons.number, mode == "number")
    end

    if mode == "number" and self.colorGroups then
        local colorByStack = cfg.colorByStack ~= false
        SetColorGroupEnabled(self.colorGroups.stack, colorByStack)
        SetColorGroupEnabled(self.colorGroups.flat, not colorByStack)
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
