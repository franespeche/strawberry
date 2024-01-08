-- schedule_wrap
-- run sys commands
-- local result = vim.fn.systemlist('git diff-tree --no-commit-id --name-only -r HEAD')

-- helpers
local open_file = function (file, ctx)
  vim.api.nvim_buf_delete(ctx.buf, {})
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(ctx.win_origin, buf)
  vim.cmd('e ' .. file)
end

-- Seed
local Seed = {
  num = nil,
  title = nil,
  value = { nil, true }, -- value, visible
  action = nil,
}

function Seed:create(num, value, title, visible, action)
  local obj = {
      num = num,
      value = { value, visible },
      title = title,
      action = action or open_file
    }
  setmetatable(obj, { __index = Seed })
  return obj
end

function Seed:execute()
  self.action(self.value[1], self.ctx)
end

-- Strawberry
local Strawberry = {
  ctx = {},
  -- make this a table of actions
  actions = {}
}


-- Populate seeds with given lines
function Strawberry:populate_seeds(action)
  local seeds = action.callback()
  self.seeds = seeds or {}
end

function Strawberry:action_exists(action_name)
  for _, registered_action in pairs(self.actions) do
    if(registered_action.name == action_name) then
      return true
    end
  end
  return false
end
-- Validates action
function Strawberry:validate_action(action)
  -- validate fields
  if(type(action.name) ~= 'string') then
    error('"action.name" must be of type "string"')
    return false
  end
  -- check if already exists
  if (self:action_exists(action.name)) then
    return false
  end
  return true
end

-- Registers an action
function Strawberry:register_action(action)
  table.insert(self.actions, action)
end

local function get_line_content(seed)
  local line = tostring(seed.num)

  local value = seed.value[1]
  local value_visible = seed.value[2]

  if(seed.title ~= "") then
    line = line .. " " ..seed.title
  end

  if(value_visible) then
    line = line .. " " .. value
  end
  return line
end

-- Opens buffer with lines
function Strawberry:open()
  -- get the lines to render
  local lines = {}
  for _, seed in pairs(self.seeds) do
    table.insert(lines, get_line_content(seed))
  end

  -- open new split
  vim.cmd('split')
  local win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_create_buf(false, true)
  self.ctx.win = win
  self.ctx.buf = buf

  -- set options
  vim.api.nvim_buf_set_option(buf, 'modifiable', true)
  vim.api.nvim_set_option('number', false)
  vim.api.nvim_set_option('relativenumber', false)
  vim.api.nvim_set_option('foldcolumn', "0")
  vim.api.nvim_set_option('foldenable', false)
  vim.api.nvim_set_option('cursorline', true)
  vim.api.nvim_set_option('spell', false)
  vim.api.nvim_set_option('wrap', false)
  vim.api.nvim_buf_set_option(buf, 'buflisted', false)
  vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(buf, 'swapfile', false)
  vim.api.nvim_buf_set_lines(buf, 0, #lines, false, lines)
  vim.api.nvim_buf_set_option(buf, 'modifiable', false)

  vim.api.nvim_win_set_buf(win, buf)

  -- resize
  vim.cmd('resize ' .. #lines + 1)

  -- <CR> handler
  local function execute_seed()
    local num = vim.api.nvim_win_get_cursor(0)[1]
    self.seeds[num]:execute(self.ctx)
  end
  vim.keymap.set("n", "<cr>", function() execute_seed() end, { silent = true, buffer = buf })
end

function Strawberry:setup(config)
  setmetatable(Seed, { __index = Strawberry })

  -- Validate config
  if(vim.tbl_isempty(config or {})) then return error('Called the setup() method without any config') end

  -- Register actions
  for _, action in pairs(config.actions) do
    local is_valid = Strawberry:validate_action(action)
    if(is_valid) then
      Strawberry:register_action(action)
    end
  end

  -- Create autocommands
  vim.api.nvim_create_user_command('Strawberry', function(args)
    local action_name = args.args
    if(action_name == "") then return error("Attempted to launch Strawberry with no action name") end
    return Strawberry:init(action_name)
  end, { nargs = '?' })
end

function Strawberry:get_action(action_name)
  for _, action in pairs(self.actions) do
    if(action.name == action_name) then
      return action
    end
  end
end

function Strawberry:init(action_name)
  self.ctx.buf_origin = vim.api.nvim_get_current_buf()
  self.ctx.win_origin = vim.api.nvim_get_current_win()
  if(self:action_exists(action_name)) then
    self:populate_seeds(self:get_action(action_name))
    self:open()
  else
    return error("No registered action under name: " .. action_name)
  end
end

return {
  setup = Strawberry.setup,
  create_seed = function(num, value, title, visible, action)
     return Seed:create(num, value, title, visible, action)
    end
  }
