describe("ai_commit_msg config", function()
  local ai_commit_msg

  before_each(function()
    -- Reset the module
    package.loaded["ai_commit_msg"] = nil
    ai_commit_msg = require("ai_commit_msg")
  end)

  describe("default configuration", function()
    it("has openai as default provider", function()
      assert.equals("openai", ai_commit_msg.config.provider)
    end)

    it("has gpt-4.1-nano as default model", function()
      assert.equals("gpt-4.1-nano", ai_commit_msg.config.model)
    end)

    it("has all required fields", function()
      local config = ai_commit_msg.config
      assert.is_boolean(config.enabled)
      assert.is_string(config.provider)
      assert.is_string(config.model)
      assert.is_number(config.temperature)
      assert.is_string(config.prompt)
      assert.is_boolean(config.auto_push_prompt)
      assert.is_true(type(config.spinner) == "boolean" or type(config.spinner) == "table")
      assert.is_boolean(config.notifications)
      assert.is_table(config.keymaps)
    end)
  end)

  describe("setup", function()
    it("merges user config with defaults", function()
      ai_commit_msg.setup({
        provider = "anthropic",
        model = "claude-3-5-sonnet-20241022",
        temperature = 0.5,
      })

      assert.equals("anthropic", ai_commit_msg.config.provider)
      assert.equals("claude-3-5-sonnet-20241022", ai_commit_msg.config.model)
      assert.equals(0.5, ai_commit_msg.config.temperature)
      -- Should preserve other defaults
      assert.is_true(ai_commit_msg.config.enabled)
      assert.is_true(ai_commit_msg.config.notifications)
    end)

    it("preserves defaults when partial config provided", function()
      ai_commit_msg.setup({
        model = "gpt-4o",
      })

      assert.equals("openai", ai_commit_msg.config.provider) -- Should keep default
      assert.equals("gpt-4o", ai_commit_msg.config.model)
      assert.equals(0.3, ai_commit_msg.config.temperature) -- Should keep default
    end)
  end)
end)
