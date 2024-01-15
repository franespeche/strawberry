# 🍓 Strawberry
_A tasty fruit covered in seeds._ 

## TL;DR:
Neovim Plugin to create custom lists with specific actions per list item.

For example, we could create a custom `get_recent_files` method that returns a list with n items, each corresponding with a recent file, and defining a custom action to be executed for each selected item.

If no action specified, defaults to `open_file`.

https://github.com/franespeche/strawberry/assets/73555733/2de8cb08-f966-4658-afab-37e139427417

# Usage:
1. Define a custom action which will return a list of items (seeds), by using the built in `create_seed` method for each item:

```lua
-- note that we'll need this method to create each item
-- @param id: number [will be deprecated]
-- @param value: The value of the item, will also be passed into the item's action
-- @param title: The title to be displayed between the item number and the item value
-- @param action?: Custom action to be executed when selecting the item. Default: open_file
local create_seed = require("strawberry").create_seed

-- custom logic to generate a list of recent files
local show_recent_files = {
  name = "show_recent_files",
  format_value = function(v) return (remove_home_path(v)) end,
  callback = function(limit)
    limit = limit or 15

    local oldfiles = vim.v.oldfiles
    local seeds = {}

    local i = 1
    while (i <= #oldfiles and (#seeds < limit or i < 10)) do
      local file = oldfiles[i]
      if (vim.fn.filereadable(file) == 1) then
        -- implementing the `create_seed` method
        -- TODO: remove the first "id" parameter (#seeds + 1) as it might be confusing
        local seed = create_seed(#seeds + 1, file, get_filename(file), true)
        table.insert(seeds, seed)
      end
      i = i + 1
    end
    return seeds
  end,
}

```
2. Setup the plugin:
```lua
-- setup
require("strawberry"):setup({
  actions = { show_recent_files },
  config = {
    window_height = 5 -- specify the amount of lines that will be visible in the list [not supported yet]
  },
})
```
3. Keymap it
```lua
vim.keymap.set("n", "<leader>rf", ":Strawberry show_git_worktree_recent_files<cr>", { silent = true, noremap = true })
```

# notes:
Both the README file and the plugin are in a beta state

