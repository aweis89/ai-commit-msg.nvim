local M = {}

function M.call_api(config, diff, callback)
  if vim.fn.executable("claude") ~= 1 then
    callback(false, "claude CLI not found. Install Claude Code: https://docs.anthropic.com/en/docs/claude-code")
    return
  end

  local prompt
  if config.prompt:find("{diff}", 1, true) then
    local before, after = config.prompt:match("^(.*)%{diff%}(.*)$")
    if before and after then
      prompt = before .. diff .. after
    else
      prompt = config.prompt .. "\n\n" .. diff
    end
  else
    prompt = config.prompt .. "\n\n" .. diff
  end

  vim.schedule(function()
    require("ai_commit_msg.config").notify(
      "ai-commit-msg.nvim: Prompt length: " .. #prompt .. " chars",
      vim.log.levels.DEBUG
    )
  end)

  local cmd = {
    "claude",
    "-p",
    "--output-format",
    "json",
    "--max-turns",
    "1",
    "--system-prompt",
    config.system_prompt,
  }

  if config.model then
    table.insert(cmd, "--model")
    table.insert(cmd, config.model)
  end

  vim.system(cmd, { stdin = prompt }, function(res)
    if res.code ~= 0 then
      callback(false, "claude CLI failed: " .. (res.stderr or "Unknown error"))
      return
    end

    local ok, response = pcall(vim.json.decode, res.stdout)
    if not ok then
      callback(false, "Failed to parse claude CLI response: " .. tostring(response))
      return
    end

    if response.is_error then
      callback(false, "Claude Code error: " .. (response.result or "Unknown error"))
      return
    end

    vim.schedule(function()
      require("ai_commit_msg.config").notify(
        "ai-commit-msg.nvim: Full CLI response: " .. vim.inspect(response),
        vim.log.levels.DEBUG
      )
    end)

    if response.result then
      local commit_msg = response.result
      commit_msg = commit_msg:gsub("^```%w*\n", ""):gsub("\n```$", ""):gsub("^`", ""):gsub("`$", "")
      commit_msg = vim.trim(commit_msg)

      callback(true, commit_msg, nil)
    else
      callback(false, "Unexpected claude CLI response format")
    end
  end)
end

return M
