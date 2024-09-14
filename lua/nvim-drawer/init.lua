--- @class NvimDrawerModule
local mod = {}

--- @class NvimDrawerCreateOptions
--- Initial size of the drawer, in lines or columns.
--- @field size integer
--- Position of the drawer.
--- @field position 'left' | 'right' | 'above' | 'below' | 'float'
--- Don't keep the same buffer across all tabs.
--- @field should_reuse_previous_bufnr? boolean
--- Deprecated, please use `should_reuse_previous_bufnr = false` instead.
--- @field nvim_tree_hack? boolean
--- Called before a buffer is created. This is called very rarely.
--- Not called in the context of the drawer window.
--- @field on_will_create_buffer? fun(event: { instance: NvimDrawerInstance }): nil
--- Called after a buffer is created. This is called very rarely.
--- Called in the context of the drawer window.
--- @field on_did_create_buffer? fun(event: { instance: NvimDrawerInstance, winid: integer, bufnr: integer }): nil
--- Called before a buffer is opened.
--- Not called in the context of the drawer window.
--- @field on_will_open_buffer? fun(event: { instance: NvimDrawerInstance }): nil
--- Called after a buffer is opened.
--- Called in the context of the drawer window.
--- @field on_did_open_buffer? fun(event: { instance: NvimDrawerInstance, winid: integer, bufnr: integer }): nil
--- Called before the window is created.
--- Not called in the context of the drawer window.
--- @field on_will_open_window? fun(event: { instance: NvimDrawerInstance, bufnr: integer }): nil
--- Called after a window is created.
--- Called in the context of the drawer window.
--- @field on_did_open_window? fun(event: { instance: NvimDrawerInstance, winid: integer, bufnr: integer }): nil
--- Called before the drawer is closed. Note this will is called even if the
--- drawer is closed.
--- Not called in the context of the drawer window.
--- @field on_will_close? fun(event: { instance: NvimDrawerInstance }): nil
--- Called after the drawer is closed. Only called if the drawer was actually
--- open.
--- Not called in the context of the drawer window.
--- @field on_did_close? fun(event: { instance: NvimDrawerInstance, winid: integer }): nil
--- Called when vim starts up. Helpful to have drawers appear in the order they
--- were created in.
--- Not called in the context of the drawer window.
--- @field on_vim_enter? fun(event: { instance: NvimDrawerInstance }): nil
--- Called after .open() is done. Note this will be called even if the drawer
--- is open.
--- Called in the context of the drawer window.
--- @field on_did_open? fun(event: { instance: NvimDrawerInstance, winid: integer, bufnr: integer }): nil
--- Configuration for the floating window.
--- @field win_config? NvimDrawerWindowConfig
--- @field does_own_window? fun(context: { instance: NvimDrawerInstance, winid: integer, bufnr: integer, bufname: string }): boolean
--- @field does_own_buffer? fun(context: { instance: NvimDrawerInstance, bufnr: integer, bufname: string }): boolean
--- @field should_claim_new_window? boolean

--- Extends `vim.api.keyset.win_config`
--- @class NvimDrawerWindowConfig: vim.api.keyset.win_config
--- Keep the window this many rows / columns away from the screen edge.
--- @field margin? number
--- Width of the window. Can be a number or a percentage.
--- @field width? number | string
--- Width of the window. Can be a number or a percentage.
--- @field height? number | string
--- Anchor the window to a corner or center. Accepts variants for centering as well.
--- @field anchor? 'NE' | 'NC' | 'N' | 'NW' | 'CE' | 'E' | 'CC' | 'C' | 'CW' | 'W' | 'SE' | 'SC' | 'S' | 'SW'

--- @class NvimDrawerState
--- Whether the drawer assumes it's open or not.
--- @field is_open boolean
--- The last known size of the drawer.
--- @field size integer
--- The number of the previous buffer that was opened.
--- @field previous_bufnr integer
--- The number of all buffers that have been created.
--- @field buffers integer[]
--- The internal ID of the drawer.
--- @field index integer
--- The windows and buffers belonging to the drawer.
--- @field windows_and_buffers table<integer, integer>
--- Whether the drawer is zoomed or not.
--- @field is_zoomed boolean

--- @type NvimDrawerInstance[]
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

