local M = {}
local cfg_notify = require("ai_commit_msg.config").notify

local function get_spinner()
  local spinner = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
  return spinner[math.floor(vim.uv.hrtime() / (1e6 * 80)) % #spinner + 1]
end

local function call_api(config, diff, callback)
  local providers = require("ai_commit_msg.providers")
  return providers.call_api(config, diff, callback)
end

function M.generate(config, callback)
  vim.schedule(function()
    cfg_notify("ai-commit-msg.nvim: Starting generation", vim.log.levels.DEBUG)
  end)

  local spinner_timer
  local notif_id = "ai-commit-msg"

  -- Start spinner if enabled
  if config.spinner then
    local function update_spinner()
      if not spinner_timer or spinner_timer:is_closing() then
        return
      end
      vim.notify(get_spinner() .. " Generating commit message...", vim.log.levels.INFO, {
        id = notif_id,
        title = "AI Commit",
        timeout = false,
      })
    end

    spinner_timer = vim.uv.new_timer()
    if spinner_timer then
      spinner_timer:start(0, 100, vim.schedule_wrap(update_spinner))
    end
  elseif config.notifications then
    vim.schedule(function()
      cfg_notify("Generating commit message...", vim.log.levels.INFO, { title = "AI Commit" })
    end)
  end

  -- Get git diff first
  local git_cmd = { "git", "diff", "--staged" }
  if config.context_lines and type(config.context_lines) == "number" and config.context_lines >= 0 then
    table.insert(git_cmd, "-U" .. config.context_lines)
  end
  vim.system(git_cmd, {}, function(diff_res)
    if diff_res.code ~= 0 then
      -- Stop spinner
      if spinner_timer and not spinner_timer:is_closing() then
        spinner_timer:stop()
        spinner_timer:close()
      end
      spinner_timer = nil

      vim.schedule(function()
        local error_msg = "Failed to get git diff: " .. (diff_res.stderr or "Unknown error")
        cfg_notify("❌ " .. error_msg, vim.log.levels.ERROR, {
          id = notif_id,
          title = "AI Commit",
          timeout = 3000,
        })
        if callback then
          callback(false, error_msg)
        end
      end)
      return
    end

    local diff = diff_res.stdout or ""
    if diff == "" then
      -- Stop spinner
      if spinner_timer and not spinner_timer:is_closing() then
        spinner_timer:stop()
        spinner_timer:close()
      end
      spinner_timer = nil

      vim.schedule(function()
        cfg_notify("⚠️  No staged changes to commit", vim.log.levels.WARN, {
          id = notif_id,
          title = "AI Commit",
          timeout = 3000,
        })
        if callback then
          callback(false, "No staged changes to commit")
        end
      end)
      return
    end

    vim.schedule(function()
      cfg_notify("ai-commit-msg.nvim: Calling AI API", vim.log.levels.DEBUG)
    end)

    local start_time = vim.uv.hrtime()

    call_api(config, diff, function(success, result, usage)
      -- Stop spinner
      if spinner_timer and not spinner_timer:is_closing() then
        spinner_timer:stop()
        spinner_timer:close()
      end
      spinner_timer = nil

      vim.schedule(function()
        if not success then
          cfg_notify("❌ " .. result, vim.log.levels.ERROR, {
            id = notif_id,
            title = "AI Commit",
            timeout = 3000,
          })
          if callback then
            callback(false, result)
          end
        else
          local duration = (vim.uv.hrtime() - start_time) / 1e9
          local duration_str = string.format("%.2fs", duration)

          -- Calculate and format cost if available
          local ai_commit_msg = require("ai_commit_msg")
          local cost_info = ai_commit_msg.calculate_cost(usage, config)
          local duration_cost_str = duration_str
          if cost_info and config.cost_display then
            if config.cost_display == "compact" then
              duration_cost_str = duration_str .. " " .. ai_commit_msg.format_cost(cost_info, config.cost_display)
            else
              duration_cost_str = duration_str .. ") " .. ai_commit_msg.format_cost(cost_info, config.cost_display)
            end
          end

          cfg_notify("ai-commit-msg.nvim: Generated message: " .. result:sub(1, 50) .. "...", vim.log.levels.DEBUG)
          -- Clear spinner notification with success message
          if config.spinner or config.notifications then
            cfg_notify("✅ Commit message generated (" .. duration_cost_str .. ")", vim.log.levels.INFO, {
              id = notif_id,
              title = "AI Commit",
              timeout = 2000,
            })
          end
          if callback then
            callback(true, result)
          end
        end
      end)
    end)
  end)
end

return M
