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

drawer.create_drawer({
  size = 15,
  position = 'bottom',
})
```

When opened, this drawer will be at the bottom of the screen, 15 lines tall,
editing a scratch buffer.

This doesn't do much, you get a nice scratch space, but to get the most out of
it, you need to use the API and add some key mappings.

Your drawer has methods like ...

- `open()`: Open the drawer.
- `close()`: Close the drawer.
- `toggle()`: Toggle the drawer.
- `focus()`: Focus the drawer.
- `go()`: Go to a different tab.

... and callbacks like:

- `on_did_create_buffer`: Called after a buffer is created.
- `on_did_open_window`: Called after a drawer is opened.
- `on_did_close`: Called after a drawer is closed.

## Examples

### Terminal

```lua
local drawer = require('nvim-drawer')

drawer.create_drawer({
  bufname_prefix = 'quick_terminal_',
  size = 15,
  position = 'below',

  on_vim_enter = function(event)
    -- Open the drawer on startup.
    event.instance.open({
      focus = false,
    })

    -- Example keymaps:
    -- C-`: focus the drawer.
    -- <leader>tn: open a new terminal.
    -- <leader>tt: go to the next terminal.
    -- <leader>tT: go to the previous terminal.
    vim.keymap.set('n', '<C-`>', function()
      event.instance.focus_or_toggle()
    end)
    vim.keymap.set('n', '<leader>tn', function()
      event.instance.open({ mode = 'new' })
    end)
    vim.keymap.set('n', '<leader>tt', function()
      event.instance.go(1)
    end)
    vim.keymap.set('n', '<leader>tT', function()
      event.instance.go(-1)
    end)
  end,

  -- When a new buffer is created, switch it to a terminal.
  on_did_create_buffer = function()
    vim.fn.termopen(os.getenv('SHELL'))
  end,

  -- Remove some UI elements.
  on_did_open_window = function()
    vim.opt.number = false
    vim.opt.signcolumn = 'no'
    vim.opt.statuscolumn = ''
  end,

  -- Scroll to the end when changing tabs.
  on_did_open = function()
    vim.cmd('$')
  end,
})
```

### nvim-tree

```lua
local drawer = require('nvim-drawer')

drawer.create_drawer({
  size = 40,
  position = 'right',
  nvim_tree_hack = true,

  on_vim_enter = function(event)
    --- Open the drawer on startup.
    event.instance.open({
      focus = false,
    })

    --- Example mapping to toggle.
    vim.keymap.set('n', '<leader>e', function()
      event.instance.focus_or_toggle()
    end)
  end,

  --- Ideally, we would just call this here and be done with it, but
  --- mappings in nvim-tree don't seem to apply when re-using a buffer in
  --- a new tab / window.
  on_did_create_buffer = function()
    local nvim_tree_api = require('nvim-tree.api')
    nvim_tree_api.tree.open({ current_window = true })
  end,

  --- This gets the tree to sync when changing tabs.
  on_did_open = function()
    local nvim_tree_api = require('nvim-tree.api')
    nvim_tree_api.tree.reload()

    vim.opt_local.number = false
    vim.opt_local.signcolumn = 'no'
    vim.opt_local.statuscolumn = ''
  end,

  --- Cleans up some things when closing the drawer.
  on_did_close = function()
    local nvim_tree_api = require('nvim-tree.api')
    nvim_tree_api.tree.close()
  end,
})
```

## API

[API.md](API.md)
