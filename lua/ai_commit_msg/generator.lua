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

local function call_openai_api(config, diff, callback)
  local api_key = os.getenv("OPENAI_API_KEY")
  if not api_key or api_key == "" then
    callback(false, "OPENAI_API_KEY environment variable not set")
    return
  end

  -- Replace {diff} placeholder with actual diff content
  local prompt
  if config.prompt:find("{diff}", 1, true) then
    local before, after = config.prompt:match("^(.*)%{diff%}(.*)$")
    if before and after then
      prompt = before .. diff .. after
    else
      -- Fallback if pattern doesn't match
      prompt = config.prompt .. "\n\n" .. diff
    end
  else
    -- If no {diff} placeholder, append the diff
    prompt = config.prompt .. "\n\n" .. diff
  end
  
  vim.notify("ai-commit-msg.nvim: Prompt length: " .. #prompt .. " chars", vim.log.levels.DEBUG)
  
  local payload = vim.json.encode({
    model = config.model or "gpt-4o-mini",
    messages = {
      {
        role = "system",
        content = "You are a helpful assistant that generates conventional commit messages based on git diffs."
      },
      {
        role = "user",
        content = prompt
      }
    },
    temperature = config.temperature or 0.3,
    max_tokens = config.max_tokens or 500
  })

  local curl_args = {
    "curl",
    "-X", "POST",
    "https://api.openai.com/v1/chat/completions",
    "-H", "Content-Type: application/json",
    "-H", "Authorization: Bearer " .. api_key,
    "-d", payload,
    "--silent",
    "--show-error"
  }

  vim.system(curl_args, {}, function(res)
    if res.code ~= 0 then
      callback(false, "API request failed: " .. (res.stderr or "Unknown error"))
      return
    end

    local ok, response = pcall(vim.json.decode, res.stdout)
    if not ok then
      callback(false, "Failed to parse API response: " .. tostring(response))
      return
    end

    if response.error then
      callback(false, "OpenAI API error: " .. (response.error.message or "Unknown error"))
      return
    end

    if response.choices and response.choices[1] and response.choices[1].message then
      local commit_msg = response.choices[1].message.content
      -- Clean up the message (remove markdown code blocks if present)
      commit_msg = commit_msg:gsub("^```%w*\n", ""):gsub("\n```$", ""):gsub("^`", ""):gsub("`$", "")
      commit_msg = vim.trim(commit_msg)
      callback(true, commit_msg)
    else
      callback(false, "Unexpected API response format")
    end
  end)
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
  vim.system({ "git", "diff", "--staged" }, {}, function(diff_res)
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

    vim.notify("ai-commit-msg.nvim: Calling OpenAI API", vim.log.levels.DEBUG)

    call_openai_api(config, diff, function(success, result)
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
          vim.notify("ai-commit-msg.nvim: Generated message: " .. result:sub(1, 50) .. "...", vim.log.levels.DEBUG)
          -- Clear spinner notification with success message
          if config.notifications then
            vim.notify("✅ Commit message generated", vim.log.levels.INFO, {
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
