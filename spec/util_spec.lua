-- spec/util_spec.lua
-- Unit tests for DMX.Util.Clamp, ParseHexColor, Trim.
-- Each describe block reloads the addon via loader.load() for full isolation (D-06).

local loader = require("spec.support.init")

describe("DMX.Util.Clamp", function()
    local DMX

    before_each(function()
        DMX = loader.load()
    end)

    it("returns value when within bounds", function()
        assert.are.equal(5, DMX.Util.Clamp(5, 0, 10))
    end)

    it("returns minValue when below lower bound", function()
        assert.are.equal(0, DMX.Util.Clamp(-1, 0, 10))
    end)

    it("returns maxValue when above upper bound", function()
        assert.are.equal(10, DMX.Util.Clamp(11, 0, 10))
    end)

    it("returns minValue when exactly at lower boundary", function()
        assert.are.equal(0, DMX.Util.Clamp(0, 0, 10))
    end)

    it("returns maxValue when exactly at upper boundary", function()
        assert.are.equal(10, DMX.Util.Clamp(10, 0, 10))
    end)

    it("coerces a numeric string to a number", function()
        assert.are.equal(5, DMX.Util.Clamp("5", 0, 10))
    end)

    it("returns nil for a non-numeric string", function()
        assert.is_nil(DMX.Util.Clamp("abc", 0, 10))
    end)

    it("works correctly with a negative range", function()
        assert.are.equal(-5, DMX.Util.Clamp(-5, -10, -1))
    end)

    it("returns -10 when below a negative lower bound", function()
        assert.are.equal(-10, DMX.Util.Clamp(-15, -10, -1))
    end)

    it("returns -1 when above a negative upper bound", function()
        assert.are.equal(-1, DMX.Util.Clamp(0, -10, -1))
    end)
end)

describe("DMX.Util.ParseHexColor", function()
    local DMX

    before_each(function()
        DMX = loader.load()
    end)

    it("parses a 6-char hex string and returns r, g, b with a=1", function()
        local c = DMX.Util.ParseHexColor("b88c03")
        assert.is_not_nil(c)
        assert.is_near(0.722, c.r, 0.01)
        assert.is_near(0.549, c.g, 0.01)
        assert.is_near(0.012, c.b, 0.01)
        assert.are.equal(1, c.a)
    end)

    it("parses an 8-char hex string and includes alpha", function()
        local c = DMX.Util.ParseHexColor("b88c0380")
        assert.is_not_nil(c)
        assert.is_near(0.722, c.r, 0.01)
        assert.is_near(0.502, c.a, 0.01)
    end)

    it("strips a leading # and parses correctly", function()
        local c = DMX.Util.ParseHexColor("#ff0000")
        assert.is_not_nil(c)
        assert.are.equal(1, c.r)
        assert.are.equal(0, c.g)
        assert.are.equal(0, c.b)
        assert.are.equal(1, c.a)
    end)

    it("returns nil for invalid hex characters", function()
        assert.is_nil(DMX.Util.ParseHexColor("zzzzzz"))
    end)

    it("returns nil for wrong-length input (3 chars)", function()
        assert.is_nil(DMX.Util.ParseHexColor("fff"))
    end)

    it("returns nil for an empty string", function()
        assert.is_nil(DMX.Util.ParseHexColor(""))
    end)

    it("returns nil for a wrong-length input (7 chars)", function()
        assert.is_nil(DMX.Util.ParseHexColor("ff00001"))
    end)

    it("parses pure-white 6-char hex correctly", function()
        local c = DMX.Util.ParseHexColor("ffffff")
        assert.is_not_nil(c)
        assert.are.equal(1, c.r)
        assert.are.equal(1, c.g)
        assert.are.equal(1, c.b)
        assert.are.equal(1, c.a)
    end)

    it("parses pure-black 6-char hex correctly", function()
        local c = DMX.Util.ParseHexColor("000000")
        assert.is_not_nil(c)
        assert.are.equal(0, c.r)
        assert.are.equal(0, c.g)
        assert.are.equal(0, c.b)
        assert.are.equal(1, c.a)
    end)
end)

describe("DMX.Util.Trim", function()
    local DMX

    before_each(function()
        DMX = loader.load()
    end)

    it("strips leading and trailing whitespace", function()
        assert.are.equal("hello", DMX.Util.Trim("  hello  "))
    end)

    it("returns empty string for nil input", function()
        assert.are.equal("", DMX.Util.Trim(nil))
    end)

    it("returns empty string for whitespace-only input", function()
        assert.are.equal("", DMX.Util.Trim("   "))
    end)

    it("passes through a string with no surrounding whitespace", function()
        assert.are.equal("hello", DMX.Util.Trim("hello"))
    end)

    it("strips only surrounding spaces, preserving internal whitespace", function()
        assert.are.equal("hello world", DMX.Util.Trim("  hello world  "))
    end)
end)
