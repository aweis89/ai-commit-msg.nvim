local M = {}

function M.get_provider(config)
  if config.provider == "openai" then
    return require("ai_commit_msg.providers.openai")
  elseif config.provider == "anthropic" then
    return require("ai_commit_msg.providers.anthropic")
  else
    error("Unsupported provider: " .. tostring(config.provider))
  end
end

function M.call_api(config, diff, callback)
  local provider = M.get_provider(config)
  return provider.call_api(config, diff, callback)
end

return M