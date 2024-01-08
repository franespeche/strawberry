local augroup = vim.api.nvim_create_augroup("Strawberry", { clear = true })

-- enums
local ITEMS_AMOUNT = 1

-- helpers
local open_file = function (file)
  print('execute line ' .. file)
end

local function get_recent_files(limit)
  limit = limit or ITEMS_AMOUNT

  local oldfiles = vim.v.oldfiles
  local seeds = {}

  local i = 1
  while(i <= #oldfiles and (#seeds < limit or i < 10)) do
    local file = oldfiles[i]
    if(vim.fn.filereadable(file) == 1) then
      local seed = Seed:create(#seeds + 1, file, nil, true, open_file)
      table.insert(seeds, seed)
    end
    i = i + 1
  end
  return seeds
end

-- Seed
local Seed = {
  num = nil,
  title = nil,
  value = { nil, true }, -- value, visible
  action = nil,
  default_action = open_file
}

function Seed:create(num, value, title, visible, action)
  local obj = {
      num = num,
      value = { value, visible },
      title = title,
      action = action or self.default_action
    }
  setmetatable(obj, { __index = Seed })
  return obj
end

function Seed:execute()
  self.action(self, self.value[1])
end


-- Strawberry
local Strawberry = {
  ctx = {},
  -- make this a table of actions
  action = nil,
  actions = {}
}


-- Populate seeds with given lines
function Strawberry:populate_seeds(seeds_type, opts)
  if(seeds_type == 'git_recent_files') then
    -- setmetatable(self, { __index = Strawberry })
    self.seeds = get_recent_files(opts)
  end
end

-- Validates action
function Strawberry:validate_action(action)
  -- validate fields
  if(type(action.name) ~= 'string') then 
    error('"action.name" must be of type "string"') 
    return false
  end
  -- check if already exists
  for _, registered_action in pairs(self.actions) do
    if(registered_action.name == action.name) then
      error('Action name "' .. action.name .. '" already exists')
      return false
    end
  end
  return true
end

-- Registers an action
function Strawberry:register_action(action)
  table.insert(self.actions, action)
end

-- Opens buffer with lines
function Strawberry:open()
  -- get the lines to render
  local lines = {}
  for _, seed in pairs(self.seeds) do
    table.insert(lines, seed.value[1])
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
  vim.api.nvim_set_option('foldcolumn', "0")
  vim.api.nvim_set_option('foldenable', false)
  vim.api.nvim_set_option('cursorline', true)
  vim.api.nvim_set_option('spell', false)
  vim.api.nvim_set_option('wrap', false)
  vim.api.nvim_buf_set_option(buf, 'buflisted', false)
  vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(buf, 'swapfile', false)
  vim.api.nvim_buf_set_option(buf, 'modifiable', false)
  vim.api.nvim_win_set_buf(win, buf)

  -- resize
  vim.cmd('resize ' .. #lines + 1)

  -- <CR> handler
  local function execute_seed()
    local num = vim.api.nvim_win_get_cursor(0)[1]
    self.seeds[num]:execute()
  end
  vim.keymap.set("n", "<cr>", function() execute_seed() end, { silent = true, buffer = buf })

end

function Strawberry:setup(config)
  -- Validations
  if(vim.tbl_isempty(config or {})) then return error('Called the setup() method without any config') end

  -- Register actions
  for _, action in pairs(config.actions) do
    local is_valid = Strawberry:validate_action(action)
    if(is_valid) then
      Strawberry:register_action(action)
    end
  end
end

function Strawberry:init(seeds_type)
  self.ctx.buf_origin = vim.api.nvim_get_current_buf()
  self:populate_seeds(seeds_type)
  self:open()
end

return { setup = Strawberry.setup, create_seed = Seed.create }
