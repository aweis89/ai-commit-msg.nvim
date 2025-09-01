# ai-commit-msg.nvim

[![test](https://github.com/aweis89/ai-commit-msg.nvim/actions/workflows/test.yml/badge.svg)](https://github.com/aweis89/ai-commit-msg.nvim/actions/workflows/test.yml)
[![lint-test](https://github.com/aweis89/ai-commit-msg.nvim/actions/workflows/lint-test.yml/badge.svg)](https://github.com/aweis89/ai-commit-msg.nvim/actions/workflows/lint-test.yml)

**AI-powered commit messages while you review your diff in your favorite editor.**

A Neovim plugin that automatically generates commit messages using AI when you
run `git commit -v`, letting you review your changes while the AI crafts the
perfect commit message.

<img width="1512" height="943" alt="Screenshot 2025-09-01 at 3 22 28 PM" src="https://github.com/user-attachments/assets/790e66cc-733b-49bf-bd85-d9d5be359a46" />


## Features

- 🤖 Automatically generates commit messages using Gemini, OpenAI, or Anthropic APIs
  when you run `git commit -v`
- 🎯 Works from terminal or within Neovim (using vim-fugitive)
- 🤝 Non-intrusive - if you start typing, AI suggestions are added as comments instead
- 🔑 Uses `GEMINI_API_KEY`, `OPENAI_API_KEY`, or `ANTHROPIC_API_KEY` environment variables for authentication
- ⚙️ Configurable model, temperature, and max tokens
- 🔄 Optional push prompt after successful commits
- ⌨️ Customizable keymaps for commit buffer
- 📊 Optional spinner and notifications during generation

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "aweis89/ai-commit-msg.nvim",
  ft = "gitcommit",
  config = true,
  opts = {
    -- your configuration options here
  },
}
```

### With vim-fugitive (recommended)

```lua
{
  "tpope/vim-fugitive",
  cmd = { "Git" },
  keys = {
    -- Opens commit in a new tab so quitting doesn't exit Neovim
    { "<leader>gc", "<cmd>tab Git commit -v<cr>", desc = "Git commit" },
  },
},
{
  "aweis89/ai-commit-msg.nvim",
  ft = "gitcommit",
  config = true,
  opts = {
    -- your configuration options here
  },
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "aweis89/ai-commit-msg.nvim",
  config = function()
    require("ai_commit_msg").setup({
      -- your configuration
    })
  end
}
```

## Prerequisites

1. Set your AI provider's API key as an environment variable:

**For Gemini (default, best value):**

```bash
export GEMINI_API_KEY="your-api-key-here"
```

**For OpenAI:**

```bash
export OPENAI_API_KEY="your-api-key-here"
```

**For Anthropic:**

```bash
export ANTHROPIC_API_KEY="your-api-key-here"
```

1. Configure Neovim as your Git editor:

```bash
git config --global core.editor nvim
```

## Configuration

```lua
require("ai_commit_msg").setup({
  -- Enable/disable the plugin
  enabled = true,
  
  -- AI provider to use ("gemini", "openai", or "anthropic")
  provider = "gemini",
  
  -- Whether to prompt for push after commit
  auto_push_prompt = true,
  
  -- Show spinner while generating
  spinner = true,
  
  -- Show notifications
  notifications = true,
  
  -- Number of surrounding lines to include in git diff (default: 10)
  context_lines = 10,
  
  -- Cost display format ("compact", "verbose", or false to disable)
  cost_display = "compact",
  
  -- Keymaps for commit buffer
  keymaps = {
    quit = "q",  -- Set to false to disable
  },
  
  -- Provider-specific configurations
  providers = {
    openai = {
      model = "gpt-4.1-mini",
      temperature = 0.3,
      max_tokens = nil,  -- Uses model default
      -- Used to display cost per commit in notifications (see screenshot above)
      reasoning_effort = "minimal",  -- Options: "minimal", "medium", "high" (only applies to reasoning models like gpt-5*)
      pricing = {
        input_per_million = 0.40,   -- Cost per million input tokens
        output_per_million = 1.60,  -- Cost per million output tokens
      },
      system_prompt = nil, -- Override to customize commit message generation instructions
    },
    anthropic = {
      model = "claude-3-5-haiku-20241022",
      temperature = 0.3,
      max_tokens = 1000,  -- Required for Anthropic API
      pricing = {
        input_per_million = 0.80,   -- Cost per million input tokens
        output_per_million = 4.00,  -- Cost per million output tokens
      },
      system_prompt = nil, -- Override to customize commit message generation instructions
    },
    gemini = {
      model = "gemini-2.5-flash-lite",
      temperature = 0.3,
      max_tokens = 1000,
      pricing = {
        input_per_million = 0.10,   -- Cost per million input tokens
        output_per_million = 0.40,  -- Cost per million output tokens
      },
    },
  },
})
```

## Example Configurations

### Switch to OpenAI

```lua
require("ai_commit_msg").setup({
  provider = "openai",
})
```

### Switch to Anthropic Claude

```lua
require("ai_commit_msg").setup({
  provider = "anthropic",
})
```

### Customize Gemini settings (default)

```lua
require("ai_commit_msg").setup({
  provider = "gemini",
  providers = {
    gemini = {
      model = "gemini-2.5-flash-lite",
      temperature = 0.5,
      -- IMPORTANT: When overriding model, also update pricing for accurate cost display
      pricing = {
        input_per_million = 0.10,   -- gemini-2.5-flash-lite pricing
        output_per_million = 0.40,
      },
    },
  },
})
```

### Custom system prompt for specific commit style

```lua
require("ai_commit_msg").setup({
  providers = {
    gemini = {
      system_prompt = [[Generate a commit message following Angular commit conventions.
Include scope if applicable. Format: type(scope): description]], -- Override system prompt, diff is added as user message
    },
  },
})
```

## ⚠️ Important: Custom Model Pricing

**When overriding the default model for any provider, you MUST also update the pricing information to ensure accurate cost calculations.** The plugin includes pricing for the default models, but if you use a different model, the cost display will be inaccurate unless you specify the correct pricing.

Example:
```lua
require("ai_commit_msg").setup({
  providers = {
    gemini = {
      model = "gemini-2.5-flash",  -- Using different model
      pricing = {
        input_per_million = 0.30,   -- Update to gemini-2.5-flash pricing
        output_per_million = 2.50,
      },
    },
  },
})
```

## Commands

- `:AiCommitMsg` - Manually generate a commit message (prints to messages)
- `:AiCommitMsgDisable` - Disable automatic commit message generation
- `:AiCommitMsgEnable` - Enable automatic commit message generation

## How it works

The plugin works seamlessly whether you commit from the terminal or within Neovim:

### From Terminal

```bash
git add .
git commit -v  # Opens Neovim with diff visible, AI generates message while you review
```

### From within Neovim (using vim-fugitive)

```vim
:Git add .
:tab Git commit -v  " Opens in new tab, AI generates message while you review
" or with the keymap: <leader>gc
```

1. When you run `git commit -v` (with Neovim as your Git editor), the plugin automatically:
   - Detects when Git opens the commit message buffer
   - Runs `git diff --staged` to get your staged changes
   - Sends the diff to your configured AI provider's API with your configured prompt
   - Inserts the generated message into the commit buffer
   - The `-v` flag shows the diff below the message,
   allowing you to review changes during commit generation

2. If the buffer already has content (e.g., from a commit template),
the AI-generated message is added as comments below for reference.

3. After you save and close the commit buffer, the plugin:
   - Checks if the commit was successful (not cancelled or empty)
   - If successful and `auto_push_prompt` is enabled, prompts you to push the commit

**Note:** This requires Neovim to be your Git editor. Set it with:

```bash
git config --global core.editor nvim
```

## Requirements

- Neovim >= 0.7.0
- AI provider API key:
  - Gemini: Set `GEMINI_API_KEY` environment variable (default, best value)
  - OpenAI: Set `OPENAI_API_KEY` environment variable
  - Anthropic: Set `ANTHROPIC_API_KEY` environment variable
- Git
- curl (for making API requests)

## Tips

- The plugin uses Gemini API, OpenAI Chat Completions API, and Anthropic Messages API directly
- Lower temperature values (0.1-0.3) produce more consistent commit messages
- Higher temperature values (0.5-0.8) produce more creative variations
- The default model `gemini-2.5-flash-lite` provides excellent results at a very low cost
- For OpenAI's `gpt-5*`, the reasoning effort defaults to "minimal" when not specified
- Claude 3.5 Haiku is also a solid choice for commit message generation
- If you don't specify `max_tokens`, the model will use its default limit
- For Anthropic models, `max_tokens` is required by the API
  (defaults to 1000 if not specified)

## License

MIT
