# nvim-drawer

A Drawer plugin for Neovim.

Ever wanted your terminal or file explorer to be at the bottom, have the same
height, and appear on all tabs at a consistent size? And when you just want to
hide it, you don't want to have to do that across all tabs?

Then this plugin is for you.

## Installation

```lua
{
  'mikew/nvim-drawer',
  opts = {},
  config = function(_, opts)
    local drawer = require('nvim-drawer')
    drawer.setup(opts)

    -- See usage and examples below.
  end
}
```

## Features

- Attach to any side of the screen.
- Size is consistent across tabs.
- Open/close state is consistent across tabs.
- Has a tab system.
- When the last non-drawer is closed in a tab, the tab (or vim) is closed.
- Simple API.
- Uses buffers and is very flexible.

## Usage

First, you need to create a drawer via `create_drawer`:

```lua
local drawer = require('nvim-drawer')

local example_drawer = drawer.create_drawer({
  bufname_prefix = 'example_drawer_',
  size = 15,
  position = 'bottom',
})
```

When opened, this drawer will be at the bottom of the screen, 15 lines tall,
editing a buffer named `example_drawer_1`.

This doesn't do much, you get a nice scratch space, but to get the most out of
it, you need to use the API and add some key mappings.

Your drawer has methods like:

- `open()`: Open the drawer.
- `close()`: Close the drawer.
- `toggle()`: Toggle the drawer.
- `focus()`: Focus the drawer.
- `go()`: Go to a different tab.

## Examples

### Terminal

```lua
local drawer = require('nvim-drawer')

local terminal_drawer = drawer.create_drawer({
  bufname_prefix = 'quick_terminal_',
  size = 15,
  position = 'bottom',

  on_will_create_buffer = function()
    vim.fn.termopen(os.getenv('SHELL'))

    vim.opt_local.number = false
    vim.opt_local.signcolumn = 'no'
    vim.opt_local.statuscolumn = ''
  end,

  on_did_open_buffer = function()
    vim.cmd('$')
  end,
})

vim.keymap.set('n', '<C-`>', function()
  terminal_drawer.focus_or_toggle()
end)

vim.keymap.set('n', '<leader>tn', function()
  terminal_drawer.open({ mode = 'new' })
end)

vim.keymap.set('n', '<leader>tt', function()
  terminal_drawer.go(1)
end)

vim.keymap.set('n', '<leader>tT', function()
  terminal_drawer.go(-1)
end)

vim.api.nvim_create_autocmd('VimEnter', {
  desc = 'Open Tree automatically',
  once = true,
  callback = function()
    terminal_drawer.open()
  end,
})
```

### nvim-tree

```lua
local drawer = require('nvim-drawer')

local tree_drawer = drawer.create_drawer({
  bufname_prefix = 'tree_',
  size = 40,
  position = 'right',

  on_did_open_buffer = function()
    local nvim_tree_api = require('nvim-tree.api')
    nvim_tree_api.tree.open({ current_window = true })
    nvim_tree_api.tree.reload()

    -- NvimTree seems to set this back to true.
    vim.opt_local.winfixheight = false

    vim.opt_local.number = false
    vim.opt_local.signcolumn = 'no'
    vim.opt_local.statuscolumn = ''
  end,

  on_did_close = function()
    local nvim_tree_api = require('nvim-tree.api')
    nvim_tree_api.tree.close()
  end,
})

-- This is the trick to getting NvimTree working in a drawer.
-- We let NvimTree completely overwrite the split, which ends up renaming it to
-- something like `NvimTree_{N}`.
-- Then, we overwrite how the drawer is found so that any NvimTree windows are
-- found instead of drawer windows.
local original_is_buffer = tree_drawer.is_buffer
function tree_drawer.is_buffer(bufname)
  return string.find(bufname, 'NvimTree_') ~= nil or original_is_buffer(bufname)
end

