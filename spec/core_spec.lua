-- spec/core_spec.lua
-- Unit tests for Core.lua pure-logic functions: NormalizeDB and MergeDefaults.
-- Both functions are accessed via DMX._test (exposed by Plan 02).
-- Each describe block calls loader.load() in before_each for full isolation (D-06).

local loader = require("spec.support.init")

describe("MergeDefaults", function()
    local DMX

    before_each(function()
        DMX = loader.load()
    end)

    it("does not overwrite existing non-nil values", function()
        local result = DMX._test.MergeDefaults({a = 1, b = 2}, {a = 10})
        assert.equals(10, result.a)
        assert.equals(2,  result.b)
    end)

    it("fills nil slots from defaults", function()
        local result = DMX._test.MergeDefaults({a = 1, b = 2}, {})
        assert.equals(1, result.a)
        assert.equals(2, result.b)
    end)

    it("deep-merges nested tables, preserving existing nested values", function()
        local result = DMX._test.MergeDefaults({tip = {x = 0, y = -160}}, {tip = {x = 50}})
        assert.equals(50,   result.tip.x)
        assert.equals(-160, result.tip.y)
    end)

    it("creates missing nested table when target has nil for that key", function()
        local result = DMX._test.MergeDefaults({tip = {x = 0}}, {})
        assert.is_table(result.tip)
        assert.equals(0, result.tip.x)
    end)

    it("returns the same target table reference", function()
        local t = {}
        local result = DMX._test.MergeDefaults({a = 1}, t)
        assert.equal(t, result)
    end)

    it("handles nil target, returning a copy of defaults", function()
        local result = DMX._test.MergeDefaults({a = 1}, nil)
        assert.is_table(result)
        assert.equals(1, result.a)
    end)

    it("fills missing colorByStack and all four stackColors defaults byte-for-byte", function()
        local result = DMX._test.MergeDefaults(DMX.defaults, {})
        assert.is_true(result.tip.colorByStack)
        for i = 0, 3 do
            for _, key in ipairs({"r", "g", "b", "a"}) do
                assert.near(DMX.defaults.tip.stackColors[i][key], result.tip.stackColors[i][key], 0.00001)
            end
        end
    end)

    it("does not overwrite a user-set colorByStack = false", function()
        local result = DMX._test.MergeDefaults(DMX.defaults, {tip = {colorByStack = false}})
        assert.is_false(result.tip.colorByStack)
    end)

    it("preserves an edited stackColors[1] entry instead of overwriting with the default", function()
        local edited = {r = 0.9, g = 0.1, b = 0.1, a = 1}
        local result = DMX._test.MergeDefaults(DMX.defaults, {tip = {stackColors = {[1] = edited}}})
        for _, key in ipairs({"r", "g", "b", "a"}) do
            assert.near(edited[key], result.tip.stackColors[1][key], 0.00001)
        end
    end)
end)

describe("NormalizeDB — migration branch (settingsMigration does not match)", function()
    local DMX

    before_each(function()
        DMX = loader.load()
    end)

    local function migrationDB(tipOverrides)
        local db = {
            settingsMigration = "old-version",
            tip = {
                enabled          = true,
                hideWhenEmpty    = false,
                x                = 0,
                y                = -160,
                scale            = 1,
                displayMode      = "bar",
                optionsX         = 360,
                optionsY         = 170,
            },
        }
        if tipOverrides then
            for k, v in pairs(tipOverrides) do
                db.tip[k] = v
            end
        end
        return db
    end

    it("runs migration and sets settingsMigration to the current version", function()
        local db = migrationDB()
        DMX._test.NormalizeDB(db)
        assert.equals(DMX._test.SETTINGS_MIGRATION, db.settingsMigration)
    end)

    it("preserves x during migration", function()
        local db = migrationDB({x = 50})
        DMX._test.NormalizeDB(db)
        assert.equals(50, db.tip.x)
    end)

    it("preserves y during migration", function()
        local db = migrationDB({y = -100})
        DMX._test.NormalizeDB(db)
        assert.equals(-100, db.tip.y)
    end)

    it("preserves scale during migration", function()
        local db = migrationDB({scale = 1.5})
        DMX._test.NormalizeDB(db)
        assert.equals(1.5, db.tip.scale)
    end)

    it("preserves optionsX and optionsY during migration", function()
        local db = migrationDB({optionsX = 400, optionsY = 200})
        DMX._test.NormalizeDB(db)
        assert.equals(400, db.tip.optionsX)
        assert.equals(200, db.tip.optionsY)
    end)

    it("resets displayMode to default 'bar' during migration", function()
        local db = migrationDB({displayMode = "icons"})
        DMX._test.NormalizeDB(db)
        assert.equals("bar", db.tip.displayMode)
    end)

    it("sets db.locked = true during migration", function()
        local db = migrationDB()
        DMX._test.NormalizeDB(db)
        assert.is_true(db.locked)
    end)

    it("clears deprecated barWidth during migration", function()
        local db = migrationDB({barWidth = 300})
        DMX._test.NormalizeDB(db)
        assert.is_nil(db.tip.barWidth)
    end)

    it("clears deprecated barHeight during migration", function()
        local db = migrationDB({barHeight = 20})
        DMX._test.NormalizeDB(db)
        assert.is_nil(db.tip.barHeight)
    end)

    it("clears deprecated spacing during migration", function()
        local db = migrationDB({spacing = 2})
        DMX._test.NormalizeDB(db)
        assert.is_nil(db.tip.spacing)
    end)
end)

