local M = {}

local function build_prompt(config, diff)
  if not config.prompt then
    return nil
  end

  if config.prompt:find("{diff}", 1, true) then
    local before, after = config.prompt:match("^(.*)%{diff%}(.*)$")
    if before and after then
      return before .. diff .. after
    end
  end

  return config.prompt .. "\n\n" .. diff
end

local function strip_code_fence(message)
  return message:gsub("^```%w*\n", ""):gsub("\n```$", ""):gsub("^`", ""):gsub("`$", "")
end

function M.call_api(config, diff, callback)
  local prompt = build_prompt(config, diff)
  if not prompt then
    callback(false, "No prompt configured for Pi provider")
    return
  end

  local executable = config.executable or "pi"
  if vim.fn.executable(executable) ~= 1 then
    callback(false, "Pi executable not found: " .. executable)
    return
  end

  local command = {
    executable,
    "--print",
    "--no-session",
    "--no-tools",
    "--no-approve",
    "--no-context-files",
    "--no-skills",
    "--no-prompt-templates",
    "--system-prompt",
    config.system_prompt,
  }

  if config.cli_provider and config.cli_provider ~= "" then
    vim.list_extend(command, { "--provider", config.cli_provider })
  end
  if config.model and config.model ~= "" then
    vim.list_extend(command, { "--model", config.model })
  end
  if config.thinking and config.thinking ~= "" then
    vim.list_extend(command, { "--thinking", config.thinking })
  end
  if config.args then
    vim.list_extend(command, config.args)
  end

  vim.system(command, { stdin = prompt, text = true }, function(result)
    if result.code ~= 0 then
      local error_message = vim.trim(result.stderr or "")
      if error_message == "" then
        error_message = "Pi exited with code " .. tostring(result.code)
      end
      callback(false, "Pi CLI failed: " .. error_message)
      return
    end

    local commit_message = vim.trim(strip_code_fence(result.stdout or ""))
    if commit_message == "" then
      callback(false, "Pi CLI returned an empty response")
      return
    end

    callback(true, commit_message)
  end)
end

return M
