-- Imports --
local Item = require('Item')
local utils = require('utils')
local table_utils = utils.table_utils
local actions = require('actions')

-- Helpers --

local function get_single_character_keymaps(config)
    local single_char_keys = {}

    for _, keymap in pairs(config.keymaps) do
        for _, key in ipairs(keymap) do
            if #key == 1 then table.insert(single_char_keys, key) end
        end
    end

    return single_char_keys
end

-- Get available keys for the items, excluding the ones used by any existing keymap
local function get_available_keys(config)
    local keys = "123qweasdzxc4rfv5tgb6y7umABCDEFGHIJLKLMNOPQRSTUVWXYZ"
    local single_char_keys = get_single_character_keymaps(config)

    local available_keys = {}
    for key in keys:gmatch(".") do available_keys[key] = true end

    for _, key in ipairs(single_char_keys) do available_keys[key] = nil end

    local result = ""
    for key in keys:gmatch(".") do
        if available_keys[key] then result = result .. key end
    end

    return result
end

-- Deletes a buffer
local function delete_buffer(buf) vim.api.nvim_buf_delete(buf, {force = true}) end

-- Deletes buffers by filetype
local function delete_buffers_by_filetype(filetype)
    local buffers = vim.api.nvim_list_bufs()
    for _, buf in ipairs(buffers) do
        if vim.api.nvim_buf_is_loaded(buf) then
            if vim.api.nvim_buf_get_option(buf, 'filetype') == filetype then
                delete_buffer(buf)
            end
        end
    end
end

-- Clears autocommands for a given augroup
local function clear_autocmds(augroup)
    vim.api.nvim_clear_autocmds({group = augroup})
end

-- Validates setup props
local function validate_setup_props(props)
    if (vim.tbl_isempty(props or {})) then
        return error('Called setup() method without any props')
    end
    -- Pickers
    if (not props.pickers) then
        return error('Called setup() method with no pickers')
    end
    -- Config
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

-- Enums --
local Commands = {
    REDRAW = "StrawberryRedraw",
    CLOSE = "StrawberryClose",
    SELECT = "StrawberrySelect",
    DELETE = "StrawberryDelete"
}

-- Constants --
local STRAWBERRY_FILETYPE = "strawberry"
local STRAWBERRY_AUGROUP = "Strawberry"

-- Strawberry --
local Strawberry = {
    items = {},
    pickers = {},
    config = {
        window_height = 5, -- height of the strawberry window
        close_on_leave = false, -- close on BufLeave
        close_on_select = true, -- close on item selection
        keymaps = {close = {"q"}, select_item = {"<cr>"}}
    },
    picker = nil,
    ctx = {
        win_origin = nil, -- window where Strawberry was launched from
        buf_origin = nil, -- buffer where Strawberry was launched from
        cursor_line = nil, -- the cursor's line position where an item was selected
        cursor_column = nil, -- the cursor's column position where an item was selected
        window = nil, -- window where Strawberry is rendered
        buffer = nil -- buffer where Strawberry is rendered
    }
}

function Strawberry:setup(props)
    validate_setup_props(props)
    setmetatable(self, {__index = Strawberry})

    Strawberry:register_pickers(props.pickers)
    Strawberry:register_config(props.config)
    -- Create init command
    vim.api.nvim_create_user_command('Strawberry', function(args)
        local picker_name = args.args
        if (picker_name == "") then
            return error("Attempted to launch Strawberry with no picker name")
        end
        return Strawberry:init(picker_name)
    end, {nargs = '?'})
end

-- Initialize Strawberry
function Strawberry:init(picker_name)
    -- Close any existing Strawberry
    Strawberry:close()
    Strawberry:apply_picker(picker_name)
    Strawberry:register_config(self.active_picker.config)
    Strawberry:register_items()
    Strawberry:register_ctx()
    Strawberry:register_listeners()
    Strawberry:create_window()
    Strawberry:apply_keymaps()
    Strawberry:render()
end

local function get_cursor_position(win)
    local cursor = vim.api.nvim_win_get_cursor(win)
    local line = cursor[1]
    local column = cursor[2]
    return line, column
end

