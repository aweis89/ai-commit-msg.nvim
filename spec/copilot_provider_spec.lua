describe("copilot provider", function()
  local copilot_provider

  before_each(function()
    copilot_provider = require("ai_commit_msg.providers.copilot")
  end)

  describe("call_api", function()
    it("calls callback with error when token not set in config", function()
      local callback_called = false
      local result_success, result_message

      copilot_provider.call_api({}, "test diff", function(success, message)
        callback_called = true
        result_success = success
        result_message = message
      end)

      assert.is_true(callback_called)
      assert.is_false(result_success)
      assert.equals("Copilot token not set in config", result_message)
    end)
  end)
end)
