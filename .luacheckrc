-- .luacheckrc
-- luacheck configuration for Duncedmaxxing WoW addon.
-- Target: Lua 5.1 (WoW sandbox). Spec files are excluded from addon linting.

std = "lua51"

-- Writeable globals: addon code defines or assigns these at the top level.
globals = {
    "DuncedmaxxingDB",
    "SLASH_DUNCEDMAXXING1",
    "SLASH_DUNCEDMAXXING2",
    "Duncedmaxxing",
    -- SlashCmdList is a WoW global table; addon mutates a field on it (SlashCmdList.DUNCEDMAXXING).
    "SlashCmdList",
}

-- Read-only WoW API globals: referenced but never reassigned by addon code.
read_globals = {
    "CreateFrame",
    "UIParent",
    "STANDARD_TEXT_FONT",
    "C_UnitAuras",
    "C_Timer",
    "C_SpecializationInfo",
    "C_Spell",
    "GetSpecialization",
    "GetSpellTexture",
    "IsPlayerSpell",
    "C_SpellBook",
    "InCombatLockdown",
    "UnitClass",
    "GetTime",
    "DEFAULT_CHAT_FRAME",
}

-- Disable line-length warnings — WoW addon layout code has long lines by nature.
max_line_length = false

-- Suppress W432: shadowing upvalue argument.
-- WoW SetScript closures use `self` to refer to the frame; this shadows the
-- outer `self` method argument intentionally (established WoW addon pattern).
ignore = { "432" }

-- Exclude spec files — test infrastructure uses busted globals (describe, it, etc.)
-- that are not part of the addon and should not be linted as addon code.
exclude_files = { "spec/**/*.lua" }
