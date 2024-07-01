-- Imports
local Item = require('Item')
local utils = require('utils')
local table_utils = utils.table_utils

-- Helpers
-- Deletes buffer
local function delete_buffer(buf) vim.api.nvim_buf_delete(buf, {force = true}) end

-- Deletes buffers by filetype
local function delete_buffers_by_filetype(filetype)
    local buffers = vim.api.nvim_list_bufs()

    for _, buf in ipairs(buffers) do
        if vim.api.nvim_buf_is_loaded(buf) then
            local buf_filetype = vim.api.nvim_buf_get_option(buf, 'filetype')
            if buf_filetype == filetype then delete_buffer(buf) end
        end
    end
end

local function delete_strawberry_buffers()
    delete_buffers_by_filetype('strawberry')
end

-- Set autocommand to close buffer on BufLeave or on item selection
local function set_auto_close(config)
    -- Clear any existing autocommands to support different pickers with different auto_close configs
    local augroup = vim.api.nvim_create_augroup("Strawberry", {clear = true})
    vim.api.nvim_clear_autocmds({group = augroup})

    -- Create autocommand to close buffer on StrawberrySelect
    -- vim.api.nvim_create_user_command('StrawberrySelect', function()
    -- Strawberry:render()
    -- if (config.close_on_select) then delete_strawberry_buffers() end
    -- end, {nargs = '?'})

    -- Create autocommand to close buffer on BufLeave
    if (config.close_on_leave) then
        vim.api.nvim_create_autocmd('BufLeave', {
            pattern = "*",
            group = augroup,
            callback = function()
                if (vim.bo.filetype == "strawberry") then
                    return vim.api.nvim_command('StrawberryClose')
                end
            end
        })
    end
end

-- Validates setup props
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

-- Constants
local BASE_CONFIG = {
    window_height = 5, -- height of the strawberry window
    close_on_leave = false, -- close on BufLeave
    close_on_select = true, -- close on item selection
    keymaps = {
        close = {"<esc>"}, -- Not yet supported
        select_item = {"<cr>"}
    }
}

-- Strawberry
local Strawberry = {items = {}, ctx = {}, pickers = {}, config = BASE_CONFIG}

-- Validates a picker
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

-- Registers pickers to Strawberry
function Strawberry:register_picker(picker) table.insert(self.pickers, picker) end

-- Parses items to be rendered by Strawberry
function Strawberry:get_stringified_items(items)
    local lines = {}
    local max_title_length = utils.get_max_title_length(items)
    for _, item in pairs(items) do
        table.insert(lines, item:to_string(max_title_length))
    end
    return lines
end

