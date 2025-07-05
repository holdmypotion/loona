local M = {}

local config = require("gemini-chat.config")

-- Check if Gemini CLI is available
function M.check_gemini_cli()
    local gemini_cmd = config.get("gemini_cli.cmd")
    if not gemini_cmd then
        return false
    end
    
    -- Check if command exists
    local handle = io.popen("which " .. gemini_cmd .. " 2>/dev/null")
    if handle then
        local result = handle:read("*a")
        handle:close()
        return result and result ~= ""
    end
    
    return false
end

-- Generate session ID
function M.generate_session_id()
    local timestamp = os.time()
    local random = math.random(1000, 9999)
    return string.format("gemini-session-%d-%d", timestamp, random)
end

-- Get current file context
function M.get_current_file_context(filename)
    filename = filename or vim.api.nvim_buf_get_name(0)
    
    if filename == "" then
        return nil
    end
    
    local buf = vim.api.nvim_get_current_buf()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    
    if #lines == 0 then
        return nil
    end
    
    local content = table.concat(lines, "\n")
    local filetype = vim.api.nvim_buf_get_option(buf, "filetype")
    
    local context = {
        filename = vim.fn.fnamemodify(filename, ":t"),
        filepath = filename,
        filetype = filetype,
        content = content,
        line_count = #lines,
        size = #content,
        timestamp = os.time(),
    }
    
    -- Add imports/dependencies
    context.imports = M.extract_imports(content, filetype)
    
    -- Add functions/classes
    context.functions = M.extract_functions(content, filetype)
    
    -- Add comments
    if config.get("chat.include_comments") then
        context.comments = M.extract_comments(content, filetype)
    end
    
    return context
end

-- Extract imports from code
function M.extract_imports(content, filetype)
    local imports = {}
    local lines = vim.split(content, "\n")
    
    local import_patterns = {
        lua = { "require%s*%(?[\"'](.-)[\"']%)?", "local%s+%w+%s*=%s*require" },
        python = { "import%s+([%w%.]+)", "from%s+([%w%.]+)%s+import" },
        javascript = { "import%s+.-from%s+[\"'](.-)[\"']", "require%s*%([\"'](.-)[\"']%)" },
        typescript = { "import%s+.-from%s+[\"'](.-)[\"']", "require%s*%([\"'](.-)[\"']%)" },
        java = { "import%s+([%w%.]+)" },
        go = { "import%s+[\"'](.-)[\"']" },
        rust = { "use%s+([%w:]+)" },
        c = { "#include%s+[<\"](.-)[>\"]" },
        cpp = { "#include%s+[<\"](.-)[>\"]" },
    }
    
    local patterns = import_patterns[filetype] or {}
    
    for _, line in ipairs(lines) do
        for _, pattern in ipairs(patterns) do
            local match = line:match(pattern)
            if match then
                table.insert(imports, match)
            end
        end
    end
    
    return imports
end

-- Extract functions from code
function M.extract_functions(content, filetype)
    local functions = {}
    local lines = vim.split(content, "\n")
    
    local function_patterns = {
        lua = { 
            "function%s+([%w_%.]+)%s*%(",
            "local%s+function%s+([%w_]+)%s*%(",
            "([%w_]+)%s*=%s*function%s*%("
        },
        python = { 
            "def%s+([%w_]+)%s*%(",
            "class%s+([%w_]+)%s*%("
        },
        javascript = { 
            "function%s+([%w_]+)%s*%(",
            "const%s+([%w_]+)%s*=%s*function",
            "([%w_]+)%s*:%s*function%s*%(",
            "([%w_]+)%s*=%s*%([^%)]*%)%s*=>",
            "class%s+([%w_]+)%s*{"
        },
        typescript = { 
            "function%s+([%w_]+)%s*%(",
            "const%s+([%w_]+)%s*=%s*function",
            "([%w_]+)%s*:%s*function%s*%(",
            "([%w_]+)%s*=%s*%([^%)]*%)%s*=>",
            "class%s+([%w_]+)%s*{"
        },
        java = { 
            "public%s+[%w<>%[%]]+%s+([%w_]+)%s*%(",
            "private%s+[%w<>%[%]]+%s+([%w_]+)%s*%(",
            "protected%s+[%w<>%[%]]+%s+([%w_]+)%s*%(",
            "class%s+([%w_]+)%s*{"
        },
        go = { 
            "func%s+([%w_]+)%s*%(",
            "type%s+([%w_]+)%s+struct"
        },
        rust = { 
            "fn%s+([%w_]+)%s*%(",
            "struct%s+([%w_]+)%s*{"
        },
        c = { 
            "[%w*]+%s+([%w_]+)%s*%([^%)]*%)%s*{"
        },
        cpp = { 
            "[%w*:]+%s+([%w_:]+)%s*%([^%)]*%)%s*{"
        },
    }
    
    local patterns = function_patterns[filetype] or {}
    
    for line_num, line in ipairs(lines) do
        for _, pattern in ipairs(patterns) do
            local match = line:match(pattern)
            if match then
                table.insert(functions, {
                    name = match,
                    line = line_num,
                    content = line:gsub("^%s*", "")
                })
            end
        end
    end
    
    return functions
