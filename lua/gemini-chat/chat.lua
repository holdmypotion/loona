local M = {}

local config = require("gemini-chat.config")
local utils = require("gemini-chat.utils")
local diff = require("gemini-chat.diff")

-- Chat state
M.state = {
    conversation_history = {},
    current_context = {},
    last_response = "",
    is_processing = false,
    session_id = nil,
}

-- Initialize chat system
function M.init()
    M.state.session_id = utils.generate_session_id()
    M.state.conversation_history = {}
    M.state.current_context = {}
    M.state.last_response = ""
    M.state.is_processing = false
end

-- Update context with current file information
function M.update_context(filename)
    filename = filename or vim.api.nvim_buf_get_name(0)
    
    if filename == "" then
        return
    end
    
    local context = utils.get_current_file_context(filename)
    if context then
        M.state.current_context = context
        M.add_context_to_history(context)
    end
end

-- Add context to conversation history
function M.add_context_to_history(context)
    local context_message = {
        type = "context",
        filename = context.filename,
        filetype = context.filetype,
        content = context.content,
        line_count = context.line_count,
        timestamp = os.time(),
    }
    
    table.insert(M.state.conversation_history, context_message)
    
    -- Keep history within limits
    local max_history = config.get("chat.max_history_size")
    if #M.state.conversation_history > max_history then
        table.remove(M.state.conversation_history, 1)
    end
end

-- Send message to Gemini
function M.send_message(message, message_type)
    message_type = message_type or "user"
    
    if M.state.is_processing then
        vim.notify("Previous message still processing, please wait...", vim.log.levels.WARN)
        return
    end
    
    M.state.is_processing = true
    
    -- Add message to history
    local chat_message = {
        type = message_type,
        content = message,
        timestamp = os.time(),
    }
    
    table.insert(M.state.conversation_history, chat_message)
    
    -- Build context-aware message
    local enhanced_message = M.build_context_message(message)
    
    -- Send to terminal
    local terminal = require("gemini-chat.terminal")
    terminal.send_message(enhanced_message)
    
    -- Set up response handler
    M.setup_response_handler()
end

-- Build context-aware message
function M.build_context_message(message)
    local context_parts = {}
    
    -- Add current file context if available
    if M.state.current_context.filename then
        table.insert(context_parts, string.format("Current file: %s", M.state.current_context.filename))
        table.insert(context_parts, string.format("Language: %s", M.state.current_context.filetype))
        
        if config.get("chat.include_imports") and M.state.current_context.imports then
            table.insert(context_parts, "Imports:")
            for _, import in ipairs(M.state.current_context.imports) do
                table.insert(context_parts, "  " .. import)
            end
        end
    end
    
    -- Add relevant code context
    local context_lines = config.get("chat.context_lines")
    if context_lines > 0 and M.state.current_context.content then
        local lines = vim.split(M.state.current_context.content, "\n")
        local total_lines = #lines
        
        if total_lines > context_lines then
            -- Get surrounding context around cursor
            local current_line = vim.api.nvim_win_get_cursor(0)[1]
            local start_line = math.max(1, current_line - math.floor(context_lines / 2))
            local end_line = math.min(total_lines, start_line + context_lines - 1)
            
            local context_lines_content = {}
            for i = start_line, end_line do
                table.insert(context_lines_content, string.format("%d: %s", i, lines[i]))
            end
            
            table.insert(context_parts, "Code context:")
            table.insert(context_parts, "```" .. M.state.current_context.filetype)
            table.insert(context_parts, table.concat(context_lines_content, "\n"))
            table.insert(context_parts, "```")
        end
    end
    
    -- Combine context with user message
    local full_message = message
    if #context_parts > 0 then
        full_message = table.concat(context_parts, "\n") .. "\n\n" .. message
    end
    
    return full_message
end

-- Setup response handler
function M.setup_response_handler()
    -- This will be called when the terminal receives output
    vim.defer_fn(function()
        M.process_response()
    end, 100)
end

-- Process Gemini response
function M.process_response()
    local terminal = require("gemini-chat.terminal")
    local chat_history = terminal.get_chat_history()
    
    -- Get the last assistant response
    local last_response = nil
    for i = #chat_history, 1, -1 do
        local entry = chat_history[i]
        if entry.type == "assistant" then
            last_response = entry.content
            break
        end
    end
    
    if last_response and last_response ~= M.state.last_response then
        M.state.last_response = last_response
        M.handle_response(last_response)
    end
    
    M.state.is_processing = false
end

