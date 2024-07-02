-- Helpers
local function sanitize_props(opts)
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

--[[
     Item:
     Each item constitutes a line in Strawberry's pickers
     For instance, a list of recent files picker could look like:
     ------------------------------------------------------------
      1   init.lua         ~/dotfiles/nvim/lua/init.lua
      2   some-util.lua    ~/dotfiles/nvim/lua/utils/some-util.lua
     ------------------------------------------------------------
     (num)(title)          (label)

     @param {string} title - The title of the item
     @param {string} label(optional) - The label of the item
     @param {string} value(optional) - The value of the item. This will be passed to the item's on_select
     @param {function} on_select - The on_select to be executed when the item is selected
]] --
local Item = {title = nil, label = nil, value = nil, on_select = nil}

-- Constructor
function Item:create(props)
    sanitize_props(props)
    local item = {
        value = props.value,
        title = props.title,
        label = props.label or "",
        on_select = props.on_select
    }
    setmetatable(item, {__index = Item})
    return item
end

-- To be called when the item is selected
function Item:execute(ctx) self.on_select(self.value, ctx) end

-- Returns the content of the item as a string
function Item:to_string(max_title_length)
    local spacer = "  "
    local punctuation_space = " " -- note this is not the same ascii as space. this will also be used as a highlight delimiter
    local column_delimiter = spacer .. punctuation_space .. spacer
    local auto_width = string.rep(' ', max_title_length - #self.title)

    local line_key = spacer .. tostring(self.key) .. spacer
    local title = self.title .. auto_width
    local label = self.label

    return line_key .. title .. column_delimiter .. label
end

return Item
