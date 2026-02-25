-- Minimal vim mock for running outside nvim
if not rawget(_G, "vim") then
  _G.vim = {
    fn = { executable = function() return 1 end },
    system = function() end,
    schedule = function(fn) fn() end,
    json = {
      encode = function(t) return require("dkjson").encode(t) end,
      decode = function(s) return require("dkjson").decode(s) end,
    },
    trim = function(s) return s:match("^%s*(.-)%s*$") end,
    inspect = function(t) return tostring(t) end,
    log = { levels = { DEBUG = 1, INFO = 2, WARN = 3, ERROR = 4 } },
  }
end

describe("claude_code provider", function()
  local claude_code_provider
  local original_executable = vim.fn.executable
  local original_vim_system = vim.system

  local default_config = {
    model = "sonnet",
    prompt = "{diff}",
    system_prompt = "Generate a commit message",
  }

  local function mock_cli_response(response)
    vim.system = function(cmd, opts, callback)
      callback({
        code = 0,
        stdout = type(response) == "string" and response or vim.json.encode(response),
      })
      return cmd
    end
  end

  before_each(function()
    package.loaded["ai_commit_msg.providers.claude_code"] = nil
    package.loaded["ai_commit_msg.config"] = nil
    package.preload["ai_commit_msg.config"] = function()
      return { notify = function() end }
    end
    claude_code_provider = require("ai_commit_msg.providers.claude_code")
    vim.fn.executable = function() return 1 end
  end)

  after_each(function()
    vim.fn.executable = original_executable
    vim.system = original_vim_system
  end)

  describe("call_api", function()
    it("calls callback with error when claude CLI not found", function()
      vim.fn.executable = function() return 0 end

      local result_success, result_message
      claude_code_provider.call_api({}, "test diff", function(success, message)
        result_success = success
        result_message = message
      end)

      assert.is_false(result_success)
      assert.truthy(result_message:find("claude CLI not found"))
    end)

    it("passes model flag from config", function()
      local captured_cmd
      vim.system = function(cmd, opts, callback)
        captured_cmd = cmd
        callback({
          code = 0,
          stdout = '{"type":"result","is_error":false,"result":"feat: test commit","usage":{"input_tokens":10,"output_tokens":5}}',
        })
      end

      claude_code_provider.call_api(default_config, "test diff", function() end)

      local found_model = false
      for i, arg in ipairs(captured_cmd) do
        if arg == "--model" and captured_cmd[i + 1] == "sonnet" then
          found_model = true
          break
        end
      end
      assert.is_true(found_model)
    end)

    it("pipes prompt via stdin and system prompt via flag", function()
      local captured_cmd, captured_opts
      vim.system = function(cmd, opts, callback)
        captured_cmd = cmd
        captured_opts = opts
        callback({
          code = 0,
          stdout = '{"type":"result","is_error":false,"result":"feat: test commit","usage":{"input_tokens":10,"output_tokens":5}}',
        })
      end

      local config = { model = "haiku", prompt = "{diff}", system_prompt = "Generate a commit message" }
      claude_code_provider.call_api(config, "my test diff", function() end)

      assert.truthy(captured_opts.stdin)
      assert.truthy(captured_opts.stdin:find("my test diff"))

      local found_system_prompt = false
      for i, arg in ipairs(captured_cmd) do
        if arg == "--system-prompt" and captured_cmd[i + 1] == "Generate a commit message" then
          found_system_prompt = true
          break
        end
      end
      assert.is_true(found_system_prompt)
    end)

    it("parses successful response and extracts usage", function()
      mock_cli_response({
        type = "result",
        is_error = false,
        result = "feat: add new feature",
        usage = {
          input_tokens = 100,
          cache_creation_input_tokens = 50,
          cache_read_input_tokens = 200,
          output_tokens = 20,
        },
      })

      local result_success, result_message, result_usage
      local config = { model = "haiku", prompt = "{diff}", system_prompt = "test" }
      claude_code_provider.call_api(config, "test diff", function(success, message, usage)
        result_success = success
        result_message = message
        result_usage = usage
      end)

      assert.is_true(result_success)
      assert.equals("feat: add new feature", result_message)
      assert.equals(350, result_usage.input_tokens) -- 100 + 50 + 200
      assert.equals(20, result_usage.output_tokens)
    end)

    it("handles error response from claude CLI", function()
      mock_cli_response('{"type":"result","is_error":true,"result":"Something went wrong"}')

      local result_success, result_message
      local config = { model = "haiku", prompt = "{diff}", system_prompt = "test" }
      claude_code_provider.call_api(config, "test diff", function(success, message)
        result_success = success
        result_message = message
      end)

      assert.is_false(result_success)
      assert.truthy(result_message:find("Something went wrong"))
    end)
  end)
end)