describe("NormalizeDB — migration branch preserves user customizations (SC-6 regression)", function()
    local DMX

    before_each(function()
        DMX = loader.load()
    end)

    local function shippedLegacyDB()
        return {
            settingsMigration = "0.3.2-fontfix",
            tip = {
                enabled          = true,
                hideWhenEmpty    = true,
                x                = 0,
                y                = -160,
                scale            = 1,
                displayMode      = "number",
                width            = 400,
                borderSize       = 3,
                numberFontSize   = 40,
                borderColor      = { r = 0.5, g = 0, b = 0, a = 1 },
                colorByStack     = false,
                stackColors = {
                    [0] = { 1, 1, 1, 1 },
                    [1] = { 0.18039, 0.8, 0.44314, 1 },
                    [2] = { 1, 0.94118, 0, 1 },
                    [3] = { 1, 0.29804, 0.18824, 1 },
                },
                optionsX = 360,
                optionsY = 170,
            },
        }
    end

    it("preserves non-position customizations and repairs legacy stackColors shape when migrating from the shipped v1.0.0 token", function()
        local db = shippedLegacyDB()

        DMX._test.NormalizeDB(db)

        assert.equals("number", db.tip.displayMode)
        assert.is_true(db.tip.hideWhenEmpty)
        assert.equals(400, db.tip.width)
        assert.equals(3, db.tip.borderSize)
        assert.equals(40, db.tip.numberFontSize)
        assert.near(0.5, db.tip.borderColor.r, 0.00001)
        assert.is_false(db.tip.colorByStack)

        assert.is_table(db.tip.stackColors[0])
        assert.near(1, db.tip.stackColors[0].r, 0.00001)

        assert.equals(DMX._test.SETTINGS_MIGRATION, db.settingsMigration)
    end)
end)

describe("NormalizeDB — already migrated branch (settingsMigration matches)", function()
    local DMX

    before_each(function()
        DMX = loader.load()
    end)

    local function migratedDB(tipOverrides)
        local db = {
            settingsMigration = "0.3.3-stackcolorfmt",
            tip = {
                enabled          = true,
                hideWhenEmpty    = false,
                x                = 0,
                y                = -160,
                scale            = 1,
                displayMode      = "bar",
                width            = 247,
                height           = 10,
                borderSize       = 1,
                numberFontSize   = 22,
                optionsX         = 360,
                optionsY         = 170,
            },
        }
        if tipOverrides then
            for k, v in pairs(tipOverrides) do
                db.tip[k] = v
            end
        end
        return db
    end

    it("skips migration: stored displayMode='icons' normalizes to 'bar' (icons removed in DISP-02)", function()
        local db = migratedDB({displayMode = "icons"})
        DMX._test.NormalizeDB(db)
        assert.equals("bar", db.tip.displayMode)
    end)

    it("skips migration: settingsMigration remains unchanged", function()
        local db = migratedDB()
        DMX._test.NormalizeDB(db)
        assert.equals("0.3.3-stackcolorfmt", db.settingsMigration)
    end)
end)

describe("MergeDefaults + NormalizeDB — legacy DB gains colorByStack/stackColors with no wipe (D-11)", function()
    local DMX

    before_each(function()
        DMX = loader.load()
    end)

    local function legacyMigratedDB()
        return {
            settingsMigration = "0.3.3-stackcolorfmt",
            tip = {
                enabled          = true,
                hideWhenEmpty    = false,
                x                = 50,
                y                = -100,
                scale            = 1.2,
                displayMode      = "number",
                width            = 247,
                height           = 10,
                borderSize       = 1,
                numberFontSize   = 22,
                optionsX         = 360,
                optionsY         = 170,
                -- colorByStack / stackColors intentionally absent, simulating a
                -- pre-DISP-06 SavedVariables snapshot.
            },
        }
    end

    it("default-merges colorByStack + stackColors onto a legacy DB with no wipe, no error, no migration bump", function()
        local db = legacyMigratedDB()

        local ok, err = pcall(function()
            DMX._test.MergeDefaults(DMX.defaults, db)
            DMX._test.NormalizeDB(db)
        end)
        assert.is_true(ok, "MergeDefaults/NormalizeDB should not raise on a legacy DB: " .. tostring(err))

        -- New fields populated.
        assert.is_true(db.tip.colorByStack)
        assert.is_table(db.tip.stackColors)
        for i = 0, 3 do
            assert.is_table(db.tip.stackColors[i])
            for _, key in ipairs({"r", "g", "b", "a"}) do
                assert.near(DMX.defaults.tip.stackColors[i][key], db.tip.stackColors[i][key], 0.00001)
            end
        end

        -- Existing fields unchanged (no wipe).
        assert.equals("number", db.tip.displayMode)
        assert.equals(50,       db.tip.x)
        assert.equals(-100,     db.tip.y)
        assert.equals(1.2,      db.tip.scale)
        assert.equals(true,     db.tip.enabled)

        -- No migration bump — already at current settingsMigration.
        assert.equals("0.3.3-stackcolorfmt", db.settingsMigration)
    end)
end)

