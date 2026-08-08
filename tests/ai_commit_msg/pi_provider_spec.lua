describe("pi provider", function()
  local pi_provider
  local original_schedule
  local original_system
  local original_writefile

  before_each(function()
    package.loaded["ai_commit_msg.providers.pi"] = nil
    pi_provider = require("ai_commit_msg.providers.pi")
    original_schedule = vim.schedule
    original_system = vim.system
    original_writefile = vim.fn.writefile
  end)

  after_each(function()
    vim.schedule = original_schedule
    vim.system = original_system
    vim.fn.writefile = original_writefile
  end)

  it("passes the prompt to Pi over stdin and logs its model selection", function()
    local captured_command
    local captured_options
    local log_flags
    local log_lines
    local log_path
    local scheduled_log
    vim.fn.writefile = function(lines, path, flags)
      log_flags = flags
      log_lines = lines
      log_path = path
    end
    vim.schedule = function(callback)
      scheduled_log = callback
    end
    vim.system = function(command, options, callback)
      captured_command = command
      captured_options = options
      callback({ code = 0, stdout = "feat(cli): add pi provider\n", stderr = "" })
    end

    local success, message
    pi_provider.call_api(
      {
        executable = "nvim",
        cli_provider = "github-copilot",
        model = "gpt-5-mini",
        thinking = "low",
        args = { "--offline" },
        prompt = "Changes:\n{diff}",
        system_prompt = "Return one commit message.",
      },
      "+new line",
      function(result_success, result_message)
        success = result_success
        message = result_message
      end
    )

    assert.is_true(success)
    assert.equals("feat(cli): add pi provider", message)
    assert.same({
      "nvim",
      "--print",
      "--no-session",
      "--no-tools",
      "--no-approve",
      "--no-context-files",
      "--no-skills",
      "--no-prompt-templates",
      "--system-prompt",
      "Return one commit message.",
      "--provider",
      "github-copilot",
      "--model",
      "gpt-5-mini",
      "--thinking",
      "low",
      "--offline",
    }, captured_command)
    assert.equals("Changes:\n+new line", captured_options.stdin)
    assert.is_true(captured_options.text)
    assert.equals(
      "ai-commit-msg.nvim: Pi CLI selection: model=gpt-5-mini, provider=github-copilot, thinking=low",
      pi_provider.last_selection
    )
    assert.is_nil(log_lines)
    assert.is_function(scheduled_log)
    scheduled_log()
    assert.same({ pi_provider.last_selection }, log_lines)
    assert.equals(vim.fn.stdpath("state") .. "/ai-commit-msg.log", log_path)
    assert.equals("a", log_flags)
  end)

  it("reports Pi process failures", function()
    vim.system = function(_, _, callback)
      callback({ code = 1, stdout = "", stderr = "authentication required\n" })
    end

    local success, message
    pi_provider.call_api(
      {
        executable = "nvim",
        prompt = "{diff}",
        system_prompt = "Return one commit message.",
      },
      "+new line",
      function(result_success, result_message)
        success = result_success
        message = result_message
      end
    )

    assert.is_false(success)
    assert.equals("Pi CLI failed: authentication required", message)
  end)

  it("rejects empty responses", function()
    vim.system = function(_, _, callback)
      callback({ code = 0, stdout = "\n", stderr = "" })
    end

    local success, message
    pi_provider.call_api(
      {
        executable = "nvim",
        prompt = "{diff}",
        system_prompt = "Return one commit message.",
      },
      "+new line",
      function(result_success, result_message)
        success = result_success
        message = result_message
      end
    )

    assert.is_false(success)
    assert.equals("Pi CLI returned an empty response", message)
  end)
end)
