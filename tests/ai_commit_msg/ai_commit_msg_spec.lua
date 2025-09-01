local plugin = require("ai_commit_msg")

describe("setup", function()
  it("works with default config", function()
    plugin.setup()
    assert(plugin.config.enabled == true, "Plugin should be enabled by default")
    assert(plugin.config.providers.gemini.prompt ~= nil, "Default prompt should be set")
  end)

  it("works with custom config", function()
    plugin.setup({
      enabled = false,
      prompt = "Custom prompt",
      command = "echo 'test'",
    })
    assert(plugin.config.enabled == false, "Plugin should be disabled")
    assert(plugin.config.prompt == "Custom prompt", "Custom prompt should be set")
    assert(plugin.config.command == "echo 'test'", "Custom command should be set")
  end)

  it("merges config correctly", function()
    plugin.setup({
      prompt = "Another prompt",
    })
    assert(plugin.config.prompt == "Another prompt", "Prompt should be overridden")
    assert(plugin.config.auto_push_prompt == true, "Other defaults should remain")
  end)
end)

describe("enable/disable", function()
  it("can disable the plugin", function()
    plugin.setup({ enabled = true })
    plugin.disable()
    assert(plugin.config.enabled == false, "Plugin should be disabled")
  end)

  it("can enable the plugin", function()
    plugin.setup({ enabled = false })
    plugin.enable()
    assert(plugin.config.enabled == true, "Plugin should be enabled")
  end)
end)
