local M = {}

function M.get_provider(config)
  local provider_name = config.provider
  if provider_name == "openai" then
    return require("ai_commit_msg.providers.openai")
  elseif provider_name == "anthropic" then
    return require("ai_commit_msg.providers.anthropic")
  elseif provider_name == "gemini" then
    return require("ai_commit_msg.providers.gemini")
  else
    error("Unsupported provider: " .. tostring(provider_name))
  end
end

function M.call_api(config, diff, callback)
  local provider = M.get_provider(config)
  return provider.call_api(config, diff, callback)
end

return M
