-- Gemini Chat Plugin Entry Point
-- This file is loaded automatically when Neovim starts

-- Prevent loading twice
if vim.g.loaded_gemini_chat == 1 then
    return
end
vim.g.loaded_gemini_chat = 1

-- Check Neovim version
if vim.fn.has("nvim-0.8.0") == 0 then
    vim.notify("Gemini Chat requires Neovim 0.8.0 or higher", vim.log.levels.ERROR)
    return
end

-- Create user commands
vim.api.nvim_create_user_command("GeminiChat", function(opts)
    require("gemini-chat").toggle_chat()
end, {
    desc = "Toggle Gemini Chat session",
    nargs = 0,
})

vim.api.nvim_create_user_command("GeminiDiff", function(opts)
    require("gemini-chat").show_diff()
end, {
    desc = "Show Gemini code diff",
    nargs = 0,
})

vim.api.nvim_create_user_command("GeminiApply", function(opts)
    require("gemini-chat").apply_suggestions()
end, {
    desc = "Apply current Gemini suggestions",
    nargs = 0,
})

vim.api.nvim_create_user_command("GeminiReject", function(opts)
    require("gemini-chat").reject_suggestions()
end, {
    desc = "Reject current Gemini suggestions",
    nargs = 0,
})

vim.api.nvim_create_user_command("GeminiSend", function(opts)
    local selection = require("gemini-chat.utils").get_visual_selection()
    if selection then
        require("gemini-chat.chat").send_code_context(selection.content, "selection")
    end
end, {
    desc = "Send current selection to Gemini",
    nargs = 0,
})

vim.api.nvim_create_user_command("GeminiFile", function(opts)
    require("gemini-chat.chat").send_file_context()
end, {
    desc = "Send current file to Gemini",
    nargs = 0,
})

vim.api.nvim_create_user_command("GeminiClear", function(opts)
    require("gemini-chat.chat").clear_conversation_history()
end, {
    desc = "Clear Gemini conversation history",
    nargs = 0,
})

vim.api.nvim_create_user_command("GeminiExport", function(opts)
    local filename = opts.args ~= "" and opts.args or nil
    require("gemini-chat.chat").export_conversation(filename)
end, {
    desc = "Export Gemini conversation to file",
    nargs = "?",
    complete = "file",
})

vim.api.nvim_create_user_command("GeminiHealth", function(opts)
    require("gemini-chat").health()
end, {
    desc = "Check Gemini Chat health",
    nargs = 0,
})

-- Global key mappings (can be overridden by user)
if vim.g.gemini_chat_no_default_keymaps ~= 1 then
    vim.keymap.set("n", "<leader>gc", "<cmd>GeminiChat<cr>", { desc = "Toggle Gemini Chat" })
    vim.keymap.set("n", "<leader>gd", "<cmd>GeminiDiff<cr>", { desc = "Show Gemini Diff" })
    vim.keymap.set("n", "<leader>ga", "<cmd>GeminiApply<cr>", { desc = "Apply Gemini Suggestions" })
    vim.keymap.set("n", "<leader>gr", "<cmd>GeminiReject<cr>", { desc = "Reject Gemini Suggestions" })
    vim.keymap.set("v", "<leader>gs", "<cmd>GeminiSend<cr>", { desc = "Send Selection to Gemini" })
    vim.keymap.set("n", "<leader>gf", "<cmd>GeminiFile<cr>", { desc = "Send File to Gemini" })
    vim.keymap.set("n", "<leader>gx", "<cmd>GeminiClear<cr>", { desc = "Clear Gemini Chat" })
end 