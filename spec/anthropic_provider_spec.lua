describe("anthropic provider", function()
  local anthropic_provider

  before_each(function()
    anthropic_provider = require("ai_commit_msg.providers.anthropic")
  end)

  describe("call_api", function()
    it("calls callback with error when ANTHROPIC_API_KEY not set", function()
      -- Mock environment
      local original_getenv = os.getenv
      os.getenv = function(key)
        if key == "ANTHROPIC_API_KEY" then
          return nil
        end
        return original_getenv(key)
      end

      local callback_called = false
      local result_success, result_message

      anthropic_provider.call_api({}, "test diff", function(success, message)
        callback_called = true
        result_success = success
        result_message = message
      end)

      assert.is_true(callback_called)
      assert.is_false(result_success)
      assert.equals("ANTHROPIC_API_KEY environment variable not set", result_message)

      -- Restore environment
      os.getenv = original_getenv
    end)

    it("uses default max_tokens when not configured", function()
      -- Mock environment with API key
      local original_getenv = os.getenv
      os.getenv = function(key)
        if key == "ANTHROPIC_API_KEY" then
          return "test-key"
        end
        return original_getenv(key)
      end

      -- Mock vim.system to capture the payload
      local captured_payload
      local original_vim_system = vim.system
      vim.system = function(args, opts, callback)
        -- Find the payload in the curl args
        for i, arg in ipairs(args) do
          if arg == "-d" and args[i + 1] then
            captured_payload = args[i + 1]
            break
          end
        end
        -- Call the callback with a mock response
        callback({ code = 0, stdout = '{"content":[{"text":"test commit"}]}' })
      end

      local config = { max_tokens = nil }
      anthropic_provider.call_api(config, "test diff", function() end)

      -- Parse the payload to check max_tokens
      local payload = vim.json.decode(captured_payload)
      assert.equals(1000, payload.max_tokens) -- Should default to 1000

      -- Restore mocks
      os.getenv = original_getenv
      vim.system = original_vim_system
    end)
  end)
end)
