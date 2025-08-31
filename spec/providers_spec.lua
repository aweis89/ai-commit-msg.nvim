describe("providers", function()
  local providers

  before_each(function()
    providers = require("ai_commit_msg.providers")
  end)

  describe("get_provider", function()
    it("returns openai provider when configured", function()
      local config = { provider = "openai" }
      local provider = providers.get_provider(config)
      assert.is_not_nil(provider)
      assert.is_function(provider.call_api)
    end)

    it("returns anthropic provider when configured", function()
      local config = { provider = "anthropic" }
      local provider = providers.get_provider(config)
      assert.is_not_nil(provider)
      assert.is_function(provider.call_api)
    end)

    it("throws error for unsupported provider", function()
      local config = { provider = "unsupported" }
      assert.has_error(function()
        providers.get_provider(config)
      end, "Unsupported provider: unsupported")
    end)

    it("throws error for nil provider", function()
      local config = { provider = nil }
      assert.has_error(function()
        providers.get_provider(config)
      end, "Unsupported provider: nil")
    end)
  end)

  describe("call_api", function()
    it("delegates to provider's call_api method", function()
      local mock_provider = {
        call_api = function(config, diff, callback)
          callback(true, "test result")
        end
      }
      
      -- Mock the get_provider function
      local original_get_provider = providers.get_provider
      providers.get_provider = function(config)
        return mock_provider
      end

      local config = { provider = "openai" }
      local callback_called = false
      local result_success, result_message

      providers.call_api(config, "test diff", function(success, message)
        callback_called = true
        result_success = success
        result_message = message
      end)

      assert.is_true(callback_called)
      assert.is_true(result_success)
      assert.equals("test result", result_message)

      -- Restore original function
      providers.get_provider = original_get_provider
    end)
  end)
end)