# API References

This file tracks every WoW API or widget API used by Duncedmaxxing. All current calls have either a Warcraft Wiki reference or a direct example in the addon code you provided.

## Gameplay and State

- `UnitClass("player")`
  - Warcraft Wiki: https://warcraft.wiki.gg/wiki/API_UnitClass
  - Local examples: `AzortharionUI/Libs/Ace3/AceDB-3.0/AceDB-3.0.lua`, `AzortharionUI/Libs/AUI3/Animations/NeonBorder.lua`

- `C_SpecializationInfo.GetSpecialization()` with fallback to `GetSpecialization()`
  - Warcraft Wiki: https://warcraft.wiki.gg/wiki/API_C_SpecializationInfo.GetSpecialization
  - Fallback reference: https://warcraft.wiki.gg/wiki/API_GetSpecialization

- `InCombatLockdown()`
  - Warcraft Wiki: https://warcraft.wiki.gg/wiki/API_InCombatLockdown
  - Local examples: `ElvUI/Game/Shared/Modules/ActionBars/ActionBars.lua`, `ElvUI/Game/Shared/Modules/ActionBars/Bind.lua`

- `GetTime()`
  - Warcraft Wiki: https://warcraft.wiki.gg/wiki/API_GetTime

- `C_UnitAuras.GetPlayerAuraBySpellID(260286)`
  - Warcraft Wiki: https://warcraft.wiki.gg/wiki/API_C_UnitAuras.GetPlayerAuraBySpellID
  - Local example: `AzortharionUI/Modules/BuffTracking/Hunter.lua`
  - Note: the wiki marks this as `RequiresNonSecretAura` / `SecretWhenUnitAuraRestricted`, so Duncedmaxxing treats aura reads as delayed verification rather than the primary combat source.

- `C_Spell.GetSpellTexture(260286)` with fallback to `GetSpellTexture(260286)`
  - Warcraft Wiki: https://warcraft.wiki.gg/wiki/API_C_Spell.GetSpellTexture
  - Local examples: `ElvUI/Game/Shared/Modules/ActionBars/StanceBar.lua`, `AzortharionUI/Libs/AUI3/Controls/TalentGrid.lua`

## Timers

- `C_Timer.After(seconds, callback)`
  - Warcraft Wiki: https://warcraft.wiki.gg/wiki/API_C_Timer.After
  - Local examples: `AzortharionUI/Libs/Ace3/AceTimer-3.0/AceTimer-3.0.lua`

- `C_Timer.NewTimer(seconds, callback)` plus timer-handle `:Cancel()` / `:IsCancelled()`
  - Warcraft Wiki: https://warcraft.wiki.gg/wiki/API_C_Timer.NewTimer

## Events

- `CreateFrame("Frame", ...)`
  - Warcraft Wiki: https://warcraft.wiki.gg/wiki/API_CreateFrame
  - Local examples: `AzortharionUI/Utility/Events.lua`, `ElvUI/Game/Shared/Layout/Layout.lua`

- `Frame:RegisterEvent(eventName)`
  - Warcraft Wiki: https://warcraft.wiki.gg/wiki/API_Frame_RegisterEvent
  - Local examples: `AzortharionUI/Utility/Events.lua`, `ElvUI/Game/Shared/Layout/Layout.lua`

- `Frame:RegisterUnitEvent(eventName, "player")`
  - Warcraft Wiki: https://warcraft.wiki.gg/wiki/API_Frame_RegisterUnitEvent
  - Local examples: `AzortharionUI/Utility/Events.lua`, `ElvUI/Game/Shared/Modules/ActionBars/ActionBars.lua`

- `ScriptObject:SetScript(scriptTypeName, handler)`
  - Warcraft Wiki: https://warcraft.wiki.gg/wiki/API_ScriptObject_SetScript
  - Local examples: `AzortharionUI/Utility/Events.lua`, `ElvUI/Game/Shared/Layout/Layout.lua`

## Frames, Textures, and Text

- `Frame:CreateTexture(...)`
  - Warcraft Wiki: https://warcraft.wiki.gg/wiki/API_Frame_CreateTexture
  - Local examples: `ElvUI/Game/Shared/Layout/Layout.lua`, `AzortharionUI/Libs/AUI3/Controls/TalentGrid.lua`

- `Frame:CreateFontString(...)`
  - Warcraft Wiki: https://warcraft.wiki.gg/wiki/API_Frame_CreateFontString
  - Local examples: `AzortharionUI/Modules/BuffTracking/Display.lua`, `AzortharionUI/Libs/AUI3/Controls/Text.lua`

- `TextureBase:SetTexture(...)`
  - Warcraft Wiki: https://warcraft.wiki.gg/wiki/API_TextureBase_SetTexture

- `Region:SetVertexColor(...)`
  - Warcraft Wiki: https://warcraft.wiki.gg/wiki/API_Region_SetVertexColor
  - Local examples: `ElvUI/Game/Shared/Modules/ActionBars/StanceBar.lua`, `AzortharionUI/Libs/AUI3/Controls/TalentGrid.lua`

- `FontInstance:SetFont(...)`
  - Warcraft Wiki: https://warcraft.wiki.gg/wiki/API_FontInstance_SetFont

- `FontString:SetText(...)`
  - Warcraft Wiki object reference: https://warcraft.wiki.gg/wiki/UIOBJECT_FontString

