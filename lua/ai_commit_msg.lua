local M = {}

-- Default prompts used by all providers
local DEFAULT_PROMPT = [[{diff}]]
local DEFAULT_SYSTEM_PROMPT = require("ai_commit_msg.prompts").DEFAULT_SYSTEM_PROMPT

---@class ProviderConfig
---@field model string Model to use for this provider
---@field temperature number Temperature for the model (0.0 to 1.0)
---@field max_tokens number|nil Maximum tokens in the response
---@field prompt string Prompt to send to the AI
---@field system_prompt string System prompt that defines the AI's role and behavior
---@field reasoning_effort string|nil Reasoning effort for models that support it ("minimal", "medium", "high")
---@field pricing table|nil Pricing information for cost calculation
---@field pricing.input_per_million number Cost per million input tokens
---@field pricing.output_per_million number Cost per million output tokens

---@class AiCommitMsgConfig
---@field enabled boolean Whether to enable the plugin
---@field provider string AI provider to use ("openai" or "anthropic")
---@field providers table<string, ProviderConfig> Provider-specific configurations
---@field auto_push_prompt boolean Whether to prompt for push after commit
---@field spinner boolean Whether to show a spinner while generating
---@field notifications boolean Whether to show notifications
---@field context_lines number Number of surrounding lines to include in git diff
---@field keymaps table<string, string|false> Keymaps for commit buffer
---@field cost_display string|false Cost display format ("compact", "verbose", or false to disable)

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
  cost_display = "compact", -- "compact", "verbose", or false
  providers = {
    openai = {
      model = "gpt-4.1-mini",
      temperature = 0.3,
      max_tokens = nil,
      reasoning_effort = "minimal",
      prompt = DEFAULT_PROMPT,
      system_prompt = DEFAULT_SYSTEM_PROMPT,
      pricing = {
        input_per_million = 0.40,
        output_per_million = 1.60,
      },
    },
    anthropic = {
      model = "claude-3-5-haiku-20241022",
      temperature = 0.3,
      max_tokens = 1000,
      prompt = DEFAULT_PROMPT,
      system_prompt = DEFAULT_SYSTEM_PROMPT,
      pricing = {
        input_per_million = 0.80,
        output_per_million = 4.00,
      },
    },
  },
}

M.config = default_config

-- Calculate cost from token usage and provider pricing
function M.calculate_cost(usage, config)
  if not usage or not config.pricing then
    return nil
  end
  
  local input_cost = (usage.input_tokens / 1000000) * config.pricing.input_per_million
  local output_cost = (usage.output_tokens / 1000000) * config.pricing.output_per_million
  local total_cost = input_cost + output_cost
  
  return {
    input_tokens = usage.input_tokens,
    output_tokens = usage.output_tokens,
    input_cost = input_cost,
    output_cost = output_cost,
    total_cost = total_cost,
  }
end

-- Format cost information for display
function M.format_cost(cost_info, format)
  if not cost_info or format == false then
    return ""
  end
  
  if format == "verbose" then
    return string.format(
      "%d in $%.4f, %d out $%.4f, total $%.4f",
      cost_info.input_tokens,
      cost_info.input_cost,
      cost_info.output_tokens,
      cost_info.output_cost,
      cost_info.total_cost
    )
  else -- compact format (default)
    return string.format("$%.4f", cost_info.total_cost)
  end
end

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
    cost_display = M.config.cost_display,
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
