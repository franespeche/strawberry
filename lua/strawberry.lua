-- Imports
local Item = require('Item')
local utils = require('utils')

-- Constants
local DEFAULT_CONFIG = {window_height = 5, auto_close = true}

-- Strawberry
local Strawberry = {ctx = {}, actions = {}, config = DEFAULT_CONFIG}

-- Generates items
function Strawberry:generate_items(action)
    local items = action.get_items()
    self.items = items or {}
    return items
end

-- Validates action
function Strawberry:validate_action(action)
    -- validate fields
    if (type(action.name) ~= 'string') then
        error('"action.name" must be of type "string"')
        return false
    end
    -- check if the action already exists
    for _, registered_action in pairs(self.actions) do
        if (registered_action.name == action.name) then return false end
    end
    return true
end

-- Registrators
function Strawberry:register_action(action) table.insert(self.actions, action) end

function Strawberry:get_parsed_items(items)
    local lines = {}
    local max_title_length = utils.get_max_title_length(items)
    for _, item in pairs(items) do
        table.insert(lines, item:get_line_content(max_title_length))
    end
    return lines
end

-- Renders main buffer
function Strawberry:render(lines)
    -- Open new split
    local height = vim.fn.min({#lines, self.config.window_height}) + 1
    vim.cmd('botright ' .. height .. ' split')

    local win = vim.api.nvim_get_current_win()
    local buf = vim.api.nvim_create_buf(false, true)
    self.ctx.win = win
    self.ctx.buf = buf

    -- Set options
    utils.set_options(buf)

    -- Fill main buffer and focus
    vim.api.nvim_buf_set_lines(buf, 0, #lines, false, lines)
    vim.api.nvim_win_set_buf(win, buf)

    -- lock main buffer
    vim.api.nvim_buf_set_option(buf, 'modifiable', false)

    utils.set_highlights()

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

local function validate_setup_config(cfg)
    if (vim.tbl_isempty(cfg or {})) then
        return error('Called setup() method without any config')
    end
end

function Strawberry:setup(props)
    setmetatable(self, {__index = Strawberry})
    setmetatable(Item, {__index = Strawberry})

    -- Validate config
    validate_setup_config(props)

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
    vim.api.nvim_create_autocmd('BufLeave', {
        pattern = "*",
        group = vim.api.nvim_create_augroup("Strawberry", {clear = true}),
        callback = function(e)
            if (vim.bo.filetype == "strawberry") then
                vim.api.nvim_buf_delete(e.buf, {})
            end
        end
    })

    -- Save context
    self.ctx.buf_origin = vim.api.nvim_get_current_buf()
    self.ctx.win_origin = vim.api.nvim_get_current_win()

    -- Each item constitutes a line in the main buffer
    local items = self:generate_items(action)
    local parsed_items = self:get_parsed_items(items)

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