- `FontString:SetTextColor(...)`
  - Warcraft Wiki: https://warcraft.wiki.gg/wiki/API_FontString_SetTextColor

- `ScriptRegion:Show()` / `ScriptRegion:Hide()` / `ScriptRegion:SetShown(...)`
  - Warcraft Wiki: https://warcraft.wiki.gg/wiki/API_ScriptRegion_Show
  - Widget object reference including `SetShown`: https://warcraft.wiki.gg/wiki/UIOBJECT_ScriptRegion

- `ScriptRegionResizing:SetPoint(...)`, `:ClearAllPoints()`, `:SetAllPoints(...)`, `:SetSize(...)`
  - Warcraft Wiki:
    - https://warcraft.wiki.gg/wiki/API_ScriptRegionResizing_SetPoint
    - https://warcraft.wiki.gg/wiki/API_ScriptRegionResizing_ClearAllPoints
    - https://warcraft.wiki.gg/wiki/API_ScriptRegionResizing_SetAllPoints
    - https://warcraft.wiki.gg/wiki/API_ScriptRegionResizing_SetSize

- `ScriptRegion:GetCenter()`, `:GetWidth()`, `:GetHeight()`
  - Warcraft Wiki object references:
    - https://warcraft.wiki.gg/wiki/UIOBJECT_ScriptRegion
    - https://warcraft.wiki.gg/wiki/API_ScriptRegion_GetSize

- `Region:SetScale(...)`
  - Warcraft Wiki object reference: https://warcraft.wiki.gg/wiki/Widget_API

- `Frame:SetFrameStrata(...)`, `Frame:SetFrameLevel(...)`, `Frame:SetClampedToScreen(...)`
  - Warcraft Wiki:
    - https://warcraft.wiki.gg/wiki/API_Frame_SetFrameStrata
    - Frame object method list: https://warcraft.wiki.gg/wiki/UIOBJECT_Frame

## Movable Options Window

- `CreateFrame("Button", ..., "UIPanelButtonTemplate")`
  - Warcraft Wiki: https://warcraft.wiki.gg/wiki/API_CreateFrame
  - Local example: `ElvUI/Game/Shared/Modules/ActionBars/Bind.lua`

- `Button:SetText(...)`
  - Warcraft Wiki object reference: https://warcraft.wiki.gg/wiki/UIOBJECT_Button
  - Local example: `ElvUI/Game/Shared/Modules/ActionBars/Bind.lua`

- `CreateFrame("CheckButton", ..., "UICheckButtonTemplate")`
  - Warcraft Wiki: https://warcraft.wiki.gg/wiki/API_CreateFrame
  - Local examples: `ElvUI/Game/Shared/Modules/ActionBars/Bind.lua`, `SenseiClassResourceBar/Libs/LibEQOL/LibEQOLNativeEditMode.lua`

- `CheckButton:SetChecked(...)` and `CheckButton:GetChecked()`
  - Warcraft Wiki object reference: https://warcraft.wiki.gg/wiki/UIOBJECT_CheckButton
  - Local example: `ElvUI/Game/Shared/Modules/ActionBars/Bind.lua`

- `CreateFrame("EditBox", ..., "InputBoxTemplate")`
  - Warcraft Wiki: https://warcraft.wiki.gg/wiki/API_CreateFrame
  - Local examples: `SenseiClassResourceBar/Libs/LibEQOL/LibEQOLNativeEditMode.lua`, `SenseiClassResourceBar/Libs/LibEQOL/LibEQOLSettingsInput.lua`

- `EditBox:SetAutoFocus(...)`, `EditBox:SetText(...)`, `EditBox:GetText()`, `EditBox:ClearFocus()`
  - Warcraft Wiki object reference: https://warcraft.wiki.gg/wiki/UIOBJECT_EditBox
  - Local examples: `SenseiClassResourceBar/Libs/LibEQOL/LibEQOLNativeEditMode.lua`, `SenseiClassResourceBar/Libs/LibEQOL/LibEQOLSettingsInput.lua`

## Dragging and Chat Commands

- `ScriptRegion:EnableMouse(...)`
  - Warcraft Wiki: https://warcraft.wiki.gg/wiki/API_ScriptRegion_EnableMouse
  - Local examples: `ElvUI/Game/Shared/Modules/ActionBars/ActionBars.lua`, `ElvUI/Game/Shared/Modules/ActionBars/Bind.lua`

- `Frame:SetMovable(...)`
  - Warcraft Wiki: https://warcraft.wiki.gg/wiki/API_Frame_SetMovable

- `Frame:RegisterForDrag(...)`
  - Warcraft Wiki: https://warcraft.wiki.gg/wiki/API_Frame_RegisterForDrag

- `Frame:StartMoving(...)` and `Frame:StopMovingOrSizing()`
  - Warcraft Wiki:
    - https://warcraft.wiki.gg/wiki/API_Frame_StartMoving
    - https://warcraft.wiki.gg/wiki/API_Frame_StopMovingOrSizing
  - Local example: `ElvUI/Game/Shared/Modules/ActionBars/Bind.lua`

- `SlashCmdList` and `SLASH_*` globals
  - Warcraft Wiki: https://warcraft.wiki.gg/wiki/Creating_a_slash_command

- `DEFAULT_CHAT_FRAME:AddMessage(...)`
  - Warcraft Wiki: https://warcraft.wiki.gg/wiki/API_ScrollingMessageFrame_AddMessage

## Unsatisfied References

None at the time this file was written.
