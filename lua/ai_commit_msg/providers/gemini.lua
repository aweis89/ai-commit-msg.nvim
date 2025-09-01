local M = {}

function M.call_api(config, diff, callback)
  local api_key = os.getenv("GEMINI_API_KEY")
  if not api_key or api_key == "" then
    callback(false, "GEMINI_API_KEY environment variable not set")
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
    contents = {
      {
        parts = {
          {
            text = config.system_prompt .. "\n\n" .. prompt,
          },
        },
      },
    },
    generationConfig = {
      maxOutputTokens = max_tokens,
      temperature = config.temperature or 0.3,
    },
  })

  local curl_args = {
    "curl",
    "-X",
    "POST",
    "https://generativelanguage.googleapis.com/v1beta/models/" .. config.model .. ":generateContent?key=" .. api_key,
    "-H",
    "Content-Type: application/json",
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
      callback(false, "Gemini API error: " .. (response.error.message or "Unknown error"))
      return
    end

    vim.notify("ai-commit-msg.nvim: Full API response: " .. vim.inspect(response), vim.log.levels.DEBUG)

    if
      response.candidates
      and response.candidates[1]
      and response.candidates[1].content
      and response.candidates[1].content.parts
      and response.candidates[1].content.parts[1]
    then
      local commit_msg = response.candidates[1].content.parts[1].text
      commit_msg = commit_msg:gsub("^```%w*\n", ""):gsub("\n```$", ""):gsub("^`", ""):gsub("`$", "")
      commit_msg = vim.trim(commit_msg)

      -- Extract token usage if available
      local usage = nil
      if response.usageMetadata then
        usage = {
          input_tokens = response.usageMetadata.promptTokenCount or 0,
          output_tokens = response.usageMetadata.candidatesTokenCount or 0,
        }
      end

      callback(true, commit_msg, usage)
    else
      callback(false, "Unexpected API response format")
    end
  end)
end

return M
