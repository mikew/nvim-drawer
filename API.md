# NvimDrawerCloseOptions

## save_size

```lua
boolean?
```

---

# NvimDrawerCreateOptions

## does_own_buffer

```lua
fun(context: { instance: NvimDrawerInstance, bufnr: integer, bufname: string, reason: 'lookup'|'vim_BufWinEnter'|'vim_BufWipeout' }):boolean??
```

## does_own_window

```lua
fun(context: { instance: NvimDrawerInstance, winid: integer, bufnr: integer, bufname: string, reason: 'lookup'|'vim_BufWinEnter' }):boolean??
```

## nvim_tree_hack

```lua
boolean?
```

Deprecated, please use `should_reuse_previous_bufnr = false` instead.

## on_did_close

```lua
(fun(event: { instance: NvimDrawerInstance, winid: integer }):nil)?
```

Called after the drawer is closed. Only called if the drawer was actually
open.
Not called in the context of the drawer window.

## on_did_create_buffer

```lua
(fun(event: { instance: NvimDrawerInstance, winid: integer, bufnr: integer }):nil)?
```

Called after a buffer is created. This is called very rarely.
Called in the context of the drawer window.

## on_did_open

```lua
(fun(event: { instance: NvimDrawerInstance, winid: integer, bufnr: integer }):nil)?
```

Called after .open() is done. Note this will be called even if the drawer
is open.
Called in the context of the drawer window.

## on_did_open_buffer

```lua
(fun(event: { instance: NvimDrawerInstance, winid: integer, bufnr: integer }):nil)?
```

Called after a buffer is opened.
Called in the context of the drawer window.

## on_did_open_window

```lua
(fun(event: { instance: NvimDrawerInstance, winid: integer, bufnr: integer }):nil)?
```

Called after a window is created.
Called in the context of the drawer window.

## on_vim_enter

```lua
(fun(event: { instance: NvimDrawerInstance }):nil)?
```

Called when vim starts up. Helpful to have drawers appear in the order they
were created in.
Not called in the context of the drawer window.

## on_will_close

```lua
(fun(event: { instance: NvimDrawerInstance }):nil)?
```

Called before the drawer is closed. Note this will is called even if the
drawer is closed.
Not called in the context of the drawer window.

## on_will_create_buffer

```lua
(fun(event: { instance: NvimDrawerInstance }):nil)?
```

Called before a buffer is created. This is called very rarely.
Not called in the context of the drawer window.

## on_will_open_buffer

```lua
(fun(event: { instance: NvimDrawerInstance, bufnr: integer, winid: integer }):nil)?
```

Called before a buffer is opened.
Not called in the context of the drawer window.

## on_will_open_window

```lua
(fun(event: { instance: NvimDrawerInstance, bufnr: integer }):nil)?
```

Called before the window is created.
Not called in the context of the drawer window.

## position

```lua
'above'|'below'|'float'|'left'|'right'
```

Position of the drawer.

## should_claim_new_window

```lua
boolean?
```

## should_reuse_previous_bufnr

```lua
boolean?
```

Don't keep the same buffer across all tabs.

## size

```lua
integer
```

Initial size of the drawer, in lines or columns.

## win_config

```lua
NvimDrawerWindowConfig?
```

Configuration for the floating window.

---

# NvimDrawerDoesOwnBufferReason

---

# NvimDrawerDoesOwnWindowReason

---

# NvimDrawerInstance

## build_win_config

```lua
function NvimDrawerInstance.build_win_config()
  -> vim.api.keyset.win_config
```

Builds a win_config for the drawer to be used with `nvim_win_set_config`.

## claim

```lua
function NvimDrawerInstance.claim(winid: integer)
```

## close

```lua
function NvimDrawerInstance.close(opts?: NvimDrawerCloseOptions)
```

Close the drawer. By default, the size of the drawer is saved.

```lua
example_drawer.close()

--- Don't save the size of the drawer.
example_drawer.close({ save_size = false })
```

## does_own_buffer

```lua
function NvimDrawerInstance.does_own_buffer(bufnr: integer, reason: 'lookup'|'vim_BufWinEnter'|'vim_BufWipeout')
  -> boolean
```

Check if a buffer belongs to the drawer.

```lua
reason:
    | 'vim_BufWipeout'
    | 'lookup'
    | 'vim_BufWinEnter'
```

## does_own_window

