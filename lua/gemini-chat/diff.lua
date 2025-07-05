local M = {}

local config = require("gemini-chat.config")
local utils = require("gemini-chat.utils")

-- Diff state
M.state = {
    diff_buf = nil,
    diff_win = nil,
    original_buf = nil,
    suggested_changes = {},
    current_diff_index = 1,
    is_preview_mode = false,
}

-- Create diff buffer
function M.create_diff_buffer()
    local diff_config = config.get("diff")
    
    -- Create buffer
    local buf = vim.api.nvim_create_buf(false, true)
    
    -- Set buffer options
    vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
    vim.api.nvim_buf_set_option(buf, "swapfile", false)
    vim.api.nvim_buf_set_option(buf, "buflisted", false)
    vim.api.nvim_buf_set_option(buf, "filetype", "diff")
    vim.api.nvim_buf_set_option(buf, "modifiable", false)
    
    -- Set buffer name
    vim.api.nvim_buf_set_name(buf, "Gemini Diff")
    
    -- Store state
    M.state.diff_buf = buf
    M.state.original_buf = vim.api.nvim_get_current_buf()
    
    -- Set up syntax highlighting
    M.setup_diff_syntax(buf)
    
    -- Set up buffer keymaps
    M.setup_diff_keymaps(buf)
    
    return buf
end

-- Setup diff syntax highlighting
function M.setup_diff_syntax(buf)
    local signs = config.get("ui.signs")
    
    -- Define highlight groups
    vim.api.nvim_set_hl(0, "DiffAdd", { fg = "#00ff00", bg = "#001100" })
    vim.api.nvim_set_hl(0, "DiffDelete", { fg = "#ff0000", bg = "#110000" })
    vim.api.nvim_set_hl(0, "DiffChange", { fg = "#ffff00", bg = "#111100" })
    vim.api.nvim_set_hl(0, "DiffText", { fg = "#ffffff", bg = "#333333" })
    
    -- Define signs
    vim.fn.sign_define("diff_add", { text = signs.add, texthl = "DiffAdd" })
    vim.fn.sign_define("diff_delete", { text = signs.delete, texthl = "DiffDelete" })
    vim.fn.sign_define("diff_change", { text = signs.change, texthl = "DiffChange" })
    vim.fn.sign_define("diff_suggestion", { text = signs.suggestion, texthl = "DiffText" })
end

-- Setup diff buffer keymaps
function M.setup_diff_keymaps(buf)
    local opts = { buffer = buf, noremap = true, silent = true }
    
    -- Navigate suggestions
    vim.keymap.set("n", "]g", function()
        M.next_suggestion()
    end, opts)
    
    vim.keymap.set("n", "[g", function()
        M.prev_suggestion()
    end, opts)
    
    -- Apply/reject changes
    vim.keymap.set("n", "<leader>ga", function()
        M.apply_current_suggestion()
    end, opts)
    
    vim.keymap.set("n", "<leader>gr", function()
        M.reject_current_suggestion()
    end, opts)
    
    vim.keymap.set("n", "<leader>gA", function()
        M.apply_all_suggestions()
    end, opts)
    
    vim.keymap.set("n", "<leader>gR", function()
        M.reject_all_suggestions()
    end, opts)
    
    -- Toggle preview mode
    vim.keymap.set("n", "<leader>gp", function()
        M.toggle_preview_mode()
    end, opts)
    
    -- Close diff
    vim.keymap.set("n", "q", function()
        M.close_diff_buffer()
    end, opts)
    
    -- Refresh diff
    vim.keymap.set("n", "<leader>gf", function()
        M.refresh_diff()
    end, opts)
end

