-- Imports
local Item = require('Item')
local utils = require('utils')

-- Helpers
local function delete_buffer(buf) vim.api.nvim_buf_delete(buf, {force = true}) end

local function set_auto_close(config)
    -- Clear any existing autocommands to support different pickers with potential different auto_close configs
    local augroup = vim.api.nvim_create_augroup("Strawberry", {clear = true})
    vim.api.nvim_clear_autocmds({group = augroup})

    -- Create autocommand to close buffer on BufLeave
    if (config.auto_close) then
        vim.api.nvim_create_autocmd('BufLeave', {
            pattern = "*",
            group = augroup,
            -- once = true,
            callback = function(e)
                if (vim.bo.filetype == "strawberry") then
                    delete_buffer(e.buf)
                end
            end
        })
    end
end

local function delete_buffers_by_filetype(filetype, picker)
    -- Get a list of all buffer handles
    local buffers = vim.api.nvim_list_bufs()

    -- Iterate over each buffer handle
    for _, buf in ipairs(buffers) do
        -- Check if the buffer is loaded and the filetype matches
        if vim.api.nvim_buf_is_loaded(buf) then
            local buf_filetype = vim.api.nvim_buf_get_option(buf, 'filetype')
            if buf_filetype == filetype then
                -- Perform the desired picker on the buffer
                picker(buf)
            end
        end
    end
end

-- Constants
local DEFAULT_CONFIG = {window_height = 5, auto_close = true}

-- Strawberry
local Strawberry = {ctx = {}, pickers = {}, config = DEFAULT_CONFIG}

-- Validates picker
function Strawberry:validate_picker(picker)
    -- validate fields
    if (not picker.name) then
        error('"picker.name" must be defined')
        return false
    end
    if (type(picker.name) ~= 'string') then
        error('"picker.name" must be of type "string"')
        return false
    end

    if (not picker.get_items) then
        error('"picker.get_items" must be defined')
        return false
    end
    if (type(picker.get_items) ~= 'function') then
        error('"picker.get_items" must be of type "function"')
        return false
    end

    -- check if the picker already exists
    for _, registered_picker in pairs(self.pickers) do
        if (registered_picker.name == picker.name) then return false end
    end
    return true
end

-- Registrators
function Strawberry:register_picker(picker)
    -- Register picker
    table.insert(self.pickers, picker)
end

function Strawberry:get_parsed_items(items)
    local lines = {}
    local max_title_length = utils.get_max_title_length(items)
    for _, item in pairs(items) do
        table.insert(lines, item:get_line_content(max_title_length))
    end
    return lines
end

-- Renders strawberry
function Strawberry:render(lines)
    -- Open new split
    local height = vim.fn.min({#lines, self.config.window_height}) + 1
    vim.cmd('botright ' .. height .. ' split')

    local strawberry_win = vim.api.nvim_get_current_win()
    local strawberry_buf = vim.api.nvim_create_buf(false, true)
    self.ctx.strawberry_win = strawberry_win
    self.ctx.strawberry_buf = strawberry_buf

    -- Set strawberry options
    utils.set_options(strawberry_buf)

    -- Fill strawberry and focus
    vim.api.nvim_buf_set_lines(strawberry_buf, 0, #lines, false, lines)
    vim.api.nvim_win_set_buf(strawberry_win, strawberry_buf)

    -- Lock strawberry
    vim.api.nvim_buf_set_option(strawberry_buf, 'modifiable', false)

    utils.set_highlights()

    -- <CR> handler
    vim.keymap.set("n", "<cr>", function()
        local num = vim.api.nvim_win_get_cursor(0)[1]
        self.items[num]:execute(self.config)
    end, {silent = true, buffer = strawberry_buf})
end

function Strawberry:get_picker(picker_name)
    for _, picker in pairs(self.pickers) do
        if (picker.name == picker_name) then return picker end
    end
    return nil
end

local function validate_setup_props(props)
    if (vim.tbl_isempty(props or {})) then
        return error('Called setup() method without any props')
    end
    -- pickers
    if (not props.pickers) then
        return error('Called setup() method with no pickers')
    end
    -- config
    if (props.config) then
        if (props.config.window_height and type(props.config.window_height) ~=
            'number') then
            return error('config.window_height must be a number')
        end
        if (props.config.auto_close and type(props.config.auto_close) ~=
            'boolean') then
            return error('config.auto_close must be a boolean')
        end

    end
end

function Strawberry:setup(props)
    setmetatable(self, {__index = Strawberry})
    -- TODO: should we _not_ use the same metatable for Item?
    setmetatable(Item, {__index = Strawberry})

    -- Validate props
    validate_setup_props(props)

    -- Register pickers
    for _, picker in pairs(props.pickers or {}) do
        if (Strawberry:validate_picker(picker)) then
            Strawberry:register_picker(picker)
        end
    end

    -- Register configs
    for k, v in pairs(props.config or {}) do self.config[k] = v end

    -- Create autocommands
    vim.api.nvim_create_user_command('Strawberry', function(args)
        local picker_name = args.args
        if (picker_name == "") then
            return error("Attempted to launch Strawberry with no picker name")
        end
        return Strawberry:init(picker_name)
    end, {nargs = '?'})
end

-- Strawberry refers to the buffer that contains the list of items
function Strawberry:init(picker_name)
    local picker = self:get_picker(picker_name)
    if (not picker) then
        return error("No registered picker under name: " .. picker_name)
    end

    -- Close any existing strawberry buffers
    delete_buffers_by_filetype('strawberry', delete_buffer)

    -- Merge configs
    for k, v in pairs(picker.config or {}) do self.config[k] = v end

    -- Auto close strawberry on BufLeave
    set_auto_close(self.config)

    -- Save context
    self.ctx.buf_origin = vim.api.nvim_get_current_buf()
    self.ctx.win_origin = vim.api.nvim_get_current_win()

    -- Each item constitutes a line in the strawberry
    self.items = picker.get_items()
    -- if (picker.delimiter) then self.delimiter = picker.delimiter end
    local parsed_items = self:get_parsed_items(self.items)

    -- Render strawberry
    self:render(parsed_items)
end

return {
    setup = Strawberry.setup,
    create_item = function(opts) return Item:create(opts) end,
    -- public utils
    utils = {
        is_git_directory = utils.is_git_directory,
        open_file = utils.open_file,
        get_home_path = utils.get_home_path,
        remove_home_path = utils.remove_home_path,
        get_filename = utils.get_filename
    }
}
