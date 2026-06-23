#!/usr/bin/env node
// spec/run.cjs
// Node + fengari runner for the Duncedmaxxing spec suite.
//
// Usage:
//   node spec/run.cjs              -- run all *_spec.lua files
//   node spec/run.cjs --self-test  -- smoke test: boot the Lua VM + shim, run one synthetic spec
//   node spec/run.cjs --dry-run    -- alias for --self-test
//
// LOCAL-FIRST fengari resolution:
//   Attempts require.resolve('fengari') first (finds a committed node_modules copy).
//   If not present locally, prints a clear error message — no silent opaque failure.
//   The caller should invoke via:
//     node spec/run.cjs || npx -y -p fengari@0.1.5 node spec/run.cjs
//   so npx supplies fengari when no local copy exists.

'use strict';

const fs   = require('fs');
const path = require('path');

// ---------------------------------------------------------------------------
// Resolve fengari: local-first, then PATH-based (npx environment), then error
// ---------------------------------------------------------------------------

// When invoked as: npx -y -p fengari@0.1.5 node spec/run.cjs
// npx prepends `<cache>/node_modules/.bin` to PATH but does NOT add the parent
// to NODE_PATH, so require.resolve('fengari') still fails.  We probe the PATH
// directories for a fengari package alongside the .bin dir as a fallback.
function findFengariViaPATH() {
  const pathEnv = process.env.PATH || '';
  const dirs = pathEnv.split(path.delimiter);
  for (const dir of dirs) {
    // Each PATH entry added by npx is <cache>/node_modules/.bin; fengari lives
    // in <cache>/node_modules/fengari.
    const candidate = path.join(dir, '..', 'fengari');
    try {
      const pkg = require(path.resolve(candidate, 'package.json'));
      if (pkg && pkg.name === 'fengari') {
        return path.resolve(candidate);
      }
    } catch (_) {}
  }
  return null;
}

let fengari;
try {
  const fenPath = require.resolve('fengari');
  fengari = require(fenPath);
} catch (_) {
  // Not locally resolvable — probe PATH for an npx-supplied copy
  const viaPath = findFengariViaPATH();
  if (viaPath) {
    try {
      fengari = require(viaPath);
    } catch (e) {
      fengari = null;
    }
  }
  if (!fengari) {
    console.error(
      '[run.cjs] ERROR: fengari is not locally resolvable via require.resolve("fengari").\n' +
      '  Install it locally:  npm install fengari@0.1.5\n' +
      '  Or re-invoke under npx:  npx -y -p fengari@0.1.5 node spec/run.cjs'
    );
    process.exit(2);
  }
}

const { lua, lauxlib, lualib, to_luastring, to_jsstring } = fengari;

// ---------------------------------------------------------------------------
// Project root — run.cjs lives in spec/, so root is one level up
// ---------------------------------------------------------------------------
const ROOT = path.resolve(__dirname, '..');

// ---------------------------------------------------------------------------
// Argument parsing
// ---------------------------------------------------------------------------
const args      = process.argv.slice(2);
const SELF_TEST = args.includes('--self-test') || args.includes('--dry-run');

// ---------------------------------------------------------------------------
// Helper: execute a Lua chunk string in an existing state; throw on error
// ---------------------------------------------------------------------------
function execLua(L, src, chunkName) {
  const chunk = to_luastring(src);
  const name  = to_luastring('@' + (chunkName || 'chunk'));
  if (lauxlib.luaL_loadbuffer(L, chunk, chunk.length, name) !== lua.LUA_OK) {
    const msgRaw = lua.lua_tostring(L, -1);
    const msg = msgRaw ? to_jsstring(msgRaw) : '(unknown error)';
    lua.lua_pop(L, 1);
    throw new Error('Lua compile error in ' + (chunkName || 'chunk') + ': ' + msg);
  }
  if (lua.lua_pcall(L, 0, lua.LUA_MULTRET, 0) !== lua.LUA_OK) {
    const msgRaw = lua.lua_tostring(L, -1);
    const msg = msgRaw ? to_jsstring(msgRaw) : '(unknown error)';
    lua.lua_pop(L, 1);
    throw new Error('Lua runtime error in ' + (chunkName || 'chunk') + ': ' + msg);
  }
}

