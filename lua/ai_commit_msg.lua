local M = {}

-- Default prompts used by all providers
local DEFAULT_PROMPT = [[{diff}]]

-- Load system prompt from external file if available, fallback to default
local function load_system_prompt()
  local system_prompt_path = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h")
    .. "/prompts/system_prompt.md"
  local file = io.open(system_prompt_path, "r")
  if file then
    local content = file:read("*all")
    file:close()
    return content:gsub("\n$", "") -- Remove trailing newline
  end
  return "You are a helpful assistant that generates conventional commit messages based on git diffs."
end

local DEFAULT_SYSTEM_PROMPT = load_system_prompt()

---@class ProviderConfig
---@field model string Model to use for this provider
---@field temperature number Temperature for the model (0.0 to 1.0)
---@field max_tokens number|nil Maximum tokens in the response
---@field prompt string Prompt to send to the AI
---@field system_prompt string System prompt that defines the AI's role and behavior
---@field reasoning_effort string|nil Reasoning effort for models that support it ("minimal", "medium", "high")

---@class AiCommitMsgConfig
---@field enabled boolean Whether to enable the plugin
---@field provider string AI provider to use ("openai" or "anthropic")
---@field providers table<string, ProviderConfig> Provider-specific configurations
---@field auto_push_prompt boolean Whether to prompt for push after commit
---@field spinner boolean Whether to show a spinner while generating
---@field notifications boolean Whether to show notifications
---@field context_lines number Number of surrounding lines to include in git diff
---@field keymaps table<string, string|false> Keymaps for commit buffer

---@type AiCommitMsgConfig
local default_config = {
  enabled = true,
  provider = "openai",
  auto_push_prompt = true,
  spinner = true,
  notifications = true,
  context_lines = 10,
  keymaps = {
    quit = "q", -- Set to false to disable
  },
  providers = {
    openai = {
      model = "gpt-4.1-mini",
      temperature = 0.3,
      max_tokens = nil,
      reasoning_effort = "minimal",
      prompt = DEFAULT_PROMPT,
      system_prompt = DEFAULT_SYSTEM_PROMPT,
    },
    anthropic = {
      model = "claude-3-5-haiku-20241022",
      temperature = 0.3,
      max_tokens = 1000,
      prompt = DEFAULT_PROMPT,
      system_prompt = DEFAULT_SYSTEM_PROMPT,
    },
  },
}

M.config = default_config

-- Get the active provider configuration
function M.get_active_provider_config()
  local provider_name = M.config.provider
  local provider_config = M.config.providers[provider_name]

  if not provider_config then
    error("No configuration found for provider: " .. tostring(provider_name))
  end

  -- Return a merged config with provider-specific settings
  local active_config = vim.tbl_deep_extend("force", {}, provider_config)
  active_config.provider = provider_name

  return active_config
end

---@param opts? AiCommitMsgConfig
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

  vim.notify("ai-commit-msg.nvim: Setup called", vim.log.levels.DEBUG)

  if M.config.enabled then
    require("ai_commit_msg.autocmds").setup(M.config)
    vim.notify("ai-commit-msg.nvim: Autocmds registered", vim.log.levels.DEBUG)
  else
    vim.notify("ai-commit-msg.nvim: Plugin disabled", vim.log.levels.DEBUG)
  end
end

function M.generate_commit_message(callback)
  local active_config = M.get_active_provider_config()
  -- Merge provider-specific config with global settings needed by generator
  local complete_config = vim.tbl_deep_extend("force", active_config, {
    notifications = M.config.notifications,
    spinner = M.config.spinner,
    context_lines = M.config.context_lines,
  })
  require("ai_commit_msg.generator").generate(complete_config, callback)
end

function M.disable()
  M.config.enabled = false
  require("ai_commit_msg.autocmds").disable()
end

function M.enable()
  M.config.enabled = true
  require("ai_commit_msg.autocmds").setup(M.config)
end

return M
