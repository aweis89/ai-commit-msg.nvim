local M = {}

function M.call_api(config, diff, callback)
  local api_key = os.getenv("ANTHROPIC_API_KEY")
  if not api_key or api_key == "" then
    callback(false, "ANTHROPIC_API_KEY environment variable not set")
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

  vim.notify("ai-commit-msg.nvim: Prompt length: " .. #prompt .. " chars", vim.log.levels.DEBUG)

  local max_tokens = config.max_tokens or 1000

  local payload = vim.json.encode({
    model = config.model,
    max_tokens = max_tokens,
    messages = {
      {
        role = "user",
        content = prompt,
      },
    },
    system = config.system_prompt,
  })

  local curl_args = {
    "curl",
    "-X",
    "POST",
    "https://api.anthropic.com/v1/messages",
    "-H",
    "Content-Type: application/json",
    "-H",
    "x-api-key: " .. api_key,
    "-H",
    "anthropic-version: 2023-06-01",
    "-d",
    payload,
    "--silent",
    "--show-error",
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
      callback(false, "Anthropic API error: " .. (response.error.message or "Unknown error"))
      return
    end

    vim.notify("ai-commit-msg.nvim: Full API response: " .. vim.inspect(response), vim.log.levels.DEBUG)

    if response.content and response.content[1] and response.content[1].text then
      local commit_msg = response.content[1].text
      commit_msg = commit_msg:gsub("^```%w*\n", ""):gsub("\n```$", ""):gsub("^`", ""):gsub("`$", "")
      commit_msg = vim.trim(commit_msg)

      -- Extract token usage if available
      local usage = nil
      if response.usage then
        usage = {
          input_tokens = response.usage.input_tokens,
          output_tokens = response.usage.output_tokens,
        }
      end

      callback(true, commit_msg, usage)
    else
      callback(false, "Unexpected API response format")
    end
  end)
end

return M
