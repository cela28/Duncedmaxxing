local _, DMX = ...

local Tip = {}

local TIP_OF_THE_SPEAR = 260286
local KILL_COMMAND = 259489
local MAX_STACKS = 3
local BUFF_DURATION = 10
local AURA_VERIFY_DELAY = 1.25
local FINAL_AURA_VERIFY_DELAY = 2.05
local CONSUMER_UPSYNC_GRACE = 2.75
local FALLBACK_ICON = 132275
local TRACKER_WIDTH = 247
local TRACKER_HEIGHT = 10
local BORDER_SIZE = 1

local CONSUMERS = {
    [1261193] = true, -- Boomstick
    [1250646] = true, -- Takedown
    [259495] = true,  -- Wildfire Bomb
    [186270] = true,  -- Raptor Strike
    [1262293] = true, -- Raptor Swipe
}

local TIP_COLOR = { 0.72, 0.55, 0.02, 1 }
local EMPTY_COLOR = { 0, 0, 0, 0.5 }
local BORDER_COLOR = { 0, 0, 0, 1 }
local WHITE_TEX = "Interface\\Buttons\\WHITE8X8"

local GetPlayerAuraBySpellID = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID

Tip.stacks = 0
Tip.active = false
Tip.inCombat = false
Tip.testMode = false
Tip.testStacks = MAX_STACKS
Tip.expiresAt = 0
Tip.castVerifySerial = 0
Tip.auraVerifyPending = false
Tip.lastPredictAt = 0
Tip.lastPredictKind = nil

local function ClampStacks(value)
    value = tonumber(value) or 0
    if value < 0 then return 0 end
    if value > MAX_STACKS then return MAX_STACKS end
    return value
end

local function ClassifySpellID(value)
    if value == KILL_COMMAND then
        return "generator"
    end

    if type(value) == "number" and CONSUMERS[value] then
        return "consumer"
    end
end

local function FindTrackedSpell(...)
    for i = 1, select("#", ...) do
        local kind = ClassifySpellID(select(i, ...))
        if kind then
            return kind
        end
    end
end

local function ReadLiveState()
    if not GetPlayerAuraBySpellID then
        return nil, nil
    end

    local ok, aura = pcall(GetPlayerAuraBySpellID, TIP_OF_THE_SPEAR)
    if not ok then
        return nil, nil
    end

    if not aura then
        return 0, 0
    end

    local okState, stacks, expiresAt = pcall(function()
        local applications = aura.applications
        local stackCount

        if applications and applications > 0 then
            stackCount = ClampStacks(applications)
        else
            stackCount = 1
        end

        local expirationTime = aura.expirationTime
        if expirationTime and expirationTime > GetTime() then
            return stackCount, expirationTime
        end

        return stackCount, nil
    end)

    if okState then
        return stacks, expiresAt
    end

    return nil, nil
end

local function GetCfg()
    return DMX:GetDB().tip
end

local function ColorTuple(color, fallback)
    color = color or fallback or {}
    fallback = fallback or {}

    return color.r or color[1] or fallback.r or fallback[1] or 1,
        color.g or color[2] or fallback.g or fallback[2] or 1,
        color.b or color[3] or fallback.b or fallback[3] or 1,
        color.a or color[4] or fallback.a or fallback[4] or 1
end

local function ResolveSpellTexture()
    if C_Spell and C_Spell.GetSpellTexture then
        return C_Spell.GetSpellTexture(TIP_OF_THE_SPEAR) or FALLBACK_ICON
    end

    if _G.GetSpellTexture then
        return _G.GetSpellTexture(TIP_OF_THE_SPEAR) or FALLBACK_ICON
    end

    return FALLBACK_ICON
end

local function ApplyPosition(tip)
    if not tip.root then return end

    local cfg = GetCfg()
    tip.root:ClearAllPoints()
    tip.root:SetPoint("CENTER", UIParent, "CENTER", cfg.x or 0, cfg.y or -160)
