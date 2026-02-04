local M = {}
local EDITOR_VERSION = "Neovim/" .. vim.version().major .. "." .. vim.version().minor .. "." .. vim.version().patch

-- Models that support reasoning_effort parameter
local REASONING_EFFORT_MODELS = {
  ["gpt-5-nano"] = true,
  ["gpt-5-mini"] = true,
  ["gpt-5"] = true,
}

-- Cache for OAuth and Copilot tokens
local _oauth_token = nil
local _copilot_token = nil
local _copilot_endpoints = nil
local _token_fetch_in_progress = false

local function model_supports_reasoning_effort(model)
  return REASONING_EFFORT_MODELS[model] or model:match("^gpt%-5")
end

-- Find the configuration path for GitHub Copilot
local function find_config_path()
  local path = os.getenv("XDG_CONFIG_HOME")
  if path and vim.uv.fs_stat(path) then
    return path
  end

  local home = os.getenv("HOME") or os.getenv("USERPROFILE")
  if not home then
    return nil
  end

  if vim.fn.has("win32") == 1 then
    path = home .. "/AppData/Local"
    if vim.uv.fs_stat(path) then
      return path
    end
  else
    path = home .. "/.config"
    if vim.uv.fs_stat(path) then
      return path
    end
  end
  return nil
end

-- Get OAuth token from environment or config files
local function get_oauth_token()
  if _oauth_token then
    return _oauth_token
  end

  -- Check for GitHub Codespaces environment
  local token = os.getenv("GITHUB_TOKEN")
  local codespaces = os.getenv("CODESPACES")
  if token and codespaces then
    _oauth_token = token
    return _oauth_token
  end

  -- Look for token in config files
  local config_path = find_config_path()
  if not config_path then
    return nil
  end

  local file_paths = {
    config_path .. "/github-copilot/hosts.json",
    config_path .. "/github-copilot/apps.json",
  }

  for _, file_path in ipairs(file_paths) do
    local stat = vim.uv.fs_stat(file_path)
    if stat and stat.type == "file" then
      local fd = vim.uv.fs_open(file_path, "r", 438)
      if fd then
        local stat_result = vim.uv.fs_fstat(fd)
        if stat_result then
          local content = vim.uv.fs_read(fd, stat_result.size, 0)
          vim.uv.fs_close(fd)

          if content then
            local ok_decode, data = pcall(vim.json.decode, content)
            if ok_decode and type(data) == "table" then
              for key, value in pairs(data) do
                if key:find("github.com") and type(value) == "table" and value.oauth_token then
                  _oauth_token = value.oauth_token
                  return _oauth_token
                end
              end
            end
          end
        else
          vim.uv.fs_close(fd)
        end
      end
    end
  end

  return nil
end

-- Exchange OAuth token for Copilot token
local function get_copilot_token(callback)
  -- Check if we have a valid cached token
  if _copilot_token and _copilot_token.expires_at and _copilot_token.expires_at > os.time() then
    callback(true, _copilot_token.token, _copilot_endpoints)
    return
  end

  -- Wait if another fetch is in progress
  if _token_fetch_in_progress then
    local max_wait = 100 -- 5 seconds (100 * 50ms)
    local waited = 0
    vim.wait(50, function()
      waited = waited + 1
      if waited >= max_wait then
        return true
      end
      return _copilot_token ~= nil and _copilot_token.expires_at ~= nil and _copilot_token.expires_at > os.time()
    end, 50)

    if _copilot_token and _copilot_token.expires_at and _copilot_token.expires_at > os.time() then
      callback(true, _copilot_token.token, _copilot_endpoints)
      return
    end
  end

  _token_fetch_in_progress = true

  local oauth_token = _oauth_token
  if not oauth_token then
    _token_fetch_in_progress = false
    callback(false, "No OAuth token found")
    return
  end

  local curl_args = {
    "curl",
    "-X",
    "GET",
    "https://api.github.com/copilot_internal/v2/token",
    "-H",
    "Authorization: Bearer " .. oauth_token,
    "-H",
    "Accept: application/json",
    "--silent",
    "--show-error",
  }

  vim.system(curl_args, {}, function(res)
    _token_fetch_in_progress = false

    if res.code ~= 0 then
      callback(false, "Failed to get Copilot token: " .. (res.stderr or "Unknown error"))
      return
    end

    local ok, token_data = pcall(vim.json.decode, res.stdout)
    if not ok or type(token_data) ~= "table" then
      callback(false, "Failed to parse Copilot token response")
      return
    end

    _copilot_token = token_data
    _copilot_endpoints = token_data.endpoints
    callback(true, token_data.token, token_data.endpoints)
  end)
end

-- Copilot provider using GitHub Models API chat completions
function M.call_api(config, diff, callback)
  -- First try COPILOT_TOKEN env var
  local env_token = os.getenv("COPILOT_TOKEN")

  if env_token and env_token ~= "" then
    M._make_api_call(env_token, nil, config, diff, callback)
    return
  end

  -- Fallback to OAuth token mechanism
  local oauth_token = get_oauth_token()
  if not oauth_token then
    callback(false, "No Copilot token found. Set COPILOT_TOKEN env var or authenticate with GitHub Copilot")
    return
  end

  get_copilot_token(function(success, token, endpoints)
    if not success then
      callback(false, token) -- token contains error message here
      return
    end

    M._make_api_call(token, endpoints, config, diff, callback)
  end)
end

-- Internal function to make the actual API call
function M._make_api_call(token, endpoints, config, diff, callback)
  if not token or token == "" then
    callback(false, "Invalid Copilot token")
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

  -- Use endpoint from Copilot token if available, otherwise use default
  local api_url = "https://models.github.ai/inference/chat/completions"
  if endpoints and endpoints.api then
    api_url = endpoints.api .. "/chat/completions"
  end

  local curl_args = {
    "curl",
    "-X",
    "POST",
    api_url,
    "-H",
    "Content-Type: application/json",
    "-H",
    "Authorization: Bearer " .. token,
    "-H",
    "Editor-Version: " .. EDITOR_VERSION,
    "-H",
    "Editor-Plugin-Version: ai-commit-msg.nvim/*",
    "-H",
    "Copilot-Integration-Id: vscode-chat",
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
      if response.usage and type(response.usage) == "table" then
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
    if response.usage and type(response.usage) == "table" then
      usage = {
        input_tokens = response.usage.prompt_tokens or response.usage.input_tokens,
        output_tokens = response.usage.completion_tokens or response.usage.output_tokens,
      }
    end

    callback(true, commit_msg, usage)
  end)
end

return M
