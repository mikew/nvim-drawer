# CreateDrawerOptions

## nvim_tree_hack

```lua
boolean
```

Don't keep the same buffer across all tabs.

## on_did_close

```lua
fun(event: { instance: DrawerInstance, winid: integer }):nil
```

Called after the drawer is closed. Only called if the drawer was actually
open.
Not called in the context of the drawer window.

## on_did_create_buffer

```lua
fun(event: { instance: DrawerInstance, winid: integer, bufnr: integer }):nil
```

Called after a buffer is created. This is called very rarely.
Called in the context of the drawer window.

## on_did_open

```lua
fun(event: { instance: DrawerInstance, winid: integer, bufnr: integer }):nil
```

Called after .open() is done. Note this will be called even if the drawer
is open.
Called in the context of the drawer window.

## on_did_open_buffer

```lua
fun(event: { instance: DrawerInstance, winid: integer, bufnr: integer }):nil
```

Called after a buffer is opened.
Called in the context of the drawer window.

## on_did_open_window

```lua
fun(event: { instance: DrawerInstance, winid: integer, bufnr: integer }):nil
```

Called after a window is created.
Called in the context of the drawer window.

## on_vim_enter

```lua
fun(event: { instance: DrawerInstance }):nil
```

Called when vim starts up. Helpful to have drawers appear in the order they
were created in.
Not called in the context of the drawer window.

## on_will_close

```lua
fun(event: { instance: DrawerInstance }):nil
```

Called before the drawer is closed. Note this will is called even if the
drawer is closed.
Not called in the context of the drawer window.

## on_will_create_buffer

```lua
fun(event: { instance: DrawerInstance }):nil
```

Called before a buffer is created. This is called very rarely.
Not called in the context of the drawer window.

## on_will_open_buffer

```lua
fun(event: { instance: DrawerInstance }):nil
```

Called before a buffer is opened.
Not called in the context of the drawer window.

## on_will_open_window

```lua
fun(event: { instance: DrawerInstance, bufnr: integer }):nil
```

Called before the window is created.
Not called in the context of the drawer window.

## position

```lua
'above'|'below'|'left'|'right'
```

Position of the drawer.

## size

```lua
integer
```

Initial size of the drawer, in lines or columns.

---

# DrawerCloseOptions

## save_size

```lua
boolean?
```

---

# DrawerInstance

## close

```lua
function DrawerInstance.close(opts?: DrawerCloseOptions)
```

Close the drawer. By default, the size of the drawer is saved.

```lua
example_drawer.close()

--- Don't save the size of the drawer.
example_drawer.close({ save_size = false })
```

## does_own_buffer

```lua
function DrawerInstance.does_own_buffer(bufnr: any)
```

Check if a buffer belongs to the drawer.

## does_own_window

```lua
function DrawerInstance.does_own_window(winid: any)
  -> boolean
```

Check if a window belongs to the drawer.

## focus

```lua
function DrawerInstance.focus()
```

Focus the drawer.

## focus_and_return

```lua
function DrawerInstance.focus_and_return(callback: fun())
```

Helper function to focus the drawer, run a callback, and return focus to
the previous window.

## focus_or_toggle

```lua
function DrawerInstance.focus_or_toggle()
```

Focus the drawer if it's open, otherwise toggle it, and give it focus
when it is opened.

## get_size

```lua
function DrawerInstance.get_size()
  -> integer
```

Get the size of the drawer in lines or columns.

## get_winid

```lua
function DrawerInstance.get_winid()
  -> integer
```

Get the window id of the drawer. Returns `-1` if the drawer is not
open.

## go

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

## is_foucsed

```lua
function DrawerInstance.is_foucsed()
  -> boolean
```

Check if the drawer is focused.

## open

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

## set_size

```lua
function DrawerInstance.set_size(size: integer)
```

Set the size of the drawer in lines or columns.

## store_buffer_info

```lua
function DrawerInstance.store_buffer_info(winid: integer)
```

## toggle

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

# DrawerOpenOptions

## focus

```lua
boolean?
```

## mode

```lua
('new'|'previous_or_new')?
```

---

# DrawerState

## buffers

```lua
integer[]
```

The number of all buffers that have been created.

## count

```lua
integer
```

The number of buffers that have been created.

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

The windows belonging to the drawer.

- @field winids integer[]

---

# DrawerToggleOptions

## open

```lua
DrawerOpenOptions?
```

---

# LuaLS

---

# NvimDrawerModule

## create_drawer

```lua
function NvimDrawerModule.create_drawer(opts: CreateDrawerOptions)
  -> DrawerInstance
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

## setup

```lua
function NvimDrawerModule.setup(_: any)
```
