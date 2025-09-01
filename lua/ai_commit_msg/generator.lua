local M = {}

local function get_spinner()
  local spinner = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
  return spinner[math.floor(vim.uv.hrtime() / (1e6 * 80)) % #spinner + 1]
end

local function notify(msg, level, config)
  if config.notifications then
    vim.notify(msg, level, {
      title = "AI Commit",
    })
  end
end

local function call_api(config, diff, callback)
  local providers = require("ai_commit_msg.providers")
  return providers.call_api(config, diff, callback)
end

function M.generate(config, callback)
  vim.notify("ai-commit-msg.nvim: Starting generation", vim.log.levels.DEBUG)

  local spinner_timer
  local notif_id = "ai-commit-msg"

  -- Start spinner if enabled
  if config.spinner and config.notifications then
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
    notify("Generating commit message...", vim.log.levels.INFO, config)
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
        vim.notify("ai-commit-msg.nvim: " .. error_msg, vim.log.levels.ERROR)
        -- Clear spinner notification with error message
        if config.notifications then
          vim.notify("❌ " .. error_msg, vim.log.levels.ERROR, {
            id = notif_id,
            title = "AI Commit",
            timeout = 3000,
          })
        end
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
        local error_msg = "No staged changes to commit"
        vim.notify("ai-commit-msg.nvim: " .. error_msg, vim.log.levels.WARN)
        -- Clear spinner notification with warning message
        if config.notifications then
          vim.notify("⚠️  " .. error_msg, vim.log.levels.WARN, {
            id = notif_id,
            title = "AI Commit",
            timeout = 3000,
          })
        end
        if callback then
          callback(false, error_msg)
        end
      end)
      return
    end

    vim.notify("ai-commit-msg.nvim: Calling AI API", vim.log.levels.DEBUG)

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
          vim.notify("ai-commit-msg.nvim: " .. result, vim.log.levels.ERROR)
          -- Clear spinner notification with error message
          if config.notifications then
            vim.notify("❌ " .. result, vim.log.levels.ERROR, {
              id = notif_id,
              title = "AI Commit",
              timeout = 3000,
            })
          end
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

          vim.notify("ai-commit-msg.nvim: Generated message: " .. result:sub(1, 50) .. "...", vim.log.levels.DEBUG)
          -- Clear spinner notification with success message
          if config.notifications then
            vim.notify("✅ Commit message generated (" .. duration_cost_str .. ")", vim.log.levels.INFO, {
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
