local M = {}

---@class AiCommitMsgConfig
---@field enabled boolean Whether to enable the plugin
---@field model string OpenAI model to use (e.g. "gpt-4o-mini", "gpt-4o", "gpt-3.5-turbo")
---@field temperature number Temperature for the model (0.0 to 1.0)
---@field max_tokens number Maximum tokens in the response
---@field prompt string Prompt to send to the AI
---@field auto_push_prompt boolean Whether to prompt for push after commit
---@field spinner boolean Whether to show a spinner while generating
---@field notifications boolean Whether to show notifications
---@field keymaps table<string, string|false> Keymaps for commit buffer

---@type AiCommitMsgConfig
local default_config = {
  enabled = true,
  model = "gpt-4o-mini",
  temperature = 0.3,
  max_tokens = 500,
  prompt = [[Generate a conventional commit message for the staged git changes.

Requirements:
- Use conventional commit format: <type>(<scope>): <description>
- Types: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert
- Keep the first line under 72 characters
- Respond ONLY with the commit message, no explanations or markdown

Git diff of staged changes:
{diff}]],
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
