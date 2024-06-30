local open_file = function(file, ctx)
    vim.api.nvim_buf_delete(ctx.buf, {})
    -- TODO: possible bug, maybe if possible we should use the buffer from where we came from instead of creating a new one
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_win_set_buf(ctx.win_origin, buf)
    vim.cmd('e ' .. file)
end

local function get_home_path() return os.getenv("HOME") end

local function remove_home_path(file)
    local home = get_home_path()
    return string.gsub(file, home .. "/", "")
end

local function get_filename(path)
    local pattern = "/([^/]+)$"
    return path:match(pattern) or "-"
end

local function is_git_directory()
    return vim.api.nvim_exec("!git rev-parse --is-inside-work-tree", true)
end

local function set_highlights()
    if (vim.fn.has("syntax")) then
        vim.cmd([[syntax clear]])
        vim.cmd([[syntax match strawberryLineNum /\v^\s\s(\d+)/ contained]])
        vim.cmd(
            [[syntax match strawberryKey /\v^\s\s\d+\s+(.+)\s+/ contains=strawberryLineNum]])
        vim.cmd([[hi def link strawberryLineNum String]])
        vim.cmd([[hi def link strawberryKey Type]])
    end
end

local function set_options(buf)
    vim.api.nvim_buf_set_option(buf, 'modifiable', true)
    vim.api.nvim_set_option('number', false)
    vim.api.nvim_set_option('relativenumber', false)
    vim.api.nvim_set_option('foldcolumn', "0")
    vim.api.nvim_set_option('foldenable', false)
    vim.api.nvim_set_option('cursorline', true)
    vim.api.nvim_set_option('spell', false)
    vim.api.nvim_set_option('wrap', false)
    vim.api.nvim_buf_set_option(buf, 'filetype', "strawberry")
    vim.api.nvim_buf_set_option(buf, 'buflisted', false)
    vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
    vim.api.nvim_buf_set_option(buf, 'swapfile', false)
end

local function get_max_title_length(items)
    local max = 0
    for _, item in pairs(items) do
        if (item.title and #item.title > max) then max = #item.title end
    end
    return max
end
local M = {
    set_options = set_options,
    set_highlights = set_highlights,
    get_max_title_length = get_max_title_length,
    is_git_directory = is_git_directory,
    open_file = open_file,
    get_home_path = get_home_path,
    remove_home_path = remove_home_path,
    get_filename = get_filename
}

return M
