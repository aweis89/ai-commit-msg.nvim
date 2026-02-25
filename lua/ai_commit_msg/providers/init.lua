local M = {}

local PROVIDERS = {
  openai = "ai_commit_msg.providers.openai",
  anthropic = "ai_commit_msg.providers.anthropic",
  gemini = "ai_commit_msg.providers.gemini",
  copilot = "ai_commit_msg.providers.copilot",
  claude_code = "ai_commit_msg.providers.claude_code",
}

function M.get_provider(config)
  local module = PROVIDERS[config.provider]
  if not module then
    error("Unsupported provider: " .. tostring(config.provider))
  end
  return require(module)
end

function M.call_api(config, diff, callback)
  local provider = M.get_provider(config)
  return provider.call_api(config, diff, callback)
end

return M