end

local function SavePosition(tip)
    if not tip.root then return end

    local cfg = GetCfg()
    local centerX, centerY = tip.root:GetCenter()
    local parentX, parentY = UIParent:GetCenter()

    if centerX and centerY and parentX and parentY then
        cfg.x = centerX - parentX
        cfg.y = centerY - parentY
    end

    ApplyPosition(tip)
end

local function CreateBorder(parent)
    local texture = parent:CreateTexture(nil, "BACKGROUND")
    texture:SetTexture(WHITE_TEX)
    return texture
end

local function CreatePip(parent)
    local pip = CreateFrame("Frame", nil, parent)
    pip.fill = pip:CreateTexture(nil, "ARTWORK")
    pip.fill:SetAllPoints()
    pip.fill:SetTexture(WHITE_TEX)

    pip.border = {
        top = CreateBorder(pip),
        bottom = CreateBorder(pip),
        left = CreateBorder(pip),
        right = CreateBorder(pip),
    }

    return pip
end

local function EnsureBorders(tip)
    if tip.borders and tip.borders.top then return end

    tip.borders = {}
    tip.borders.top      = CreateBorder(tip.root)
    tip.borders.bottom   = CreateBorder(tip.root)
    tip.borders.left     = CreateBorder(tip.root)
    tip.borders.right    = CreateBorder(tip.root)
    tip.borders.divider1 = CreateBorder(tip.root)
    tip.borders.divider2 = CreateBorder(tip.root)
end

local function PaintBorder(border)
    local r, g, b, a = ColorTuple(GetCfg().borderColor, BORDER_COLOR)
    border:SetVertexColor(r, g, b, a)
end

local function LayoutBorders(tip, width, height, borderSize, segmentWidths)
    if borderSize <= 0 then
        for _, border in pairs(tip.borders) do
            border:Hide()
        end
        return
    end

    tip.borders.top:ClearAllPoints()
    tip.borders.top:SetPoint("TOPLEFT", tip.root, "TOPLEFT", 0, 0)
    tip.borders.top:SetSize(width, borderSize)

    tip.borders.bottom:ClearAllPoints()
    tip.borders.bottom:SetPoint("BOTTOMLEFT", tip.root, "BOTTOMLEFT", 0, 0)
    tip.borders.bottom:SetSize(width, borderSize)

    tip.borders.left:ClearAllPoints()
    tip.borders.left:SetPoint("TOPLEFT", tip.root, "TOPLEFT", 0, 0)
    tip.borders.left:SetSize(borderSize, height)

    tip.borders.right:ClearAllPoints()
    tip.borders.right:SetPoint("TOPRIGHT", tip.root, "TOPRIGHT", 0, 0)
    tip.borders.right:SetSize(borderSize, height)

    tip.borders.divider1:ClearAllPoints()
    tip.borders.divider1:SetPoint("TOPLEFT", tip.root, "TOPLEFT", borderSize + segmentWidths[1], 0)
    tip.borders.divider1:SetSize(borderSize, height)

    tip.borders.divider2:ClearAllPoints()
    tip.borders.divider2:SetPoint("TOPLEFT", tip.root, "TOPLEFT", borderSize + segmentWidths[1] + borderSize + segmentWidths[2], 0)
    tip.borders.divider2:SetSize(borderSize, height)

    for _, border in pairs(tip.borders) do
        PaintBorder(border)
    end
end

local function SetBordersShown(tip, shown)
    for _, border in pairs(tip.borders) do
        if shown then
            border:Show()
        else
            border:Hide()
        end
    end
end

local function SetPipBordersShown(pip, shown)
    for _, border in pairs(pip.border) do
        if shown then
            border:Show()
        else
            border:Hide()
        end
    end
end

