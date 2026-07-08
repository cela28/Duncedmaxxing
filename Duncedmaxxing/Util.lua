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

Util.Trim         = Trim
Util.Clamp        = Clamp
Util.ParseHexColor = ParseHexColor
