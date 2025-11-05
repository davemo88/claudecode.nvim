---@mod claudecode.file_refresh File refresh functionality for claudecode.nvim
---@brief [[
--- This module provides file refresh functionality to detect and reload files
--- that have been modified by Claude Code or other external processes.
---@brief ]]

local M = {}

local logger = require("claudecode.logger")

--- Timer for checking file changes
--- @type userdata|nil
local refresh_timer = nil

--- Reference to the main plugin module
--- @type table|nil
local plugin_module = nil

--- Saved updatetime value
--- @type number|nil
local saved_updatetime = nil

--- Check if Claude Code server is running
--- @return boolean
local function is_claude_active()
  if not plugin_module then
    return false
  end
  return plugin_module.state.server ~= nil
end

--- Setup autocommands for file change detection
--- @param claudecode table The main plugin module
--- @param config table The plugin configuration
function M.setup(claudecode, config)
  if not config.refresh.enable then
    return
  end

  -- Store reference to main plugin module
  plugin_module = claudecode

  local augroup = vim.api.nvim_create_augroup("ClaudeCodeFileRefresh", { clear = true })

  -- Create an autocommand that checks for file changes more frequently
  vim.api.nvim_create_autocmd({
    "CursorHold",
    "CursorHoldI",
    "FocusGained",
    "BufEnter",
    "InsertLeave",
    "TextChanged",
    "TermLeave",
    "TermEnter",
    "BufWinEnter",
  }, {
    group = augroup,
    pattern = "*",
    callback = function()
      if vim.fn.filereadable(vim.fn.expand("%")) == 1 then
        vim.cmd("checktime")
      end
    end,
    desc = "Check for file changes on disk",
  })

  -- Clean up any existing timer
  if refresh_timer then
    refresh_timer:stop()
    refresh_timer:close()
    refresh_timer = nil
  end

  -- Create a timer to check for file changes periodically
  refresh_timer = vim.loop.new_timer()
  if refresh_timer then
    refresh_timer:start(
      0,
      config.refresh.timer_interval,
      vim.schedule_wrap(function()
        -- Only check time if Claude Code server is active
        if is_claude_active() then
          vim.cmd("silent! checktime")
        end
      end)
    )
  end

  -- Create an autocommand that notifies when a file has been changed externally
  if config.refresh.show_notifications then
    vim.api.nvim_create_autocmd("FileChangedShellPost", {
      group = augroup,
      pattern = "*",
      callback = function()
        logger.info("refresh", "File changed on disk. Buffer reloaded.")
      end,
      desc = "Notify when a file is changed externally",
    })
  end

  -- Save the original updatetime
  saved_updatetime = vim.o.updatetime

  -- Create autocmd to set shorter updatetime when Claude Code server starts
  vim.api.nvim_create_autocmd("User", {
    group = augroup,
    pattern = "ClaudeCodeServerStarted",
    callback = function()
      saved_updatetime = vim.o.updatetime
      vim.o.updatetime = config.refresh.updatetime
      logger.debug("refresh", "Set updatetime to " .. config.refresh.updatetime .. "ms (saved: " .. saved_updatetime .. "ms)")
    end,
    desc = "Set shorter updatetime when Claude Code server starts",
  })

  -- Restore normal updatetime when Claude Code server stops
  vim.api.nvim_create_autocmd("User", {
    group = augroup,
    pattern = "ClaudeCodeServerStopped",
    callback = function()
      if saved_updatetime then
        vim.o.updatetime = saved_updatetime
        logger.debug("refresh", "Restored updatetime to " .. saved_updatetime .. "ms")
      end
    end,
    desc = "Restore normal updatetime when Claude Code server stops",
  })
end

--- Clean up the file refresh functionality (stop the timer)
function M.cleanup()
  if refresh_timer then
    refresh_timer:stop()
    refresh_timer:close()
    refresh_timer = nil
  end

  -- Restore updatetime if we saved it
  if saved_updatetime then
    vim.o.updatetime = saved_updatetime
    saved_updatetime = nil
  end

  plugin_module = nil
end

return M
