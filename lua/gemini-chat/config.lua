local M = {}

-- Default configuration
M.defaults = {
    -- Gemini CLI settings
    gemini_cli = {
        cmd = "gemini",
        model = "gemini-2.5-pro",
        temperature = 0.7,
        max_tokens = 2048,
        timeout = 30000, -- 30 seconds
    },
    
    -- Terminal settings
    terminal = {
        position = "right",
        width = 60,
        height = 30,
        shell = vim.o.shell,
        close_on_exit = false,
        start_in_insert = true,
    },
    
    -- Diff settings
    diff = {
        position = "split",
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
        system_prompt = "You are a helpful coding assistant integrated into Neovim. When suggesting code changes, provide clear, concise explanations and format your responses with proper diff markers when applicable.",
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
        pumblend = 0,
        signs = {
            add = "+",
            delete = "-",
            change = "~",
            suggestion = "💡",
        },
    },
    
    -- Auto-commands
    auto_commands = {
        update_context_on_save = true,
        update_context_on_buffer_enter = true,
        cleanup_on_exit = true,
    },
    
    -- Logging
    log = {
        level = "info", -- trace, debug, info, warn, error
        file = vim.fn.stdpath("data") .. "/gemini-chat.log",
        max_size = 1024 * 1024, -- 1MB
    },
}

-- Current configuration
M.config = {}

-- Setup configuration
function M.setup(opts)
    opts = opts or {}
    M.config = vim.tbl_deep_extend("force", M.defaults, opts)
    
    -- Validate configuration
    M.validate_config()
    
    -- Set up logging
    M.setup_logging()
end

-- Validate configuration
function M.validate_config()
    local config = M.config
    
    -- Validate gemini_cli settings
    if type(config.gemini_cli.cmd) ~= "string" or config.gemini_cli.cmd == "" then
        error("gemini_cli.cmd must be a non-empty string")
    end
    
    if type(config.gemini_cli.temperature) ~= "number" or 
       config.gemini_cli.temperature < 0 or 
       config.gemini_cli.temperature > 2 then
        error("gemini_cli.temperature must be a number between 0 and 2")
    end
    
    if type(config.gemini_cli.max_tokens) ~= "number" or 
       config.gemini_cli.max_tokens < 1 then
        error("gemini_cli.max_tokens must be a positive number")
    end
    
    -- Validate terminal settings
    if not vim.tbl_contains({"right", "left", "top", "bottom"}, config.terminal.position) then
        error("terminal.position must be one of: right, left, top, bottom")
    end
    
    if type(config.terminal.width) ~= "number" or config.terminal.width < 10 then
        error("terminal.width must be a number >= 10")
    end
    
    if type(config.terminal.height) ~= "number" or config.terminal.height < 5 then
        error("terminal.height must be a number >= 5")
    end
    
    -- Validate diff settings
    if not vim.tbl_contains({"split", "vsplit", "tab", "float"}, config.diff.position) then
        error("diff.position must be one of: split, vsplit, tab, float")
    end
    
    -- Validate chat settings
    if type(config.chat.context_lines) ~= "number" or config.chat.context_lines < 0 then
        error("chat.context_lines must be a non-negative number")
    end
    
    if type(config.chat.max_history_size) ~= "number" or config.chat.max_history_size < 1 then
        error("chat.max_history_size must be a positive number")
    end
    
    -- Validate log level
    if not vim.tbl_contains({"trace", "debug", "info", "warn", "error"}, config.log.level) then
        error("log.level must be one of: trace, debug, info, warn, error")
    end
end

-- Setup logging
function M.setup_logging()
    -- Create log directory if it doesn't exist
    local log_dir = vim.fn.fnamemodify(M.config.log.file, ":h")
    if vim.fn.isdirectory(log_dir) == 0 then
        vim.fn.mkdir(log_dir, "p")
    end
    
    -- Set up log rotation if file is too large
    local log_file = M.config.log.file
    if vim.fn.filereadable(log_file) == 1 then
        local size = vim.fn.getfsize(log_file)
        if size > M.config.log.max_size then
            -- Rotate log file
            local backup_file = log_file .. ".old"
            vim.fn.rename(log_file, backup_file)
        end
    end
end

-- Get configuration value
function M.get(key)
    local keys = vim.split(key, ".", { plain = true })
    local value = M.config
    
    for _, k in ipairs(keys) do
        if type(value) == "table" and value[k] ~= nil then
            value = value[k]
        else
            return nil
        end
    end
    
    return value
end

-- Set configuration value
function M.set(key, value)
    local keys = vim.split(key, ".", { plain = true })
    local config = M.config
    
    for i = 1, #keys - 1 do
        local k = keys[i]
        if type(config[k]) ~= "table" then
            config[k] = {}
        end
        config = config[k]
    end
    
    config[keys[#keys]] = value
end

-- Merge configuration
function M.merge(opts)
    M.config = vim.tbl_deep_extend("force", M.config, opts)
    M.validate_config()
end

-- Get all configuration
function M.get_all()
    return M.config
end

-- Reset to defaults
function M.reset()
    M.config = vim.deepcopy(M.defaults)
end

return M 