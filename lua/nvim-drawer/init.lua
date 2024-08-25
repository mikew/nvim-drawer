--- @class NvimDrawerModule
local mod = {}

--- @class CreateDrawerOptions
--- Prefix used when creating buffers.
--- Buffers will be named `{bufname_prefix}1`, `{bufname_prefix}2`, etc.
--- @field bufname_prefix string
--- Initial size of the drawer, in lines or columns.
--- @field size integer
--- Position of the drawer.
--- @field position 'left' | 'right' | 'top' | 'bottom'
--- Called before a buffer is created. This is called very rarely.
--- @field on_will_create_buffer? fun(bufname: string): nil
--- Called after a buffer is created. This is called very rarely.
--- @field on_did_create_buffer? fun(bufname: string): nil
--- Called before a buffer is opened.
--- @field on_will_open_buffer? fun(bufname: string): nil
--- Called after a buffer is opened.
--- @field on_did_open_buffer? fun(bufname: string): nil
--- Called before the splt is created.
--- @field on_will_open_split? fun(bufname: string): nil
--- Called after a split is created.
--- @field on_did_open_split? fun(bufname: string): nil
--- Called before the drawer is closed. Note this will is called even if the
--- drawer is closed.
--- @field on_will_close? fun(): nil
--- Called after the drawer is closed. Only called if the drawer was actually
--- open.
--- @field on_did_close? fun(): nil

--- @class DrawerState
--- Whether the drawer assumes it's open or not.
--- @field is_open boolean
--- The last known size of the drawer.
--- @field size integer
--- The name of the previous buffer that was opened.
--- @field previous_bufname string
--- The number of buffers that have been created.
--- @field count integer
--- The names of all buffers that have been created.
--- @field buffers string[]

--- @type DrawerInstance[]
local instances = {}

--- @param t table
--- @param value any
local function index_of(t, value)
  for i, v in ipairs(t) do
    if v == value then
      return i
    end
  end

  return -1
end

--- @return integer[]
local function get_windows_in_tab()
  local tabinfo = vim.fn.gettabinfo(vim.fn.tabpagenr())[1]

  if tabinfo == nil then
    return {}
  end

  return tabinfo.windows
end