-- Handle Gemini response
function M.handle_response(response)
    -- Add response to conversation history
    local response_message = {
        type = "assistant",
        content = response,
        timestamp = os.time(),
    }
    
    table.insert(M.state.conversation_history, response_message)
    
    -- Parse response for code suggestions
    local suggestions = M.parse_code_suggestions(response)
    if #suggestions > 0 then
        diff.add_suggestions(suggestions)
        vim.notify("Found " .. #suggestions .. " code suggestions", vim.log.levels.INFO)
    end
    
    -- Check for actions/commands
    M.process_response_actions(response)
end

-- Parse code suggestions from response
function M.parse_code_suggestions(response)
    local suggestions = {}
    
    -- Look for code blocks
    local lines = vim.split(response, "\n")
    local current_suggestion = nil
    local in_code_block = false
    local code_block_lang = nil
    local code_lines = {}
    
    for i, line in ipairs(lines) do
        -- Check for code block start
        local lang = line:match("^```(%w*)")
        if lang then
            in_code_block = true
            code_block_lang = lang
            code_lines = {}
            
            -- Look for description in previous lines
            local description = "Code suggestion"
            for j = math.max(1, i - 3), i - 1 do
                local prev_line = lines[j]
                if prev_line and prev_line:match("^[%w%s]+:") then
                    description = prev_line:gsub("^%s*", ""):gsub(":$", "")
                    break
                end
            end
            
            current_suggestion = {
                description = description,
                filetype = code_block_lang,
                start_line = 1,
                end_line = 1,
                original_content = "",
                suggested_content = "",
                diff_lines = {},
            }
            
        elseif line:match("^```$") and in_code_block then
            -- End of code block
            in_code_block = false
            
            if current_suggestion then
                current_suggestion.suggested_content = table.concat(code_lines, "\n")
                current_suggestion.diff_lines = code_lines
                
                -- Try to determine line range
                local line_range = M.determine_line_range(current_suggestion.suggested_content)
                if line_range then
                    current_suggestion.start_line = line_range.start_line
                    current_suggestion.end_line = line_range.end_line
                end
                
                table.insert(suggestions, current_suggestion)
                current_suggestion = nil
            end
            
        elseif in_code_block then
            -- Inside code block
            table.insert(code_lines, line)
        end
    end
    
    -- Handle suggestions without explicit code blocks
    if #suggestions == 0 then
        local implicit_suggestions = M.parse_implicit_suggestions(response)
        for _, suggestion in ipairs(implicit_suggestions) do
            table.insert(suggestions, suggestion)
        end
    end
    
    return suggestions
end

-- Parse implicit code suggestions (without code blocks)
function M.parse_implicit_suggestions(response)
    local suggestions = {}
    
    -- Look for patterns like "replace X with Y" or "add this function"
    local lines = vim.split(response, "\n")
    
    for i, line in ipairs(lines) do
        -- Look for action keywords
        local action_patterns = {
            "replace",
            "change",
            "add",
            "modify",
            "update",
            "fix",
            "remove",
            "delete",
        }
        
        for _, pattern in ipairs(action_patterns) do
            if line:lower():find(pattern) then
                local suggestion = {
                    description = line:gsub("^%s*", ""),
                    filetype = M.state.current_context.filetype or "text",
                    start_line = 1,
                    end_line = 1,
                    original_content = "",
                    suggested_content = "",
                    diff_lines = { line },
                }
                
                table.insert(suggestions, suggestion)
                break
            end
        end
    end
    
    return suggestions
end

-- Determine line range for code suggestion
function M.determine_line_range(content)
    local current_buf = vim.api.nvim_get_current_buf()
    local current_lines = vim.api.nvim_buf_get_lines(current_buf, 0, -1, false)
    
    -- Try to find similar content in current buffer
    local content_lines = vim.split(content, "\n")
    if #content_lines == 0 then
        return nil
    end
    
    -- Look for the first line of the suggestion in the current buffer
    local first_line = content_lines[1]:gsub("^%s*", "")
    
    for i, line in ipairs(current_lines) do
        if line:gsub("^%s*", ""):find(first_line, 1, true) then
            return {
                start_line = i,
                end_line = math.min(i + #content_lines - 1, #current_lines),
            }
        end
    end
    
    -- Default to current cursor position
    local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
    return {
        start_line = cursor_line,
        end_line = cursor_line,
    }
end

-- Process response actions
function M.process_response_actions(response)
    -- Check for special commands or actions in the response
    local response_lower = response:lower()
    
    -- Auto-show diff if code suggestions are detected
    if response_lower:find("suggestion") or response_lower:find("change") or response_lower:find("modify") then
        if config.get("diff.auto_preview") then
            vim.defer_fn(function()
                diff.show_diff()
            end, 500)
        end
    end
    
    -- Handle file operations
    if response_lower:find("create file") or response_lower:find("new file") then
        M.handle_file_creation(response)
    end
    
    -- Handle explanations
    if response_lower:find("explain") or response_lower:find("because") then
        M.handle_explanation(response)
    end
end

-- Handle file creation suggestions
function M.handle_file_creation(response)
    -- Extract filename and content from response
    local filename = response:match("create file%s+['\"]([^'\"]+)['\"]")
    if not filename then
        filename = response:match("create%s+['\"]([^'\"]+)['\"]")
    end
    
    if filename then
        vim.notify("Gemini suggests creating file: " .. filename, vim.log.levels.INFO)
        -- Could add logic to actually create the file here
    end
end

-- Handle explanations
function M.handle_explanation(response)
    -- Format explanations nicely
    local explanation_lines = vim.split(response, "\n")
    local formatted_lines = {}
    
    for _, line in ipairs(explanation_lines) do
        if line:match("^%s*$") then
            table.insert(formatted_lines, "")
        else
            table.insert(formatted_lines, "# " .. line)
        end
    end
    
    -- Could show in a separate explanation buffer
end

-- Send code context to Gemini
function M.send_code_context(code, context_type)
    context_type = context_type or "selection"
    
    local message = string.format("Here's my %s:\n\n```%s\n%s\n```\n\nCan you help me with this code?",
        context_type,
        M.state.current_context.filetype or "text",
        code)
    
    M.send_message(message, "user")
end

-- Send file context to Gemini
function M.send_file_context(filename)
    filename = filename or vim.api.nvim_buf_get_name(0)
    
    if filename == "" then
        vim.notify("No file to send context for", vim.log.levels.WARN)
        return
    end
    
    local context = utils.get_current_file_context(filename)
    if context then
        local message = string.format("Here's the current file I'm working on:\n\nFile: %s\nLanguage: %s\n\n```%s\n%s\n```\n\nWhat do you think about this code?",
            context.filename,
            context.filetype,
            context.filetype,
            context.content)
        
        M.send_message(message, "user")
    end
end

-- Get conversation history
function M.get_conversation_history()
    return M.state.conversation_history
end

-- Clear conversation history
function M.clear_conversation_history()
    M.state.conversation_history = {}
    M.state.last_response = ""
    vim.notify("Conversation history cleared", vim.log.levels.INFO)
end

-- Save conversation history
function M.save_conversation_history()
    if not config.get("chat.auto_save_history") then
        return
    end
    
    local history_file = vim.fn.stdpath("data") .. "/gemini-chat-history.json"
    local history_data = {
        session_id = M.state.session_id,
        timestamp = os.time(),
        conversation = M.state.conversation_history,
    }
    
    local encoded = vim.json.encode(history_data)
    local file = io.open(history_file, "w")
    if file then
        file:write(encoded)
        file:close()
    end
end

-- Load conversation history
function M.load_conversation_history()
    if not config.get("chat.auto_save_history") then
        return
    end
    
    local history_file = vim.fn.stdpath("data") .. "/gemini-chat-history.json"
    local file = io.open(history_file, "r")
    if file then
        local content = file:read("*all")
        file:close()
        
        local success, history_data = pcall(vim.json.decode, content)
        if success and history_data.conversation then
            M.state.conversation_history = history_data.conversation
            M.state.session_id = history_data.session_id
            vim.notify("Conversation history loaded", vim.log.levels.INFO)
        end
    end
end

-- Export conversation
function M.export_conversation(filename)
    filename = filename or ("gemini-chat-export-" .. os.date("%Y%m%d-%H%M%S") .. ".md")
    
    local lines = {}
    table.insert(lines, "# Gemini Chat Export")
    table.insert(lines, "")
    table.insert(lines, "Session ID: " .. (M.state.session_id or "unknown"))
    table.insert(lines, "Export Date: " .. os.date("%Y-%m-%d %H:%M:%S"))
    table.insert(lines, "")
    
    for _, message in ipairs(M.state.conversation_history) do
        local timestamp = os.date("%H:%M:%S", message.timestamp)
        
        if message.type == "user" then
            table.insert(lines, "## User [" .. timestamp .. "]")
            table.insert(lines, "")
            table.insert(lines, message.content)
        elseif message.type == "assistant" then
            table.insert(lines, "## Assistant [" .. timestamp .. "]")
            table.insert(lines, "")
            table.insert(lines, message.content)
        elseif message.type == "context" then
            table.insert(lines, "## Context [" .. timestamp .. "]")
            table.insert(lines, "")
            table.insert(lines, "File: " .. message.filename)
            table.insert(lines, "Language: " .. message.filetype)
            table.insert(lines, "")
            table.insert(lines, "```" .. message.filetype)
            table.insert(lines, message.content)
            table.insert(lines, "```")
        end
        
        table.insert(lines, "")
    end
    
    -- Write to file
    local file = io.open(filename, "w")
    if file then
        file:write(table.concat(lines, "\n"))
        file:close()
        vim.notify("Conversation exported to " .. filename, vim.log.levels.INFO)
    else
        vim.notify("Failed to export conversation", vim.log.levels.ERROR)
    end
end

-- Get current context
function M.get_current_context()
    return M.state.current_context
end

-- Check if chat is processing
function M.is_processing()
    return M.state.is_processing
end

-- Get session ID
function M.get_session_id()
    return M.state.session_id
end

return M 