local function LayoutPipBorder(pip, size)
    local r, g, b, a = ColorTuple(GetCfg().borderColor, BORDER_COLOR)
    for _, border in pairs(pip.border) do
        border:SetVertexColor(r, g, b, a)
    end

    if size <= 0 then
        SetPipBordersShown(pip, false)
        return
    end

    pip.border.top:ClearAllPoints()
    pip.border.top:SetPoint("TOPLEFT", pip, "TOPLEFT", 0, 0)
    pip.border.top:SetSize(pip:GetWidth(), size)

    pip.border.bottom:ClearAllPoints()
    pip.border.bottom:SetPoint("BOTTOMLEFT", pip, "BOTTOMLEFT", 0, 0)
    pip.border.bottom:SetSize(pip:GetWidth(), size)

    pip.border.left:ClearAllPoints()
    pip.border.left:SetPoint("TOPLEFT", pip, "TOPLEFT", 0, 0)
    pip.border.left:SetSize(size, pip:GetHeight())

    pip.border.right:ClearAllPoints()
    pip.border.right:SetPoint("TOPRIGHT", pip, "TOPRIGHT", 0, 0)
    pip.border.right:SetSize(size, pip:GetHeight())
end

local function EnsureFrame(tip)
    if tip.root then return end

    tip.root = CreateFrame("Frame", "Duncedmaxxing_TipOfTheSpear", UIParent)
    tip.root:SetFrameStrata("MEDIUM")
    tip.root:SetFrameLevel(20)
    tip.root:SetClampedToScreen(true)
    tip.pips = {}
    tip.borders = {}
    EnsureBorders(tip)

    for i = 1, MAX_STACKS do
        tip.pips[i] = CreatePip(tip.root)
    end

    tip.label = tip.root:CreateFontString(nil, "OVERLAY")
    tip.label:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    tip.label:SetText("|cffaad372Duncedmaxxing|r")
    tip.label:SetPoint("BOTTOM", tip.root, "TOP", 0, 4)

    tip.numberText = tip.root:CreateFontString(nil, "OVERLAY")
    tip.numberText:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 22, "OUTLINE")
    tip.numberText:SetPoint("CENTER", tip.root, "CENTER", 0, 0)
    tip.numberText:SetText("0")
    tip.numberText:Hide()

    tip.root:RegisterForDrag("LeftButton")
    tip.root:SetScript("OnDragStart", function(self)
        if not DMX:GetDB().locked then
            self:StartMoving()
        end
    end)
    tip.root:SetScript("OnDragStop", function(self)   -- self = WoW frame here
        self:StopMovingOrSizing()
        SavePosition(tip)   -- tip = Tip module table, captured from outer scope
    end)
end

function Tip:RefreshActive()
    self.active = DMX:IsSurvivalHunter()
end

function Tip:SyncFromAura()
    local liveStacks, liveExpiresAt = ReadLiveState()
    if liveStacks == nil then
        return false
    end

    if self.inCombat and self.lastPredictKind == "consumer" and liveStacks > self.stacks then
        if GetTime() < (self.lastPredictAt or 0) + CONSUMER_UPSYNC_GRACE then
            return false
        end
    end

    self.stacks = liveStacks
    if liveStacks > 0 then
        if liveExpiresAt then
            self.expiresAt = liveExpiresAt
        elseif not self.expiresAt or self.expiresAt <= GetTime() then
            self.expiresAt = GetTime() + BUFF_DURATION
        end
    else
        self.expiresAt = 0
    end
    self:ScheduleExpiration()

    return true
end

function Tip:ScheduleExpiration()
    if self.expireTimer and not self.expireTimer:IsCancelled() then
        self.expireTimer:Cancel()
    end
    self.expireTimer = nil

    if not C_Timer or self.stacks <= 0 or not self.expiresAt or self.expiresAt <= 0 then
        return
    end

    local remaining = self.expiresAt - GetTime()
    if remaining <= 0 then
        self.stacks = 0
        self.expiresAt = 0
        self:Update()
        return
    end

    self.expireTimer = C_Timer.NewTimer(remaining + 0.03, function()
        if self.testMode then
            return
        end

        if self.expiresAt and self.expiresAt > 0 and GetTime() >= self.expiresAt - 0.02 then
            self.stacks = 0
            self.expiresAt = 0
            self:Update()
        else
            self:ScheduleExpiration()
        end
    end)