```lua
function NvimDrawerInstance.does_own_window(winid: integer, reason: 'lookup'|'vim_BufWinEnter')
  -> boolean
```

Check if a window belongs to the drawer.

```lua
reason:
    | 'lookup'
    | 'vim_BufWinEnter'
```

## focus

```lua
function NvimDrawerInstance.focus()
```

Focus the drawer.

## focus_and_return

```lua
function NvimDrawerInstance.focus_and_return(callback: fun())
```

Helper function to focus the drawer, run a callback, and return focus to
the previous window.

## focus_or_toggle

```lua
function NvimDrawerInstance.focus_or_toggle()
```

Focus the drawer if it's open, otherwise toggle it, and give it focus
when it is opened.

## get_size

```lua
function NvimDrawerInstance.get_size()
  -> integer
```

Get the size of the drawer in lines or columns.

## get_winid

```lua
function NvimDrawerInstance.get_winid()
  -> integer
```

Get the window id of the drawer. Returns `-1` if the drawer is not
open.

## go

```lua
function NvimDrawerInstance.go(distance: integer)
```

Navigate to the next or previous buffer.

```lua
--- Go to the next buffer.
example_drawer.go(1)

--- Go to the previous buffer.
example_drawer.go(-1)
```

## initialize_window

```lua
function NvimDrawerInstance.initialize_window(winid: integer)
```

## is_focused

```lua
function NvimDrawerInstance.is_focused()
  -> boolean
```

Check if the drawer is focused.

## open

```lua
function NvimDrawerInstance.open(opts?: NvimDrawerOpenOptions)
```

Open the drawer.

```lua
example_drawer.open()

--- Keep focus in the drawer.
example_drawer.open({ focus = true })

--- Open a new tab and focus it.
example_drawer.open({ mode = 'new', focus = true })
```

## store_buffer_info

```lua
function NvimDrawerInstance.store_buffer_info(winid: integer)
```

Store the current window and buffer information.

## toggle

```lua
function NvimDrawerInstance.toggle(opts?: NvimDrawerToggleOptions)
```

Toggle the drawer. Also lets you pass options to open the drawer.

```lua
example_drawer.toggle()

--- Focus the drawer when opening it.
example_drawer.toggle({ open = { focus = true } })
```

## toggle_zoom

```lua
function NvimDrawerInstance.toggle_zoom()
```

Toggles the drawer between its normal size and a zoomed size.

---

# NvimDrawerModule

## create_drawer

```lua
function NvimDrawerModule.create_drawer(opts: NvimDrawerCreateOptions)
  -> NvimDrawerInstance
```

Create a new drawer.

```lua
local example_drawer = drawer.create_drawer({
  size = 15,
  position = 'bottom',

  on_did_create_buffer = function()
  end,
})
```

## find_instance_for_winid

```lua
function NvimDrawerModule.find_instance_for_winid(winid: integer)
  -> NvimDrawerInstance|nil
```

## setup

```lua
function NvimDrawerModule.setup(options?: NvimDrawerSetupOptions)
```

---

# NvimDrawerOpenOptions

## focus

```lua
boolean?
```

## mode

```lua
('new'|'previous_or_new')?
```

---

# NvimDrawerSetupOptions

## position_order

```lua
('creation'|('above'|'below'|'float'|'left'|'right')[])?
```

---

# NvimDrawerState

## buffers

```lua
integer[]
```

The number of all buffers that have been created.

## index

```lua
integer
```

The internal ID of the drawer.

## is_open

```lua
boolean
```

Whether the drawer assumes it's open or not.

## is_zoomed

```lua
boolean
```

Whether the drawer is zoomed or not.

## previous_bufnr

```lua
integer
```

The number of the previous buffer that was opened.

## size

```lua
integer
```

The last known size of the drawer.

## windows_and_buffers

```lua
table<integer, integer>
```

The windows and buffers belonging to the drawer.

---

# NvimDrawerToggleOptions

## open

```lua
NvimDrawerOpenOptions?
```

---

# NvimDrawerWindowConfig

## anchor

```lua
('C'|'CC'|'CE'|'CW'|'E'...(+9))?
```

Anchor the window to a corner or center. Accepts variants for centering as well.

## height

```lua
(string|number)?
```

Width of the window. Can be a number or a percentage.

## margin

```lua
number?
```

Keep the window this many rows / columns away from the screen edge.

## width

```lua
(string|number)?
```

Width of the window. Can be a number or a percentage.

---
