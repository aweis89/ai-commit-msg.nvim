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

-- Copilot provider using GitHub Models API chat completions
-- Reads token from `config.token` (no env var usage)
function M.call_api(config, diff, callback)
  local token = os.getenv("COPILOT_TOKEN")
  if not token or token == "" then
    callback(false, "Copilot token not set in config")
    return
  end

  if not config.prompt then
    callback(false, "No prompt configured for Copilot provider")
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
    vim.notify("ai-commit-msg.nvim: Copilot prompt length: " .. #prompt .. " chars", vim.log.levels.DEBUG)
  end)

  local payload_data = {
    model = config.model,
    messages = {
      { role = "system", content = config.system_prompt },
      { role = "user", content = prompt },
    },
    n = 1,
  }

  -- Only add max_completion_tokens if explicitly set
  if config.max_tokens then
    payload_data.max_completion_tokens = config.max_tokens
  end

  -- Some Copilot (GitHub) gpt-5* models do not accept a custom `temperature` field.
  -- Only include `temperature` when the configured model is not a gpt-5 variant.
  if not (config.model and config.model:match("^gpt%-5")) then
    payload_data.temperature = config.temperature
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
    "https://models.github.ai/inference/chat/completions",
    "-H",
    "Content-Type: application/json",
    "-H",
    "Authorization: Bearer " .. token,
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
      callback(false, "Copilot API error: " .. (response.error.message or "Unknown error"))
      return
    end

    -- Expect chat-style choices[1].message.content
    if response.choices and response.choices[1] and response.choices[1].message then
      local commit_msg = response.choices[1].message.content
      commit_msg = commit_msg:gsub("^```%w*\n", ""):gsub("\n```$", ""):gsub("^`", ""):gsub("`$", "")
      commit_msg = vim.trim(commit_msg)

      local usage = nil
      if response.usage then
        usage = {
          input_tokens = response.usage.prompt_tokens or response.usage.input_tokens,
          output_tokens = response.usage.completion_tokens or response.usage.output_tokens,
        }
      end

      callback(true, commit_msg, usage)
      return
    end

    -- Fallback: try other common shapes
    local commit_msg = nil
    if response.choices and response.choices[1] and response.choices[1].text then
      commit_msg = response.choices[1].text
    elseif response.result and response.result[1] and response.result[1].content then
      commit_msg = response.result[1].content
    end

    if not commit_msg then
      callback(false, "Unexpected Copilot response format")
      return
    end

    commit_msg = commit_msg:gsub("^```%w*\n", ""):gsub("\n```$", ""):gsub("^`", ""):gsub("`$", "")
    commit_msg = vim.trim(commit_msg)

    local usage = nil
    if response.usage then
      usage = {
        input_tokens = response.usage.prompt_tokens or response.usage.input_tokens,
        output_tokens = response.usage.completion_tokens or response.usage.output_tokens,
      }
    end

    callback(true, commit_msg, usage)
  end)
end

return M