end

function Tip:ScheduleCastVerify()
    if not C_Timer then
        if self:SyncFromAura() then
            self:Update()
        end
        return
    end

    self.castVerifySerial = self.castVerifySerial + 1
    local serial = self.castVerifySerial

    local function Verify()
        if serial ~= self.castVerifySerial then
            return
        end

        if self:SyncFromAura() then
            self:Update()
        end
    end

    C_Timer.After(AURA_VERIFY_DELAY, Verify)
    C_Timer.After(FINAL_AURA_VERIFY_DELAY, Verify)
end

function Tip:ScheduleAuraVerify(delay)
    if self.auraVerifyPending then
        return
    end

    if not C_Timer then
        if self:SyncFromAura() then
            self:Update()
        end
        return
    end

    local requestedDelay = delay or 0.05
    if self.inCombat then
        local quietRemaining = ((self.lastPredictAt or 0) + AURA_VERIFY_DELAY) - GetTime()
        if quietRemaining > requestedDelay then
            requestedDelay = quietRemaining
        end
    end

    self.auraVerifyPending = true
    local serial = self.castVerifySerial
    C_Timer.After(requestedDelay, function()
        self.auraVerifyPending = false
        if self.inCombat and serial ~= self.castVerifySerial then
            return
        end

        if self:SyncFromAura() then
            self:Update()
        end
    end)
end

function Tip:RefreshLayout()
    EnsureFrame(self)
    local root       = self.root       -- D-08 local alias
    local pips       = self.pips
    local numberText = self.numberText

    local cfg = GetCfg()
    local mode = cfg.displayMode or "bar"
    local borderSize = tonumber(cfg.borderSize or cfg.spacing) or BORDER_SIZE
    if borderSize < 0 then borderSize = 0 end
    if borderSize > 10 then borderSize = 10 end
    self.layoutBorderSize = borderSize

    for i = 1, MAX_STACKS do
        pips[i]:Hide()
        SetPipBordersShown(pips[i], false)
    end
    SetBordersShown(self, false)
    numberText:Hide()

    if mode == "icons" then
        local iconSize = tonumber(cfg.iconSize) or 28
        local spacing = tonumber(cfg.iconSpacing) or 4
        local totalWidth = iconSize * MAX_STACKS + spacing * (MAX_STACKS - 1)

        root:SetSize(totalWidth, iconSize)
        root:SetScale(cfg.scale or 1)

        for i = 1, MAX_STACKS do
            local pip = pips[i]
            pip:SetSize(iconSize, iconSize)
            pip:ClearAllPoints()
            pip:SetPoint("LEFT", root, "LEFT", (i - 1) * (iconSize + spacing), 0)
            pip.fill:ClearAllPoints()
            pip.fill:SetPoint("TOPLEFT", pip, "TOPLEFT", borderSize, -borderSize)
            pip.fill:SetPoint("BOTTOMRIGHT", pip, "BOTTOMRIGHT", -borderSize, borderSize)
            pip.fill:SetTexture(ResolveSpellTexture())
            LayoutPipBorder(pip, borderSize)
            pip:Show()
        end
    elseif mode == "number" then
        local fontSize = tonumber(cfg.numberFontSize) or 22
        root:SetSize(fontSize * 2, fontSize + 4)
        root:SetScale(cfg.scale or 1)
        numberText:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", fontSize, "OUTLINE")
        local r, g, b, a = ColorTuple(cfg.textColor, DMX.defaults.tip.textColor)
        numberText:SetTextColor(r, g, b, a)
    else
        local width = tonumber(cfg.width or cfg.barWidth) or TRACKER_WIDTH
        local height = tonumber(cfg.height or cfg.barHeight) or TRACKER_HEIGHT
        if width < 20 then width = 20 end
        if height < 4 then height = 4 end

        local innerWidth = width - borderSize * (MAX_STACKS + 1)
        if innerWidth < MAX_STACKS then
            innerWidth = MAX_STACKS
            width = innerWidth + borderSize * (MAX_STACKS + 1)
        end

        local segmentWidths = {}
        local baseWidth = math.floor(innerWidth / MAX_STACKS)
        local remainder = innerWidth - baseWidth * MAX_STACKS
        for i = 1, MAX_STACKS do
            segmentWidths[i] = baseWidth + (i <= remainder and 1 or 0)
        end

        root:SetSize(width, height)
        root:SetScale(cfg.scale or 1)
        LayoutBorders(self, width, height, borderSize, segmentWidths)

        local segmentHeight = height - borderSize * 2
        if segmentHeight < 1 then segmentHeight = 1 end

        local x = borderSize
        for i = 1, MAX_STACKS do
            local pip = pips[i]
            pip:SetSize(segmentWidths[i], segmentHeight)
            pip:ClearAllPoints()
            pip:SetPoint("TOPLEFT", root, "TOPLEFT", x, -borderSize)
            pip.fill:ClearAllPoints()
            pip.fill:SetAllPoints()
            pip.fill:SetTexture(WHITE_TEX)
            pip:Show()
            x = x + segmentWidths[i] + borderSize
        end
    end

    ApplyPosition(self)
    self:ApplyLock()
    self:Update()
