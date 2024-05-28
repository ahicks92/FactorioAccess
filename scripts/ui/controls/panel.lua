--[[
Panels are the root of a UI workflow.  They contain control-common stuff, plus
the root event handling, focus and state management, etc.

All of a panel's direct state is derive from two things: some state in global,
and the result of a builder function used to describe this panel to itself.  You
supply the builder, which gets a builder object as a single argument; that
object allows for adding controls.  Each kind of control returns a builder
itself, linked to the in-progress panel, to build control-specific stuff.

Since this mod has one "control" per panel, for lack of better phrasing, and tab
actually moves between tabs, controls themselves handle focus to subcontrols and
tell the panel what the leaf should be now.

Subcontrols, when accessed, are handed their specific global state.  They are
responsible for saying whether they are a leaf or if not what their active
focused child is.  When a control gains focus, evt_focused is called on it; when
it loses focus evt_unfocused. Controls themselves are responsible for handling
their own speech.

The builder itself contains some implicit state.  global-state.lua will call the
builder for a registered panel, then yank that out and cache it.  This is
supplied back for all other panel ops.

specifically, all internal functions in this file will be called as (pindex,
panel_ctx, ...other args).  panel_ctx is:

```
{
   "global" = { whatever the panel's state is in global },
   "descriptor" = { whatever the builder wanted to cache. Immutable },
}
```

Where global is the global state, and descriptor is a blob of whatever the
builder made.  The panel uses the descriptors in builder, then modifies global
as necessary.

Controls have their events done a little differnetly. For those, it's
evt_whatever(pindex, { state, descriptor, panel }).  State and descriptor come
back from the builder function as `{ global_state = bla, descriptor = bla }`.
panel is a small helper handle to the currently active panel, which knows how to
e.g. tell a panel to change focus.
]]
local ustate = require("scripts.ui.global-state")

local mod = {}

local function find_focused_vtab(pindex, ctx)
   return assert(
      ctx.descriptor.controls[ctx.state.focused_control],
      "focused control " .. ctx.state.focused_control .. " not found"
   ).vtable
end

local function dispatcher(evt_name, pindex, ctx) end
--- @alias ControlBuilderReturn { global_state: any, descriptor: any }

-- Might be able to not use any heere, someday. LuaLS says generics are beta.
---@alias ControlBuilderFn fun(pindex: number): ControlBuilderReturn

---@class PanelBuilder
--- @field add_control fun(unique_id: string, builder: ControlBuilderFn)

---@class PanelTabDesc
---@field controls table<string, ControlBuilderFn> The values come from subbuilders. Only the top-level controls.

---@class PanelTabState
--- @field focused_control string
--- @field first_control string
--- @field control_states table<string, any>

---@class PanelInternalState
---@field tabs table<string, PanelTabState>

-- Returns the new control. Gets re-called every time the panel's children must
-- be rebuilt.  This is always a top-level control.  The nested controls manage
-- controls of their own.
---@alias RootControlBuilderFn fun(pindex: number): any

---@class TabBuilder
---@field add_control fun(name: string, builder: RootControlBuilderFn)

---@returns TabBuilder
local function tab_builder(pindex, tab_name)
   ---@type PanelTabDesc
   local state = { controls = {} }

   local ret = {}

   --- @returns PanelTabDesc
   function ret._get_state()
      return state
   end

   ---@param name string
   ---@param builder RootControlBuilderFn
   function ret.add_control(name, builder)
      assert(state.controls[name] == nil, "Tried to add " .. name .. " a second time")
      state.controls[name] = builder(pindex)
      return ret
   end

   return ret
end

local function add_tab(pindex, panel_desc, name, tab_builder)
   assert(panel_desc.tabs[name] == nil, "Attempt to create a tab with a duplicate name is not allowed. Name=" .. name)
   local tab_builder_results = {}
   panel_desc.tabs[name] = builder(pindex, tab_builder(tab_builder_results))
end

--- @returns PanelBuilder
function mod.get_builder(panel_name)
   local bstate = {
      descriptor = {},
      registration_name = panel_name,
   }

   local builder = {}

   function builder.add_tab(name, builder_fn)
      add_tab(pindex, bstate.descriptor, name, builder_fn)
   end

   function builder._get_descriptor()
      return bstate.descriptor
   end

   return builder
end

function mod.build_panel(panel_name, builder_fn)
   ustate.register_panel(panel_name, function(pindex)
      local builder = mod.get_builder(panel_name)
      builder_fn(pindex, builder)
      return builder._get_descriptor()
   end)
end

return mod
