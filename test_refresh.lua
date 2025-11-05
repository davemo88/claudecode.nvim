-- Simple test to verify file_refresh module loads and has correct structure
local file_refresh = require("claudecode.file_refresh")

assert(file_refresh ~= nil, "file_refresh module should load")
assert(type(file_refresh.setup) == "function", "file_refresh.setup should be a function")
assert(type(file_refresh.cleanup) == "function", "file_refresh.cleanup should be a function")

print("✓ file_refresh module structure is correct")

-- Test config module has refresh config
local config = require("claudecode.config")
assert(config.defaults.refresh ~= nil, "config.defaults.refresh should exist")
assert(config.defaults.refresh.enable == true, "refresh.enable should be true by default")
assert(config.defaults.refresh.updatetime == 100, "refresh.updatetime should be 100")
assert(config.defaults.refresh.timer_interval == 1000, "refresh.timer_interval should be 1000")
assert(config.defaults.refresh.show_notifications == true, "refresh.show_notifications should be true")

print("✓ config.defaults.refresh is correct")

-- Test config validation accepts valid refresh config
local valid_config = vim.deepcopy(config.defaults)
if vim.tbl_deep_extend then
  valid_config = vim.tbl_deep_extend("force", valid_config, {
    refresh = {
      enable = false,
      updatetime = 200,
      timer_interval = 2000,
      show_notifications = false,
    }
  })
else
  valid_config.refresh = {
    enable = false,
    updatetime = 200,
    timer_interval = 2000,
    show_notifications = false,
  }
end

-- Lazy-load terminal defaults to avoid circular dependency
if valid_config.terminal == nil then
  local terminal_ok, terminal_module = pcall(require, "claudecode.terminal")
  if terminal_ok and terminal_module.defaults then
    valid_config.terminal = terminal_module.defaults
  end
end

local ok, err = pcall(config.validate, valid_config)
assert(ok, "Valid refresh config should pass validation: " .. tostring(err))

print("✓ config validation accepts valid refresh config")

-- Test config validation rejects invalid refresh config
local invalid_configs = {
  { refresh = "not a table" },
  { refresh = { enable = "not a boolean" } },
  { refresh = { enable = true, updatetime = -1 } },
  { refresh = { enable = true, updatetime = 100, timer_interval = 0 } },
  { refresh = { enable = true, updatetime = 100, timer_interval = 1000, show_notifications = "not a boolean" } },
}

for i, invalid in ipairs(invalid_configs) do
  local test_config = vim.deepcopy(config.defaults)
  if vim.tbl_deep_extend then
    test_config = vim.tbl_deep_extend("force", test_config, invalid)
  else
    for k, v in pairs(invalid) do
      test_config[k] = v
    end
  end

  -- Lazy-load terminal defaults
  if test_config.terminal == nil then
    local terminal_ok, terminal_module = pcall(require, "claudecode.terminal")
    if terminal_ok and terminal_module.defaults then
      test_config.terminal = terminal_module.defaults
    end
  end

  local ok, err = pcall(config.validate, test_config)
  assert(not ok, "Invalid refresh config #" .. i .. " should fail validation")
end

print("✓ config validation rejects invalid refresh configs")

print("\n✅ All file refresh tests passed!")