describe("NormalizeDB — deprecated fields ignored post-migration (QUAL-03)", function()
    local DMX

    before_each(function()
        DMX = loader.load()
    end)

    local function migratedDB(tipOverrides)
        local db = {
            settingsMigration = "0.3.3-stackcolorfmt",
            tip = {
                enabled    = true,
                displayMode = "bar",
                x = 0, y = -160, scale = 1,
                optionsX = 360, optionsY = 170,
            },
        }
        if tipOverrides then
            for k, v in pairs(tipOverrides) do
                db.tip[k] = v
            end
        end
        return db
    end

    it("does not map barWidth to width when already migrated", function()
        local db = migratedDB({barWidth = 300})
        DMX._test.NormalizeDB(db)
        assert.is_nil(db.tip.width)
    end)

    it("does not map barHeight to height when already migrated", function()
        local db = migratedDB({barHeight = 20})
        DMX._test.NormalizeDB(db)
        assert.is_nil(db.tip.height)
    end)

    it("does not map spacing to borderSize when already migrated", function()
        local db = migratedDB({spacing = 3})
        db.tip.borderSize = nil
        DMX._test.NormalizeDB(db)
        assert.is_nil(db.tip.borderSize)
    end)

    it("does not overwrite existing borderSize with spacing", function()
        local db = migratedDB({spacing = 3, borderSize = 2})
        DMX._test.NormalizeDB(db)
        assert.equals(2, db.tip.borderSize)
    end)

    it("NormalizeDB idempotency — double call does not wipe settings", function()
        local db = migratedDB()
        DMX._test.NormalizeDB(db)
        DMX._test.NormalizeDB(db)
        assert.equals(true,  db.tip.enabled)
        assert.equals("bar", db.tip.displayMode)
        assert.equals(0,     db.tip.x)
        assert.equals(-160,  db.tip.y)
        assert.equals(1,     db.tip.scale)
    end)

    it("persisted showOnlyInCombat key is left inert (NormalizeDB does not strip unknown keys when already migrated)", function()
        local db = migratedDB({ showOnlyInCombat = true })
        DMX._test.NormalizeDB(db)
        -- NormalizeDB only validates displayMode in the already-migrated branch;
        -- arbitrary leftover keys are preserved untouched (harmless inert field).
        assert.is_true(db.tip.showOnlyInCombat)
    end)
end)

describe("NormalizeDB — displayMode validation (always runs)", function()
    local DMX

    before_each(function()
        DMX = loader.load()
    end)

    local function migratedDB(displayMode)
        return {
            settingsMigration = "0.3.3-stackcolorfmt",
            tip = {
                enabled    = true,
                displayMode = displayMode,
                x = 0, y = -160, scale = 1,
                optionsX = 360, optionsY = 170,
            },
        }
    end

    it("resets invalid displayMode to default 'bar'", function()
        local db = migratedDB("invalid")
        DMX._test.NormalizeDB(db)
        assert.equals("bar", db.tip.displayMode)
    end)

    it("preserves valid displayMode 'bar'", function()
        local db = migratedDB("bar")
        DMX._test.NormalizeDB(db)
        assert.equals("bar", db.tip.displayMode)
    end)

    it("resets stored displayMode 'icons' to default 'bar' (icons removed in DISP-02)", function()
        local db = migratedDB("icons")
        DMX._test.NormalizeDB(db)
        assert.equals("bar", db.tip.displayMode)
    end)

    it("preserves valid displayMode 'number'", function()
        local db = migratedDB("number")
        DMX._test.NormalizeDB(db)
        assert.equals("number", db.tip.displayMode)
    end)

    it("resets nil displayMode to default 'bar'", function()
        local db = migratedDB(nil)
        DMX._test.NormalizeDB(db)
        assert.equals("bar", db.tip.displayMode)
    end)
end)
