local M = {}

-- Load default configuration from dedicated module
local config_mod = require("ai_commit_msg.config")
M.config = vim.deepcopy(config_mod.default)

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
