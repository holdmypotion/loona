local M = {}

local config = require("gemini-chat.config")
local utils = require("gemini-chat.utils")

-- Terminal state
M.state = {
    terminal_buf = nil,
    terminal_win = nil,
    terminal_job = nil,
    chat_history = {},
    last_response = "",
    is_waiting_response = false,
}

-- Create terminal window
function M.create_terminal()
    local terminal_config = config.get("terminal")
    local gemini_config = config.get("gemini_cli")
    
    -- Calculate window dimensions
    local win_width = vim.o.columns
    local win_height = vim.o.lines
    
    local width, height
    if terminal_config.position == "right" or terminal_config.position == "left" then
        width = terminal_config.width
        height = win_height - 2
    else
        width = win_width
        height = terminal_config.height
    end
    
    -- Create buffer
    local buf = vim.api.nvim_create_buf(false, true)
    
    -- Set buffer options
    vim.api.nvim_buf_set_option(buf, "buftype", "terminal")
    vim.api.nvim_buf_set_option(buf, "swapfile", false)
    vim.api.nvim_buf_set_option(buf, "buflisted", false)
    
    -- Create window
    local win_opts = {
        relative = "editor",
        width = width,
        height = height,
        row = 0,
        col = terminal_config.position == "right" and (win_width - width) or 0,
        style = "minimal",
        border = config.get("ui.border"),
        title = " Gemini Chat ",
        title_pos = "center",
    }
    
    -- Adjust for different positions
    if terminal_config.position == "top" then
        win_opts.row = 0
        win_opts.col = 0
    elseif terminal_config.position == "bottom" then
        win_opts.row = win_height - height - 2
        win_opts.col = 0
    elseif terminal_config.position == "left" then
        win_opts.row = 0
        win_opts.col = 0
    end
    
    local win = vim.api.nvim_open_win(buf, true, win_opts)
    
    -- Set window options
    vim.api.nvim_win_set_option(win, "winblend", config.get("ui.winblend"))
    vim.api.nvim_win_set_option(win, "number", false)
    vim.api.nvim_win_set_option(win, "relativenumber", false)
    vim.api.nvim_win_set_option(win, "signcolumn", "no")
    vim.api.nvim_win_set_option(win, "foldcolumn", "0")
    vim.api.nvim_win_set_option(win, "wrap", true)
    
    -- Store state
    M.state.terminal_buf = buf
    M.state.terminal_win = win
    
    -- Start gemini CLI
    M.start_gemini_cli(buf)
    
    -- Set up buffer keymaps
    M.setup_buffer_keymaps(buf)
    
    -- Set up autocommands
    M.setup_terminal_autocommands(buf, win)
    
    -- Enter insert mode if configured
    if terminal_config.start_in_insert then
        vim.cmd("startinsert")
    end
    
    return buf
end

-- Start Gemini CLI process
function M.start_gemini_cli(buf)
    local gemini_config = config.get("gemini_cli")
    
    -- Build command
    local cmd = {
        gemini_config.cmd,
        "chat",
        "--model", gemini_config.model,
        "--temperature", tostring(gemini_config.temperature),
        "--max-tokens", tostring(gemini_config.max_tokens),
    }
    
    -- Add system prompt if configured
    local system_prompt = config.get("chat.system_prompt")
    if system_prompt and system_prompt ~= "" then
        table.insert(cmd, "--system")
        table.insert(cmd, system_prompt)
    end
    
    -- Start terminal job
    local job_id = vim.fn.termopen(cmd, {
        on_exit = function(_, exit_code)
            M.on_terminal_exit(exit_code)
        end,
        on_stdout = function(_, data)
            M.on_terminal_output(data)
        end,
        on_stderr = function(_, data)
            M.on_terminal_error(data)
        end,
    })
    
    if job_id <= 0 then
        vim.notify("Failed to start Gemini CLI", vim.log.levels.ERROR)
        return nil
    end
    
    M.state.terminal_job = job_id
    
    -- Send initial context
    M.send_initial_context()
    
    return job_id
end

-- Send initial context to Gemini
function M.send_initial_context()
    local context = utils.get_current_file_context()
    if context then
        local message = string.format("Current file context:\n```%s\n%s\n```\n\nI'm ready to help you with this code. What would you like to discuss or modify?", 
            context.filetype, context.content)
        M.send_message(message)
    else
        M.send_message("Hello! I'm ready to help you with your code. What would you like to discuss?")
    end
end

-- Send message to Gemini CLI
function M.send_message(message)
    if not M.state.terminal_job then
        vim.notify("No active Gemini CLI session", vim.log.levels.ERROR)
        return
    end
    
    -- Add to chat history
    table.insert(M.state.chat_history, {
        type = "user",
        content = message,
        timestamp = os.time(),
    })
    
    -- Send to terminal
    vim.fn.chansend(M.state.terminal_job, message .. "\n")
    M.state.is_waiting_response = true
end

