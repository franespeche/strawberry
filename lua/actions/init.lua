local open_file = function(filepath, ctx)
    vim.api.nvim_set_current_win(ctx.win_origin)
    vim.cmd('e ' .. filepath)
end

local A = {open_file = open_file}

return A
