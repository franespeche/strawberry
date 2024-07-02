local open_file = function(filepath, ctx)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_win(ctx.target_win)
    vim.api.nvim_win_set_buf(ctx.target_win, buf)
    vim.cmd('e ' .. filepath)
end

local function get_metatable_field(obj, field)
    local mt = getmetatable(obj)
    if mt and mt.__index then return mt.__index[field] end
    return nil
end

local function get_home_path() return os.getenv("HOME") end

local function remove_home_path(filepath)
    local home = get_home_path()
    return string.gsub(filepath, home .. "/", "")
end

local function get_filename(path)
    local pattern = "/([^/]+)$"
    return path:match(pattern) or "-"
end

local function is_git_directory()
    return vim.api.nvim_exec("!git rev-parse --is-inside-work-tree", true)
end

local function set_buffer_options(buf)
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

local table_utils = {
    merge = function(t1, t2) for k, v in pairs(t2) do t1[k] = v end end
}

local U = {
    table_utils = table_utils,
    get_filename = get_filename,
    get_home_path = get_home_path,
    get_max_title_length = get_max_title_length,
    get_metatable_field = get_metatable_field,
    is_git_directory = is_git_directory,
    open_file = open_file,
    remove_home_path = remove_home_path,
    set_buffer_options = set_buffer_options
}

return U
