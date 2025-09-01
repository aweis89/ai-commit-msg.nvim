describe("gemini provider", function()
  local gemini_provider

  before_each(function()
    gemini_provider = require("ai_commit_msg.providers.gemini")
  end)

  describe("call_api", function()
    it("calls callback with error when GEMINI_API_KEY not set", function()
      -- Mock environment
      local original_getenv = os.getenv
      os.getenv = function(key)
        if key == "GEMINI_API_KEY" then
          return nil
        end
        return original_getenv(key)
      end

      local callback_called = false
      local result_success, result_message

      gemini_provider.call_api({}, "test diff", function(success, message)
        callback_called = true
        result_success = success
        result_message = message
      end)

      assert.is_true(callback_called)
      assert.is_false(result_success)
      assert.equals("GEMINI_API_KEY environment variable not set", result_message)

      -- Restore original function
      os.getenv = original_getenv
    end)

    it("calls callback with error when GEMINI_API_KEY is empty string", function()
      -- Mock environment
      local original_getenv = os.getenv
      os.getenv = function(key)
        if key == "GEMINI_API_KEY" then
          return ""
        end
        return original_getenv(key)
      end

      local callback_called = false
      local result_success, result_message

      gemini_provider.call_api({}, "test diff", function(success, message)
        callback_called = true
        result_success = success
        result_message = message
      end)

      assert.is_true(callback_called)
      assert.is_false(result_success)
      assert.equals("GEMINI_API_KEY environment variable not set", result_message)

      -- Restore original function
      os.getenv = original_getenv
    end)
  end)
end)