end

function Tip:ApplyLock()
    if not self.root then return end

    local root, label = self.root, self.label
    local unlocked = not DMX:GetDB().locked
    root:EnableMouse(unlocked)
    root:SetMovable(unlocked)
    label:SetShown(unlocked)
end

function Tip:ResetPosition()
    local cfg = DMX:GetDB().tip
    cfg.x = DMX.defaults.tip.x
    cfg.y = DMX.defaults.tip.y
    cfg.scale = DMX.defaults.tip.scale
    self:RefreshLayout()
end

function Tip:SetTestStacks(stacks)
    self.testMode = true
    self.testStacks = ClampStacks(stacks)
    self:Update()

    if C_Timer then
        C_Timer.After(8, function()
            if self.testMode then
                self.testMode = false
                self:SyncFromAura()
                self:Update()
            end
        end)
    end
end

function Tip:GetStacks()
    if self.testMode then
        return self.testStacks
    end

    return self.stacks
end

function Tip:Update()
    EnsureFrame(self)
    local root       = self.root       -- D-08 local alias
    local pips       = self.pips
    local label      = self.label
    local numberText = self.numberText

    self:RefreshActive()

    local db = DMX:GetDB()
    local cfg = db.tip
    local stacks = self:GetStacks()
    local unlocked = not db.locked

    local shouldShow = unlocked or self.testMode or (cfg.enabled and self.active)
    if shouldShow and cfg.showOnlyInCombat and not self.inCombat and not self.testMode and not unlocked then
        shouldShow = false
    end
    if shouldShow and cfg.hideWhenEmpty and stacks == 0 and not self.testMode and not unlocked then
        shouldShow = false
    end

    if not shouldShow then
        root:Hide()
        return
    end

    root:Show()

    local mode = cfg.displayMode or "bar"
    local drawShell = stacks > 0 or unlocked
    local hasBorder = (self.layoutBorderSize or 0) > 0
    local fillR, fillG, fillB, fillA = ColorTuple(cfg.fillColor, TIP_COLOR)
    local emptyR, emptyG, emptyB, emptyA = ColorTuple(cfg.emptyColor, EMPTY_COLOR)

    if mode == "number" then
        SetBordersShown(self, false)
        for i = 1, MAX_STACKS do
            pips[i]:Hide()
            SetPipBordersShown(pips[i], false)
        end

        numberText:SetText(stacks)
        numberText:Show()
        label:SetShown(unlocked)
        return
    end

    numberText:Hide()

    if mode == "icons" then
        SetBordersShown(self, false)
        for i = 1, MAX_STACKS do
            local pip = pips[i]
            pip:Show()

            if not drawShell then
                pip.fill:Hide()
                SetPipBordersShown(pip, false)
            elseif i <= stacks then
                pip.fill:SetTexture(ResolveSpellTexture())
                pip.fill:SetVertexColor(1, 1, 1, 1)
                pip.fill:Show()
                SetPipBordersShown(pip, hasBorder)
            else
                pip.fill:SetTexture(WHITE_TEX)
                pip.fill:SetVertexColor(emptyR, emptyG, emptyB, emptyA)
                pip.fill:Show()
                SetPipBordersShown(pip, hasBorder)
            end
        end

        label:SetShown(unlocked)
        return
    end

    SetBordersShown(self, drawShell and hasBorder)

    for i = 1, MAX_STACKS do
        local pip = pips[i]
        pip:Show()
        SetPipBordersShown(pip, false)

        if not drawShell then
            pip.fill:Hide()
        elseif i <= stacks then
            pip.fill:SetTexture(WHITE_TEX)
            pip.fill:SetVertexColor(fillR, fillG, fillB, fillA)
            pip.fill:Show()
        else
            pip.fill:SetTexture(WHITE_TEX)
            pip.fill:SetVertexColor(emptyR, emptyG, emptyB, emptyA)
            pip.fill:Show()
        end
    end

    label:SetShown(unlocked)
