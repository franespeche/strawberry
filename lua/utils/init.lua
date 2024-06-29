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

local M = {
    is_git_directory = is_git_directory,
    open_file = open_file,
    get_home_path = get_home_path,
    remove_home_path = remove_home_path,
    get_filename = get_filename
}

return M
