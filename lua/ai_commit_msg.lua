local M = {}

---@class AiCommitMsgConfig
---@field enabled boolean Whether to enable the plugin
---@field provider string AI provider to use ("openai" or "anthropic")
---@field model string Model to use (e.g. "gpt-4o-mini", "claude-3-5-sonnet-20241022")
---@field temperature number Temperature for the model (0.0 to 1.0)
---@field max_tokens number|nil Maximum tokens in the response
---@field prompt string Prompt to send to the AI
---@field system_prompt string System prompt that defines the AI's role and behavior
---@field auto_push_prompt boolean Whether to prompt for push after commit
---@field spinner boolean Whether to show a spinner while generating
---@field notifications boolean Whether to show notifications
---@field keymaps table<string, string|false> Keymaps for commit buffer

---@type AiCommitMsgConfig
local default_config = {
  enabled = true,
  provider = "openai",
  model = "gpt-4.1-nano",
  temperature = 0.3,
  max_tokens = nil,
  prompt = [[Generate a conventional commit message for the staged git changes.

Requirements:
- Use conventional commit format: <type>(<scope>): <description>
- Types: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert
- Keep the first line under 72 characters
- Respond ONLY with the commit message, no explanations or markdown

Git diff of staged changes:
{diff}]],
  system_prompt = "You are a helpful assistant that generates conventional commit messages based on git diffs.",
  auto_push_prompt = true,
  spinner = true,
  notifications = true,
  keymaps = {
    quit = "q", -- Set to false to disable
  },
}

M.config = default_config

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
  require("ai_commit_msg.generator").generate(M.config, callback)
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
