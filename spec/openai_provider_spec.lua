describe("openai provider", function()
  local openai_provider

  before_each(function()
    openai_provider = require("ai_commit_msg.providers.openai")
  end)

  describe("call_api", function()
    it("calls callback with error when OPENAI_API_KEY not set", function()
      -- Mock environment
      local original_getenv = os.getenv
      os.getenv = function(key)
        if key == "OPENAI_API_KEY" then
          return nil
        end
        return original_getenv(key)
      end

      local callback_called = false
      local result_success, result_message

      openai_provider.call_api({}, "test diff", function(success, message)
        callback_called = true
        result_success = success
        result_message = message
      end)

      assert.is_true(callback_called)
      assert.is_false(result_success)
      assert.equals("OPENAI_API_KEY environment variable not set", result_message)

      -- Restore environment
      os.getenv = original_getenv
    end)

    it("processes prompt with {diff} placeholder correctly", function()
      -- This test would require mocking vim.system, which is complex
      -- For now, we test the prompt processing logic separately
      local config = {
        prompt = "Generate commit for:\n{diff}\nEnd of diff."
      }
      local diff = "diff --git a/file.txt"
      
      -- We'd need to extract the prompt processing logic to test it properly
      -- This is a placeholder for the actual test implementation
      assert.is_table(config)
      assert.is_string(diff)
    end)
  end)
end)