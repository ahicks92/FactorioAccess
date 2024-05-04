--[[
This file contains "descriptors" of prototypes and entities.  It may be split
later, for example if we opt to start accounting for mods.  Logic doesn't belong
here: this should be as close to pure data as feasible.

Most Factorio entities have some common behaviors.  While there are exceptions
(for example combinators, the Rocket silo), we can look at the API and see a few
things.  Such examples include whether or not something has health, whether or
not something is a container (and if that container supports filtering), whether
or not something connects to the logistic network, etc.  In practice most of
this handling may be generic, and in so doing it may extend itself inh some
cases without our help (all inserters are "inserter" for example).

Further down the road, the special cases may likely be handled here as well:
that requires only a generic concept of actions and a way to extend the list on
a per-prototype basis. For now, however, we restrict ourselves to really common
things like the circuit network.

Since this is in progress--in particular it's only circuit send modes at the
moment--we leave documentation of the schema aside.  Otherwise this comment will
probably become stale very quickly.  The exammples here should be reasonably
self-explanatory.
]]
local F = require('scripts.field-ref')

local dcb = defines.control_behavior

local mod  = {}

-- Prototypes, by type.
mod.PROTOTYPES = {
   inserter = {
      circuit_network = {
         reading = {
            toggle_field = F.circuit_read_hand_contents(),
            mode_field = F.circuit_hand_read_mode(),
            disabled_label = "None",
            choices = {
               { dcb.inserter.hand_read_mode.hold,  "Reading held items" },
               { dcb.inserter.hand_read_mode.pulse, "pulsing held items" }
            },
         },
      },
   },
}

return mod