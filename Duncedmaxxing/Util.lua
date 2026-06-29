local _, DMX = ...

DMX.Util = {}
local Util = DMX.Util

local function Trim(text)
    return (text or ""):match("^%s*(.-)%s*$")
end

local function Clamp(value, minValue, maxValue)
    value = tonumber(value)
    if not value then return nil end
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local function ParseOnOff(value)
    value = string.lower(Trim(value))
    if value == "on" or value == "true" or value == "1" or value == "yes" then
        return true
    elseif value == "off" or value == "false" or value == "0" or value == "no" then
        return false
    end
end

local function ParseHexColor(value)
    value = Trim(value):gsub("^#", "")
    if not value:match("^[0-9a-fA-F]+$") or (#value ~= 6 and #value ~= 8) then
        return nil
    end

    local r = tonumber(value:sub(1, 2), 16) / 255
    local g = tonumber(value:sub(3, 4), 16) / 255
    local b = tonumber(value:sub(5, 6), 16) / 255
    local a = (#value == 8) and (tonumber(value:sub(7, 8), 16) / 255) or 1
    return { r = r, g = g, b = b, a = a }
end

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

Util.Trim          = Trim
Util.Clamp         = Clamp
Util.ParseOnOff    = ParseOnOff
Util.ParseHexColor = ParseHexColor
Util.CopyDefaults  = CopyDefaults