--- Create a new drawer.
--- ```lua
--- local example_drawer = drawer.create_drawer({
---   bufname_prefix = 'example_drawer_',
---   size = 15,
---   position = 'bottom',
---
---   on_will_create_buffer = function()
---   end,
--- })
--- ```
--- @param opts CreateDrawerOptions
function mod.create_drawer(opts)
  --- @class DrawerInstance
  local instance = {
    opts = opts,

    --- @type DrawerState
    state = {
      is_open = false,
      size = opts.size,
      previous_bufname = '',
      count = 0,
      buffers = {},
    },
  }

  --- @param callback_name string
  local function try_callback(callback_name, ...)
    if instance.opts[callback_name] then
      instance.opts[callback_name](...)
    end
  end

  --- @class DrawerOpenOptions
  --- @field focus? boolean
  --- @field mode? 'previous_or_new' | 'new'

  --- Open the drawer.
  --- ```lua
  --- example_drawer.open()
  ---
  --- --- Keep focus in the drawer.
  --- example_drawer.open({ focus = true })
  ---
  --- --- Open a new tab and focus it.
  --- example_drawer.open({ mode = 'new', focus = true })
  --- ```
  --- @param opts? DrawerOpenOptions
  function instance.open(opts)
    opts = vim.tbl_extend(
      'force',
      { focus = false, mode = 'previous_or_new' },
      opts or {}
    )

    local bufname = ''
    if opts.mode == 'previous_or_new' then
      local previous_buffer_exists = instance.state.previous_bufname ~= ''
        and vim.fn.bufnr(instance.state.previous_bufname) ~= -1

      bufname = instance.state.previous_bufname
      if not previous_buffer_exists then
        instance.state.count = instance.state.count + 1
        bufname = instance.opts.bufname_prefix .. instance.state.count
      end
    elseif opts.mode == 'new' then
      instance.state.count = instance.state.count + 1
      bufname = instance.opts.bufname_prefix .. instance.state.count
    end

    instance.state.is_open = true

    local winnr = instance.get_winnr()

    if winnr == -1 then
      local cmd = ''
      if instance.opts.position == 'left' then
        cmd = 'topleft vertical '
      elseif instance.opts.position == 'right' then
        cmd = 'botright vertical '
      elseif instance.opts.position == 'top' then
        cmd = 'topleft '
      elseif instance.opts.position == 'bottom' then
        cmd = 'botright '
      end

      try_callback('on_will_open_split', bufname)

      vim.cmd(
        cmd
          .. instance.state.size
          .. 'new | setlocal nobuflisted | setlocal noswapfile'
      )

      try_callback('on_did_open_split', bufname)
    else
      vim.cmd(winnr .. 'wincmd w')

      if opts.mode == 'new' then
        vim.cmd('enew | setlocal nobuflisted | setlocal noswapfile')
      end
    end

    instance.switch_window_to_buffer(bufname)

    if not opts.focus then
      vim.cmd('wincmd p')
    end
  end

  --- Switch the current window to a buffer and prepare it as a drawer.
  --- @param bufname string
  function instance.switch_window_to_buffer(bufname)
    local bufnr = vim.fn.bufnr(bufname)

    try_callback('on_will_open_buffer', bufname)

    if bufnr == -1 then
      try_callback('on_will_create_buffer', bufname)

      vim.cmd('file ' .. bufname)

      try_callback('on_did_create_buffer', bufname)
    else
      vim.cmd('buffer ' .. bufname)
    end

    vim.opt_local.bufhidden = 'hide'
    vim.opt_local.buflisted = false

    vim.opt_local.equalalways = false
    if
      instance.opts.position == 'left' or instance.opts.position == 'right'
    then
      vim.opt_local.winfixwidth = true
      vim.opt_local.winfixheight = false
    else
      vim.opt_local.winfixwidth = false
      vim.opt_local.winfixheight = true
    end

    if not vim.list_contains(instance.state.buffers, bufname) then
      table.insert(instance.state.buffers, bufname)
    end
    instance.state.previous_bufname = bufname

    try_callback('on_did_open_buffer', bufname)
  end

  --- Navigate to the next or previous buffer.
  --- ```lua
  --- --- Go to the next buffer.
  --- example_drawer.go(1)
  ---
  --- --- Go to the previous buffer.
  --- example_drawer.go(-1)
  --- ```
  --- @param distance integer
  function instance.go(distance)
    local winnr = instance.get_winnr()

    if winnr == -1 then
      return
    end

    local index = index_of(
      instance.state.buffers,
      -- TODO Should probably use winnr instead of relyng on the
      -- previous_bufname, that would be less brittle.
      instance.state.previous_bufname
    )
    if index == -1 then
      return
    end

    index = index - 1
    local next_index = index + distance
    local next_bufname =
      instance.state.buffers[(next_index % #instance.state.buffers) + 1]

    instance.focus()
    instance.switch_window_to_buffer(next_bufname)
  end

  --- @class DrawerCloseOptions
  --- @field save_size? boolean

  --- Close the drawer. By default, the size of the drawer is saved.
  --- ```lua
  --- example_drawer.close()
  ---
  --- --- Don't save the size of the drawer.
  --- example_drawer.close({ save_size = false })
  --- ```
  --- @param opts? DrawerCloseOptions
  function instance.close(opts)
    opts = vim.tbl_extend('force', { save_size = true }, opts or {})

    try_callback('on_will_close')

    instance.state.is_open = false

    local winnr = instance.get_winnr()

    if winnr ~= -1 then
      if opts.save_size then
        instance.state.size = instance.get_size()
      end
    end

    instance.focus_and_return(function()
      vim.cmd('close')
      try_callback('on_did_close')
    end)
  end

  --- @class DrawerToggleOptions
  --- @field open? DrawerOpenOptions

  --- Toggle the drawer. Also lets you pass options to open the drawer.
  --- ```lua
  --- example_drawer.toggle()
  ---
  --- --- Focus the drawer when opening it.
  --- example_drawer.toggle({ open = { focus = true } })
  --- ```
  --- @param opts? DrawerToggleOptions
  function instance.toggle(opts)
    opts = vim.tbl_extend('force', { open = nil }, opts or {})

    if instance.state.is_open then
      instance.close({ save_size = true })
    else
      instance.open(opts.open)
    end
  end

  --- Focus the drawer if it's open, otherwise toggle it, and give it focus
  --- when it is opened.
  function instance.focus_or_toggle()
    local winnr = instance.get_winnr()

    if winnr == -1 then
      instance.open({ focus = true })
    else
      if instance.is_foucsed() then
        instance.close({ save_size = true })
      else
        instance.focus()
      end
    end
  end

  --- Get the window number of the drawer. Returns `-1` if the drawer is not
  --- open.
  function instance.get_winnr()
    for _, w in ipairs(vim.fn.range(1, vim.fn.winnr('$'))) do
      if instance.is_buffer(vim.fn.bufname(vim.fn.winbufnr(w))) then
        return w
      end
    end

    return -1
  end

  --- Focus the drawer.
  function instance.focus()
    local winnr = instance.get_winnr()

    if winnr == -1 then
      return
    end

    vim.cmd(winnr .. 'wincmd w')
  end

  --- Check if the drawer is focused.
  function instance.is_foucsed()
    local winnr = instance.get_winnr()

    if winnr == -1 then
      return false
    end

    return vim.fn.winnr() == winnr
  end

  --- Helper function to focus the drawer, run a callback, and return focus to
  --- the previous window.
  --- @param callback fun()
  function instance.focus_and_return(callback)
    local winnr = instance.get_winnr()

    if winnr == -1 then
      return
    end

    instance.focus()
    callback()
    vim.cmd('wincmd p')
  end

  --- Get the size of the drawer in lines or columns.
  function instance.get_size()
    local winnr = instance.get_winnr()

    if winnr == -1 then
      return 0
    end

    local size = 0

    instance.focus_and_return(function()
      size = vim.fn.winheight(0)

      if
        instance.opts.position == 'left' or instance.opts.position == 'right'
      then
        size = vim.fn.winwidth(0)
      end
    end)

    return size
  end

  --- Check if a buffer belongs to the drawer. You can override this function
  --- to work with other plugins.
  --- @param bufname string
  function instance.is_buffer(bufname)
    return string.find(bufname, instance.opts.bufname_prefix) ~= nil
  end

  table.insert(instances, instance)

  return instance
end

local drawer_augroup = vim.api.nvim_create_augroup('nvim-drawer', {
  clear = true,
})

function mod.setup(_)
  vim.api.nvim_create_autocmd('TabEnter', {
    desc = 'nvim-drawer: Restore drawers',
    group = drawer_augroup,
    callback = function()
      for _, instance in ipairs(instances) do
        if instance.state.is_open then
          instance.close({ save_size = false })
          instance.open({ focus = false })

          instance.focus_and_return(function()
            local cmd = ''
            if
              instance.opts.position == 'left'
              or instance.opts.position == 'right'
            then
              cmd = 'vertical resize '
            else
              cmd = 'resize '
            end

            vim.cmd(cmd .. instance.state.size)
          end)
        else
          instance.close({ save_size = false })
        end
      end
    end,
  })

  vim.api.nvim_create_autocmd('TabLeave', {
    desc = 'nvim-drawer: Save drawer sizes',
    group = drawer_augroup,
    callback = function()
      for _, instance in ipairs(instances) do
        if instance.state.is_open then
          instance.state.size = instance.get_size()
        end
      end
    end,
  })

  vim.api.nvim_create_autocmd('BufWipeout', {
    desc = 'nvim-drawer: Cleanup when buffer is wiped out',
    group = drawer_augroup,
    callback = function(event)
      local bufname = event.file
      for _, instance in ipairs(instances) do
        if instance.is_buffer(bufname) then
          local new_buffers = vim.tbl_filter(function(b)
            return b ~= bufname
          end, instance.state.buffers)

          instance.state.is_open = false
          instance.state.previous_bufname = new_buffers[#new_buffers] or ''
          instance.state.buffers = new_buffers

          -- TODO Not sure if this is useful. Technically, the drawer will be
          -- "closed", like, it's not open any more.
          -- But not sure if BufWipeout will happen anyways via whatever people
          -- do with their drawers, and if .close() is properly called, then
          -- these callbacks would be doubled-up.
          -- if instance.opts.on_will_close then
          --   instance.opts.on_will_close()
          -- end
          -- if instance.opts.on_did_close then
          --   instance.opts.on_did_close()
          -- end
        end
      end
    end,
  })

  vim.api.nvim_create_autocmd('WinClosed', {
    desc = 'nvim-drawer: Close tab when all non-drawers are closed',
    group = drawer_augroup,
    callback = function(event)
      --- @type integer
      --- @diagnostic disable-next-line: assign-type-mismatch
      local closing_window_id = tonumber(event.match)

      local closing_window_buffer =
        vim.fn.bufname(vim.fn.winbufnr(closing_window_id))
      --- @type DrawerInstance | nil
      local closing_window_instance = nil

      for _, instance in ipairs(instances) do
        if instance.is_buffer(closing_window_buffer) then
          closing_window_instance = instance
          break
        end
      end

      if closing_window_instance == nil then
        local windows_in_tab = get_windows_in_tab()
        local windows_in_tab_without_closing = vim.tbl_filter(function(winid)
          return winid ~= closing_window_id
        end, windows_in_tab)

        local num_drawers_in_tab = 0
        for _, winid in ipairs(windows_in_tab_without_closing) do
          for _, instance in ipairs(instances) do
            if instance.is_buffer(vim.fn.bufname(vim.fn.winbufnr(winid))) then
              num_drawers_in_tab = num_drawers_in_tab + 1
              break
            end
          end
        end

        if num_drawers_in_tab == #windows_in_tab_without_closing then
          if vim.fn.tabpagenr('$') > 1 then
            vim.cmd('tabclose')
          else
            vim.cmd('qa')
          end
        end
      else
        closing_window_instance.close({ save_size = false })
      end
    end,
  })
end

return mod
