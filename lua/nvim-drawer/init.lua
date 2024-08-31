--- @class NvimDrawerModule
local mod = {}

--- @class CreateDrawerOptions
--- Initial size of the drawer, in lines or columns.
--- @field size integer
--- Position of the drawer.
--- @field position 'left' | 'right' | 'above' | 'below' | 'float'
--- Don't keep the same buffer across all tabs.
--- @field nvim_tree_hack? boolean
--- Called before a buffer is created. This is called very rarely.
--- Not called in the context of the drawer window.
--- @field on_will_create_buffer? fun(event: { instance: DrawerInstance }): nil
--- Called after a buffer is created. This is called very rarely.
--- Called in the context of the drawer window.
--- @field on_did_create_buffer? fun(event: { instance: DrawerInstance, winid: integer, bufnr: integer }): nil
--- Called before a buffer is opened.
--- Not called in the context of the drawer window.
--- @field on_will_open_buffer? fun(event: { instance: DrawerInstance }): nil
--- Called after a buffer is opened.
--- Called in the context of the drawer window.
--- @field on_did_open_buffer? fun(event: { instance: DrawerInstance, winid: integer, bufnr: integer }): nil
--- Called before the window is created.
--- Not called in the context of the drawer window.
--- @field on_will_open_window? fun(event: { instance: DrawerInstance, bufnr: integer }): nil
--- Called after a window is created.
--- Called in the context of the drawer window.
--- @field on_did_open_window? fun(event: { instance: DrawerInstance, winid: integer, bufnr: integer }): nil
--- Called before the drawer is closed. Note this will is called even if the
--- drawer is closed.
--- Not called in the context of the drawer window.
--- @field on_will_close? fun(event: { instance: DrawerInstance }): nil
--- Called after the drawer is closed. Only called if the drawer was actually
--- open.
--- Not called in the context of the drawer window.
--- @field on_did_close? fun(event: { instance: DrawerInstance, winid: integer }): nil
--- Called when vim starts up. Helpful to have drawers appear in the order they
--- were created in.
--- Not called in the context of the drawer window.
--- @field on_vim_enter? fun(event: { instance: DrawerInstance }): nil
--- Called after .open() is done. Note this will be called even if the drawer
--- is open.
--- Called in the context of the drawer window.
--- @field on_did_open? fun(event: { instance: DrawerInstance, winid: integer, bufnr: integer }): nil
--- @field win_config? DrawerWindowConfig

--- Adapted from `vim.api.keyset.win_config`
--- @class DrawerWindowConfig
--- @field margin? number
--- @field width? number
--- @field height? number
--- @field anchor? 'NE' | 'NC' | 'N' | 'NW' | 'CE' | 'E' | 'CC' | 'C' | 'CW' | 'W' | 'SE' | 'SC' | 'S' | 'SW'
--- @field external? boolean
--- @field focusable? boolean
--- @field zindex? integer
--- @field border? any
--- @field title? any
--- @field title_pos? string
--- @field footer? any
--- @field footer_pos? string
--- @field style? string
--- @field fixed? boolean

--- @class DrawerState
--- Whether the drawer assumes it's open or not.
--- @field is_open boolean
--- The last known size of the drawer.
--- @field size integer
--- The number of the previous buffer that was opened.
--- @field previous_bufnr integer
--- The number of buffers that have been created.
--- @field count integer
--- The number of all buffers that have been created.
--- @field buffers integer[]
--- The internal ID of the drawer.
--- @field index integer
--- The windows and buffers belonging to the drawer.
--- @field windows_and_buffers table<integer, integer>
--- Whether the drawer is zoomed or not.
--- @field is_zoomed boolean

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

