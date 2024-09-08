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

https://github.com/user-attachments/assets/008b0d7f-2edc-408c-9422-0fa7b7bc72ed

- Attach to any side of the screen.
- Floating drawers.
- Automatically claim buffers.
- Size is consistent across tabs.
- Open/close state is consistent across tabs.
- Drawers can be zoomed to take up the whole screen.
- Drawers remember what buffer they were editing.
- Has a tab system.
- When the last non-drawer is closed in a tab, the tab (or vim) is closed.
- Simple API.
- Uses buffers and is very flexible.

## About

At its core, nvim-drawer just creates and hides windows and tries _really_ hard
to keep them consistent across tabs. You could also call a "drawer" a
persistent window, or a persistent split.

Since windows in vim require a buffer, nvim-drawer creates a scratch buffer for
you.

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

https://github.com/user-attachments/assets/a4818838-5c9a-4e68-87eb-396c7e781a11

```lua
local drawer = require('nvim-drawer')

drawer.create_drawer({
  size = 15,
  position = 'below',

  -- Automatically claim any opened terminals.
  does_own_buffer = function(context)
    return context.bufname:match('term://') ~= nil
  end,

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
    -- <leader>tz: zoom the terminal.
    vim.keymap.set('n', '<C-`>', function()
      event.instance.focus_or_toggle()
    end)
    vim.keymap.set('t', '<C-`>', function()
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
    vim.keymap.set('n', '<leader>tz', function()
      event.instance.toggle_zoom()
    end)
  end,

  -- When a new buffer is created, switch it to a terminal.
  on_did_create_buffer = function()
    vim.fn.termopen(os.getenv('SHELL'))
  end,

  -- Remove some UI elements.
  on_did_open_buffer = function()
    vim.opt_local.number = false
    vim.opt_local.signcolumn = 'no'
    vim.opt_local.statuscolumn = ''
  end,

  -- Scroll to the end when changing tabs.
  on_did_open = function()
    vim.cmd('$')
  end,
})
```

### nvim-tree

https://github.com/user-attachments/assets/5aad5f84-ccd2-4b25-9b32-369f01b508d3

```lua
local drawer = require('nvim-drawer')

drawer.create_drawer({
  size = 40,
  position = 'right',
  should_reuse_previous_bufnr = false,

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

### `NOTES.md` / `.plan`

https://github.com/user-attachments/assets/99161d29-6c41-4209-947e-d20dcea8dd89

```lua
local drawer = require('nvim-drawer')

drawer.create_drawer({
  position = 'float',
  -- Technically unused when using `position = 'float'`.
  size = 40,

  win_config = {
    anchor = 'NC',
    margin = 2,
    border = 'rounded',
    width = '100%',
    height = 10,
  },

  -- Automatically claim any opened NOTES.md file.
  does_own_buffer = function(context)
    return context.bufname:match('NOTES.md') ~= nil
  end,

  on_vim_enter = function(event)
    vim.keymap.set('n', '<leader>nn', function()
      event.instance.focus_or_toggle()
    end)
    vim.keymap.set('n', '<leader>nz', function()
      event.instance.toggle_zoom()
    end)
  end,

  on_did_create_buffer = function()
    vim.cmd('edit NOTES.md')
  end,
})
```

## API

[API.md](API.md)

## Alternatives

- [nvim-ide](https://github.com/ldelossa/nvim-ide)
- [edgy.nvim](https://github.com/folke/edgy.nvim)