// ---------------------------------------------------------------------------
// Build a fresh Lua state with all standard libs open and package.path set
// ---------------------------------------------------------------------------
function buildState() {
  const L = lauxlib.luaL_newstate();
  lualib.luaL_openlibs(L);

  // Set package.path so that:
  //   require("spec.support.init")        -> spec/support/init.lua
  //   require("spec.support.wow_stubs")   -> spec/support/wow_stubs.lua
  //   loadfile("Duncedmaxxing/Core.lua")  -> resolved relative to ROOT
  // We add both ROOT and ROOT/spec to the search path.
  const packagePath = [
    ROOT + '/?.lua',
    ROOT + '/?/init.lua',
  ].join(';');

  execLua(L, `package.path = "${packagePath.replace(/\\/g, '\\\\')}"`, 'set-package-path');

  return L;
}

// ---------------------------------------------------------------------------
// Inject the busted-compatible shim into the Lua state
//
// Shim globals provided:
//   describe(name, fn)          -- top-level test group
//   it(name, fn)                -- registers a test case
//   before_each(fn)             -- registers a before-each hook for current describe
//   assert                      -- table with assertion methods
//
// Assertion surface (from grep across all *_spec.lua files):
//   assert.equals / assert.equal / assert.are.equal
//   assert.not_equals
//   assert.is_true
//   assert.is_false
//   assert.is_nil
//   assert.is_not_nil
//   assert.is_table
//   assert.is_near / assert.near
// ---------------------------------------------------------------------------
function injectShim(L, registry) {
  // We communicate the JS registry via a global table that the Lua shim pops into.
  // The cleanest approach: expose JS callback via a lua_CFunction that the Lua shim
  // calls to register tests.  We use the simpler approach: push the shim entirely as
  // a Lua string and execute it; it builds the global functions; then we wrap them to
  // feed back into the JS registry by injecting JS-callable hooks.

  // Strategy: Lua shim stores pending tests in a global __tests__ table.
  // After all spec files are loaded, we iterate __tests__ from JS to run them.

  const shimSrc = `
-- Busted-compatible shim for spec/run.cjs
-- Stores test registrations in __tests__ for the JS harness to execute.

__tests__    = __tests__    or {}  -- flat list of { describe, name, before_eachs, fn }
__describe__ = __describe__ or {}  -- stack of describe names

local _describe_stack   = {}   -- stack of { name, before_eachs = {} }
local _current_befores  = {}   -- before_each callbacks for current describe

-- describe(name, fn): opens a new context, runs fn, then closes it
function describe(name, fn)
  table.insert(_describe_stack, { name = name, befores = {} })
  local prev_befores = _current_befores
  _current_befores   = _describe_stack[#_describe_stack].befores

  local ok, err = pcall(fn)

  _current_befores = prev_befores
  table.remove(_describe_stack)

  if not ok then
    error("describe('" .. name .. "') body error: " .. tostring(err))
  end
end

-- before_each(fn): registers a hook for the current describe scope
function before_each(fn)
  table.insert(_current_befores, fn)
end

-- it(name, fn): registers a test case
function it(name, fn)
  -- snapshot the current describe path and before_each chain
  local names = {}
  local befores = {}
  for _, frame in ipairs(_describe_stack) do
    table.insert(names, frame.name)
    for _, b in ipairs(frame.befores) do
      table.insert(befores, b)
    end
  end
  -- also include the current (innermost) describe's befores
  for _, b in ipairs(_current_befores) do
    table.insert(befores, b)
  end

  local label = table.concat(names, " > ")
  table.insert(__tests__, {
    describe  = label,
    name      = name,
    befores   = befores,
    fn        = fn,
  })
end

-- ---------------------------------------------------------------------------
-- assert shim
-- ---------------------------------------------------------------------------
local function failMsg(...)
  local parts = {}
  for i = 1, select('#', ...) do
    parts[i] = tostring(select(i, ...))
  end
  return table.concat(parts, "  ")
end

local function assertEq(expected, actual, msg)
  if expected ~= actual then
    error(string.format(
      "Expected %s but got %s%s",
      tostring(expected), tostring(actual),
      msg and ("  (" .. msg .. ")") or ""
    ), 2)
  end
end

local function assertNear(expected, actual, tol, msg)
  if type(expected) ~= "number" or type(actual) ~= "number" then
    error(string.format(
      "assert.near: expected numbers, got %s and %s",
      type(expected), type(actual)
    ), 2)
  end
  if math.abs(expected - actual) > (tol or 1e-7) then
    error(string.format(
      "Expected ~%s (tol %s) but got %s%s",
      tostring(expected), tostring(tol or 1e-7), tostring(actual),
      msg and ("  (" .. msg .. ")") or ""
    ), 2)
  end
end

-- Build the assert table
assert = {
  -- assert.equals(expected, actual)
  equals = assertEq,
  -- assert.equal(expected, actual)
  equal  = assertEq,
  -- assert.not_equals(expected, actual)
  not_equals = function(expected, actual, msg)
    if expected == actual then
      error(string.format(
        "Expected value to NOT equal %s, but it did%s",
        tostring(expected),
        msg and ("  (" .. msg .. ")") or ""
      ), 2)
    end
  end,
  -- assert.is_true(v)
  is_true = function(v, msg)
    if v ~= true then
      error(string.format(
        "Expected true but got %s%s",
        tostring(v), msg and ("  (" .. msg .. ")") or ""
      ), 2)
    end
  end,
  -- assert.is_false(v)
  is_false = function(v, msg)
    if v ~= false then
      error(string.format(
        "Expected false but got %s%s",
        tostring(v), msg and ("  (" .. msg .. ")") or ""
      ), 2)
    end
  end,
  -- assert.is_nil(v)
  is_nil = function(v, msg)
    if v ~= nil then
      error(string.format(
        "Expected nil but got %s%s",
        tostring(v), msg and ("  (" .. msg .. ")") or ""
      ), 2)
    end
  end,
  -- assert.is_not_nil(v)
  is_not_nil = function(v, msg)
    if v == nil then
      error(string.format(
        "Expected non-nil value%s",
        msg and ("  (" .. msg .. ")") or ""
      ), 2)
    end
  end,
  -- assert.is_table(v)
  is_table = function(v, msg)
    if type(v) ~= "table" then
      error(string.format(
        "Expected table but got %s%s",
        type(v), msg and ("  (" .. msg .. ")") or ""
      ), 2)
    end
  end,
  -- assert.is_near(value, expected, tolerance)   [busted arg order: value, expected, tol]
  is_near = function(value, expected, tol, msg)
    assertNear(expected, value, tol, msg)
  end,
  -- assert.near(expected, actual, tol, msg)
  near = assertNear,
  -- assert.are.equal(expected, actual)
  are = {
    equal = assertEq,
  },
}

-- Also allow assert(condition, msg) as a bare truthy check
setmetatable(assert, {
  __call = function(_, cond, msg)
    if not cond then
      error(msg or "assertion failed", 2)
    end
  end,
})
`;

  execLua(L, shimSrc, 'busted-shim');
}

