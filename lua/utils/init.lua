-- @deprecated: use actions.open_file instead
local open_file = function(filepath, ctx)
    vim.notify(
        "utils.open_file is deprecated. Please use actions.open_file instead.",
        vim.log.levels.WARN)
    vim.api.nvim_set_current_win(ctx.win_origin)
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

local function get_max_title_length(items)
    local max = 0
    for _, item in pairs(items) do
        if (item.title and #item.title > max) then max = #item.title end
    end
    return max
end

local U = {
    get_filename = get_filename,
    get_home_path = get_home_path,
    get_max_title_length = get_max_title_length,
    get_metatable_field = get_metatable_field,
    is_git_directory = is_git_directory,
    open_file = open_file,
    remove_home_path = remove_home_path
}

return U
