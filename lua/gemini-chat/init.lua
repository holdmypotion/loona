local M = {}

local config = require("gemini-chat.config")
local terminal = require("gemini-chat.terminal")
local diff = require("gemini-chat.diff")
local chat = require("gemini-chat.chat")
local utils = require("gemini-chat.utils")

M.config = config
M.terminal = terminal
M.diff = diff
M.chat = chat

-- Plugin state
M.state = {
    initialized = false,
    terminal_buf = nil,
    diff_buf = nil,
    chat_history = {},
    current_file = nil,
    active_session = false
}

-- Initialize the plugin
function M.setup(opts)
    opts = opts or {}
    config.setup(opts)
    
    -- Check if gemini-cli is available
    if not utils.check_gemini_cli() then
        vim.notify("Gemini CLI not found. Please install it first.", vim.log.levels.ERROR)
        return
    end
    
    M.state.initialized = true
    
    -- Set up autocommands
    M.setup_autocommands()
    
    -- Set up key mappings
    M.setup_keymaps()
    
    vim.notify("Gemini Chat initialized successfully!", vim.log.levels.INFO)
end

-- Set up autocommands for file watching and context updates
function M.setup_autocommands()
    local augroup = vim.api.nvim_create_augroup("GeminiChat", { clear = true })
    
    -- Update context when buffer changes
    vim.api.nvim_create_autocmd({"BufEnter", "BufWritePost"}, {
        group = augroup,
        callback = function()
            if M.state.active_session then
                M.update_context()
            end
        end,
    })
    
    -- Clean up on exit
    vim.api.nvim_create_autocmd("VimLeavePre", {
        group = augroup,
        callback = function()
            M.cleanup()
        end,
    })
end

-- Set up default keymaps
function M.setup_keymaps()
    local opts = { noremap = true, silent = true }
    
    vim.keymap.set("n", "<leader>gc", M.toggle_chat, opts)
    vim.keymap.set("n", "<leader>gd", M.show_diff, opts)
    vim.keymap.set("n", "<leader>ga", M.apply_suggestions, opts)
    vim.keymap.set("n", "<leader>gr", M.reject_suggestions, opts)
    vim.keymap.set("n", "<leader>gs", M.send_selection, opts)
    vim.keymap.set("v", "<leader>gs", M.send_selection, opts)
end

-- Toggle the chat interface
function M.toggle_chat()
    if not M.state.initialized then
        vim.notify("Gemini Chat not initialized. Run :lua require('gemini-chat').setup()", vim.log.levels.ERROR)
        return
    end
    
    if M.state.active_session then
        M.close_session()
    else
        M.open_session()
    end
end

-- Open a new chat session
function M.open_session()
    -- Create terminal window on the right
    M.state.terminal_buf = terminal.create_terminal()
    
    -- Set up diff buffer
    M.state.diff_buf = diff.create_diff_buffer()
    
    -- Update context with current file
    M.update_context()
    
    M.state.active_session = true
    vim.notify("Gemini Chat session started", vim.log.levels.INFO)
end

-- Close the current chat session
function M.close_session()
    if M.state.terminal_buf then
        terminal.close_terminal(M.state.terminal_buf)
        M.state.terminal_buf = nil
    end
    
    if M.state.diff_buf then
        diff.close_diff_buffer(M.state.diff_buf)
        M.state.diff_buf = nil
    end
    
    M.state.active_session = false
    vim.notify("Gemini Chat session closed", vim.log.levels.INFO)
end

-- Update context with current file information
function M.update_context()
    local current_buf = vim.api.nvim_get_current_buf()
    local filename = vim.api.nvim_buf_get_name(current_buf)
    
    if filename ~= "" then
        M.state.current_file = filename
        chat.update_context(filename)
    end
end

-- Show diff of suggested changes
function M.show_diff()
    if not M.state.active_session then
        vim.notify("No active Gemini Chat session", vim.log.levels.WARN)
        return
    end
    
    diff.show_diff(M.state.diff_buf)
end

-- Apply suggested changes
function M.apply_suggestions()
    if not M.state.active_session then
        vim.notify("No active Gemini Chat session", vim.log.levels.WARN)
        return
    end
    
    diff.apply_changes()
    vim.notify("Changes applied successfully", vim.log.levels.INFO)
end

-- Reject suggested changes
function M.reject_suggestions()
    if not M.state.active_session then
        vim.notify("No active Gemini Chat session", vim.log.levels.WARN)
        return
    end
    
    diff.reject_changes()
    vim.notify("Changes rejected", vim.log.levels.INFO)
end

-- Send current selection or line to Gemini
function M.send_selection()
    if not M.state.active_session then
        vim.notify("No active Gemini Chat session", vim.log.levels.WARN)
        return
    end
    
    local selection = utils.get_visual_selection()
    if selection then
        chat.send_code_context(selection)
    end
end

-- Cleanup function
function M.cleanup()
    if M.state.active_session then
        M.close_session()
    end
end

-- Health check function
function M.health()
    vim.health.report_start("Gemini Chat")
    
    if utils.check_gemini_cli() then
        vim.health.report_ok("Gemini CLI is available")
    else
        vim.health.report_error("Gemini CLI not found", {"Install gemini-cli: https://github.com/google-gemini/gemini-cli"})
    end
    
    if M.state.initialized then
        vim.health.report_ok("Plugin is initialized")
    else
        vim.health.report_warn("Plugin not initialized", {"Run require('gemini-chat').setup()"})
    end
end

return M 