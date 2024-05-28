--[[
Stuff internal to the UI system. This file exists to avoid circular imports; the
public API is scripts/ui.lua and ui/controls, which are mostly reexported via
ui.lua for convenience.

Mainly this is functions to manipulate the global state and do event handling,
as pulling those out to a file avoids any possible issues around circular
importing.  If controls had to require ui.lua, and ui.lua wants to reexport the
controls, that won't work. Instead controls require this file.

The rest of this comment explains the internal structure.  For better
end-user-facing docs and conceptual info, see ui.lua.  If you are building a new
interface look at ui/flows/fast-travel.lua.  This handles most of the following
in a way that allows for building interfaces without having to fully understand
it.  In other words most of the following is internal to the implementation.

To briefly summarize, the registered panels are mostly opaque.  For example the
inventory workflow is in ui/workflows, and someone wanting to play with the
inventory is supposed to just open it.

UIs have 3 entities:

- Panels, which are "windows".
- Tabs. All panels must have at least one tab.
- Controls. Controls respond to events.  Technically panels and windows are
  special controls.

Panels and tabs are special.  Panels always handle all events fed to them, even
if there is nowhere to send it.  That is unhandled events are swallowed.  Tabs
are always immediate children of panels, and always handle only tab and
shift+tab, via evt_next_tab and evt_prev_tab.  A panel without tabs from the UX
perspective is a panel with one tab.

To allow for nesting, we place a stack for panels and a panel-relative path in
global.  This module owns (for now) global.ui_new.  Once we remove the old
systems, this will change to global.ui.  It looks like this.

```
{
   stack = {
      { 
         panel_name = "foo", 
   },
   panel_states = { name: opaque, opaque, ... }
}
```

The code in the mod is already enforced to be the same for all players by
Factorio's hashing, and as a consequence users need only consistently build the
same UI.  The non-global-safe code can thus include functions in tables.  This
module will include the global state necessary for each piece to run in the
calls.

When this module says "calls", it means `a.b`, which can be done however you
want.  It doesn't care how, and it won't be trying to save functions in global,
so a simple table of closures or normal functions is generally good enough, and
it's not necessary to do more complicated things with metatables.

Event dispatching finds the top of the panel stack.  Then it locates the
player's focus.  It climbs up the stack until something handles it, giving each
control a chance.  As an example of why this is important, it allows for
building the fast travel menu as a vertical menu with horizontal rows, where the
horizontal rows  are other controls: the deepest control handles
left/right/click, the vertical part handles up/down/search.  In the case of
other boring menus with a fixed list, using a label control lets them not worry
about state themselves.  That said, this is actually split: panels themselves
handle the focus management and panel-local dispatch, not this file.

To allow controls to respond to state changes, they periodically have `rebuild`
called on them, starting at the panel and moving down (because starting at the
bottom for a control that may no longer need to exist isn't cheap).  In many
cases options also support being functions instead of fixed values.  For the
time being, however, the only argument such functions get is the player index,
so use closures for any extra state.  When implementing a new control, don't
read user-passed fields directly.  Instead, use `ui_index` to index into the
table, which will call functions whenever it hits one.  Actually wanting
closures to get through to the control itself must be handled specially by the
control as these will be mistaken for lazy values.  This mechanism allows one to
write functions to compute something (e.g. an item and a count), then just plug
it in and the UI will do the rest.

Or put more simply, controls themselves are "normal" objects, and only part
lives in global state.

Note that it's fine to let closures capture the pindex themselves: they're
already linked to a specific panel in that case.  Passing the pindex in is just
about convenience.

We would like to be more convenient.  Unfortunately Factorio has both
straightforward state management like the travel menu, and more complex things
like listing off entities which sometimes don't have a unit number and thus
cannot be uniquely identified.

One may be asking how one handles the case in which some control changes in a
way incompatible with ui global state.  It's wiped out in on_init and
on_configuration_changed.  That covers mod and game updates both, as well as
settings changes.  It turns out it's not possible to reliably detect save
restarts, so we cannot handle that case.

Panels have to register at the time control.lua is loaded, and there can only be
one of each name.  This basically means that for a complex workflow or whatever,
it may reuse a panel it already made if it wants, but it can't make more after
control.lua finishes loading.  These registration functions return the passed
name.  So:

```
mod.travel_menu = ustat.register('travel', travel_builder)
assert(mod.travel_menu == 'travel')
```

And then panels are referred to by their names.

The workaround for multiple panels or recursive panels or w/e that doesn't
require reusing is to register multiple under different names.  If this is ever required, it is best
to re-examine the problem, but this module could probably be extended if someone
comes up with a good use case.

All this said, the concrete flow for an event is as follows:

- This file finds the panel
- It gets the panel's global state and calls the panel's event function, passing
  it the global state.
- The panel finds the focused control and goes up to the panel as the root, then
  tells ui that it handled it even if it didn't.

Actual control functions get a copy of their state in global, and a controller
that talks to the panel to let it do things, for example constructing it to
close.  Player build functions also get this controller, plus methods to add
things to itt.  The panel stores the state of controls as a subfield of the
state it manages, and re-links them up via user-supplied tags.
]]

local mod = {}

---@class PanelStack
---@field panel_name string
---@field path  number[]
---@field control_states table<string, any>

---@class UiPlayerState
---@field stack PanelStack
---@field panel_states table<string, any>

---@alias UiGlobalState UiPlayerState[]

-- Return a reference to our part of global state.  Nil
-- if it hasn't been built yet.  UI usage before on_init is not possible and
-- will result in nil indexing errors.
--
-- Just a table of players.  Each player gets their own state.
local function ui_global()
   if not global.ui_new then mod.reset_global() end

   return global.ui_new
end

-- Used to reset our global state in on_init, on_configuration_changed.
function mod.reset_global()
   global.ui_new = {}
end

--- Index a table calling functions whenever we find one before applying the
--  next index.  If the last index is a function, also call it, then return that
--  value.
mod.ui_index = function(pindex, tab, first, ...)
   local nargs = select("#", ...)
   local ret = tab[first]

   for i = 1, nargs do
      if type(ret) == "function" then ret = ret(pindex) end
      ret = ret[select(i, ...)]
   end

   -- Possibly we need to resolve the final function call here.
   if type(ret) == "function" then ret = ret(pindex) end
   return ret
end

--- @returns UiPlayerState
function mod.global_state_for_player(pindex)
   local ug = ui_global()
   if not ug[pindex] then ug[pindex] = { stack = {}, panel_states = {} } end
   return ug[pindex]
end

-- When tables for panels are built at runtime, they go into this.
local panel_registry = {}

-- Cache of the results of the deterministic builder functions by pindex then by panel name.
local built_panel_cache = {}

-- Register a panel's builder.
--
---@param name string
---@param builder function
---@returns string
function mod.register_panel(name, builder)
   assert(panel_registry[name] == nil)
   panel_registry[name] = builder
   return name
end

---@param pindex number
--- @returns string?
--
-- Get the name of the currently active panel. If this returns nil the UI is
-- closed.
function mod.active_panel_name(pindex)
   local l = mod.global_state_for_player(pindex)
   local stack_ent = l.stack[#l.stack]
   if not stack_ent then return end
   return stack_ent.name
end

local function active_panel_state(pindex)
   local ug = ui_global()[pindex]
   local len = #ug.stack
   if len == 0 then return end
   local s = ug.stack[len]
   if not ug.panel_states[s.panel_name] then ug.panel_states[s.panel_name] = {} end
   return ug.panel_states[s.panel_name]
end

local function get_active_panel_descriptor_and_vtab(pindex)
   local ug = ui_global()[pindex]
   local len = #ug.stack
   if len == 0 then return end
   local s = ug.stack[len]
   local meta = mod.lookup_panel(s.name)
   return meta.descriptor, meta.vtable
end

function mod.lookup_panel(name)
   assert(panel_registry[name])
   if built_panel_cache[name] ~= nil then return built_panel_cache[name] end
   built_panel_cache[name] = panel_registry[name].builder()
   return built_panel_cache[name]
end

-- Build a panel for a given pindex if it has not been cached, then push it onto the panel stack.
---@param name string
---@returns nil
function mod.oepn_panel(pindex, name)
   mod.lookup_panel(name) -- Doesn't matter, just makes sure one got built.
   local ug = ui_global()[pindex]
   if ug.panel_states[name] == nil then ug.panel_states[name] = {} end
   table.insert(ug.stack, { panel_name = name })
end

-- Get access to a cached panel's function table.
--
-- Returns nil if the ui is closed.
function mod.get_active_panel_vtab(pindex)
   local a_p = mod.active_panel_name(pindex)
   if not a_p then return end
   local r = panel_registry[a_p]
   assert(r)
   return r
end

-- Internal. name is prefixed with evt_ by the closure variant below, , then
-- passed off to the currently open panel's handle_event function.  Returns
-- whether or not the caller should treat the event as handled which, in this
-- case, is synonymous with whether or not the UI is open.
--
---@param pindex number
---@param name string
--- @returns bool
function mod.dispatch_event(pindex, name, ...)
   local d, v = mod.get_active_panel_descriptor_and_vtab(pindex)
   if v and v[name] then
      local gstate = active_panel_state(pindex)

      v[name](pindex, {
         descriptor = d,
         global_state = gstate,
      }, ...)
      -- Bubbling in a panel is handled by panel.lua. The caller only gets
      -- false if there isn't one to swallow it.
      return true
   end

   return false
end

---@type string[]
--
-- An array of every event name this module uses in no particular order, with
-- the evt_ prefix prepended.  Occasionally useful to add something for all
-- events in a loop.
mod.all_event_names = {}

-- This also adds per-event per-tick rate limiting.  The mod currently has tons
-- of events on the same keypress.  We can limit with a capture of a local
-- holding the last tick.  This will have to be removed but is good enough to
-- get a single-player prototype up.  If we could handle an event of some given
-- type, we just always handle it this tick but only make one call.  That'll
-- shut down anything that comes after that's the same key and make it no-op.
-- The cost is that in multiplayer it is entirely reasonable to send more than
-- one keypress if the game or network is slow.  Also this very much doesn't
-- work multiplayer anyway.
local function decl_evt_fn(name)
   local name = "evt_" .. name
   table.insert(mod.all_event_names, name)

   local tick_last_handled = -1 -- -1 isn't a tick number the game uses.

   return function(pindex, ...)
      if mod.dispatch_event(pindex, name, ...) then
         if game.tick == tick_last_handled and mod.active_panel_name(pindex) ~= nil then return end

         tick_last_handled = game.tick
         return true
      end

      return false
   end
end

-- these are our event handlers.  All take the pindex, save for click, which
-- needs to know about ctrl and shift.

--- @alias SimpleEventFn fun(pindex: number): boolean

---@type SimpleEventFn
mod.evt_left = decl_evt_fn("left")

---@type SimpleEventFn
mod.evt_right = decl_evt_fn("right")

---@type SimpleEventFn
mod.evt_up = decl_evt_fn("up")

---@type SimpleEventFn
mod.evt_down = decl_evt_fn("down")

---@type SimpleEventFn
mod.evt_tab_forward = decl_evt_fn("tab_forward")

---@type SimpleEventFn
mod.evt_tab_backward = decl_evt_fn("tab_backward")

---@alias ClickEvt fun(pindex: number, flags: { ctrl: boolean, shift: boolean, alt: boolean }): boolean

-- Click events are [(left) and ] (right) by default.  This doesn't quite map to
-- the mod's controls in the world vs vanilla, but it does map to the UI
-- reasonably well.

---@type ClickEvt
mod.evt_left_click = decl_evt_fn("left_click")

---@type ClickEvt
mod.evt_right_click = decl_evt_fn("right_click")

--These are types used internally to easily name "lazy" values that can be
--either a function or a value.

---@alias LazyString fun(pindex: number): string
---@alias LazyNumber fun(pindex: number): number
---@alias LazyBool fun(pindex: number): boolean
---@alias LazyTable fun(pindex: number): table
---@alias LazyArray fun(pindex: number): any[]

return mod
