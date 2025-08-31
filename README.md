# ai-commit-msg.nvim

**AI-powered commit messages while you review your diff in your favorite editor.**

A Neovim plugin that automatically generates commit messages using AI when you
run `git commit -v`, letting you review your changes while the AI crafts the
perfect commit message.

## Features

- 🤖 Automatically generates commit messages using OpenAI or Anthropic APIs when you run
  `git commit -v`
- 🎯 Works from terminal or within Neovim (using vim-fugitive)
- 🔑 Uses `OPENAI_API_KEY` or `ANTHROPIC_API_KEY` environment variables for authentication
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
  
  -- AI provider to use ("openai" or "anthropic")
  provider = "openai",
  
  -- Whether to prompt for push after commit
  auto_push_prompt = true,
  
  -- Show spinner while generating
  spinner = true,
  
  -- Show notifications
  notifications = true,
  
  -- Keymaps for commit buffer
  keymaps = {
    quit = "q",  -- Set to false to disable
  },
  
  -- Provider-specific configurations
  providers = {
    openai = {
      model = "gpt-5-mini",
      temperature = 0.3,
      max_tokens = nil,  -- Uses model default
      reasoning_effort = "minimal",  -- Options: "minimal", "medium", "high"
      prompt = [[Generate a conventional commit message for the staged git changes.

Requirements:
- Use conventional commit format: <type>(<scope>): <description>
- Types: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert
- Keep the first line under 72 characters
- Respond ONLY with the commit message, no explanations or markdown

Git diff of staged changes:
{diff}]],
      system_prompt = "You are a helpful assistant that generates conventional commit messages based on git diffs.",
    },
    anthropic = {
      model = "claude-3-5-haiku-20241022",
      temperature = 0.3,
      max_tokens = 1000,  -- Required for Anthropic API
      prompt = [[Generate a conventional commit message for the staged git changes.

Requirements:
- Use conventional commit format: <type>(<scope>): <description>
- Types: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert
- Keep the first line under 72 characters
- Respond ONLY with the commit message, no explanations or markdown

Git diff of staged changes:
{diff}]],
      system_prompt = "You are a helpful assistant that generates conventional commit messages based on git diffs.",
    },
  },
})
```

## Example Configurations

### Switch to Anthropic Claude

```lua
require("ai_commit_msg").setup({
  provider = "anthropic",
})
```

### Customize OpenAI settings

```lua
require("ai_commit_msg").setup({
  provider = "openai",
  providers = {
    openai = {
      model = "gpt-4o-mini",
      temperature = 0.5,
      reasoning_effort = "medium",
    },
  },
})
```

### Custom prompt for specific commit style

```lua
require("ai_commit_msg").setup({
  providers = {
    openai = {
      prompt = [[Generate a commit message following Angular commit conventions.
Include scope if applicable. Format: type(scope): description

Git diff:
{diff}]],
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
   - Sends the diff to OpenAI's API with your configured prompt
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
  - OpenAI: Set `OPENAI_API_KEY` environment variable
  - Anthropic: Set `ANTHROPIC_API_KEY` environment variable
- Git
- curl (for making API requests)

## Tips

- The plugin uses OpenAI Chat Completions API and Anthropic Messages API directly
- Lower temperature values (0.1-0.3) produce more consistent commit messages
- Higher temperature values (0.5-0.8) produce more creative variations
- The default model `gpt-5-mini` with minimal reasoning effort is chosen for speed and efficiency
- Claude 3.5 Haiku is also a solid choice for commit message generation
- If you don't specify `max_tokens`, the model will use its default limit
- For Anthropic models, `max_tokens` is required by the API (defaults to 1000 if not specified)

## License

MIT
