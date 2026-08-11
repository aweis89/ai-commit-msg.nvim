if vim.fn.has("nvim-0.7.0") == 0 then
  vim.api.nvim_err_writeln("ai-commit-msg.nvim requires at least nvim-0.7.0")
  return
end

if vim.g.loaded_ai_commit_msg == 1 then
  return
end
vim.g.loaded_ai_commit_msg = 1

local cfg_notify = require("ai_commit_msg.config").notify

cfg_notify("ai-commit-msg.nvim: Plugin loaded", vim.log.levels.DEBUG)

-- Create user commands
vim.api.nvim_create_user_command("AiCommitMsg", function()
  require("ai_commit_msg").generate_commit_message(function(success, message)
    if success then
      print(message)
    end
  end)
end, { desc = "Generate AI commit message" })

vim.api.nvim_create_user_command("AiCommitMsgDisable", function()
  require("ai_commit_msg").disable()
  cfg_notify("AI Commit Message disabled", vim.log.levels.INFO)
end, { desc = "Disable AI commit message generation" })

vim.api.nvim_create_user_command("AiCommitMsgEnable", function()
  require("ai_commit_msg").enable()
  cfg_notify("AI Commit Message enabled", vim.log.levels.INFO)
end, { desc = "Enable AI commit message generation" })

vim.api.nvim_create_user_command("AiCommitMsgDebug", function()
  vim.g.ai_commit_msg_debug = not vim.g.ai_commit_msg_debug
  vim.notify("ai-commit-msg.nvim debug: " .. (vim.g.ai_commit_msg_debug and "ON" or "OFF"), vim.log.levels.INFO)
  local plugin = require("ai_commit_msg")
  cfg_notify("Plugin config: " .. vim.inspect(plugin.config), vim.log.levels.INFO)

  -- Check if autocmds are registered
  local autocmds = vim.api.nvim_get_autocmds({ group = "ai_commit_msg" })
  if #autocmds > 0 then
    cfg_notify("Autocmds registered: " .. vim.inspect(autocmds), vim.log.levels.INFO)
  else
    cfg_notify("No autocmds registered!", vim.log.levels.WARN)
  end
end, { desc = "Debug AI commit message plugin" })

-- Run a prompt/model matrix against fixture diffs
vim.api.nvim_create_user_command("AiCommitMsgTestMatrix", function(opts)
  local args = opts.fargs or {}
  local diffs_dir = args[1] or "fixtures/diffs"
  local out_file = args[2] or ""
  local dry = vim.env.AI_COMMIT_MSG_DRY_RUN == "1"

  local harness = require("ai_commit_msg.harness")
  local results = harness.run_matrix({
    diffs_dir = diffs_dir,
    out_file = out_file,
    auto_short = true,
    dry_run = dry,
  })

  if dry then
    cfg_notify("Dry-run: collected " .. tostring(#results) .. " prompt stats", vim.log.levels.INFO)
  else
    cfg_notify("Matrix run complete: " .. tostring(#results) .. " cases", vim.log.levels.INFO)
  end
end, {
  desc = "Run prompt/model matrix over .diff fixtures",
  nargs = "*",
  complete = function(_, line)
    if not line:match("%s") then
      return { "fixtures/diffs" }
    end
    return {}
  end,
})

-- Generate commit messages for the current staged diff across all models
vim.api.nvim_create_user_command("AiCommitMsgAllModels", function()
  local plugin = require("ai_commit_msg")
  local config = plugin.config

  local git_cmd = { "git", "diff", "--staged" }
  if config.context_lines and type(config.context_lines) == "number" and config.context_lines >= 0 then
    table.insert(git_cmd, "-U" .. config.context_lines)
  end

  vim.system(git_cmd, {}, function(diff_res)
    if diff_res.code ~= 0 then
      vim.schedule(function()
        cfg_notify("Failed to get git diff: " .. (diff_res.stderr or "Unknown error"), vim.log.levels.ERROR)
      end)
      return
    end

    local diff = diff_res.stdout or ""
    if diff == "" then
      vim.schedule(function()
        cfg_notify("No staged changes to commit", vim.log.levels.WARN)
      end)
      return
    end

    -- Run the matrix and render results on the main loop
    vim.schedule(function()
      local harness = require("ai_commit_msg.harness")
      local results = harness.run_live_matrix(diff, { auto_short = true, dry_run = false })

      local buf = vim.api.nvim_create_buf(false, true)
      local lines = {}
      table.insert(lines, "# ai-commit-msg.nvim: All Models")
      table.insert(lines, "")

      local config_mod = require("ai_commit_msg.config")

      for _, rec in ipairs(results) do
        local header = string.format("## %s:%s (%s)", rec.provider, rec.model, rec.short and "short" or "full")
        table.insert(lines, header)

        if rec.duration_ms then
          table.insert(lines, string.format("time: %d ms", rec.duration_ms))
        end

        if rec.success then
          -- compute cost if usage available
          local pcfg = config_mod.default.providers[rec.provider]
          local merged = vim.tbl_deep_extend("force", {}, pcfg, { model = rec.model })
          local cost_info = plugin.calculate_cost(rec.usage, merged)
          if cost_info then
            table.insert(lines, string.format("cost: %s", plugin.format_cost(cost_info, config.cost_display)))
          end

          table.insert(lines, "")
          for line in tostring(rec.message):gmatch("([^\n]*)\n?") do
            table.insert(lines, line)
          end
        else
          table.insert(lines, "(error)")
          local err_text = tostring(rec.message or "")
          for line in err_text:gmatch("([^\n]*)\n?") do
            table.insert(lines, line)
          end
        end
        table.insert(lines, "")
      end

      vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
      vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
      vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
      vim.api.nvim_buf_set_option(buf, "filetype", "gitcommit")
      vim.api.nvim_set_current_buf(buf)
      cfg_notify("All-models results buffer opened", vim.log.levels.INFO)
    end)
  end)
end, { desc = "Generate commit messages across all models for staged diff" })
