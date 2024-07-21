local function merge(t1, t2)
    for k, v in pairs(t2) do
        if type(v) == "table" and type(t1[k]) == "table" then
            merge(t1[k], v)
        else
            t1[k] = v
        end
    end
    return t1
end

local function clone_deep(orig, copies)
    copies = copies or {}
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        if copies[orig] then
            copy = copies[orig]
        else
            copy = {}
            copies[orig] = copy
            for orig_key, orig_value in next, orig, nil do
                copy[clone_deep(orig_key, copies)] =
                    clone_deep(orig_value, copies)
            end
            setmetatable(copy, clone_deep(getmetatable(orig), copies))
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

local U = {
    merge = merge, -- Merges two tables
    clone_deep = clone_deep -- Clones a table deeply
}

return U