-- Show diff window
function M.show_diff(buf)
    buf = buf or M.state.diff_buf
    if not buf or not vim.api.nvim_buf_is_valid(buf) then
        vim.notify("No valid diff buffer", vim.log.levels.ERROR)
        return
    end
    
    local diff_config = config.get("diff")
    
    -- Calculate window dimensions
    local win_width = vim.o.columns
    local win_height = vim.o.lines
    
    local width, height
    if diff_config.position == "split" then
        width = win_width
        height = diff_config.height
    elseif diff_config.position == "vsplit" then
        width = diff_config.width
        height = win_height - 2
    else
        width = diff_config.width
        height = diff_config.height
    end
    
    -- Create window based on position
    local win
    if diff_config.position == "split" then
        vim.cmd("split")
        win = vim.api.nvim_get_current_win()
        vim.api.nvim_win_set_buf(win, buf)
        vim.api.nvim_win_set_height(win, height)
    elseif diff_config.position == "vsplit" then
        vim.cmd("vsplit")
        win = vim.api.nvim_get_current_win()
        vim.api.nvim_win_set_buf(win, buf)
        vim.api.nvim_win_set_width(win, width)
    elseif diff_config.position == "tab" then
        vim.cmd("tabnew")
        win = vim.api.nvim_get_current_win()
        vim.api.nvim_win_set_buf(win, buf)
    else -- float
        local win_opts = {
            relative = "editor",
            width = width,
            height = height,
            row = (win_height - height) / 2,
            col = (win_width - width) / 2,
            style = "minimal",
            border = config.get("ui.border"),
            title = " Code Diff ",
            title_pos = "center",
        }
        win = vim.api.nvim_open_win(buf, true, win_opts)
    end
    
    -- Set window options
    vim.api.nvim_win_set_option(win, "winblend", config.get("ui.winblend"))
    vim.api.nvim_win_set_option(win, "number", true)
    vim.api.nvim_win_set_option(win, "relativenumber", false)
    vim.api.nvim_win_set_option(win, "wrap", false)
    vim.api.nvim_win_set_option(win, "cursorline", true)
    
    M.state.diff_win = win
    
    -- Update diff content
    M.update_diff_content()
end

