# 🍓 Strawberry
_A tasty fruit covered in seeds._ 

# TL;DR:
Neovim Plugin to create custom lists (pickers) with specific actions to be executed for each item.

For example, we could create a custom `active_buffers` picker that returns a list with `n` items (each corresponding with an active buffer) 
and use a built-in `open_file` function (or a custom function instead) to be executed for each selected item.

We could also create `custom menus`, or a list of `recent files`, or _some_other_awesome_self_crafted_picker, or, or, or.._

# Demo
The following video demonstrates a `recent_files_git_worktree` picker which, as the name suggests, displays a list of the recent files for the given `git worktree` we are standing at,
and also a `active_buffers` picker with `on_delete` functionality (clicking `d` on an item will delete the selected buffer)


https://github.com/franespeche/strawberry/assets/73555733/c8840368-f974-4e8e-9ec2-3f0af5525c01


# Usage:
1. Setup the plugin

```lua
-- # lua/plugins/strawberry/init.lua
-- Imports --
local components = require("plugins.strawberry.components")
local active_buffers = components.active_buffers

-- Setup --
require("strawberry"):setup({
  pickers = {
    active_buffers,
  },
  config = {
    window_height = 15, -- strawberry's window height
    close_on_leave = true, -- close when leaving the picker's window
    close_on_select = true, -- close on item selection
    keymaps = {
      close = { "<esc>", "q" }, -- close the picker
      select_item = { "<cr>" },
      delete_item = nil,
    },
  },
})

-- Keymaps --
Keymap("n", "<leader>rf", ":Strawberry active_buffers<cr>", Opts)
```

---

2. Define a custom picker
   
This will create a `active_buffers` which will return a list of active buffers using the built-in `create_item` method for each item.
Note that it is also setting a `on_delete` function which will take care of buffer deletion

```lua
-- # lua/plugins/strawberry/components/active_buffers.lua

-- Utils --
local create_item = require("strawberry").create_item
local utils = require("strawberry").utils
local actions = require("strawberry").actions

-- Define the picker --
local picker = {
  name = "active_buffers",
  -- Note that this config will override the global config set in the setup function
  config = {
    close_on_leave = true,
    close_on_select = true,
    keymaps = { 
      delete_item = { "d" } -- This will execute the on_delete function on the selected item
    },
  },
  -- Function with the logic to get the active buffers
  get_items = function()
    local limit = 15
    local bufs = vim.api.nvim_list_bufs()
    local menu_items = {}
    local i = 1
    while (i <= #bufs and (#menu_items < limit or i < 10)) do
      local buf = bufs[i]
      if (vim.api.nvim_buf_is_loaded(buf)) then
        local file = vim.api.nvim_buf_get_name(buf)
        if file == "" then goto continue end
        -- Create the Item
        local item = create_item({
          title = utils.get_filename(file),
          label = utils.remove_home_path(file),
          value = file, -- This will be passed into the on_select function
          on_select = actions.open_file, -- Note that we are using the provided open_file function
          on_delete = function()
            vim.api.nvim_buf_delete(buf, { force = true }) -- Custom function to delete this buffer from the list of items
          end,
        })
        table.insert(menu_items, item)
      end
      ::continue::
      i = i + 1
    end
    return menu_items
  end,
}
return picker
```

3. Run a Strawberry picker with the keymap defined in the setup function

![Screen Recording 2024-07-04 at 3](https://github.com/franespeche/strawberry/assets/73555733/ce1d0857-d286-4943-98e2-fef28a44cae1)

# Examples
## Git Modified Files
Displays a list of the modified files respecting the current directory's git main (or specified) branch
```lua
local create_item = require("strawberry").create_item
local utils = require("strawberry").utils
local actions = require("strawberry").actions

-- Get the default branch name
local function get_default_branch_name()
  local result = vim.fn.system("git symbolic-ref refs/remotes/origin/HEAD")
  if vim.v.shell_error == 0 then
    return result:match("^refs/remotes/origin/(.+)%s*$"):gsub("%s+$", "") -- Extract the branch name and remove trailing whitespace
  else
    -- TODO: find a better way to get the default branch name
    return "main"
  end
end

local picker = {
  name = "git_modified",
  config = { close_on_leave = true, close_on_select = true },
  get_items = function(branch)
    if (branch == nil) then branch = get_default_branch_name() end

    -- using systemlist here because system appends a newline character at the end :/
    local root_dir = vim.fn.systemlist("git rev-parse --show-toplevel")[1]
    local git_modified_files = vim.fn.systemlist(
                                   "git diff --name-only " .. branch)

    local menu_items = {}

    local i = 1
    while (i <= #git_modified_files) do
      local file = root_dir .. "/" .. git_modified_files[i]
      if (vim.fn.filereadable(file) == 1) then
        local menu_item = create_item({
          title = utils.get_filename(file),
          label = utils.remove_home_path(file),
          value = file,
          on_select = actions.open_file,
        })
        table.insert(menu_items, menu_item)
      end
      i = i + 1
    end
    return menu_items
  end,
}

return picker
```
## Git Recent Files
Displays a list of recent files for the current git working directory
```lua
-- helpers
local create_item = require("strawberry").create_item
local utils = require("strawberry").utils
local actions = require("strawberry").actions

local picker = {
  name = "git_worktree_recent_files",
  title = "Recent Files",
  config = {
    close_on_leave = true, -- auto close the picker when an item is selected
    close_on_select = true, -- auto close the picker when an item is selected
  },
  get_items = function(limit)
    if (not utils.is_git_directory()) then
      error("Not inside a git working tree")
    end
    limit = limit or 15

    local menu_items = {}
    local oldfiles = vim.v.oldfiles
    local git_root_dir = vim.fn.system("git rev-parse --show-toplevel")

    local i = 1
    while (i <= #oldfiles and (#menu_items < limit or i < 10)) do
      local file = oldfiles[i]
      if (vim.fn.filereadable(file) == 1 and
          vim.startswith(vim.trim(file), vim.trim(git_root_dir))) then
        local menu_item = create_item({
          title = utils.get_filename(file),
          label = utils.remove_home_path(file),
          value = file,
          on_select = actions.open_file,
        })
        table.insert(menu_items, menu_item)
      end
      i = i + 1
    end
    return menu_items
  end,
}

return picker
```

## Active Buffers
Displays a list of active buffers
```lua
local create_item = require("strawberry").create_item
local get_filename = require("strawberry").utils.get_filename
local remove_home_path = require("strawberry").utils.remove_home_path
local actions = require("strawberry").actions

local picker = {
  name = "active_buffers",
  config = {
    close_on_leave = true,
    close_on_select = true,
    keymaps = { delete_item = { "d" } },
  },
  get_items = function()
    local limit = 15
    local bufs = vim.api.nvim_list_bufs()
    local menu_items = {}
    local i = 1
    while (i <= #bufs and (#menu_items < limit or i < 10)) do
      local buf = bufs[i]
      if (vim.api.nvim_buf_is_loaded(buf)) then
        local file = vim.api.nvim_buf_get_name(buf)
        if file == "" then goto continue end
        local item = create_item({
          title = get_filename(file),
          label = remove_home_path(file),
          value = file,
          on_select = actions.open_file,
          on_delete = function()
            vim.api.nvim_buf_delete(buf, { force = true })
          end,
        })
        table.insert(menu_items, item)
      end
      ::continue::
      i = i + 1
    end
    return menu_items
  end,
}

return picker
```