end

-- Extract comments from code
function M.extract_comments(content, filetype)
    local comments = {}
    local lines = vim.split(content, "\n")
    
    local comment_patterns = {
        lua = { "^%s*%-%-(.*)$" },
        python = { "^%s*#(.*)$" },
        javascript = { "^%s*//(.*)$", "^%s*%*(.*)$" },
        typescript = { "^%s*//(.*)$", "^%s*%*(.*)$" },
        java = { "^%s*//(.*)$", "^%s*%*(.*)$" },
        go = { "^%s*//(.*)$" },
        rust = { "^%s*//(.*)$" },
        c = { "^%s*//(.*)$", "^%s*%*(.*)$" },
        cpp = { "^%s*//(.*)$", "^%s*%*(.*)$" },
    }
    
    local patterns = comment_patterns[filetype] or {}
    
    for line_num, line in ipairs(lines) do
        for _, pattern in ipairs(patterns) do
            local match = line:match(pattern)
            if match and match:gsub("^%s*", "") ~= "" then
                table.insert(comments, {
                    line = line_num,
                    content = match:gsub("^%s*", "")
                })
            end
        end
    end
    
    return comments
end

-- Get visual selection
function M.get_visual_selection()
    local mode = vim.fn.mode()
    
    if mode == "v" or mode == "V" or mode == "\22" then
        -- Get selection range
        local start_pos = vim.fn.getpos("'<")
        local end_pos = vim.fn.getpos("'>")
        
        local start_line = start_pos[2]
        local start_col = start_pos[3]
        local end_line = end_pos[2]
        local end_col = end_pos[3]
        
        -- Get selected text
        local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
        
        if #lines == 0 then
            return nil
        end
        
        -- Handle single line selection
        if #lines == 1 then
            local line = lines[1]
            if mode == "v" then
                lines[1] = line:sub(start_col, end_col)
            else
                lines[1] = line
            end
        else
            -- Handle multi-line selection
            if mode == "v" then
                lines[1] = lines[1]:sub(start_col)
                lines[#lines] = lines[#lines]:sub(1, end_col)
            end
        end
        
        return {
            content = table.concat(lines, "\n"),
            start_line = start_line,
            end_line = end_line,
            start_col = start_col,
            end_col = end_col,
            mode = mode,
        }
    else
        -- Get current line if no selection
        local line = vim.api.nvim_get_current_line()
        local line_num = vim.api.nvim_win_get_cursor(0)[1]
        
        return {
            content = line,
            start_line = line_num,
            end_line = line_num,
            start_col = 1,
            end_col = #line,
            mode = "line",
        }
    end
end

-- Get cursor context
function M.get_cursor_context(context_lines)
    context_lines = context_lines or config.get("chat.context_lines")
    
    local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
    local total_lines = vim.api.nvim_buf_line_count(0)
    
    local start_line = math.max(1, cursor_line - math.floor(context_lines / 2))
    local end_line = math.min(total_lines, start_line + context_lines - 1)
    
    local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
    
    return {
        content = table.concat(lines, "\n"),
        start_line = start_line,
        end_line = end_line,
        cursor_line = cursor_line,
        total_lines = total_lines,
    }
end

-- Format file size
function M.format_file_size(size)
    local units = { "B", "KB", "MB", "GB" }
    local unit_index = 1
    
    while size >= 1024 and unit_index < #units do
        size = size / 1024
        unit_index = unit_index + 1
    end
    
    return string.format("%.2f %s", size, units[unit_index])
end

-- Format duration
function M.format_duration(seconds)
    if seconds < 60 then
        return string.format("%ds", seconds)
    elseif seconds < 3600 then
        return string.format("%dm %ds", math.floor(seconds / 60), seconds % 60)
    else
        return string.format("%dh %dm %ds", 
            math.floor(seconds / 3600), 
            math.floor((seconds % 3600) / 60), 
            seconds % 60)
    end
end

-- Escape special characters for regex
function M.escape_regex(str)
    return str:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
end

-- Split string by delimiter
function M.split_string(str, delimiter)
    delimiter = delimiter or "%s"
    local result = {}
    
    for match in str:gmatch("([^" .. delimiter .. "]+)") do
        table.insert(result, match)
    end
    
    return result
end

-- Trim whitespace
function M.trim_string(str)
    return str:match("^%s*(.-)%s*$")
end

-- Check if string is empty or whitespace
function M.is_empty_string(str)
    return not str or str:match("^%s*$")
end

-- Get file extension
function M.get_file_extension(filename)
    return filename:match("%.([^%.]+)$")
end

-- Get file name without extension
function M.get_file_basename(filename)
    return filename:match("(.+)%..+$") or filename
end

-- Check if file exists
function M.file_exists(filename)
    local file = io.open(filename, "r")
    if file then
        file:close()
        return true
    end
    return false
end

-- Read file content
function M.read_file(filename)
    local file = io.open(filename, "r")
    if file then
        local content = file:read("*all")
        file:close()
        return content
    end
    return nil
end

-- Write file content
function M.write_file(filename, content)
    local file = io.open(filename, "w")
    if file then
        file:write(content)
        file:close()
        return true
    end
    return false
end

-- Get project root directory
function M.get_project_root()
    local current_dir = vim.fn.getcwd()
    local markers = { ".git", ".hg", ".svn", "package.json", "Cargo.toml", "go.mod", "pyproject.toml" }
    
    local dir = current_dir
    while dir ~= "/" do
        for _, marker in ipairs(markers) do
            if vim.fn.isdirectory(dir .. "/" .. marker) == 1 or vim.fn.filereadable(dir .. "/" .. marker) == 1 then
                return dir
            end
        end
        dir = vim.fn.fnamemodify(dir, ":h")
    end
    
    return current_dir
end

-- Get relative path from project root
function M.get_relative_path(filename)
    local project_root = M.get_project_root()
    local relative_path = filename:gsub("^" .. M.escape_regex(project_root), "")
    return relative_path:gsub("^/", "")
end

-- Log message
function M.log(level, message)
    local log_level = config.get("log.level")
    local log_levels = { trace = 1, debug = 2, info = 3, warn = 4, error = 5 }
    
    if log_levels[level] and log_levels[log_level] and log_levels[level] >= log_levels[log_level] then
        local timestamp = os.date("%Y-%m-%d %H:%M:%S")
        local log_message = string.format("[%s] %s: %s", timestamp, level:upper(), message)
        
        local log_file = config.get("log.file")
        if log_file then
            local file = io.open(log_file, "a")
            if file then
                file:write(log_message .. "\n")
                file:close()
            end
        end
        
        -- Also print to console for debugging
        print(log_message)
    end
end

-- Debounce function
function M.debounce(func, delay)
    local timer = nil
    return function(...)
        local args = {...}
        if timer then
            timer:stop()
        end
        timer = vim.defer_fn(function()
            func(unpack(args))
        end, delay)
    end
end

-- Throttle function
function M.throttle(func, delay)
    local last_call = 0
    return function(...)
        local now = vim.loop.now()
        if now - last_call >= delay then
            last_call = now
            func(...)
        end
    end
end

-- Deep copy table
function M.deep_copy(orig)
    local copy
    if type(orig) == "table" then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[M.deep_copy(orig_key)] = M.deep_copy(orig_value)
        end
        setmetatable(copy, M.deep_copy(getmetatable(orig)))
    else
        copy = orig
    end
    return copy
end

-- Merge tables
function M.merge_tables(...)
    local result = {}
    for _, table in ipairs({...}) do
        for key, value in pairs(table) do
            result[key] = value
        end
    end
    return result
end

-- Check if table contains value
function M.table_contains(table, value)
    for _, v in ipairs(table) do
        if v == value then
            return true
        end
    end
    return false
end

-- Get table keys
function M.table_keys(table)
    local keys = {}
    for key, _ in pairs(table) do
        table.insert(keys, key)
    end
    return keys
end

-- Get table values
function M.table_values(table)
    local values = {}
    for _, value in pairs(table) do
        table.insert(values, value)
    end
    return values
end

return M 