end

function Tip:ApplySpell(kind)
    local now = GetTime()

    if kind == "generator" then
        self.stacks = ClampStacks(self.stacks + 2)
        self.expiresAt = now + BUFF_DURATION
    elseif kind == "consumer" then
        self.stacks = ClampStacks(self.stacks - 1)
        if self.stacks == 0 then
            self.expiresAt = 0
        end
    else
        return
    end

    self.lastPredictAt = now
    self.lastPredictKind = kind
    self:ScheduleExpiration()
    self:Update()
    self:ScheduleCastVerify()
end

function Tip:OnEvent(event, ...)
    if event == "PLAYER_REGEN_DISABLED" then
        self.inCombat = true
        self:Update()
        return
    elseif event == "PLAYER_REGEN_ENABLED" then
        self.inCombat = false
        self:SyncFromAura()
        self:Update()
        return
    elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        self:RefreshActive()
        self:SyncFromAura()
        self:Update()
        return
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        local unit = ...
        if unit == "player" then
            self.stacks = 0
            self:RefreshActive()
            self:SyncFromAura()
            self:Update()
        end
        return
    elseif event == "PLAYER_TALENT_UPDATE" or event == "TRAIT_CONFIG_UPDATED" then
        self:RefreshActive()
        self:Update()
        return
    elseif event == "UNIT_AURA" then
        self:ScheduleAuraVerify(0.05)
        return
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        if not self.active then
            self:RefreshActive()
        end
        if not self.active then
            return
        end

        local kind = FindTrackedSpell(...)
        if kind then
            self:ApplySpell(kind)
        end
    end
end

function Tip:Initialize(core)
    self.core = core

    if self.initialized then
        return
    end
    self.initialized = true

    EnsureFrame(self)
    self.inCombat = InCombatLockdown and InCombatLockdown() or false
    self:RefreshLayout()

    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:RegisterEvent("PLAYER_LOGIN")
    self.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    self.eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    self.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    self.eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    self.eventFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
    self.eventFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
    self.eventFrame:RegisterUnitEvent("UNIT_AURA", "player")
    self.eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    self.eventFrame:SetScript("OnEvent", function(_, event, ...)
        self:OnEvent(event, ...)
    end)
end

DMX:RegisterModule("tip", Tip)
