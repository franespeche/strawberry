-- Item
-- Each item constitutes a line in the main buffer
-- ie: A list of recent files would look like:
-- 1 init.lua      ~/dotfiles/nvim/lua/init.lua
-- (num) (title)   (label)
-- @param {number} @deprecated num - The number of the item
-- @param {string} title - The title of the item
-- @param {string} label - The label of the item
-- @param {string} value - The value of the item. This will be passed to the item's on_select
-- @param {function} on_select - The on_select to be executed when the item is selected
local Item = {num = nil, title = nil, label = nil, value = nil, on_select = nil}

function Item:create(opts)
    local obj = {
        num = opts.num,
        value = opts.value,
        title = opts.title,
        label = opts.label,
        on_select = opts.on_select
    }
    setmetatable(obj, {__index = Item})
    return obj
end

function Item:execute() self.on_select(self.value, self.ctx) end

function Item:get_line_content(max_title_length)
    local spacer = "  "
    local column_delimiter = spacer .. "·" .. spacer
    local line = "  " .. tostring(self.num)

    local label = self.label

    if (self.title and self.title ~= "") then
        line = line .. spacer .. self.title
    end

    local auto_width = string.rep(' ', max_title_length - #self.title)
    line = line .. auto_width .. column_delimiter .. label
    return line
end

return Item