// ---------------------------------------------------------------------------
// Run all registered tests from __tests__ in a Lua state
// Results: array of { label, passed, error }
// ---------------------------------------------------------------------------
function runTests(L) {
  const results = [];

  // Read __tests__ length
  execLua(L, '__run_test_count__ = #__tests__', 'count-tests');
  lua.lua_getglobal(L, to_luastring('__run_test_count__'));
  const count = lua.lua_tointeger(L, -1);
  lua.lua_pop(L, 1);

  for (let i = 1; i <= count; i++) {
    // Run the i-th test: call its before_each chain then its fn, all inside pcall
    const runSrc = `
(function()
  local t = __tests__[${i}]
  -- Run before_each chain
  for _, b in ipairs(t.befores) do
    local ok, err = pcall(b)
    if not ok then
      __run_error__   = tostring(err)
      __run_passed__  = false
      __run_label__   = (t.describe ~= "" and (t.describe .. " > ") or "") .. t.name
      return
    end
  end
  -- Run test body
  local ok, err = pcall(t.fn)
  __run_error__  = ok and nil or tostring(err)
  __run_passed__ = ok
  __run_label__  = (t.describe ~= "" and (t.describe .. " > ") or "") .. t.name
end)()
`;
    execLua(L, runSrc, 'run-test-' + i);

    // Read results back
    lua.lua_getglobal(L, to_luastring('__run_label__'));
    const labelRaw = lua.lua_tostring(L, -1);
    const label = labelRaw ? to_jsstring(labelRaw) : ('test #' + i);
    lua.lua_pop(L, 1);

    lua.lua_getglobal(L, to_luastring('__run_passed__'));
    const passed = lua.lua_toboolean(L, -1);
    lua.lua_pop(L, 1);

    lua.lua_getglobal(L, to_luastring('__run_error__'));
    const errRaw = lua.lua_type(L, -1) === lua.LUA_TNIL
      ? null
      : lua.lua_tostring(L, -1);
    const errMsg = errRaw ? to_jsstring(errRaw) : null;
    lua.lua_pop(L, 1);

    results.push({ label, passed, error: errMsg });
  }

  return results;
}

