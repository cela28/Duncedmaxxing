---
phase: quick
plan: 260622-hmo
type: execute
wave: 1
depends_on: []
files_modified:
  - Duncedmaxxing/Modules/TipOfTheSpear.lua
  - spec/support/wow_stubs.lua
  - spec/tip_spec.lua
autonomous: true
requirements: []
must_haves:
  truths:
    - "Number display at 0 stacks shows white text (1,1,1,1)"
    - "Number display at 1 stack shows green text (#2ECC71)"
    - "Number display at 2 stacks shows yellow text (#FFF000)"
    - "Number display at 3 stacks shows red/orange text (#FF4C30)"
    - "Bar and icon modes are unaffected by the change"
  artifacts:
    - path: "Duncedmaxxing/Modules/TipOfTheSpear.lua"
      provides: "STACK_COLORS table and per-stack color application in Update()"
      contains: "STACK_COLORS"
    - path: "spec/tip_spec.lua"
      provides: "Tests verifying per-stack color coding in number mode"
      contains: "STACK_COLORS"
  key_links:
    - from: "Duncedmaxxing/Modules/TipOfTheSpear.lua"
      to: "numberText:SetTextColor"
      via: "STACK_COLORS lookup in Update() number mode block"
      pattern: "STACK_COLORS\\[stacks\\]"
---

<objective>
Add per-stack color coding for the number display mode in TipOfTheSpear. When displayMode is "number", the text color changes based on current stack count: white at 0, green at 1, yellow at 2, red/orange at 3.

Purpose: Visual feedback lets the player instantly distinguish stack counts by color during combat without reading the digit.
Output: Updated TipOfTheSpear.lua with STACK_COLORS table, updated wow_stubs.lua with SetTextColor tracking, and new tests in tip_spec.lua.
</objective>

<execution_context>
@.planning/quick/260622-hmo-add-per-stack-color-coding-for-number-di/260622-hmo-PLAN.md
</execution_context>

<context>
@Duncedmaxxing/Modules/TipOfTheSpear.lua
@spec/tip_spec.lua
@spec/support/wow_stubs.lua
@spec/support/init.lua

<interfaces>
<!-- From spec/support/wow_stubs.lua noopFrame() (lines 101-122): -->
<!-- Font string stubs currently have SetText/_text but NO SetTextColor/_textColor tracking. -->
<!-- The __index metatable silently swallows unknown method calls, so SetTextColor won't error -->
<!-- but won't store the color either. Must add explicit tracking. -->

From Duncedmaxxing/Modules/TipOfTheSpear.lua Update() number mode block (lines 627-637):
```lua
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
```