-- Creates commands and event listeners
function Strawberry:register_listeners()
    -- Clear any existing autocommands to support pickers with different configs
    local augroup = vim.api.nvim_create_augroup(STRAWBERRY_AUGROUP,
                                                {clear = true})
    clear_autocmds(augroup)

    -- Event Listeners --
    -- Set highlights
    vim.api.nvim_create_autocmd('FileType', {
        pattern = STRAWBERRY_FILETYPE,
        callback = function()
            if (vim.fn.has("syntax")) then
                vim.cmd([[syntax clear]])
                vim.cmd(
                    [[syntax match strawberryLineKey /\v^\s\s((\d|\w|·))/ contained]])
                vim.cmd(
                    [[syntax match strawberryTitle /\v^\s\s(\d|\w|·)\s+(.+)\s+/ contains=strawberryLineKey]])
                vim.cmd([[hi def link strawberryLineKey String]])
                vim.cmd([[hi def link strawberryTitle Type]])
            end
        end
    })

    -- Handle BufLeave
    if (self.config.close_on_leave) then
        vim.api.nvim_create_autocmd('BufLeave', {
            pattern = "*",
            group = augroup,
            callback = function()
                if (vim.bo.filetype == STRAWBERRY_FILETYPE) then
                    vim.api.nvim_command(Commands.CLOSE)
                end
            end
        })
    end

    -- Commands Listeners --
    -- Handle Reset
    vim.api.nvim_create_user_command(Commands.REDRAW,
                                     function() Strawberry:reset() end,
                                     {nargs = '?'})

    -- Handle Delete
    vim.api.nvim_create_user_command(Commands.DELETE, function(args)
        local item_index = tonumber(args.args)
        self.items[item_index]:delete()
        Strawberry:reset()
    end, {nargs = '?'})

    -- Handle Close
    vim.api.nvim_create_user_command(Commands.CLOSE,
                                     function() Strawberry:close() end,
                                     {nargs = '?'})

    -- Handle Select
    vim.api.nvim_create_user_command(Commands.SELECT, function(args)
        local item_index = tonumber(args.args)

        local line, column = get_cursor_position(self.ctx.window)
        self.ctx.cursor_line = line
        self.ctx.cursor_column = column

        self.items[item_index]:execute(self.ctx)
        if (self.config.close_on_select) then
            vim.api.nvim_command(Commands.CLOSE)
        else
            vim.api.nvim_command(Commands.REDRAW)
        end
    end, {nargs = '?'})
end

function Strawberry:close()
    Strawberry:clear_keymaps()
    delete_buffers_by_filetype(STRAWBERRY_FILETYPE)
    self.ctx.window = nil
    self.ctx.buffer = nil
end

-- Validates a picker
function Strawberry:validate_picker(picker)
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

-- Parses items into lines to be rendered by Strawberry
local function get_lines(items)
    local lines = {}
    local max_title_length = utils.get_max_title_length(items)
    for _, item in pairs(items) do
        table.insert(lines, item:to_string(max_title_length))
    end
    return lines
end