-- Renders Strawberry buffer
function Strawberry:render()
    local items = self.items
    -- Open new split
    local height = vim.fn.min({#items, self.config.window_height}) + 1
    vim.cmd('botright ' .. height .. ' split')

    -- Save buffer's context metadata
    self.ctx.strawberry_win = vim.api.nvim_get_current_win()
    self.ctx.strawberry_buf = vim.api.nvim_create_buf(false, true)

    -- Set buffer options
    -- TODO: move this to a "Strawberry" Filetype autocommand
    utils.set_options(self.ctx.strawberry_buf)

    -- Set buffer content
    local lines = self:get_stringified_items(items)
    vim.api.nvim_buf_set_lines(self.ctx.strawberry_buf, 0, #lines, false, lines)
    vim.api.nvim_win_set_buf(self.ctx.strawberry_win, self.ctx.strawberry_buf)

    -- Lock buffer
    -- TODO: move this to a "Strawberry" Filetype autocommand
    vim.api.nvim_buf_set_option(self.ctx.strawberry_buf, 'modifiable', false)

    -- Set highlights
    -- TODO: move this to a "Strawberry" Filetype autocommand
    utils.set_highlights()

    -- Set keymap for executing items
    -- for each keymap in tuple self.config.keymaps, set a keymap that will execute the item
    for _, keymap in ipairs(self.config.keymaps.select_item) do
        vim.keymap.set("n", keymap, function()
            -- TODO: move this logic to StrawberrySelect command
            local item_index = vim.api.nvim_win_get_cursor(0)[1]
            self.items[item_index]:execute(self.ctx)
            return vim.api.nvim_command('StrawberrySelect ' ..
                                            tostring(item_index))
        end, {silent = true, buffer = self.ctx.strawberry_buf})
    end

    for _, keymap in ipairs(self.config.keymaps.close) do
        vim.keymap.set("n", keymap, function()
            return vim.api.nvim_command('StrawberryClose')
        end, {silent = true, buffer = self.ctx.strawberry_buf})
    end

    -- Set uniq hotkeys for each item
    for i, item in ipairs(items) do
        local key = item.key
        -- Break if key is nil or key is more than one character
        if (not key or #key > 1) then break end
        vim.keymap.set("n", tostring(key),
                       function() self.items[i]:execute(self.ctx) end,
                       {silent = true, buffer = self.ctx.strawberry_buf})
    end
end

-- Get picker by name
function Strawberry:get_picker(picker_name)
    for _, picker in pairs(self.pickers) do
        if (picker.name == picker_name) then return picker end
    end
    return nil
end

function Strawberry:setup(props)
    setmetatable(self, {__index = Strawberry})

    -- Validate props
    validate_setup_props(props)

    -- Register pickers
    for _, picker in pairs(props.pickers or {}) do
        if (Strawberry:validate_picker(picker)) then
            Strawberry:register_picker(picker)
        end
    end

    -- Register configs
    table_utils.merge(self.config, props.config)

    -- Create init command
    vim.api.nvim_create_user_command('Strawberry', function(args)
        local picker_name = args.args
        if (picker_name == "") then
            return error("Attempted to launch Strawberry with no picker name")
        end
        return Strawberry:init(picker_name)
    end, {nargs = '?'})
end

function Strawberry:unlock()
    -- Unlock buffer
    vim.api.nvim_buf_set_option(self.ctx.strawberry_buf, 'modifiable', true)
end

function Strawberry:lock()
    -- Unlock buffer
    vim.api.nvim_buf_set_option(self.ctx.strawberry_buf, 'modifiable', false)
end

local function create_commands(config)
    vim.api.nvim_create_user_command('StrawberryClose', function()
        return delete_strawberry_buffers()
    end, {nargs = '?'})
    vim.api.nvim_create_user_command('StrawberrySelect', function(args)
        local item_index = args.args
        P(item_index)
        -- this needs to be 
        Strawberry:redraw()
        if (config.close_on_select) then
            return vim.api.nvim_command('StrawberryClose')
        end
    end, {nargs = '?'})
end

-- TODO: revisit this logic
function Strawberry:redraw()
    Strawberry:unlock()
    local items = self.picker.get_items()
    -- Add key to each item
    for i, item in ipairs(items) do
        local key = utils.get_hotkey(i)
        item.key = key or "·"
    end
    self.items = items
    local lines = self:get_stringified_items(items)
    vim.api.nvim_buf_set_lines(self.ctx.strawberry_buf, 0, #lines, false, lines)
    Strawberry:lock()
end

-- Strawberry refers to the buffer that contains the list of items
-- The target refers to the buffer that Strawberry was launched from. 
--  In other words, the buffer that Strawberry is interacting with
function Strawberry:init(picker_name)
    local picker = self:get_picker(picker_name)
    if (not picker) then
        return error("No registered picker under name: " .. picker_name)
    end
    -- TODO: check this
    self.picker = picker

    -- Close any existing strawberry buffers
    delete_strawberry_buffers()

    -- Merge picker's config with Strawberry's base config
    table_utils.merge(self.config, picker.config)

    -- Auto close Strawberry on BufLeave
    set_auto_close(self.config)

    create_commands(self.config)

    -- Save the target's screen buffer and window into the ctx object
    self.ctx.target_buf = vim.api.nvim_get_current_buf()
    self.ctx.target_win = vim.api.nvim_get_current_win()

    -- Get items
    local items = picker.get_items()
    -- Add key to each item
    for i, item in ipairs(items) do
        local key = utils.get_hotkey(i)
        item.key = key or "·"
    end
    self.items = items

    -- Render Strawberry
    self:render()
end

return {
    setup = Strawberry.setup,
    create_item = function(opts) return Item:create(opts) end,
    -- public utils
    utils = {
        get_filename = utils.get_filename,
        get_home_path = utils.get_home_path,
        is_git_directory = utils.is_git_directory,
        open_file = utils.open_file,
        remove_home_path = utils.remove_home_path
    }
}
