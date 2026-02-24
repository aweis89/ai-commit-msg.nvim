local M = {}

-- Models that support reasoning_effort parameter
local REASONING_EFFORT_MODELS = {
  ["gpt-5-nano"] = true,
  ["gpt-5-mini"] = true,
  ["gpt-5"] = true,
}

local function model_supports_reasoning_effort(model)
  return REASONING_EFFORT_MODELS[model] or model:match("^gpt%-5")
end

function M.call_api(config, diff, callback)
  local api_key = os.getenv("OPENAI_API_KEY")
  if not api_key or api_key == "" then
    callback(false, "OPENAI_API_KEY environment variable not set")
    return
  end

  if not config.prompt then
    callback(false, "No prompt configured for OpenAI provider")
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
    require("ai_commit_msg.config").notify("ai-commit-msg.nvim: Prompt length: " .. #prompt .. " chars", vim.log.levels.DEBUG)
  end)

  local payload_data = {
    model = config.model,
    n = 1, -- ensure only one choice is generated
    messages = {
      {
        role = "system",
        content = config.system_prompt,
      },
      {
        role = "user",
        content = prompt,
      },
    },
  }

  -- Only add max_completion_tokens if explicitly set
  if config.max_tokens then
    payload_data.max_completion_tokens = config.max_tokens
  end

  -- Only add reasoning_effort for gpt-5 models that support it
  if config.reasoning_effort and config.model and model_supports_reasoning_effort(config.model) then
    payload_data.reasoning_effort = config.reasoning_effort
  end

  local payload = vim.json.encode(payload_data)

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

    vim.schedule(function()
      require("ai_commit_msg.config").notify("ai-commit-msg.nvim: Full API response: " .. vim.inspect(response), vim.log.levels.DEBUG)
    end)

    if response.choices and response.choices[1] and response.choices[1].message then
      local commit_msg = response.choices[1].message.content
      commit_msg = commit_msg:gsub("^```%w*\n", ""):gsub("\n```$", ""):gsub("^`", ""):gsub("`$", "")
      commit_msg = vim.trim(commit_msg)

      -- Extract token usage if available
      local usage = nil
      if response.usage then
        usage = {
          input_tokens = response.usage.prompt_tokens,
          output_tokens = response.usage.completion_tokens,
        }
      end

      callback(true, commit_msg, usage)
    else
      callback(false, "Unexpected API response format")
    end
  end)
end

return M
