local M = {}
local augroup_name = "ai_commit_msg"
local augroup = nil

function M.setup(config)
  M.disable()

  augroup = vim.api.nvim_create_augroup(augroup_name, { clear = true })

  vim.api.nvim_create_autocmd("BufWinEnter", {
    group = augroup,
    pattern = "COMMIT_EDITMSG",
    callback = function(arg)
      vim.notify("ai-commit-msg.nvim: COMMIT_EDITMSG buffer detected", vim.log.levels.DEBUG)
      
      -- Setup keymaps
      if config.keymaps.quit then
        vim.keymap.set("n", config.keymaps.quit, ":w | bd<CR>", {
          buffer = arg.buf,
          noremap = true,
          silent = true,
          desc = "Write and close commit buffer",
        })
      end

      -- Setup auto push prompt if enabled
      if config.auto_push_prompt then
        -- Store the HEAD commit before potential commit
        local head_before = vim.fn.trim(vim.fn.system("git rev-parse HEAD 2>/dev/null"))
        
        vim.api.nvim_create_autocmd("BufDelete", {
          group = vim.api.nvim_create_augroup(augroup_name .. "_push", { clear = true }),
          buffer = arg.buf,
          callback = function()
            vim.defer_fn(function()
              -- Check if a new commit was actually created
              local head_after = vim.fn.trim(vim.fn.system("git rev-parse HEAD 2>/dev/null"))
              
              -- Only prompt if HEAD changed (meaning a commit was made)
              if head_after ~= head_before and head_after ~= "" then
                local branch_name = vim.fn.trim(vim.fn.system("git rev-parse --abbrev-ref HEAD"))
                local prompt_message = string.format("Push commit to '%s'? (y/N): ", branch_name)
                vim.ui.input({ prompt = prompt_message }, function(input)
                  if input and input:lower() == "y" then
                    vim.cmd("Git push")
                  end
                end)
              else
                vim.notify("ai-commit-msg.nvim: No commit was created (empty message or cancelled)", vim.log.levels.DEBUG)
              end
            end, 100)
          end,
        })
      end

      -- Generate commit message
      require("ai_commit_msg.generator").generate(config, function(success, message)
        if success and message then
          vim.schedule(function()
            local first_line_content = vim.api.nvim_buf_get_lines(arg.buf, 0, 1, false)[1]
            if first_line_content == nil or vim.fn.trim(first_line_content) == "" then
              vim.api.nvim_buf_set_lines(arg.buf, 0, 1, false, vim.split(message, "\n"))
            else
              local comment_prefix = "# "
              local commented_msg_lines = {}
              for _, line in ipairs(vim.split(message, "\n")) do
                table.insert(commented_msg_lines, comment_prefix .. line)
              end
              vim.api.nvim_buf_set_lines(arg.buf, 1, 1, false, { "" })
              vim.api.nvim_buf_set_lines(arg.buf, 2, 2, false, commented_msg_lines)
            end
          end)
        else
        end
      end)
    end,
  })
end

function M.disable()
  if augroup then
    vim.api.nvim_del_augroup_by_id(augroup)
    augroup = nil
  end

  local push_group_exists, push_group = pcall(vim.api.nvim_get_autocmds, {
    group = augroup_name .. "_push",
  })
  if push_group_exists and #push_group > 0 then
    pcall(vim.api.nvim_del_augroup_by_name, augroup_name .. "_push")
  end
end

return M