-- Update diff content
function M.update_diff_content()
    if not M.state.diff_buf or not vim.api.nvim_buf_is_valid(M.state.diff_buf) then
        return
    end
    
    local lines = {}
    
    -- Add header
    table.insert(lines, "# Gemini Suggested Changes")
    table.insert(lines, "# Use ]g/[g to navigate, <leader>ga to apply, <leader>gr to reject")
    table.insert(lines, "")
    
    -- Add suggestions
    for i, suggestion in ipairs(M.state.suggested_changes) do
        local marker = i == M.state.current_diff_index and ">>> " or "    "
        table.insert(lines, marker .. "Suggestion " .. i .. ": " .. suggestion.description)
        table.insert(lines, "")
        
        -- Add diff content
        for _, line in ipairs(suggestion.diff_lines) do
            table.insert(lines, line)
        end
        
        table.insert(lines, "")
    end
    
    -- Update buffer content
    vim.api.nvim_buf_set_option(M.state.diff_buf, "modifiable", true)
    vim.api.nvim_buf_set_lines(M.state.diff_buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(M.state.diff_buf, "modifiable", false)
    
    -- Update signs
    M.update_diff_signs()
end

-- Update diff signs
function M.update_diff_signs()
    if not M.state.diff_buf or not vim.api.nvim_buf_is_valid(M.state.diff_buf) then
        return
    end
    
    -- Clear existing signs
    vim.fn.sign_unplace("*", { buffer = M.state.diff_buf })
    
    -- Place new signs
    local lines = vim.api.nvim_buf_get_lines(M.state.diff_buf, 0, -1, false)
    for i, line in ipairs(lines) do
        local sign_name = nil
        if line:match("^%+") then
            sign_name = "diff_add"
        elseif line:match("^%-") then
            sign_name = "diff_delete"
        elseif line:match("^@@") then
            sign_name = "diff_change"
        elseif line:match("^>>> ") then
            sign_name = "diff_suggestion"
        end
        
        if sign_name then
            vim.fn.sign_place(0, "diff", sign_name, M.state.diff_buf, { lnum = i })
        end
    end
end

-- Parse suggested changes from Gemini response
function M.parse_gemini_response(response)
    local suggestions = {}
    
    -- Look for code blocks and diff markers
    local lines = vim.split(response, "\n")
    local current_suggestion = nil
    local in_code_block = false
    local code_block_lang = nil
    
    for _, line in ipairs(lines) do
        -- Check for code block start
        local lang = line:match("^```(%w*)")
        if lang then
            in_code_block = true
            code_block_lang = lang
            if not current_suggestion then
                current_suggestion = {
                    description = "Code suggestion",
                    diff_lines = {},
                    start_line = 1,
                    end_line = 1,
                    original_content = "",
                    suggested_content = "",
                }
            end
        elseif line:match("^```$") then
            -- End of code block
            in_code_block = false
            if current_suggestion then
                table.insert(suggestions, current_suggestion)
                current_suggestion = nil
            end
        elseif in_code_block then
            -- Inside code block
            if current_suggestion then
                table.insert(current_suggestion.diff_lines, line)
                current_suggestion.suggested_content = current_suggestion.suggested_content .. line .. "\n"
            end
        else
            -- Outside code block - look for descriptions
            if line:match("^%s*[%w%s]+:") or line:match("^%s*%-") then
                if current_suggestion then
                    table.insert(suggestions, current_suggestion)
                end
                current_suggestion = {
                    description = line:gsub("^%s*", ""),
                    diff_lines = {},
                    start_line = 1,
                    end_line = 1,
                    original_content = "",
                    suggested_content = "",
                }
            end
        end
    end
    
    -- Add final suggestion if exists
    if current_suggestion then
        table.insert(suggestions, current_suggestion)
    end
    
    return suggestions
end

-- Add suggested changes
function M.add_suggestions(suggestions)
    if type(suggestions) == "string" then
        suggestions = M.parse_gemini_response(suggestions)
    end
    
    for _, suggestion in ipairs(suggestions) do
        table.insert(M.state.suggested_changes, suggestion)
    end
    
    -- Update diff if window is open
    if M.state.diff_win and vim.api.nvim_win_is_valid(M.state.diff_win) then
        M.update_diff_content()
    end
end

-- Navigate to next suggestion
function M.next_suggestion()
    if #M.state.suggested_changes == 0 then
        vim.notify("No suggestions available", vim.log.levels.INFO)
        return
    end
    
    M.state.current_diff_index = math.min(M.state.current_diff_index + 1, #M.state.suggested_changes)
    M.update_diff_content()
    M.jump_to_current_suggestion()
end

-- Navigate to previous suggestion
function M.prev_suggestion()
    if #M.state.suggested_changes == 0 then
        vim.notify("No suggestions available", vim.log.levels.INFO)
        return
    end
    
    M.state.current_diff_index = math.max(M.state.current_diff_index - 1, 1)
    M.update_diff_content()
    M.jump_to_current_suggestion()
end

-- Jump to current suggestion in diff buffer
function M.jump_to_current_suggestion()
    if not M.state.diff_win or not vim.api.nvim_win_is_valid(M.state.diff_win) then
        return
    end
    
    local lines = vim.api.nvim_buf_get_lines(M.state.diff_buf, 0, -1, false)
    for i, line in ipairs(lines) do
        if line:match("^>>> ") then
            vim.api.nvim_win_set_cursor(M.state.diff_win, { i, 0 })
            break
        end
    end
end

-- Apply current suggestion
function M.apply_current_suggestion()
    if #M.state.suggested_changes == 0 then
        vim.notify("No suggestions to apply", vim.log.levels.INFO)
        return
    end
    
    local suggestion = M.state.suggested_changes[M.state.current_diff_index]
    M.apply_suggestion(suggestion)
    
    -- Remove applied suggestion
    table.remove(M.state.suggested_changes, M.state.current_diff_index)
    
    -- Adjust current index
    if M.state.current_diff_index > #M.state.suggested_changes then
        M.state.current_diff_index = math.max(1, #M.state.suggested_changes)
    end
    
    M.update_diff_content()
end

-- Apply suggestion to original buffer
function M.apply_suggestion(suggestion)
    if not M.state.original_buf or not vim.api.nvim_buf_is_valid(M.state.original_buf) then
        vim.notify("Original buffer not available", vim.log.levels.ERROR)
        return
    end
    
    -- Apply the suggestion content
    local lines = vim.split(suggestion.suggested_content, "\n")
    if lines[#lines] == "" then
        table.remove(lines) -- Remove empty last line
    end
    
    vim.api.nvim_buf_set_lines(M.state.original_buf, 
        suggestion.start_line - 1, 
        suggestion.end_line, 
        false, 
        lines)
    
    vim.notify("Applied suggestion: " .. suggestion.description, vim.log.levels.INFO)
end

-- Reject current suggestion
function M.reject_current_suggestion()
    if #M.state.suggested_changes == 0 then
        vim.notify("No suggestions to reject", vim.log.levels.INFO)
        return
    end
    
    local suggestion = M.state.suggested_changes[M.state.current_diff_index]
    vim.notify("Rejected suggestion: " .. suggestion.description, vim.log.levels.INFO)
    
    -- Remove rejected suggestion
    table.remove(M.state.suggested_changes, M.state.current_diff_index)
    
    -- Adjust current index
    if M.state.current_diff_index > #M.state.suggested_changes then
        M.state.current_diff_index = math.max(1, #M.state.suggested_changes)
    end
    
    M.update_diff_content()
end

-- Apply all suggestions
function M.apply_all_suggestions()
    for _, suggestion in ipairs(M.state.suggested_changes) do
        M.apply_suggestion(suggestion)
    end
    
    M.state.suggested_changes = {}
    M.state.current_diff_index = 1
    M.update_diff_content()
    
    vim.notify("Applied all suggestions", vim.log.levels.INFO)
end

-- Reject all suggestions
function M.reject_all_suggestions()
    local count = #M.state.suggested_changes
    M.state.suggested_changes = {}
    M.state.current_diff_index = 1
    M.update_diff_content()
    
    vim.notify("Rejected " .. count .. " suggestions", vim.log.levels.INFO)
end

-- Toggle preview mode
function M.toggle_preview_mode()
    M.state.is_preview_mode = not M.state.is_preview_mode
    
    if M.state.is_preview_mode then
        vim.notify("Preview mode ON", vim.log.levels.INFO)
        M.show_preview()
    else
        vim.notify("Preview mode OFF", vim.log.levels.INFO)
        M.hide_preview()
    end
end

-- Show preview of current suggestion
function M.show_preview()
    -- Implementation for showing preview in original buffer
    -- This would highlight the changes without applying them
end

-- Hide preview
function M.hide_preview()
    -- Implementation for hiding preview
end

-- Refresh diff
function M.refresh_diff()
    M.update_diff_content()
    vim.notify("Diff refreshed", vim.log.levels.INFO)
end

-- Close diff buffer
function M.close_diff_buffer()
    if M.state.diff_win and vim.api.nvim_win_is_valid(M.state.diff_win) then
        vim.api.nvim_win_close(M.state.diff_win, true)
        M.state.diff_win = nil
    end
    
    if M.state.diff_buf and vim.api.nvim_buf_is_valid(M.state.diff_buf) then
        vim.api.nvim_buf_delete(M.state.diff_buf, { force = true })
        M.state.diff_buf = nil
    end
    
    M.cleanup_diff()
end

-- Cleanup diff resources
function M.cleanup_diff()
    M.state.diff_buf = nil
    M.state.diff_win = nil
    M.state.suggested_changes = {}
    M.state.current_diff_index = 1
    M.state.is_preview_mode = false
end

-- Apply changes (public API)
function M.apply_changes()
    M.apply_current_suggestion()
end

-- Reject changes (public API)
function M.reject_changes()
    M.reject_current_suggestion()
end

-- Get current suggestions
function M.get_suggestions()
    return M.state.suggested_changes
end

-- Clear all suggestions
function M.clear_suggestions()
    M.state.suggested_changes = {}
    M.state.current_diff_index = 1
    M.update_diff_content()
end

return M 