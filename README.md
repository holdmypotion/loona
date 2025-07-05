# Gemini Chat for Neovim

A powerful Neovim plugin that integrates Google's Gemini AI directly into your editor for interactive coding assistance. Chat with Gemini while you code, get suggestions, and apply changes seamlessly - all without leaving Neovim.

## ✨ Features

- **Interactive Chat**: Chat with Gemini AI in a dedicated terminal window
- **Context-Aware**: Automatically includes current file context in conversations
- **Diff Preview**: See suggested changes before applying them
- **Smart Suggestions**: Parse and apply code suggestions from Gemini responses
- **Visual Selection**: Send selected code directly to Gemini
- **Split Layout**: Right-side terminal for chat, left-side for code editing
- **Configurable**: Extensive configuration options for customization
- **Multi-language Support**: Works with all programming languages
- **Session Management**: Save and export conversation history
- **Health Checks**: Built-in diagnostics for troubleshooting

## 📋 Requirements

- Neovim 0.8.0 or higher
- [Gemini CLI](https://github.com/google-gemini/gemini-cli) installed and configured
- A valid Google AI API key

## 🚀 Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
    "holdmypotion/gemini-chat.nvim",
    dependencies = {
        "nvim-lua/plenary.nvim"  -- Required for some utility functions
    },
    config = function()
        require("gemini-chat").setup({
            -- Your configuration here
        })
    end,
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
    "holdmypotion/gemini-chat.nvim",
    requires = {
        "nvim-lua/plenary.nvim"
    },
    config = function()
        require("gemini-chat").setup({
            -- Your configuration here
        })
    end,
}
```

### Using [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'nvim-lua/plenary.nvim'
Plug 'holdmypotion/gemini-chat.nvim'
```

Then add to your `init.lua`:

```lua
require("gemini-chat").setup({
    -- Your configuration here
})
```

## 🔧 Setup

### 1. Install Gemini CLI

```bash
# Install Gemini CLI
npm install -g @google/gemini-cli

# Or using pip
pip install google-gemini-cli
```

### 2. Configure API Key

Set your Google AI API key:

```bash
export GOOGLE_API_KEY="your_api_key_here"
```

### 3. Basic Configuration

```lua
require("gemini-chat").setup({
    -- Gemini CLI settings
    gemini_cli = {
        cmd = "gemini",
        model = "gemini-1.5-flash",
        temperature = 0.7,
    },
    
    -- Terminal settings
    terminal = {
        position = "right",
        width = 60,
    },
    
    -- Chat settings
    chat = {
        context_lines = 50,
        include_imports = true,
        auto_save_history = true,
    },
})
```

## 📖 Usage

### Basic Commands

| Command | Description |
|---------|-------------|
| `:GeminiChat` | Toggle chat session |
| `:GeminiDiff` | Show code diff |
| `:GeminiApply` | Apply suggestions |
| `:GeminiReject` | Reject suggestions |
| `:GeminiSend` | Send selection to Gemini |
| `:GeminiFile` | Send current file to Gemini |
| `:GeminiClear` | Clear conversation history |
| `:GeminiExport` | Export conversation to file |
| `:GeminiHealth` | Check plugin health |

### Default Keymaps

| Keymap | Mode | Description |
|--------|------|-------------|
| `<leader>gc` | Normal | Toggle Gemini Chat |
| `<leader>gd` | Normal | Show Gemini Diff |
| `<leader>ga` | Normal | Apply Gemini Suggestions |
| `<leader>gr` | Normal | Reject Gemini Suggestions |
| `<leader>gs` | Visual | Send Selection to Gemini |
| `<leader>gf` | Normal | Send File to Gemini |
| `<leader>gx` | Normal | Clear Gemini Chat |

### Workflow Example

1. **Start a chat session**: Press `<leader>gc` to open the Gemini chat terminal
2. **Send code for review**: Select code and press `<leader>gs` to send it to Gemini
3. **Review suggestions**: Gemini will provide feedback and suggestions
4. **View diffs**: Press `<leader>gd` to see suggested changes in a diff view
5. **Apply changes**: Press `<leader>ga` to apply the suggestions or `<leader>gr` to reject them

