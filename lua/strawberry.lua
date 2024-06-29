-- Imports
local Item = require('Item')
local utils = require('utils')

-- Helpers
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

-- Set default config
local DEFAULT_CONFIG = {window_height = 5, auto_close = true}

-- Strawberry
local Strawberry = {ctx = {}, actions = {}, config = DEFAULT_CONFIG}

-- Populates items with given lines
function Strawberry:populate_items(action)
    local items = action.callback()
    self.items = items or {}
end

-- Validates action
function Strawberry:validate_action(action)
    -- validate fields
    if (type(action.name) ~= 'string') then
        error('"action.name" must be of type "string"')
        return false
    end
    -- check if action already exists
    for _, registered_action in pairs(self.actions) do
        if (registered_action.name == action.name) then return false end
    end
    return true
end

-- Registrators
function Strawberry:register_action(action) table.insert(self.actions, action) end

function Strawberry:get_lines_from_items()
    local lines = {}
    local max_title_length = get_max_title_length(self.items)
    for _, item in pairs(self.items) do
        table.insert(lines, item:get_line_content(max_title_length))
    end
    return lines
end

-- Opens buffer with lines
function Strawberry:open()
    -- Get the lines to render
    local lines = self:get_lines_from_items()

    -- Open new split
    local height = vim.fn.min({#lines, self.config.window_height}) + 1
    vim.cmd('botright ' .. height .. ' split')

    -- return
    local win = vim.api.nvim_get_current_win()
    local buf = vim.api.nvim_create_buf(false, true)
    self.ctx.win = win
    self.ctx.buf = buf

    -- Set options
    vim.api.nvim_buf_set_option(buf, 'modifiable', true)
    set_options(buf)

    -- Fill buffer with lines
    vim.api.nvim_buf_set_lines(buf, 0, #lines, false, lines)
    vim.api.nvim_buf_set_option(buf, 'modifiable', false)
    vim.api.nvim_win_set_buf(win, buf)

    -- Resize split
    -- vim.cmd('resize ' .. #lines + 1)

    -- Set highlights
    set_highlights()

    -- <CR> handler
    vim.keymap.set("n", "<cr>", function()
        local num = vim.api.nvim_win_get_cursor(0)[1]
        self.items[num]:execute(self.ctx)
    end, {silent = true, buffer = buf})
end

function Strawberry:get_action(action_name)
    for _, action in pairs(self.actions) do
        if (action.name == action_name) then return action end
    end
    return nil
end

function Strawberry:setup(props)
    setmetatable(self, {__index = Strawberry})
    setmetatable(Item, {__index = Strawberry})

    -- Validate config
    if (vim.tbl_isempty(props or {})) then
        return error('Called setup() method without any config')
    end

    -- Register actions
    for _, action in pairs(props.actions or {}) do
        if (Strawberry:validate_action(action)) then
            Strawberry:register_action(action)
        end
    end

    -- Register config
    for k, v in pairs(props.config or {}) do self.config[k] = v end

    -- Create autocommands
    vim.api.nvim_create_user_command('Strawberry', function(args)
        local action_name = args.args
        if (action_name == "") then
            return error("Attempted to launch Strawberry with no action name")
        end
        return Strawberry:init(action_name)
    end, {nargs = '?'})
end

function Strawberry:init(action_name)
    local action = self:get_action(action_name)
    if (not action) then
        return error("No registered action under name: " .. action_name)
    end

    -- Create autocommands
    -- Auto close menu on BufLeave
    if self.config.auto_close then
        P('inside')
        -- vim.api.nvim_create_autocmd('BufLeave', {
        -- pattern = "*",
        -- group = vim.api.nvim_create_augroup("Strawberry", {clear = true}),
        -- callback = function(e)
        -- if (vim.bo.filetype == "strawberry") then
        -- vim.api.nvim_buf_delete(e.buf, {})
        -- end
        -- end
        -- })
    end

    -- Save context
    self.ctx.buf_origin = vim.api.nvim_get_current_buf()
    self.ctx.win_origin = vim.api.nvim_get_current_win()
    -- Hack: save formatter method
    self.format_value = action.format_value
    self:populate_items(action)
    self:open()
end

return {
    utils = utils,
    setup = Strawberry.setup,
    create_item = function(num, value, title, action)
        return Item:create(num, value, title, action)
    end
}