--- Create a new drawer.
--- ```lua
--- local example_drawer = drawer.create_drawer({
---   size = 15,
---   position = 'bottom',
---
---   on_did_create_buffer = function()
---   end,
--- })
--- ```
--- @param opts CreateDrawerOptions
function mod.create_drawer(opts)
  opts = vim.tbl_extend('force', {
    nvim_tree_hack = false,
  }, opts or {})

  --- @class DrawerInstance
  local instance = {
    --- @type CreateDrawerOptions
    opts = opts,

    --- @type DrawerState
    state = {
      index = #instances + 1,
      is_open = false,
      size = opts.size,
      previous_bufnr = -1,
      count = 0,
      buffers = {},
      windows_and_buffers = {},
      is_zoomed = false,
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

    instance.state.is_open = true

    local winid = instance.get_winid()

    local bufnr = instance.state.previous_bufnr
    if instance.opts.nvim_tree_hack then
      bufnr = instance.state.windows_and_buffers[winid] or -1
    end
    if opts.mode == 'new' then
      bufnr = -1
    end

    local should_create_buffer = not vim.api.nvim_buf_is_valid(bufnr)
    if should_create_buffer then
      try_callback('on_will_create_buffer', { instance = instance })
      bufnr = vim.api.nvim_create_buf(false, true)

      -- Intentionally not calling `on_did_create_buffer` here, since the
      -- buffer isn't attached to a window yet, and things like `termopen()`
      -- expect the buffer to be in a window.
      -- It's called later after the window exists.
    end

    if winid == -1 then
      try_callback('on_will_open_window', {
        instance = instance,
        bufnr = bufnr,
      })

      try_callback('on_will_open_buffer', {
        instance = instance,
        bufnr = bufnr,
      })

      winid = vim.api.nvim_open_win(bufnr, false, instance.build_win_config())

      vim.api.nvim_win_call(winid, function()
        vim.opt_local.bufhidden = 'hide'
        vim.opt_local.buflisted = false

        vim.opt_local.equalalways = false
        if
          instance.opts.position == 'left'
          or instance.opts.position == 'right'
        then
          vim.opt_local.winfixwidth = true
          vim.opt_local.winfixheight = false
        else
          vim.opt_local.winfixwidth = false
          vim.opt_local.winfixheight = true
        end
      end)

      vim.api.nvim_win_call(winid, function()
        try_callback('on_did_open_window', {
          instance = instance,
          winid = winid,
          bufnr = bufnr,
        })
      end)

      vim.api.nvim_win_call(winid, function()
        try_callback('on_did_open_buffer', {
          instance = instance,
          winid = winid,
          bufnr = bufnr,
        })
      end)
    else
      try_callback('on_will_open_buffer', {
        instance = instance,
        bufnr = bufnr,
        winid = winid,
      })
      vim.api.nvim_win_set_buf(winid, bufnr)
      vim.api.nvim_win_call(winid, function()
        try_callback('on_did_open_buffer', {
          instance = instance,
          winid = winid,
          bufnr = bufnr,
        })
      end)
    end

    if should_create_buffer then
      vim.api.nvim_win_call(winid, function()
        try_callback('on_did_create_buffer', {
          instance = instance,
          winid = winid,
          bufnr = bufnr,
        })
      end)
    end

    if opts.focus then
      vim.api.nvim_set_current_win(winid)
    end

    vim.api.nvim_win_call(winid, function()
      try_callback('on_did_open', {
        instance = instance,
        winid = winid,
        bufnr = bufnr,
      })
    end)

    instance.store_buffer_info(winid)
  end

  --- @param winid integer
  function instance.store_buffer_info(winid)
    if winid == -1 then
      return
    end

    local final_bufnr = vim.api.nvim_win_get_buf(winid)
    instance.state.windows_and_buffers[winid] = final_bufnr
    if not vim.list_contains(instance.state.buffers, final_bufnr) then
      table.insert(instance.state.buffers, final_bufnr)
    end
    instance.state.previous_bufnr = final_bufnr
  end

  function instance.build_win_config()
    --- @type vim.api.keyset.win_config
    local win_config = {}

    --- @type integer
    local cmdheight = vim.opt.cmdheight:get()
    --- @type integer
    local screen_width = vim.opt.columns:get()
    --- @type integer
    local screen_height = vim.opt.lines:get()
    local screen_height_without_cmdline = screen_height - cmdheight

    if instance.opts.position == 'float' then
      win_config.relative = 'editor'

      --- @type DrawerWindowConfig
      local instance_win_config = vim.tbl_deep_extend('force', {
        anchor = 'CC',
        margin = 0,
      }, instance.opts.win_config or {})

      win_config = vim.tbl_deep_extend('force', win_config, instance_win_config)

      local border_width = {
        left = 0,
        right = 0,
        top = 0,
        bottom = 0,
      }
      if win_config.border ~= nil and win_config.border ~= 'none' then
        border_width = {
          left = 1,
          right = 1,
          top = 1,
          bottom = 1,
        }
      end

      -- Taken from https://github.com/MarioCarrion/videos/blob/269956e913b76e6bb4ed790e4b5d25255cb1db4f/2023/01/nvim/lua/plugins/nvim-tree.lua
      local window_width = (instance_win_config.width < 1)
          and (screen_width * instance_win_config.width)
        or instance_win_config.width
      local window_height = (instance_win_config.height < 1)
          and (screen_height_without_cmdline * instance_win_config.height)
        or instance_win_config.height
      local window_width_int = math.floor(window_width)
        - (instance_win_config.margin * 2)
      local window_height_int = math.floor(window_height)
        - (instance_win_config.margin * 2)
      local center_x = (screen_width - window_width) / 2
      local center_y = ((screen_height - window_height) / 2) - cmdheight

      win_config.width = window_width_int
      win_config.height = window_height_int

      local anchor = instance_win_config.anchor
      if anchor == 'N' then
        anchor = 'NC'
      elseif anchor == 'S' then
        anchor = 'SC'
      elseif anchor == 'E' then
        anchor = 'CE'
      elseif anchor == 'W' then
        anchor = 'CW'
      elseif anchor == 'C' then
        anchor = 'CC'
      end
      local anchor_x = string.sub(anchor, 2, 2)
      local anchor_y = string.sub(anchor, 1, 1)

      if anchor_y == 'N' then
        win_config.row = instance_win_config.margin
      elseif anchor_y == 'C' then
        win_config.row = center_y
      elseif anchor_y == 'S' then
        win_config.row = screen_height_without_cmdline
          - window_height_int
          - instance_win_config.margin
          - border_width.top
          - border_width.bottom
      end

      if anchor_x == 'E' then
        win_config.col = screen_width
          - window_width_int
          - instance_win_config.margin
          - border_width.left
          - border_width.right
      elseif anchor_x == 'C' then
        win_config.col = center_x
      elseif anchor_x == 'W' then
        win_config.col = instance_win_config.margin
      end

      if instance.state.is_zoomed then
        win_config.row = instance_win_config.margin
        win_config.col = instance_win_config.margin
        win_config.width = screen_width
          - (instance_win_config.margin * 2)
          - border_width.left
          - border_width.right
        win_config.height = screen_height_without_cmdline
          - (instance_win_config.margin * 2)
          - border_width.top
          - border_width.bottom
      end

      -- Cleanup
      win_config.margin = nil
      win_config.anchor = nil
    else
      win_config.win = -1
      win_config.split = instance.opts.position

      if
        instance.opts.position == 'left'
        or instance.opts.position == 'right'
      then
        win_config.width = instance.state.size

        if instance.state.is_zoomed then
          win_config.width = screen_width
        end
      end
      if
        instance.opts.position == 'above'
        or instance.opts.position == 'below'
      then
        win_config.height = instance.state.size

        if instance.state.is_zoomed then
          win_config.height = screen_height
        end
      end
    end

    return win_config
  end

  function instance.toggle_zoom()
    local winid = instance.get_winid()
    if winid == -1 then
      return
    end

    instance.state.is_zoomed = not instance.state.is_zoomed
    vim.api.nvim_win_set_config(winid, instance.build_win_config())
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

    local index =
      index_of(instance.state.buffers, instance.state.previous_bufnr)
    if index == -1 then
      return
    end

    local next_index = index + distance
    local next_bufnr =
      instance.state.buffers[((next_index - 1) % #instance.state.buffers) + 1]

    try_callback('on_will_open_buffer', {
      instance = instance,
      bufnr = next_bufnr,
      winid = winid,
    })
    vim.api.nvim_win_set_buf(winid, next_bufnr)
    vim.api.nvim_win_call(winid, function()
      try_callback('on_did_open_buffer', {
        instance = instance,
        winid = winid,
        bufnr = next_bufnr,
      })
    end)
    instance.store_buffer_info(winid)
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

    try_callback('on_will_close', { instance = instance })

    instance.state.is_open = false

    local winid = instance.get_winid()

    if winid == -1 then
      return
    end

    if opts.save_size then
      instance.state.size = instance.get_size()
    end

    instance.store_buffer_info(winid)
    vim.api.nvim_win_close(winid, false)
    -- instance.state.windows_and_buffers[winid] = nil
    try_callback('on_did_close', { instance = instance, winid = winid })
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
      if instance.does_own_window(w) then
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

  --- Set the size of the drawer in lines or columns.
  --- @param size integer
  function instance.set_size(size)
    local winid = instance.get_winid()
    if winid == -1 then
      return
    end

    instance.state.size = size

    if
      instance.opts.position == 'left'
      or instance.opts.position == 'right'
    then
      vim.api.nvim_win_set_width(winid, size)
    else
      vim.api.nvim_win_set_height(winid, size)
    end
  end

  --- Check if a window belongs to the drawer.
  function instance.does_own_window(winid)
    return instance.state.windows_and_buffers[winid] ~= nil
  end

  --- Check if a buffer belongs to the drawer.
  function instance.does_own_buffer(bufnr)
    return vim.list_contains(instance.state.buffers, bufnr)
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

  vim.api.nvim_create_autocmd('VimEnter', {
    desc = 'nvim-drawer: Run on_vim_enter',
    group = drawer_augroup,
    once = true,
    callback = function()
      for _, instance in ipairs(instances) do
        if instance.opts.on_vim_enter then
          instance.opts.on_vim_enter({ instance = instance })
        end
      end
    end,
  })

  vim.api.nvim_create_autocmd('TabEnter', {
    desc = 'nvim-drawer: Restore drawers',
    group = drawer_augroup,
    callback = function()
      for _, instance in ipairs(instances) do
        if instance.state.is_open then
          instance.open({ focus = false })

          local winid = instance.get_winid()
          instance.set_size(instance.state.size)

          local bufnr = instance.state.previous_bufnr
          vim.api.nvim_win_set_buf(winid, bufnr)
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
          local size = instance.get_size()
          if size > 0 then
            instance.state.size = size
          end

          local winid = instance.get_winid()
          instance.store_buffer_info(winid)
        end
      end
    end,
  })

  vim.api.nvim_create_autocmd('VimResized', {
    desc = 'nvim-drawer: Resize drawers',
    group = drawer_augroup,
    callback = function()
      for _, instance in ipairs(instances) do
        for winid, _ in pairs(instance.state.windows_and_buffers) do
          if instance.opts.position == 'float' then
            if vim.api.nvim_win_is_valid(winid) then
              vim.api.nvim_win_set_config(winid, instance.build_win_config())
            end
          end
        end
      end
    end,
  })

  vim.api.nvim_create_autocmd('BufWipeout', {
    desc = 'nvim-drawer: Cleanup when buffer is wiped out',
    group = drawer_augroup,
    callback = function(event)
      local closing_bufnr = event.buf

      for _, instance in ipairs(instances) do
        if instance.does_own_buffer(closing_bufnr) then
          local new_buffers = vim.tbl_filter(function(b)
            return b ~= closing_bufnr
          end, instance.state.buffers)

          --- TODO While it makes sense to do this here, it results in
          --- nvim-tree closing when a tab is closed.
          -- instance.state.is_open = false
          instance.state.previous_bufnr = new_buffers[#new_buffers] or -1
          instance.state.buffers = new_buffers

          for winid, bufnr in pairs(instance.state.windows_and_buffers) do
            if bufnr == closing_bufnr then
              instance.state.windows_and_buffers[winid] = nil
            end
          end

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

      --- @type DrawerInstance | nil
      local is_closing_drawer = nil

      for _, instance in ipairs(instances) do
        if instance.does_own_window(closing_window_id) then
          is_closing_drawer = true
          break
        end

        if instance.state.windows_and_buffers[closing_window_id] ~= nil then
          instance.state.windows_and_buffers[closing_window_id] = nil
        end
      end

      if not is_closing_drawer then
        local windows_in_tab = vim.api.nvim_tabpage_list_wins(0)
        local windows_in_tab_without_closing = vim.tbl_filter(function(winid)
          return winid ~= closing_window_id
        end, windows_in_tab)

        local num_drawers_in_tab = 0
        for _, winid in ipairs(windows_in_tab_without_closing) do
          for _, instance in ipairs(instances) do
            if instance.does_own_window(winid) then
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
      end
    end,
  })
end

return mod
