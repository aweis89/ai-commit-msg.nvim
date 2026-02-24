local M = {}
local augroup_name = "ai_commit_msg"
local augroup = nil
local cfg_notify = require("ai_commit_msg.config").notify

function M.setup(config)
  augroup = vim.api.nvim_create_augroup(augroup_name, { clear = true })

  vim.api.nvim_create_autocmd("FileType", {
    group = augroup,
    pattern = "gitcommit",
    callback = function(arg)
      cfg_notify("ai-commit-msg.nvim: gitcommit buffer detected", vim.log.levels.DEBUG)

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
              if head_after == head_before or head_after == "" then
                cfg_notify(
                  "ai-commit-msg.nvim: No commit was created (empty message or cancelled)",
                  vim.log.levels.DEBUG
                )
                return
              end
              local branch_name = vim.fn.trim(vim.fn.system("git rev-parse --abbrev-ref HEAD"))
              local prompt_message = string.format("Push commit to '%s'? (y/N): ", branch_name)
              vim.ui.input({ prompt = prompt_message }, function(input)
                if input and input:lower() == "y" then
                  local pull_cfg = type(config.pull_before_push) == "table" and config.pull_before_push
                    or { enabled = true, args = { "--rebase", "--autostash" } }
                  local pull_enabled = (pull_cfg.enabled ~= false)
                  local pull_args = type(pull_cfg.args) == "table" and pull_cfg.args or { "--rebase", "--autostash" }

                  local function do_push()
                    vim.cmd.tabnew()
                    local term_buf = vim.api.nvim_get_current_buf()
                    vim.fn.termopen("git push", {
                      on_exit = function(_, exit_code, _)
                        if exit_code == 0 then
                          vim.schedule(function()
                            vim.api.nvim_buf_delete(term_buf, { force = true })
                            cfg_notify("Push successful", vim.log.levels.INFO)
                          end)
                        else
                          vim.schedule(function()
                            cfg_notify("Push failed - check terminal for details", vim.log.levels.ERROR)
                          end)
                        end
                      end,
                    })
                    vim.cmd.startinsert()
                  end

                  if pull_enabled then
                    cfg_notify("Pulling latest changes before push...", vim.log.levels.INFO)
                    local cmd = { "git", "pull" }
                    for _, a in ipairs(pull_args) do
                      table.insert(cmd, a)
                    end
                    vim.system(cmd, {}, function(pull_obj)
                      vim.schedule(function()
                        if pull_obj.code == 0 then
                          do_push()
                        else
                          local err = pull_obj.stderr or pull_obj.stdout or "git pull failed"
                          cfg_notify("git pull failed; aborting push: " .. vim.fn.trim(err), vim.log.levels.ERROR)
                        end
                      end)
                    end)
                  else
                    do_push()
                  end
                end
              end)
            end, 100)
          end,
        })
      end

      -- Generate commit message
      require("ai_commit_msg").generate_commit_message(function(success, message)
        if success and message then
          vim.schedule(function()
            local first_line_content = vim.api.nvim_buf_get_lines(arg.buf, 0, 1, false)[1]
            if first_line_content == nil or vim.fn.trim(first_line_content) == "" then
              -- Empty commit: replace the first line with the generated message
              vim.api.nvim_buf_set_lines(arg.buf, 0, 1, false, vim.split(message, "\n"))
            else
              -- Non-empty commit present: append the generated message as commented
              -- lines directly below the current commit message (before git's
              -- template comments), handling multi-line commit bodies.

              -- Gather current buffer lines
              local lines = vim.api.nvim_buf_get_lines(arg.buf, 0, -1, false)

              -- Find the first line that starts a comment block (e.g. git template)
              local insert_row0 = #lines -- default to end of buffer (0-based)
              for i = 1, #lines do
                local l = lines[i]
                if type(l) == "string" and l:sub(1, 1) == "#" then
                  insert_row0 = i - 1
                  break
                end
              end

              -- Prepare commented version of the generated message
              local comment_prefix = "# "
              local commented_msg_lines = {}
              for _, line in ipairs(vim.split(message, "\n")) do
                table.insert(commented_msg_lines, comment_prefix .. line)
              end

              -- Insert a single blank line before the commented block if the line
              -- directly above the insertion point isn't already blank.
              local to_insert = {}
              if insert_row0 > 0 then
                local prev = lines[insert_row0] -- 1-based table index for row-1
                if prev ~= nil and vim.fn.trim(prev) ~= "" then
                  table.insert(to_insert, "")
                end
              else
                -- Inserting at top (edge case): add a blank line to avoid touching
                -- user's first line directly.
                table.insert(to_insert, "")
              end

              -- Add the commented message lines
              vim.list_extend(to_insert, commented_msg_lines)

              -- Perform a single insertion at the computed position
              vim.api.nvim_buf_set_lines(arg.buf, insert_row0, insert_row0, false, to_insert)
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

  pcall(vim.api.nvim_del_augroup_by_name, augroup_name .. "_push")
end

return M
