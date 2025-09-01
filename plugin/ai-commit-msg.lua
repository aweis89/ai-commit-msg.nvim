if vim.fn.has("nvim-0.7.0") == 0 then
  vim.api.nvim_err_writeln("ai-commit-msg.nvim requires at least nvim-0.7.0")
  return
end

if vim.g.loaded_ai_commit_msg == 1 then
  return
end
vim.g.loaded_ai_commit_msg = 1

vim.notify("ai-commit-msg.nvim: Plugin loaded", vim.log.levels.DEBUG)

-- Create user commands
vim.api.nvim_create_user_command("AiCommitMsg", function()
  require("ai_commit_msg").generate_commit_message(function(success, message)
    if success then
      print(message)
    end
  end)
end, { desc = "Generate AI commit message" })

vim.api.nvim_create_user_command("AiCommitMsgDisable", function()
  require("ai_commit_msg").disable()
  vim.notify("AI Commit Message disabled")
end, { desc = "Disable AI commit message generation" })

vim.api.nvim_create_user_command("AiCommitMsgEnable", function()
  require("ai_commit_msg").enable()
  vim.notify("AI Commit Message enabled")
end, { desc = "Enable AI commit message generation" })

vim.api.nvim_create_user_command("AiCommitMsgDebug", function()
  local plugin = require("ai_commit_msg")
  vim.notify("Plugin config: " .. vim.inspect(plugin.config), vim.log.levels.INFO)

  -- Check if autocmds are registered
  local autocmds = vim.api.nvim_get_autocmds({ group = "ai_commit_msg" })
  if #autocmds > 0 then
    vim.notify("Autocmds registered: " .. vim.inspect(autocmds), vim.log.levels.INFO)
  else
    vim.notify("No autocmds registered!", vim.log.levels.WARN)
  end
end, { desc = "Debug AI commit message plugin" })
