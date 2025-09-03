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
---@field pricing table|nil Pricing information for cost calculation. Supports:
---  - Flat table: { input_per_million, output_per_million } (backwards compatible)
---  - Map keyed by model: { ["model-name"] = { input_per_million, output_per_million }, default = { ... } }

---@class AiCommitMsgConfig
---@field enabled boolean Whether to enable the plugin
---@field provider string AI provider to use ("openai", "anthropic", or "gemini")
---@field providers table<string, ProviderConfig> Provider-specific configurations
---@field auto_push_prompt boolean Whether to prompt for push after commit
---@field spinner boolean Whether to show a spinner while generating
---@field notifications boolean Whether to show notifications
---@field context_lines number Number of surrounding lines to include in git diff
---@field keymaps table<string, string|false> Keymaps for commit buffer
---@field cost_display string|false Cost display format ("compact", "verbose", or false to disable)

---@type AiCommitMsgConfig
M.default = {
  enabled = true,
  provider = "gemini",
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
      model = "gpt-5-nano",
      temperature = 0.3,
      max_tokens = nil,
      reasoning_effort = "minimal",
      prompt = DEFAULT_PROMPT,
      system_prompt = DEFAULT_SYSTEM_PROMPT,
      -- Per-model pricing (you can add more models here)
      pricing = {
        ["gpt-5-nano"] = {
          input_per_million = 0.05,
          output_per_million = 0.4,
        },
        ["gpt-5-mini"] = {
          input_per_million = 0.25,
          output_per_million = 2.00,
        },
        ["gpt-4.1-mini"] = {
          input_per_million = 0.80,
          output_per_million = 3.20,
        },
        ["gpt-4.1-nano"] = {
          input_per_million = 0.20,
          output_per_million = 0.80,
        },
      },
    },
    anthropic = {
      model = "claude-3-5-haiku-20241022",
      temperature = 0.3,
      max_tokens = 2000,
      prompt = DEFAULT_PROMPT,
      system_prompt = DEFAULT_SYSTEM_PROMPT,
      pricing = {
        ["claude-3-5-haiku-20241022"] = {
          input_per_million = 0.80,
          output_per_million = 4.00,
        },
      },
    },
    gemini = {
      model = "gemini-2.5-flash-lite",
      temperature = 0.3,
      max_tokens = 4000,
      reasoning_effort = "none",
      prompt = DEFAULT_PROMPT,
      system_prompt = DEFAULT_SYSTEM_PROMPT,
      pricing = {
        ["gemini-2.5-flash-lite"] = {
          input_per_million = 0.10,
          output_per_million = 0.40,
        },
        ["gemini-2.5-flash"] = {
          input_per_million = 0.30,
          output_per_million = 2.50,
        },
      },
    },
  },
}

return M