From Duncedmaxxing/Modules/TipOfTheSpear.lua existing color constants (lines 28-31):
```lua
local TIP_COLOR = { 0.72, 0.55, 0.02, 1 }
local EMPTY_COLOR = { 0, 0, 0, 0.5 }
local BORDER_COLOR = { 0, 0, 0, 1 }
local WHITE_TEX = "Interface\\Buttons\\WHITE8X8"
```
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Add SetTextColor tracking to wow_stubs and write color-coding tests</name>
  <files>spec/support/wow_stubs.lua, spec/tip_spec.lua</files>
  <behavior>
    - Test: number mode at 0 stacks sets numberText color to (1, 1, 1, 1)
    - Test: number mode at 1 stack sets numberText color to (0.18039, 0.80000, 0.44314, 1)
    - Test: number mode at 2 stacks sets numberText color to (1, 0.94118, 0, 1)
    - Test: number mode at 3 stacks sets numberText color to (1, 0.29804, 0.18824, 1)
    - Test: bar mode Update does NOT call SetTextColor on numberText (numberText stays hidden, no color change)
  </behavior>
  <action>
    1. In spec/support/wow_stubs.lua noopFrame() function (around line 115, after the SetText/GetText pair), add explicit SetTextColor and GetTextColor methods that store RGBA in a _textColor field:
       - SetTextColor stores {r, g, b, a} in self._textColor
       - Initialize _textColor = nil alongside _text on the frame

    2. In spec/tip_spec.lua, add a new describe block "Tip:Update number mode color coding" after the existing test blocks. The tests must:
       - Use loader.load() and loader.resetTipState(Tip, clock) in before_each
       - Set db.tip.displayMode = "number" and db.tip.enabled = true
       - Set Tip.isSurvival = true (so the frame shows)
       - For each stack count (0, 1, 2, 3): set Tip.stacks, call Tip:Update(), then assert Tip.numberText._textColor matches the expected RGBA tuple
       - Use assert.near with a tolerance of 0.001 for each component (floats), or compare with a helper that checks all 4 components
       - For the bar mode test: set displayMode = "bar", set Tip.stacks = 2, call Tip:Update(), assert numberText._textColor is nil (never set since numberText is hidden in bar mode)

    3. Run the tests. They MUST FAIL (red phase) because STACK_COLORS does not exist in TipOfTheSpear.lua yet and numberText:SetTextColor is not called in the number mode block.
  </action>
  <verify>
    <automated>cd /home/cela/random-projects/Duncedmaxxing && busted spec/tip_spec.lua 2>&1 | tail -5</automated>
    Existing 42 tests still pass. New color-coding tests fail (red phase expected).
  </verify>
  <done>wow_stubs.lua tracks SetTextColor in _textColor field. spec/tip_spec.lua has 5+ new failing tests for per-stack color coding in number mode. All 42 pre-existing tests still pass.</done>
</task>

<task type="auto">
  <name>Task 2: Implement STACK_COLORS table and apply in Update()</name>
  <files>Duncedmaxxing/Modules/TipOfTheSpear.lua</files>
  <action>
    1. In TipOfTheSpear.lua, after the BORDER_COLOR constant (line 30) and before the WHITE_TEX line, add the STACK_COLORS lookup table:
       ```
       local STACK_COLORS = {
           [0] = { 1, 1, 1, 1 },
           [1] = { 0.18039, 0.80000, 0.44314, 1 },
           [2] = { 1, 0.94118, 0, 1 },
           [3] = { 1, 0.29804, 0.18824, 1 },
       }
       ```

    2. In the Update() method's number mode block (around line 634, after `numberText:SetText(stacks)`), add two lines:
       ```
       local sc = STACK_COLORS[stacks] or STACK_COLORS[0]
       numberText:SetTextColor(sc[1], sc[2], sc[3], sc[4])
       ```

    3. Run the full test suite. All tests (old + new) must pass (green phase).

    4. Run luacheck on the modified file to ensure no lint regressions.
  </action>
  <verify>
    <automated>cd /home/cela/random-projects/Duncedmaxxing && busted spec/tip_spec.lua && luacheck Duncedmaxxing/Modules/TipOfTheSpear.lua --config .luacheckrc 2>&1 | tail -10</automated>
  </verify>
  <done>STACK_COLORS table defined with 4 entries (0-3). Update() number mode block applies per-stack color via SetTextColor after SetText. All tests pass including the new color-coding tests. No luacheck warnings.</done>
</task>

</tasks>

<verification>
1. `busted spec/tip_spec.lua` — all tests pass (0 failures, 0 errors)
2. `luacheck Duncedmaxxing/Modules/TipOfTheSpear.lua --config .luacheckrc` — no warnings
3. `grep -c "STACK_COLORS" Duncedmaxxing/Modules/TipOfTheSpear.lua` returns >= 2 (definition + usage)
4. `grep -c "SetTextColor" spec/tip_spec.lua` returns >= 4 (one per stack count test)
</verification>

<success_criteria>
- Number display mode shows stack-appropriate color: white(0), green(1), yellow(2), red/orange(3)
- Bar and icon display modes are completely unaffected
- All existing tests continue to pass
- New tests cover each stack count color in number mode
- No config/options UI changes — colors are hardcoded constants
</success_criteria>

<output>
Commit with message: feat: add per-stack color coding for number display mode
</output>
