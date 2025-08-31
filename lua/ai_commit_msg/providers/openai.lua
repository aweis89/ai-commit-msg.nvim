local M = {}

function M.call_api(config, diff, callback)
  local api_key = os.getenv("OPENAI_API_KEY")
  if not api_key or api_key == "" then
    callback(false, "OPENAI_API_KEY environment variable not set")
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

  local payload = vim.json.encode({
    model = config.model,
    messages = {
      {
        role = "system",
        content = "You are a helpful assistant that generates conventional commit messages based on git diffs.",
      },
      {
        role = "user",
        content = prompt,
      },
    },
    max_completion_tokens = config.max_tokens,
  })

  local curl_args = {
    "curl",
    "-X",
    "POST",
    "https://api.openai.com/v1/chat/completions",
    "-H",
    "Content-Type: application/json",
    "-H",
    "Authorization: Bearer " .. api_key,
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
      callback(false, "OpenAI API error: " .. (response.error.message or "Unknown error"))
      return
    end

    vim.notify("ai-commit-msg.nvim: Full API response: " .. vim.inspect(response), vim.log.levels.DEBUG)

    if response.choices and response.choices[1] and response.choices[1].message then
      local commit_msg = response.choices[1].message.content
      commit_msg = commit_msg:gsub("^```%w*\n", ""):gsub("\n```$", ""):gsub("^`", ""):gsub("`$", "")
      commit_msg = vim.trim(commit_msg)
      callback(true, commit_msg)
    else
      callback(false, "Unexpected API response format")
    end
  end)
end

return M