--- @param percentage string
local function parse_percentage(percentage)
  if type(percentage) == 'string' then
    local number = tonumber(percentage)
    if number then
      return number / 100
    end

    if string.sub(percentage, -1) == '%' then
      local number_without_percentage = tonumber(string.sub(percentage, 1, -2))
      if number_without_percentage then
        return number_without_percentage / 100
      end
    end
  end

  error('Could not parse ' .. percentage)
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
--- @param opts NvimDrawerCreateOptions
function mod.create_drawer(opts)
  opts = vim.tbl_extend('force', {
    should_reuse_previous_bufnr = true,
    should_claim_new_window = true,
  }, opts or {})

  --- @class NvimDrawerInstance
  local instance = {
    --- @type NvimDrawerCreateOptions
    opts = opts,

    --- @type NvimDrawerState
    state = {
      index = #instances + 1,
      is_open = false,
      size = opts.size,
      previous_bufnr = -1,
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

  --- @class NvimDrawerOpenOptions
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
  --- @param opts? NvimDrawerOpenOptions
  function instance.open(opts)
    opts = vim.tbl_extend(
      'force',
      { focus = false, mode = 'previous_or_new' },
      opts or {}
    )

    instance.state.is_open = true

    local winid = instance.get_winid()

    -- To get the previous buffer, we start with `previous_bufnr` ...
    local bufnr = instance.state.previous_bufnr

    -- ... or we use the buffer of the window if it exists ...
    if instance.opts.nvim_tree_hack then
      instance.opts.should_reuse_previous_bufnr = false
    end
    if not instance.opts.should_reuse_previous_bufnr then
      bufnr = instance.state.windows_and_buffers[winid] or -1
    end

    -- ... and finally if we are trying to make a new window, we just force it
    -- to -1 so a buffer will be created.
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
      instance.initialize_window(winid)

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
      vim.api.nvim_win_set_config(winid, instance.build_win_config())
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

  --- Store the current window and buffer information.
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

  --- @param winid integer
  function instance.initialize_window(winid)
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
  end

  --- Builds a win_config for the drawer to be used with `nvim_win_set_config`.
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

      --- @type NvimDrawerWindowConfig
      local instance_win_config = vim.tbl_deep_extend('force', {
        anchor = 'CC',
        margin = 0,
      }, instance.opts.win_config or {})

      --- @type vim.api.keyset.win_config
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
      local window_width = 0
      if type(instance_win_config.width) == 'string' then
        window_width =
          math.floor(parse_percentage(instance_win_config.width) * screen_width)
      else
        window_width = instance_win_config.width
      end

      local window_height = 0
      if type(instance_win_config.height) == 'string' then
        window_height = math.floor(
          parse_percentage(instance_win_config.height)
            * screen_height_without_cmdline
        )
      else
        window_height = instance_win_config.height
      end

      local window_width_int = math.floor(window_width)
        - (instance_win_config.margin * 2)
      local window_height_int = math.floor(window_height)
        - (instance_win_config.margin * 2)
      local center_x = (
        screen_width
        - (window_width_int + border_width.left + border_width.right)
      ) / 2
      local center_y = (
        (
          screen_height
          - (window_height_int + border_width.top + border_width.bottom)
        ) / 2
      ) - cmdheight

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

  --- Toggles the drawer between its normal size and a zoomed size.
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

  --- @class NvimDrawerCloseOptions
  --- @field save_size? boolean

  --- Close the drawer. By default, the size of the drawer is saved.
  --- ```lua
  --- example_drawer.close()
  ---
  --- --- Don't save the size of the drawer.
  --- example_drawer.close({ save_size = false })
  --- ```
  --- @param opts? NvimDrawerCloseOptions
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

  --- @class NvimDrawerToggleOptions
  --- @field open? NvimDrawerOpenOptions

  --- Toggle the drawer. Also lets you pass options to open the drawer.
  --- ```lua
  --- example_drawer.toggle()
  ---
  --- --- Focus the drawer when opening it.
  --- example_drawer.toggle({ open = { focus = true } })
  --- ```
  --- @param opts? NvimDrawerToggleOptions
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
      if instance.is_focused() then
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
  function instance.is_focused()
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
      return instance.state.size
    end

    if instance.state.is_zoomed then
      return instance.state.size
    end

    local size = (
      (instance.opts.position == 'left' or instance.opts.position == 'right')
        and vim.api.nvim_win_get_width(winid)
      or vim.api.nvim_win_get_height(winid)
    ) or instance.state.size

    return size
  end

  --- Check if a window belongs to the drawer.
  --- @param winid integer
  function instance.does_own_window(winid)
    if not vim.api.nvim_win_is_valid(winid) then
      return false
    end

    if instance.state.windows_and_buffers[winid] ~= nil then
      return true
    end

    local bufnr = vim.api.nvim_win_get_buf(winid)
    if instance.opts.does_own_window then
      if
        instance.opts.does_own_window({
          instance = instance,
          winid = winid,
          bufnr = bufnr,
          bufname = vim.api.nvim_buf_get_name(bufnr),
        })
      then
        return true
      end
    end

    return instance.does_own_buffer(bufnr)
  end

  --- Check if a buffer belongs to the drawer.
  --- @param bufnr integer
  function instance.does_own_buffer(bufnr)
    if not vim.api.nvim_buf_is_valid(bufnr) then
      return false
    end

    if vim.list_contains(instance.state.buffers, bufnr) then
      return true
    end

    for _, buf in pairs(instance.state.windows_and_buffers) do
      if buf == bufnr then
        return true
      end
    end

    if instance.opts.does_own_buffer then
      return instance.opts.does_own_buffer({
        instance = instance,
        bufnr = bufnr,
        bufname = vim.api.nvim_buf_get_name(bufnr),
      })
    end

    return false
  end

  --- @param winid integer
  function instance.claim(winid)
    if not vim.api.nvim_win_is_valid(winid) then
      return
    end

    -- Handle the only current buffer, since the window might detach.
    local non_floating_windows = vim.tbl_filter(function(tab_winid)
      for _, drawer_instance in ipairs(instances) do
        if drawer_instance.state.windows_and_buffers[tab_winid] ~= nil then
          return false
        end
      end

      return vim.api.nvim_win_get_config(tab_winid).anchor == nil
    end, vim.api.nvim_tabpage_list_wins(0))

    if #non_floating_windows == 1 then
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_open_win(buf, false, {
        win = -1,
        split = 'above',
      })
    end

    instance.store_buffer_info(winid)
    instance.initialize_window(winid)
    instance.open({ mode = 'previous_or_new' })
  end

  table.insert(instances, instance)

  return instance
end

local drawer_augroup = vim.api.nvim_create_augroup('nvim-drawer', {
  clear = true,
})

local is_entering_new_tab = false

--- @param winid integer
function mod.find_instance_for_winid(winid)
  if not vim.api.nvim_win_is_valid(winid) then
    return
  end

  for _, instance in ipairs(instances) do
    if instance.does_own_window(winid) then
      return instance
    end
  end
end

function mod.setup(_)
  -- vim.keymap.set('n', '<leader>do', function()
  --   for _, instance in ipairs(instances) do
  --     vim.print({
  --       opts = instance.opts,
  --       state = instance.state,
  --       size = instance.get_size(),
  --       winid = instance.get_winid(),
  --       is_focused = instance.is_focused(),
  --     })
  --   end
  -- end, { noremap = true })

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
      -- Without `vim.schedule`, when calling `nvim_buf_get_name` with the
      -- buffer in the new tab, the name of the previous buffer is returned not
      -- an empty string
      -- as expected.
      vim.schedule(function()
        for _, instance in ipairs(instances) do
          if instance.state.is_open then
            instance.open({ focus = false })
          else
            -- Close here can cause issues with the automatic claiming, IE if a
            -- drawer owns `NOTES.md`, then the user does `:tabedit NOTES.md`,
            -- the new tab is closed immediately.
            -- This works around that.
            if not is_entering_new_tab then
              instance.close({ save_size = false })
            end
          end
        end

        is_entering_new_tab = false
      end)
    end,
  })

  vim.api.nvim_create_autocmd('TabNew', {
    desc = 'nvim-drawer: Set flag for new tab',
    group = drawer_augroup,
    callback = function()
      is_entering_new_tab = true
    end,
  })

  vim.api.nvim_create_autocmd('TabLeave', {
    desc = 'nvim-drawer: Save drawer sizes',
    group = drawer_augroup,
    callback = function()
      for _, instance in ipairs(instances) do
        if instance.state.is_open then
          local size = instance.get_size()
          instance.state.size = size

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

  vim.api.nvim_create_autocmd('BufWinEnter', {
    group = drawer_augroup,
    callback = function(event)
      vim.schedule(function()
        --- @type integer
        local bufnr = event.buf
        local winid = vim.fn.bufwinid(bufnr)

        for _, instance in ipairs(instances) do
          if
            instance.opts.should_claim_new_window
            and (instance.state.windows_and_buffers[winid] == nil)
            and instance.does_own_window(winid)
          then
            instance.claim(winid)
          end
        end
      end)
    end,
  })

  vim.api.nvim_create_autocmd('WinClosed', {
    desc = 'nvim-drawer: Close tab when all non-drawers are closed',
    group = drawer_augroup,
    callback = function(event)
      --- @type integer
      --- @diagnostic disable-next-line: assign-type-mismatch
      local closing_window_id = tonumber(event.match)
      local closing_instance = mod.find_instance_for_winid(closing_window_id)

      for _, instance in ipairs(instances) do
        if instance.state.windows_and_buffers[closing_window_id] ~= nil then
          instance.state.windows_and_buffers[closing_window_id] = nil
        end
      end

      if closing_instance == nil then
        local windows_in_tab = vim.api.nvim_tabpage_list_wins(0)
        local windows_in_tab_without_closing = vim.tbl_filter(function(winid)
          return winid ~= closing_window_id
        end, windows_in_tab)
        local drawers_in_tab = vim.tbl_filter(function(winid)
          return mod.find_instance_for_winid(winid) ~= nil
        end, windows_in_tab_without_closing)

        if #drawers_in_tab == #windows_in_tab_without_closing then
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
