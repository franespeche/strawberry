-- Imports
local utils = require('utils')

-- Item
local Item = {num = nil, title = nil, value = nil, action = nil}

-- TODO: get this from an object
function Item:create(num, value, title, action)
    local obj = {
        num = num,
        value = value,
        title = title,
        action = action or utils.open_file
    }
    setmetatable(obj, {__index = Item})
    return obj
end

function Item:execute() self.action(self.value, self.ctx) end

function Item:get_line_content(max_title_length)
    local spacer = "  "
    local line = "  " .. tostring(self.num)

    local value = self.format_value(self.value)

    if (self.title and self.title ~= "") then
        line = line .. spacer .. self.title
    end

    local compensate_spaces = string.rep(' ', max_title_length - #self.title)
    line = line .. compensate_spaces .. spacer .. value
    return line
end

return Item