-- Handle terminal output
function M.on_terminal_output(data)
    if not data or #data == 0 then
        return
    end
    
    -- Join data lines
    local output = table.concat(data, "\n")
    
    -- Add to last response
    M.state.last_response = M.state.last_response .. output
    
    -- Add to chat history if we have a complete response
    if not M.state.is_waiting_response then
        table.insert(M.state.chat_history, {
            type = "assistant",
            content = M.state.last_response,
            timestamp = os.time(),
        })
        M.state.last_response = ""
    end
end

-- Handle terminal errors
function M.on_terminal_error(data)
    if not data or #data == 0 then
        return
    end
    
    local error_msg = table.concat(data, "\n")
    vim.notify("Gemini CLI Error: " .. error_msg, vim.log.levels.ERROR)
end

-- Handle terminal exit
function M.on_terminal_exit(exit_code)
    if exit_code ~= 0 then
        vim.notify("Gemini CLI exited with code: " .. exit_code, vim.log.levels.WARN)
    end
    
    M.state.terminal_job = nil
    M.state.is_waiting_response = false
end

-- Setup buffer keymaps
function M.setup_buffer_keymaps(buf)
    local opts = { buffer = buf, noremap = true, silent = true }
    
    -- Exit terminal mode
    vim.keymap.set("t", "<Esc>", "<C-\\><C-n>", opts)
    vim.keymap.set("t", "<C-[>", "<C-\\><C-n>", opts)
    
    -- Send current line
    vim.keymap.set("n", "<CR>", function()
        local line = vim.api.nvim_get_current_line()
        if line and line ~= "" then
            M.send_message(line)
        end
    end, opts)
    
    -- Clear chat
    vim.keymap.set("n", "<C-l>", function()
        M.clear_chat()
    end, opts)
    
    -- Toggle between terminal and normal mode
    vim.keymap.set("n", "i", function()
        vim.cmd("startinsert")
    end, opts)
    
    -- Close terminal
    vim.keymap.set("n", "q", function()
        M.close_terminal()
    end, opts)
end

-- Setup terminal autocommands
function M.setup_terminal_autocommands(buf, win)
    local augroup = vim.api.nvim_create_augroup("GeminiTerminal", { clear = true })
    
    -- Auto-resize terminal
    vim.api.nvim_create_autocmd("VimResized", {
        group = augroup,
        callback = function()
            if vim.api.nvim_win_is_valid(win) then
                M.resize_terminal(win)
            end
        end,
    })
    
    -- Clean up on buffer delete
    vim.api.nvim_create_autocmd("BufDelete", {
        group = augroup,
        buffer = buf,
        callback = function()
            M.cleanup_terminal()
        end,
    })
end

-- Resize terminal window
function M.resize_terminal(win)
    local terminal_config = config.get("terminal")
    local win_width = vim.o.columns
    local win_height = vim.o.lines
    
    local width, height
    if terminal_config.position == "right" or terminal_config.position == "left" then
        width = terminal_config.width
        height = win_height - 2
    else
        width = win_width
        height = terminal_config.height
    end
    
    vim.api.nvim_win_set_width(win, width)
    vim.api.nvim_win_set_height(win, height)
end

-- Clear chat history
function M.clear_chat()
    if M.state.terminal_buf then
        vim.api.nvim_buf_set_lines(M.state.terminal_buf, 0, -1, false, {})
    end
    M.state.chat_history = {}
    M.state.last_response = ""
end

-- Close terminal
function M.close_terminal()
    if M.state.terminal_job then
        vim.fn.jobstop(M.state.terminal_job)
        M.state.terminal_job = nil
    end
    
    if M.state.terminal_win and vim.api.nvim_win_is_valid(M.state.terminal_win) then
        vim.api.nvim_win_close(M.state.terminal_win, true)
        M.state.terminal_win = nil
    end
    
    if M.state.terminal_buf and vim.api.nvim_buf_is_valid(M.state.terminal_buf) then
        vim.api.nvim_buf_delete(M.state.terminal_buf, { force = true })
        M.state.terminal_buf = nil
    end
    
    M.cleanup_terminal()
end

-- Cleanup terminal resources
function M.cleanup_terminal()
    M.state.terminal_buf = nil
    M.state.terminal_win = nil
    M.state.terminal_job = nil
    M.state.is_waiting_response = false
end

-- Get terminal buffer
function M.get_terminal_buffer()
    return M.state.terminal_buf
end

-- Get terminal window
function M.get_terminal_window()
    return M.state.terminal_win
end

-- Get chat history
function M.get_chat_history()
    return M.state.chat_history
end

-- Check if terminal is active
function M.is_active()
    return M.state.terminal_job ~= nil
end

-- Focus terminal
function M.focus_terminal()
    if M.state.terminal_win and vim.api.nvim_win_is_valid(M.state.terminal_win) then
        vim.api.nvim_set_current_win(M.state.terminal_win)
        if config.get("terminal.start_in_insert") then
            vim.cmd("startinsert")
        end
    end
end

return M 