## ⚙️ Configuration

<details>
<summary>Full Configuration Options</summary>

```lua
require("gemini-chat").setup({
    -- Gemini CLI settings
    gemini_cli = {
        cmd = "gemini",
        model = "gemini-1.5-flash",
        temperature = 0.7,
        max_tokens = 2048,
        timeout = 30000,
    },
    
    -- Terminal settings
    terminal = {
        position = "right",  -- "right", "left", "top", "bottom"
        width = 60,
        height = 30,
        shell = vim.o.shell,
        close_on_exit = false,
        start_in_insert = true,
    },
    
    -- Diff settings
    diff = {
        position = "split",  -- "split", "vsplit", "tab", "float"
        width = 80,
        height = 20,
        highlight_changes = true,
        auto_preview = true,
    },
    
    -- Chat settings
    chat = {
        context_lines = 50,
        include_imports = true,
        include_comments = true,
        auto_save_history = true,
        max_history_size = 100,
        system_prompt = "You are a helpful coding assistant...",
    },
    
    -- Key mappings
    keymaps = {
        toggle_chat = "<leader>gc",
        show_diff = "<leader>gd",
        apply_changes = "<leader>ga",
        reject_changes = "<leader>gr",
        send_selection = "<leader>gs",
        send_file = "<leader>gf",
        clear_chat = "<leader>gx",
        next_suggestion = "]g",
        prev_suggestion = "[g",
    },
    
    -- UI settings
    ui = {
        border = "rounded",
        winblend = 0,
        signs = {
            add = "+",
            delete = "-",
            change = "~",
            suggestion = "💡",
        },
    },
    
    -- Logging
    log = {
        level = "info",
        file = vim.fn.stdpath("data") .. "/gemini-chat.log",
        max_size = 1024 * 1024,
    },
})
```

</details>

## 🎨 Customization

### Custom Keymaps

```lua
-- Disable default keymaps
vim.g.gemini_chat_no_default_keymaps = 1

-- Set your own keymaps
vim.keymap.set("n", "<C-g>", "<cmd>GeminiChat<cr>", { desc = "Toggle Gemini Chat" })
vim.keymap.set("v", "<C-s>", "<cmd>GeminiSend<cr>", { desc = "Send to Gemini" })
```

### Custom System Prompt

```lua
require("gemini-chat").setup({
    chat = {
        system_prompt = "You are an expert software engineer specializing in " ..
                       "code reviews and refactoring. Provide concise, " ..
                       "actionable feedback with specific examples."
    }
})
```

## 🔍 Troubleshooting

### Health Check

Run `:GeminiHealth` to check if everything is configured correctly.

### Common Issues

1. **Gemini CLI not found**: Make sure it's installed and in your PATH
2. **API key issues**: Ensure your `GOOGLE_API_KEY` environment variable is set
3. **Terminal not showing**: Check terminal position and size settings
4. **No suggestions**: Verify your model supports the requested features

### Debug Logging

Enable debug logging:

```lua
require("gemini-chat").setup({
    log = {
        level = "debug",
    }
})
```

Check logs at `~/.local/share/nvim/gemini-chat.log`

## 🤝 Contributing

Contributions are welcome! Please read our [Contributing Guide](CONTRIBUTING.md) for details on how to submit pull requests, report issues, and contribute to the project.

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Inspired by [Harpoon](https://github.com/ThePrimeagen/harpoon) for the plugin architecture
- Thanks to Google for the Gemini API and CLI tool
- Built for the Neovim community

## 🔗 Links

- [Gemini CLI Documentation](https://github.com/google-gemini/gemini-cli)
- [Google AI API Documentation](https://ai.google.dev/)
- [Neovim Plugin Development](https://neovim.io/doc/user/lua-guide.html)

---

**Happy coding with Gemini! 🚀** 