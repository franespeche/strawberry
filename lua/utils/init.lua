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

local function set_highlights()
    if (vim.fn.has("syntax")) then
        vim.cmd([[syntax clear]])
        vim.cmd([[syntax match strawberryLineKey /\v^\s\s((\d|\w))/ contained]])
        vim.cmd(
            [[syntax match strawberryTitle /\v^\s\s(\d|\w)\s+(.+)\s+/ contains=strawberryLineKey]])
        vim.cmd([[hi def link strawberryLineKey String]])
        vim.cmd([[hi def link strawberryTitle Type]])
    end
end

-- Gets an easy access hot_key for the given item index
local function get_key(i)
    local number_to_letter = {
        ["1"] = '1',
        ["2"] = '2',
        ["3"] = '3',
        ["4"] = 'q',
        ["5"] = 'w',
        ["6"] = 'e',
        ["7"] = 'a',
        ["8"] = 's',
        ["9"] = 'd',
        [10] = 'z',
        [11] = 'x',
        [12] = 'c',
        [13] = '4',
        [14] = 'r',
        [15] = 'f',
        [16] = 'v',
        [17] = 't',
        [18] = 'g',
        [19] = 'b',
        [20] = '6',
        [21] = "y",
        [22] = "h",
        [23] = "n",
        [24] = "7",
        [25] = "u",
        [26] = "j",
        [27] = "m",
        [28] = '8',
        [29] = "i",
        [30] = "k"
    }
    return number_to_letter[tostring(i)] or number_to_letter[i] or tostring(i)
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

local table_utils = {
    merge = function(t1, t2) for k, v in pairs(t2) do t1[k] = v end end
}

local U = {
    table_utils = table_utils,
    get_filename = get_filename,
    get_home_path = get_home_path,
    get_key = get_key,
    get_max_title_length = get_max_title_length,
    get_metatable_field = get_metatable_field,
    is_git_directory = is_git_directory,
    open_file = open_file,
    remove_home_path = remove_home_path,
    set_highlights = set_highlights,
    set_options = set_options
}

return U