// ---------------------------------------------------------------------------
// Self-test mode: boot VM, run one synthetic inline spec, exit
// ---------------------------------------------------------------------------
function runSelfTest() {
  console.log('[run.cjs] --self-test: booting Lua VM with synthetic inline spec...');

  const L = buildState();
  injectShim(L);

  // Register a single trivially-true synthetic test
  const syntheticSpec = `
describe("self-test", function()
  it("trivially true", function()
    assert.equals(1, 1)
    assert.is_true(true)
    assert.is_not_nil("hello")
  end)
end)
`;
  execLua(L, syntheticSpec, 'synthetic-spec');

  const results = runTests(L);

  let passed = 0, failed = 0;
  for (const r of results) {
    if (r.passed) {
      passed++;
      console.log('  PASS  ' + r.label);
    } else {
      failed++;
      console.log('  FAIL  ' + r.label + '\n        ' + r.error);
    }
  }

  console.log('\nSelf-test: ' + passed + ' passed, ' + failed + ' failed');
  if (failed > 0 || results.length === 0) {
    console.error('[run.cjs] Self-test FAILED');
    process.exit(1);
  }
  console.log('[run.cjs] Self-test PASSED');
  process.exit(0);
}

// ---------------------------------------------------------------------------
// Full suite run: discover *_spec.lua files, load them, run all tests
// ---------------------------------------------------------------------------
function runSuite() {
  const specDir = path.join(ROOT, 'spec');
  const specFiles = fs.readdirSync(specDir)
    .filter(f => f.endsWith('_spec.lua'))
    .sort()
    .map(f => path.join(specDir, f));

  if (specFiles.length === 0) {
    console.error('[run.cjs] No *_spec.lua files found in ' + specDir);
    process.exit(1);
  }

  // Use a single Lua state for the whole suite (spec support uses module-level state;
  // loader.load() handles per-test isolation internally via _G resets).
  const L = buildState();
  injectShim(L);

  // Change Lua's working directory notion: set io.open to be relative to ROOT.
  // Since fengari may not honour chdir, override loadfile via a package.path approach.
  // The key is that loadfile("Duncedmaxxing/Core.lua") in init.lua must resolve to ROOT.
  // We already set package.path with ROOT; loadfile in standard Lua resolves relative to
  // cwd, so we chdir to ROOT.
  try {
    process.chdir(ROOT);
  } catch (e) {
    console.warn('[run.cjs] Warning: could not chdir to project root:', e.message);
  }

  // Load each spec file
  for (const specFile of specFiles) {
    const relPath = path.relative(ROOT, specFile);
    const src = fs.readFileSync(specFile, 'utf8');
    try {
      execLua(L, src, relPath);
    } catch (e) {
      console.error('[run.cjs] Error loading ' + relPath + ':\n  ' + e.message);
      process.exit(1);
    }
  }

  // Run all registered tests
  const results = runTests(L);

  let passed = 0, failed = 0;
  const failures = [];

  for (const r of results) {
    if (r.passed) {
      passed++;
      console.log('  PASS  ' + r.label);
    } else {
      failed++;
      console.log('  FAIL  ' + r.label);
      if (r.error) {
        console.log('        ' + r.error.replace(/\n/g, '\n        '));
      }
      failures.push(r);
    }
  }

  console.log('\n--- Results ---');
  console.log(passed + ' passed, ' + failed + ' failed, ' + results.length + ' total');

  if (failed > 0) {
    console.error('\nFailed tests:');
    for (const f of failures) {
      console.error('  ' + f.label);
    }
    process.exit(1);
  }

  if (results.length === 0) {
    console.error('[run.cjs] No tests were registered — check spec file loading');
    process.exit(1);
  }

  process.exit(0);
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------
if (SELF_TEST) {
  runSelfTest();
} else {
  runSuite();
}
