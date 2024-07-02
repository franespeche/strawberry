-- Imports --
local Item = require('Item')
local utils = require('utils')
local table_utils = utils.table_utils

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
    canvas = {buf = nil, win = nil}, -- canvas is the window and buffer where Strawberry (with its items) will be rendered
    ctx = {
        target_win = nil, -- window where Strawberry was launched from
        target_buf = nil -- buffer where Strawberry was launched from
    }
}

function Strawberry:setup(props)
    setmetatable(self, {__index = Strawberry})

    validate_setup_props(props)

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
    Strawberry:close()
    Strawberry:register_picker(picker_name)
    Strawberry:register_config(self.picker.config)
    Strawberry:register_listeners()
    Strawberry:register_ctx()
    Strawberry:register_items(self.picker)
    self.canvas = Strawberry:create_canvas(self.config)
    Strawberry:register_keymaps(self.canvas.buf)
    Strawberry:render(self.canvas, self.items)
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
    -- Handle Redraw
    vim.api.nvim_create_user_command(Commands.REDRAW,
                                     function() Strawberry:redraw() end,
                                     {nargs = '?'})

    -- Handle Close
    vim.api.nvim_create_user_command(Commands.CLOSE,
                                     function() Strawberry:close() end,
                                     {nargs = '?'})

    -- Handle Select
    vim.api.nvim_create_user_command(Commands.SELECT, function(args)
        local item_index = tonumber(args.args)
        self.items[item_index]:execute(self.ctx)
        if (self.config.close_on_select) then
            vim.api.nvim_command(Commands.CLOSE)
        else
            vim.api.nvim_command(Commands.REDRAW)
        end
    end, {nargs = '?'})
end

function Strawberry:close() delete_buffers_by_filetype(STRAWBERRY_FILETYPE) end

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

-- Parses items to be rendered by Strawberry
function Strawberry:get_stringified_items(items)
    local lines = {}
    local max_title_length = utils.get_max_title_length(items)
    for _, item in pairs(items) do
        table.insert(lines, item:to_string(max_title_length))
    end
    return lines
end

-- Register keymaps for the Strawberry buffer
function Strawberry:register_keymaps(buf)
    -- Common keymaps --
    -- Select item
    for _, keymap in ipairs(self.config.keymaps.select_item) do
        vim.keymap.set("n", keymap, function()
            local item_index = vim.api.nvim_win_get_cursor(0)[1]
            return vim.api.nvim_command(Commands.SELECT .. tostring(item_index))
        end, {silent = true, buffer = buf})
    end

    -- Close Strawberry
    for _, keymap in ipairs(self.config.keymaps.close) do
        vim.keymap.set("n", keymap, function()
            return vim.api.nvim_command(Commands.CLOSE)
        end, {silent = true, buffer = buf})
    end

    -- Keymaps for each item
    for i, item in ipairs(self.items) do
        local key = item.key
        -- Break if key is nil longer than one character
        if (not key or #key > 1) then break end
        vim.keymap.set("n", tostring(key),
                       function() self.items[i]:execute(self.ctx) end,
                       {silent = true, buffer = buf})
    end
end

-- Renders Strawberry buffer
function Strawberry:render(canvas, items)
    Strawberry:modifiable(true)
    -- Set buffer content
    local lines = self:get_stringified_items(items)
    vim.api.nvim_buf_set_lines(canvas.buf, 0, #lines, false, lines)
    vim.api.nvim_win_set_buf(canvas.win, canvas.buf)

    Strawberry:modifiable(false)
end

-- Get picker by name
function Strawberry:get_picker(picker_name)
    for _, picker in pairs(self.pickers) do
        if (picker.name == picker_name) then return picker end
    end
    return nil
end

-- Make the buffer modifiable/non-modifiable
function Strawberry:modifiable(modifiable)
    vim.api.nvim_buf_set_option(self.canvas.buf, 'modifiable', modifiable)
end

-- Recalculate items and redraw the buffer
function Strawberry:redraw(items)
    if not items then Strawberry:register_items(self.picker) end
    Strawberry:render(self.canvas, self.items)
end

-- Register a config into Strawberry
function Strawberry:register_config(config)
    table_utils.merge(self.config, config)
end

-- Save useful context
function Strawberry:register_ctx()
    -- This is where Strawberry was launched from.
    self.ctx.target_win = vim.api.nvim_get_current_win()
    self.ctx.target_buf = vim.api.nvim_get_current_buf()
end

-- Register items for the picker and set hotkeys for each item
function Strawberry:register_items(picker)
    self.items = picker.get_items()

    -- Add keys to items
    local available_keys = get_available_keys(self.config)
    for i, item in ipairs(self.items) do
        local key = string.sub(available_keys, i, i)
        item.key = key or "·"
    end
end

-- Register a picker by name
function Strawberry:register_picker(picker_name)
    local picker = self:get_picker(picker_name)
    if (not picker) then
        return error("No registered picker under name: " .. picker_name)
    end
    self.picker = picker
    return self.picker
end

-- Create a new split for Strawberry
function Strawberry:create_canvas(config)
    -- Create split
    local height = vim.fn.min({#self.items, config.window_height}) + 1
    vim.cmd('botright ' .. height .. ' split')

    local canvas = {
        win = vim.api.nvim_get_current_win(),
        buf = vim.api.nvim_create_buf(false, true)
    }
    utils.set_buffer_options(canvas.buf)
    return canvas
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