vim.keymap.set('n', '<leader>e', function()
  tree_drawer.focus_or_toggle()
end)
```

## API

### CreateDrawerOptions

#### bufname_prefix

```lua
string
```

Prefix used when creating buffers.
Buffers will be named `{bufname_prefix}1`, `{bufname_prefix}2`, etc.

#### on_did_close

```lua
(fun():nil)?
```

Called after the drawer is closed. Only called if the drawer was actually
open.

#### on_did_open_buffer

```lua
(fun(bufname: string):nil)?
```

Called after a buffer is opened.

#### on_did_open_split

```lua
fun(bufname: string):nil
```

Called after a split is created.

#### on_will_close

```lua
fun():nil
```

Called before the drawer is closed. Note this will is called even if the
drawer is closed.

#### on_will_create_buffer

```lua
(fun(bufname: string):nil)?
```

Called before a buffer is created. This is called very rarely.

#### on_will_open_split

```lua
fun(bufname: string):nil
```

Called before the splt is created.

#### position

```lua
'bottom'|'left'|'right'|'top'
```

Position of the drawer.

#### size

```lua
integer
```

Initial size of the drawer, in lines or columns.

---

### DrawerCloseOptions

#### save_size

```lua
boolean?
```

---

### DrawerInstance

#### close

```lua
function DrawerInstance.close(opts?: DrawerCloseOptions)
```

Close the drawer. By default, the size of the drawer is saved.

```lua
example_drawer.close()

--- Don't save the size of the drawer.
example_drawer.close({ save_size = false })
```

#### focus

```lua
function DrawerInstance.focus()
```

Focus the drawer.

#### focus_and_return

```lua
function DrawerInstance.focus_and_return(callback: fun())
```

Helper function to focus the drawer, run a callback, and return focus to
the previous window.

#### focus_or_toggle

```lua
function DrawerInstance.focus_or_toggle()
```

Focus the drawer if it's open, otherwise toggle it, and give it focus
when it is opened.

#### get_size

```lua
function DrawerInstance.get_size()
  -> integer
```

Get the size of the drawer in lines or columns.

#### get_winnr

```lua
function DrawerInstance.get_winnr()
  -> integer
```

Get the window number of the drawer. Returns `-1` if the drawer is not
open.

#### go

```lua
function DrawerInstance.go(distance: integer)
```

Navigate to the next or previous buffer.

```lua
--- Go to the next buffer.
example_drawer.go(1)

--- Go to the previous buffer.
example_drawer.go(-1)
```

#### is_buffer

```lua
function DrawerInstance.is_buffer(bufname: string)
  -> boolean
```

Check if a buffer belongs to the drawer. You can override this function
to work with other plugins.

#### is_foucsed

```lua
function DrawerInstance.is_foucsed()
  -> boolean
```

Check if the drawer is focused.

#### open

```lua
function DrawerInstance.open(opts?: DrawerOpenOptions)
```

Open the drawer.

```lua
example_drawer.open()

--- Keep focus in the drawer.
example_drawer.open({ focus = true })

--- Open a new tab and focus it.
example_drawer.open({ mode = 'new', focus = true })
```

#### switch_window_to_buffer

```lua
function DrawerInstance.switch_window_to_buffer(bufname: string)
```

Switch the current window to a buffer and prepare it as a drawer.

#### toggle

```lua
function DrawerInstance.toggle(opts?: DrawerToggleOptions)
```

Toggle the drawer. Also lets you pass options to open the drawer.

```lua
example_drawer.toggle()

--- Focus the drawer when opening it.
example_drawer.toggle({ open = { focus = true } })
```

---

### DrawerOpenOptions

#### focus

```lua
boolean?
```

#### mode

```lua
('new'|'previous_or_new')?
```

---

### DrawerState

#### buffers

```lua
string[]
```

The names of all buffers that have been created.

#### count

```lua
integer
```

The number of buffers that have been created.

#### is_open

```lua
boolean
```

Whether the drawer assumes it's open or not.

#### previous_bufname

```lua
string
```

The name of the previous buffer that was opened.

#### size

```lua
integer
```

The last known size of the drawer.

---

### DrawerToggleOptions

#### open

```lua
DrawerOpenOptions?
```

---

### LuaLS

---

### NvimDrawerModule

#### create_drawer

```lua
function NvimDrawerModule.create_drawer(opts: CreateDrawerOptions)
  -> DrawerInstance
```

Create a new drawer.

```lua
local example_drawer = drawer.create_drawer({
  bufname_prefix = 'example_drawer_',
  size = 15,
  position = 'bottom',

  on_will_create_buffer = function()
  end,
})
```

#### setup

```lua
function NvimDrawerModule.setup(_: any)
```
