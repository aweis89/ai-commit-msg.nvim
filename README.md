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

1. Set your OpenAI API key as an environment variable:

```bash
export OPENAI_API_KEY="your-api-key-here"
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
  
  -- OpenAI model to use
  model = "gpt-4.1-nano",  -- or "gpt-4o", "gpt-4o-mini", "gpt-3.5-turbo", etc.
  
  -- Temperature for the model (0.0 = deterministic, 1.0 = creative)
  temperature = 0.3,
  
  -- Maximum tokens in the response (optional, uses model default if not set)
  max_tokens = nil,
  
  -- The prompt to send to the AI
  -- {diff} will be replaced with the git diff
  prompt = [[Generate a conventional commit message for the staged git changes.

Requirements:
- Use conventional commit format: <type>(<scope>): <description>
- Types: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert
- Keep the first line under 72 characters
- Respond ONLY with the commit message, no explanations or markdown

Git diff of staged changes:
{diff}]],
  
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
})
```

## Example Configurations

### Using GPT-4o for more detailed messages

```lua
require("ai_commit_msg").setup({
  model = "gpt-4o",
  temperature = 0.5,
  max_tokens = 1000,
})
```

### Using GPT-4o-mini for cost-effective messages

```lua
require("ai_commit_msg").setup({
  model = "gpt-4o-mini",
  temperature = 0.3,
  max_tokens = 500,
})
```

### Using GPT-3.5-turbo for faster responses

```lua
require("ai_commit_msg").setup({
  model = "gpt-3.5-turbo",
  temperature = 0.2,
  max_tokens = 500,
})
```

### Custom prompt for specific commit style

```lua
require("ai_commit_msg").setup({
  prompt = [[Generate a commit message following Angular commit conventions.
Include scope if applicable. Format: type(scope): description

Git diff:
{diff}]],
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
- OpenAI API key (set as `OPENAI_API_KEY` environment variable)
- Git
- curl (for making API requests)

## Tips

- The plugin uses the OpenAI Chat Completions API directly
- Lower temperature values (0.1-0.3) produce more consistent commit messages
- Higher temperature values (0.5-0.8) produce more creative variations
- The `gpt-4.1-nano` model (default) is optimized for latency and speed
- The `gpt-5-nano` model provides high-quality commit messages with reasoning capabilities but is much slower
- The `gpt-4o-mini` model is fast and cost-effective for commit messages
- Consider using `gpt-4o` for complex changes that need more detailed analysis
- If you don't specify `max_tokens`, the model will use its default limit

## License

MIT
