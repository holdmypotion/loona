-- Example configuration for Gemini Chat Neovim plugin
-- Copy this to your init.lua and modify as needed

-- Basic setup with minimal configuration
require("gemini-chat").setup({
    -- Gemini CLI settings
    gemini_cli = {
        cmd = "gemini",
        model = "gemini-1.5-flash",
        temperature = 0.7,
    },
    
    -- Terminal positioned on the right
    terminal = {
        position = "right",
        width = 60,
    },
    
    -- Include context when chatting
    chat = {
        context_lines = 50,
        include_imports = true,
        auto_save_history = true,
    },
})

-- Advanced configuration with custom settings
--[[
require("gemini-chat").setup({
    -- Gemini CLI settings
    gemini_cli = {
        cmd = "gemini",
        model = "gemini-1.5-pro",  -- Use more powerful model
        temperature = 0.3,         -- Lower temperature for more focused responses
        max_tokens = 4096,
        timeout = 60000,           -- 60 second timeout
    },
    
    -- Terminal settings
    terminal = {
        position = "right",
        width = 80,               -- Wider terminal
        height = 40,
        start_in_insert = true,
        close_on_exit = false,
    },
    
    -- Diff settings
    diff = {
        position = "vsplit",      -- Vertical split for diff
        width = 100,
        highlight_changes = true,
        auto_preview = true,
    },
    
    -- Chat settings
    chat = {
        context_lines = 100,      -- More context lines
        include_imports = true,
        include_comments = true,
        auto_save_history = true,
        max_history_size = 200,
        system_prompt = "You are an expert software engineer and code reviewer. " ..
                       "Provide detailed, actionable feedback with specific examples. " ..
                       "When suggesting changes, use proper diff format and explain your reasoning.",
    },
    
    -- Custom keymaps
    keymaps = {
        toggle_chat = "<leader>ai",
        show_diff = "<leader>ad",
        apply_changes = "<leader>aa",
        reject_changes = "<leader>ar",
        send_selection = "<leader>as",
        send_file = "<leader>af",
        clear_chat = "<leader>ax",
        next_suggestion = "]a",
        prev_suggestion = "[a",
    },
    
    -- UI customization
    ui = {
        border = "double",
        winblend = 10,
        signs = {
            add = "➕",
            delete = "➖",
            change = "🔄",
            suggestion = "💡",
        },
    },
    
    -- Logging for debugging
    log = {
        level = "debug",
        file = vim.fn.stdpath("data") .. "/gemini-chat-debug.log",
        max_size = 5 * 1024 * 1024,  -- 5MB log file
    },
})
--]]

-- Custom function to send specific types of questions
local function send_code_review()
    local chat = require("gemini-chat.chat")
    chat.send_file_context()
    vim.defer_fn(function()
        local terminal = require("gemini-chat.terminal")
        terminal.send_message("Please review this code and suggest improvements focusing on:\n" ..
                             "1. Code quality and readability\n" ..
                             "2. Performance optimizations\n" ..
                             "3. Best practices\n" ..
                             "4. Potential bugs or issues")
    end, 1000)
end

-- Custom function to explain selected code
local function explain_code()
    local utils = require("gemini-chat.utils")
    local chat = require("gemini-chat.chat")
    
    local selection = utils.get_visual_selection()
    if selection then
        local message = string.format("Please explain this code in detail:\n\n```%s\n%s\n```",
            vim.bo.filetype, selection.content)
        chat.send_message(message)
    end
end

-- Custom keymaps for specific functions
vim.keymap.set("n", "<leader>gr", send_code_review, { desc = "Send code for review" })
vim.keymap.set("v", "<leader>ge", explain_code, { desc = "Explain selected code" })

-- Custom command to quickly ask about errors
vim.api.nvim_create_user_command("GeminiError", function()
    local chat = require("gemini-chat.chat")
    local utils = require("gemini-chat.utils")
    
    local context = utils.get_cursor_context(20)
    local message = string.format("I'm getting an error around this code:\n\n```%s\n%s\n```\n\nCan you help me debug this?",
        vim.bo.filetype, context.content)
    
    chat.send_message(message)
end, {
    desc = "Ask Gemini about errors in current code",
})

-- Auto-setup notification
vim.notify("Gemini Chat configured! Use <leader>gc to start chatting.", vim.log.levels.INFO) 