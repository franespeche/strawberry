-- Item
-- Each item constitutes a line in the Strawberry buffer
-- ie: A list of recent files would look like:
-- 1 init.lua      ~/dotfiles/nvim/lua/init.lua
-- (num) (title)   (label)
-- @param {number} num - The number of the item
-- @param {string} title - The title of the item
-- @param {string} label(optional) - The label of the item
-- @param {string} value(optional) - The value of the item. This will be passed to the item's on_select
-- @param {function} on_select - The on_select to be executed when the item is selected
local Item = {num = nil, title = nil, label = nil, value = nil, on_select = nil}

-- Helpers
local function validate_opts(opts)
    -- validate title
    if not opts.title then error("Item must have a title") end
    if (type(opts.title) ~= 'string') then
        error("Item title must be a string")
    end

    -- validate label
    if (opts.label and type(opts.label) ~= 'string') then
        error("Item label must be a string")
    end

    -- validate value
    if (opts.value and type(opts.value) ~= 'string') then
        error("Item value must be a string")
    end

    -- validate on_select
    if not opts.on_select then error("Item must have an on_select") end
    if (type(opts.on_select) ~= 'function') then
        error("Item on_select must be a function")
    end
end

-- Constructor
function Item:create(opts)
    validate_opts(opts)
    local obj = {
        num = opts.num,
        value = opts.value,
        title = opts.title,
        label = opts.label or "",
        on_select = opts.on_select
    }
    setmetatable(obj, {__index = Item})
    return obj
end

-- To be called when the item is selected
function Item:execute(opts) self.on_select(self.value, self.ctx, opts) end

-- Returns the content of the item as a string
function Item:get_line_content(max_title_length)
    local spacer = "  "
    local punctuation_space = " "
    local column_delimiter = spacer .. punctuation_space .. spacer
    local auto_width = string.rep(' ', max_title_length - #self.title)

    local line_num = spacer .. tostring(self.num) .. spacer
    local title = self.title .. auto_width
    local label = self.label

    return line_num .. title .. column_delimiter .. label
end

return Item