-- Register keymaps for the Strawberry buffer
function Strawberry:apply_keymaps()
    -- Select item
    if (self.config.keymaps.select_item) then
        for _, keymap in ipairs(self.config.keymaps.select_item) do
            vim.keymap.set("n", keymap, function()
                local item_index = vim.api.nvim_win_get_cursor(0)[1]
                vim.api.nvim_command(Commands.SELECT .. tostring(item_index))
            end, {silent = true, buffer = self.ctx.buffer})
        end
    end

    -- Delete item
    if (self.config.keymaps.delete_item) then
        for _, keymap in ipairs(self.config.keymaps.delete_item) do
            vim.keymap.set("n", keymap, function()
                local item_index = vim.api.nvim_win_get_cursor(0)[1]
                return vim.api.nvim_command(Commands.DELETE ..
                                                tostring(item_index))
            end, {silent = true, buffer = self.ctx.buffer})
        end
    end

    -- Close Strawberry
    if (self.config.keymaps.close) then
        for _, keymap in ipairs(self.config.keymaps.close) do
            vim.keymap.set("n", keymap, function()
                return vim.api.nvim_command(Commands.CLOSE)
            end, {silent = true, buffer = self.ctx.buffer})
        end
    end

    -- Keymaps for each item
    for i, item in ipairs(self.items) do
        local key = item.key
        -- Break if key is nil or longer than one character
        if (not key or #key > 1) then break end
        vim.keymap.set("n", tostring(key), function()
            vim.api.nvim_command(Commands.SELECT .. tostring(i))
        end, {silent = true, buffer = self.ctx.buffer})
    end
end

-- Renders Strawberry buffer
function Strawberry:render()
    Strawberry:wipe_buffer(self.ctx.buffer)
    -- Set buffer content
    Strawberry:modifiable(true)
    local lines = get_lines(self.items)
    vim.api.nvim_buf_set_lines(self.ctx.buffer, 0, #lines, false, lines)
    vim.api.nvim_win_set_buf(self.ctx.window, self.ctx.buffer)
    Strawberry:modifiable(false)
end

-- Get picker by name
function Strawberry:get_picker(picker_name)
    for _, picker in pairs(self.pickers) do
        if (picker.name == picker_name) then return picker end
    end
    return nil
end

-- Set the buffer as modifiable/non-modifiable
function Strawberry:modifiable(modifiable)
    vim.api.nvim_buf_set_option(0, 'modifiable', modifiable)
end

function Strawberry:restore_cursor_position()
    local lines_amount = vim.api.nvim_buf_line_count(self.ctx.buffer)
    if self.ctx.cursor_line > lines_amount then
        self.ctx.cursor_line = lines_amount
    end
    vim.api.nvim_win_set_cursor(self.ctx.window,
                                {self.ctx.cursor_line, self.ctx.cursor_column})
end

function Strawberry:wipe_buffer(buf)
    Strawberry:modifiable(true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
    Strawberry:modifiable(false)
end

function Strawberry:clear_keymaps()
    if (not self.ctx.buffer) then return end
    local keymaps = vim.api.nvim_buf_get_keymap(self.ctx.buffer, '')
    for _, keymap in ipairs(keymaps) do
        vim.api.nvim_buf_del_keymap(self.ctx.buffer, keymap.mode, keymap.lhs)
    end
end

-- Resets Strawberry's buffer
function Strawberry:reset()
    Strawberry:clear_keymaps()
    Strawberry:register_items()
    Strawberry:apply_keymaps()
    Strawberry:render()
    Strawberry:restore_cursor_position()
end

-- Register a config into Strawberry
function Strawberry:register_config(config)
    table_utils.merge(self.config, config)
end

-- Save useful context
function Strawberry:register_ctx()
    self.ctx.win_origin = vim.api.nvim_get_current_win() -- the window where Strawberry was launched from
    self.ctx.buf_origin = vim.api.nvim_get_current_buf() -- the buffer where Strawberry was launched from
end

-- Register items and set uniq keys to each of them
function Strawberry:register_items()
    local items = self.active_picker.get_items()
    if (#items == 0) then
        vim.notify("Strawberry: No items to display", vim.log.levels.WARN,
                   {title = "Strawberry"})
        return
    end
    self.items = items
    -- Add keys to items
    local available_keys = get_available_keys(self.config)
    for i, item in ipairs(self.items) do
        local key = string.sub(available_keys, i, i)
        item.key = key or "·"
    end
end

-- Applies a picker to Strawberry
function Strawberry:apply_picker(picker_name)
    local picker = self:get_picker(picker_name)
    if (not picker) then
        return error("No registered picker under name: " .. picker_name)
    end
    self.active_picker = picker
end

-- Create a new split for Strawberry
function Strawberry:create_window()
    -- Create split
    local height = vim.fn.min({#self.items, self.config.window_height}) + 1
    vim.cmd('botright ' .. height .. ' split')
    self.ctx.window = vim.api.nvim_get_current_win()
    self.ctx.buffer = vim.api.nvim_create_buf(false, true)

    vim.api.nvim_set_option('number', false)
    vim.api.nvim_set_option('relativenumber', false)
    vim.api.nvim_set_option('foldcolumn', "0")
    vim.api.nvim_set_option('foldenable', false)
    vim.api.nvim_set_option('cursorline', true)
    vim.api.nvim_set_option('spell', false)
    vim.api.nvim_set_option('wrap', false)
    vim.api
        .nvim_buf_set_option(self.ctx.buffer, 'filetype', STRAWBERRY_FILETYPE)
    vim.api.nvim_buf_set_option(self.ctx.buffer, 'buflisted', false)
    vim.api.nvim_buf_set_option(self.ctx.buffer, 'buftype', 'nofile')
    vim.api.nvim_buf_set_option(self.ctx.buffer, 'swapfile', false)
end

function Strawberry:register_pickers(pickers)
    for _, picker in pairs(pickers or {}) do
        if (Strawberry:validate_picker(picker)) then
            table.insert(self.pickers, picker)
        end
    end
end

return {
    setup = Strawberry.setup,
    create_item = function(opts)
        local item = Item:create(opts)
        return item
    end,
    -- public utils
    utils = {
        get_filename = utils.get_filename,
        get_home_path = utils.get_home_path,
        is_git_directory = utils.is_git_directory,
        open_file = utils.open_file,
        remove_home_path = utils.remove_home_path
    },
    actions = {open_file = actions.open_file}
}
