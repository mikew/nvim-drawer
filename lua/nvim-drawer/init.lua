--- @class NvimDrawerModule
local mod = {}

--- @class CreateDrawerOptions
--- Prefix used when creating buffers.
--- Buffers will be named `{bufname_prefix}1`, `{bufname_prefix}2`, etc.
--- @field bufname_prefix string
--- Initial size of the drawer, in lines or columns.
--- @field size integer
--- Position of the drawer.
--- @field position 'left' | 'right' | 'above' | 'below'
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
--- The internal ID of the drawer.
--- @field index integer
--- The windows belonging to the drawer.
---- @field winids integer[]
--- @field windows_and_buffers table<integer, integer>

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

--- @param bufname string
local function get_bufnr_from_bufname(bufname)
  return vim.fn.bufnr(bufname)
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
      index = #instances,
      is_open = false,
      size = opts.size,
      previous_bufname = '',
      count = 0,
      buffers = {},
      -- winids = {},
      windows_and_buffers = {},
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
        and get_bufnr_from_bufname(instance.state.previous_bufname) ~= -1

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

    local current_winid = vim.api.nvim_get_current_win()
    local winid = instance.get_winid()

    if winid == -1 then
      try_callback('on_will_open_split', {
        bufname = bufname,
      })

      local buffer = vim.api.nvim_create_buf(false, false)
      winid = vim.api.nvim_open_win(buffer, false, {
        win = -1,
        split = instance.opts.position,

        width = (
          instance.opts.position == 'left'
          or instance.opts.position == 'right'
        )
            and instance.state.size
          or nil,
        height = (
          instance.opts.position == 'above'
          or instance.opts.position == 'below'
        )
            and instance.state.size
          or nil,
      })
      vim.api.nvim_win_set_var(winid, 'nvim-drawer-info', {
        bufname_prefix = instance.opts.bufname_prefix,
        index = instance.state.index,
      })

      vim.api.nvim_win_call(winid, function()
        try_callback('on_did_open_split', bufname)
      end)
    else
      if opts.mode == 'new' then
        vim.api.nvim_win_call(winid, function()
          vim.cmd('enew | setlocal nobuflisted | setlocal noswapfile')
        end)
      end
    end

    instance.switch_window_to_buffer(winid, bufname)

    if opts.focus then
      vim.api.nvim_set_current_win(winid)
    end
  end

  --- Switch the current window to a buffer and prepare it as a drawer.
  --- @param bufname string
  function instance.switch_window_to_buffer(winid, bufname)
    local bufnr = get_bufnr_from_bufname(bufname)

    vim.api.nvim_win_call(winid, function()
      try_callback('on_will_open_buffer', {
        winid = winid,
        bufname = bufname,
      })
    end)

    if bufnr == -1 then
      -- bufnr = vim.api.nvim_buf_get_number(0)
      bufnr = vim.api.nvim_win_get_buf(winid)
      vim.api.nvim_win_set_buf(winid, bufnr)

      -- vim.api.nvim_buf_call(bufnr, function()
      vim.api.nvim_win_call(winid, function()
        try_callback('on_will_create_buffer', {
          winid = winid,
          bufname = bufname,
        })
      end)

      vim.api.nvim_buf_set_name(bufnr, bufname)

      vim.api.nvim_buf_call(bufnr, function()
        try_callback('on_did_create_buffer', {
          winid = winid,
          bufname = bufname,
          bufnr = bufnr,
        })
      end)
    else
      vim.api.nvim_win_set_buf(winid, bufnr)
    end

    -- if not vim.list_contains(instance.state.winids, winid) then
    --   table.insert(instance.state.winids, winid)
    -- end

    instance.state.windows_and_buffers[winid] = bufnr

    vim.api.nvim_win_call(winid, function()
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
    end)

    if not vim.list_contains(instance.state.buffers, bufname) then
      table.insert(instance.state.buffers, bufname)
    end
    instance.state.previous_bufname = bufname

    -- vim.api.nvim_buf_call(bufnr, function()
    vim.api.nvim_win_call(winid, function()
      try_callback('on_did_open_buffer', {
        winid = winid,
        bufname = bufname,
        bufnr = bufnr,
      })
    end)
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
    local winid = instance.get_winid()

    if winid == -1 then
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

    instance.switch_window_to_buffer(winid, next_bufname)
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

    local winid = instance.get_winid()

    if winid == -1 then
      return
    end

    if opts.save_size then
      vim.print('save_size', instance.get_size())
      instance.state.size = instance.get_size()
    end

    vim.api.nvim_win_hide(winid)
    try_callback('on_did_close')
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
    local winid = instance.get_winid()

    if winid == -1 then
      instance.open({ focus = true })
    else
      if instance.is_foucsed() then
        instance.close({ save_size = true })
      else
        instance.focus()
      end
    end
  end

  --- Get the window id of the drawer. Returns `-1` if the drawer is not
  --- open.
  function instance.get_winid()
    for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      if instance.is_window(w) then
        return w
      end
    end

    return -1
  end

  --- Focus the drawer.
  function instance.focus()
    local winid = instance.get_winid()
    if winid == -1 then
      return
    end

    vim.api.nvim_set_current_win(winid)
  end

  --- Check if the drawer is focused.
  function instance.is_foucsed()
    local winid = instance.get_winid()
    if winid == -1 then
      return false
    end

    return vim.api.nvim_get_current_win() == winid
  end

  --- Helper function to focus the drawer, run a callback, and return focus to
  --- the previous window.
  --- @param callback fun()
  function instance.focus_and_return(callback)
    local winid = instance.get_winid()
    if winid == -1 then
      return
    end

    local current_winid = vim.api.nvim_get_current_win()
    vim.api.nvim_set_current_win(winid)
    callback()
    vim.api.nvim_set_current_win(current_winid)
  end

  --- Get the size of the drawer in lines or columns.
  function instance.get_size()
    local winid = instance.get_winid()
    if winid == -1 then
      return 0
    end

    local size = (
      (instance.opts.position == 'left' or instance.opts.position == 'right')
        and vim.api.nvim_win_get_width(winid)
      or vim.api.nvim_win_get_height(winid)
    ) or 0

    return size
  end

  --- Check if a buffer belongs to the drawer. You can override this function
  --- to work with other plugins.
  --- @param bufname string
  function instance.is_buffer(bufname)
    return string.find(bufname, instance.opts.bufname_prefix) ~= nil
  end

  function instance.is_window(winid)
    return instance.state.windows_and_buffers[winid] ~= nil
    -- return vim.list_contains(instance.state.winids, winid)
  end

  table.insert(instances, instance)

  return instance
end

local drawer_augroup = vim.api.nvim_create_augroup('nvim-drawer', {
  clear = true,
})

function mod.setup(_)
  vim.keymap.set('n', '<leader>do', function()
    for _, instance in ipairs(instances) do
      vim.print({
        opts = instance.opts,
        state = instance.state,
        size = instance.get_size(),
        winid = instance.get_winid(),
        is_foucsed = instance.is_foucsed(),
      })
    end
  end, { noremap = true })

  vim.api.nvim_create_autocmd('TabEnter', {
    desc = 'nvim-drawer: Restore drawers',
    group = drawer_augroup,
    callback = function()
      for _, instance in ipairs(instances) do
        if instance.state.is_open then
          instance.close({ save_size = false })
          instance.open({ focus = false })

          local winid = instance.get_winid()
          if
            instance.opts.position == 'left'
            or instance.opts.position == 'right'
          then
            vim.api.nvim_win_set_width(winid, instance.state.size)
          else
            vim.api.nvim_win_set_height(winid, instance.state.size)
          end
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
      vim.print({
        event = event,
        winid = vim.fn.bufwinid(event.buf),
      })
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
      vim.print(event)
      --- @type integer
      --- @diagnostic disable-next-line: assign-type-mismatch
      local closing_window_id = tonumber(event.match)

      --- @type DrawerInstance | nil
      local closing_window_instance = nil

      for _, instance in ipairs(instances) do
        if instance.is_window(closing_window_id) then
          closing_window_instance = instance
          break
        end
      end

      if closing_window_instance == nil then
        local windows_in_tab = vim.api.nvim_tabpage_list_wins(0)
        local windows_in_tab_without_closing = vim.tbl_filter(function(winid)
          return winid ~= closing_window_id
        end, windows_in_tab)

        local num_drawers_in_tab = 0
        for _, winid in ipairs(windows_in_tab_without_closing) do
          for _, instance in ipairs(instances) do
            if instance.is_window(winid) then
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
