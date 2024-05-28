--Main file for mod runtime
local util = require("util")
local fa_utils = require("scripts.fa-utils")
local fa_localising = require("scripts.localising")
local fa_crafting = require("scripts.crafting")
local fa_electrical = require("scripts.electrical")
local fa_equipment = require("scripts.equipment")
local fa_combat = require("scripts.combat")
local fa_graphics = require("scripts.graphics")
local fa_mouse = require("scripts.mouse")
local fa_tutorial = require("scripts.tutorial-system")
local fa_sectors = require("scripts.building-vehicle-sectors")
local fa_menu_search = require("scripts.menu-search")
local fa_building_tools = require("scripts.building-tools")
local fa_mining_tools = require("scripts.mining-tools")
local fa_rails = require("scripts.rails")
local fa_rail_builder = require("scripts.rail-builder")
local fa_trains = require("scripts.trains")
local fa_train_stops = require("scripts.train-stops")
local fa_driving = require("scripts.driving")
local fa_scanner = require("scripts.scanner")
local fa_spidertrons = require("scripts.spidertron")
local fa_belts = require("scripts.transport-belts")
local fa_zoom = require("scripts.zoom")
local fa_bot_logistics = require("scripts.worker-robots")
local fa_blueprints = require("scripts.blueprints")
local fa_travel = require("scripts.travel-tools")
local fa_teleport = require("scripts.teleport")
local fa_warnings = require("scripts.warnings")
local fa_circuits = require("scripts.circuit-networks")
local fa_kk = require("scripts.kruise-kontrol-wrapper")
local fa_quickbar = require("scripts.quickbar")
local ui = require("scripts.ui")
-- For hooking on_init, on_configuration_changed.
local ui_internal = require("scripts.ui.global-state")

groups = {}
entity_types = {}
production_types = {}
building_types = {}
local dirs = defines.direction

ENT_NAMES_CLEARED_AS_OBSTACLES = {
   "tree-01-stump",
   "tree-02-stump",
   "tree-03-stump",
   "tree-04-stump",
   "tree-05-stump",
   "tree-06-stump",
   "tree-07-stump",
   "tree-08-stump",
   "tree-09-stump",
   "small-scorchmark",
   "small-scorchmark-tintable",
   "medium-scorchmark",
   "medium-scorchmark-tintable",
   "big-scorchmark",
   "big-scorchmark-tintable",
   "huge-scorchmark",
   "huge-scorchmark-tintable",
   "rock-big",
   "rock-huge",
   "sand-rock-big",
}
ENT_TYPES_YOU_CAN_WALK_OVER = {
   "resource",
   "transport-belt",
   "underground-belt",
   "splitter",
   "item-entity",
   "entity-ghost",
   "heat-pipe",
   "pipe",
   "pipe-to-ground",
   "character",
   "rail-signal",
   "flying-text",
   "highlight-box",
   "combat-robot",
   "logistic-robot",
   "construction-robot",
   "rocket-silo-rocket-shadow",
}
ENT_TYPES_YOU_CAN_BUILD_OVER = {
   "resource",
   "entity-ghost",
   "flying-text",
   "highlight-box",
   "combat-robot",
   "logistic-robot",
   "construction-robot",
   "rocket-silo-rocket-shadow",
}

--This function gets scheduled.
function call_to_fix_zoom(pindex)
   fa_zoom.fix_zoom(pindex)
end

--This function gets scheduled.
function call_to_sync_graphics(pindex)
   fa_graphics.sync_build_cursor_graphics(pindex)
end

--This function gets scheduled.
function call_to_run_scan(pindex, dir, mute)
   fa_scanner.run_scan(pindex, dir, mute)
end

--This function gets scheduled.
function call_to_restore_equipped_atomic_bombs(pindex)
   fa_equipment.restore_equipped_atomic_bombs(pindex)
end

--This function gets scheduled.
function call_to_check_ghost_rails(pindex)
   fa_rails.check_ghost_rail_planning_results(pindex)
end

--Returns the entity at this player's cursor selected tile
function get_selected_ent(pindex, ent_no)
   local tile = players[pindex].tile
   local ent
   local ent_no = ent_no or 1
   while true do
      if tile.index > #tile.ents then tile.index = #tile.ents end
      if tile.index == 0 then return nil end
      ent = tile.ents[tile.index]
      if not ent then print(serpent.line(tile.ents), tile.index, ent) end
      if ent.valid and (ent.type ~= "character" or players[pindex].cursor or ent.player ~= pindex) then
         ent_no = ent_no - 1
      end
      if ent_no <= 0 then return ent end
      table.remove(tile.ents, tile.index)
   end
end

--Outputs basic entity info, usually called when the cursor selects an entity.
function ent_info(pindex, ent, description)
   local p = game.get_player(pindex)
   local result = fa_localising.get(ent, pindex)
   if result == nil or result == "" then result = ent.name end
   if game.players[pindex].name == "Crimso" then result = result .. " " .. ent.type .. " " end
   if ent.type == "resource" then
      if ent.name ~= "crude-oil" then
         result = result .. ", x " .. ent.amount
      else
         result = result .. ", x " .. math.floor(ent.amount / 3000) .. "%"
      end
   end
   if ent.name == "entity-ghost" then
      result = fa_localising.get(ent.ghost_prototype, pindex) .. " " .. fa_localising.get(ent, pindex)
   elseif ent.name == "straight-rail" or ent.name == "curved-rail" then
      return fa_rails.rail_ent_info(pindex, ent, description)
   end

   result = result .. (description or "")

   --Give character names
   if ent.name == "character" then
      local p = ent.player
      local p2 = ent.associated_player
      if p ~= nil and p.valid and p.name ~= nil and p.name ~= "" then
         result = result .. " " .. p.name
      elseif p2 ~= nil and p2.valid and p2.name ~= nil and p2.name ~= "" then
         result = result .. " " .. p2.name
      elseif p ~= nil and p.valid and p.index == pindex then
         result = result .. " you "
      elseif pindex ~= nil then
         result = result .. " " .. pindex
      else
         result = result .. " X "
      end

      if p ~= nil and p.valid and p.index == pindex and not players[pindex].cursor then return "" end
   elseif ent.name == "character-corpse" then
      if ent.character_corpse_player_index == pindex then
         result = result .. " of your character "
      elseif ent.character_corpse_player_index ~= nil then
         result = result .. " of another character "
      end
   end
   --Explain the contents of a container
   if ent.type == "container" or ent.type == "logistic-container" then --Chests etc: Report the most common item and say "and other items" if there are other types.
      local itemset = ent.get_inventory(defines.inventory.chest).get_contents()
      local itemtable = {}
      for name, count in pairs(itemset) do
         table.insert(itemtable, { name = name, count = count })
      end
      table.sort(itemtable, function(k1, k2)
         return k1.count > k2.count
      end)
      if #itemtable == 0 then
         result = result .. " with nothing "
      else
         result = result
            .. " with "
            .. fa_localising.get_item_from_name(itemtable[1].name, pindex)
            .. " times "
            .. itemtable[1].count
            .. ", "
         if #itemtable > 1 then
            result = result
               .. " and "
               .. fa_localising.get_item_from_name(itemtable[2].name, pindex)
               .. " times "
               .. itemtable[2].count
               .. ", "
         end
         if #itemtable > 2 then
            result = result
               .. " and "
               .. fa_localising.get_item_from_name(itemtable[3].name, pindex)
               .. " times "
               .. itemtable[3].count
               .. ", "
         end
         if #itemtable > 3 then result = result .. "and other items " end
      end
      if ent.type == "logistic-container" then
         local network = ent.surface.find_logistic_network_by_position(ent.position, ent.force)
         if network == nil then
            local nearest_roboport = fa_utils.find_nearest_roboport(ent.surface, ent.position, 5000)
            if nearest_roboport == nil then
               result = result .. ", not in a network, no networks found within 5000 tiles"
            else
               local dist = math.ceil(util.distance(ent.position, nearest_roboport.position) - 25)
               local dir =
                  fa_utils.direction_lookup(fa_utils.get_direction_biased(nearest_roboport.position, ent.position))
               result = result
                  .. ", not in a network, nearest network "
                  .. nearest_roboport.backer_name
                  .. " is about "
                  .. dist
                  .. " to the "
                  .. dir
            end
         else
            local network_name = network.cells[1].owner.backer_name
            result = result .. ", in network" .. network_name
         end
      end
   end
   --Pipe ends are labelled to distinguish them
   if ent.name == "pipe" and fa_building_tools.is_a_pipe_end(ent, pindex) then result = result .. " end, " end
   --Explain the contents of a pipe or storage tank or etc.
   if
      ent.type == "pipe"
      or ent.type == "pipe-to-ground"
      or ent.type == "storage-tank"
      or ent.type == "pump"
      or ent.name == "boiler"
      or ent.name == "heat-exchanger"
      or ent.type == "generator"
   then
      local dict = ent.get_fluid_contents()
      local fluids = {}
      for name, count in pairs(dict) do
         table.insert(fluids, { name = name, count = count })
      end
      table.sort(fluids, function(k1, k2)
         return k1.count > k2.count
      end)
      if #fluids > 0 and fluids[1].count ~= nil then
         result = result .. " with " .. fa_localising.get_fluid_from_name(fluids[1].name, pindex) --can check amount by opening the ent menu
         if #fluids > 1 and fluids[2].count ~= nil then
            result = result .. " and " .. fa_localising.get_fluid_from_name(fluids[2].name, pindex) --(this should not happen because it means different fluids mixed!)
         end
         if #fluids > 2 then result = result .. ", and other fluids " end
      else
         result = result .. " empty "
      end
   end
   --Explain the type and content of a transport belt
   if ent.type == "transport-belt" then
      --Check if corner or junction or end
      local sideload_count = 0
      local backload_count = 0
      local outload_count = 0
      local inputs = ent.belt_neighbours["inputs"]
      local outputs = ent.belt_neighbours["outputs"]
      local outload_dir = nil
      local outload_is_corner = false
      local this_dir = ent.direction
      for i, belt in pairs(inputs) do
         if ent.direction ~= belt.direction then
            sideload_count = sideload_count + 1
         else
            backload_count = backload_count + 1
         end
      end
      for i, belt in pairs(outputs) do
         outload_count = outload_count + 1
         outload_dir = belt.direction --Note: there should be only one of these belts anyway.2
         if belt.type == "transport-belt" and (belt.belt_shape == "right" or belt.belt_shape == "left") then
            outload_is_corner = true
         end
      end
      --Check what the neighbor info reveals about the belt
      local say_middle = false
      result = result
         .. fa_belts.transport_belt_junction_info(
            sideload_count,
            backload_count,
            outload_count,
            this_dir,
            outload_dir,
            say_middle,
            outload_is_corner
         )

      --Check contents
      local left = ent.get_transport_line(1).get_contents()
      local right = ent.get_transport_line(2).get_contents()

      for name, count in pairs(right) do
         if left[name] ~= nil then
            left[name] = left[name] + count
         else
            left[name] = count
         end
      end
      local contents = {}
      for name, count in pairs(left) do
         table.insert(contents, { name = name, count = count })
      end
      table.sort(contents, function(k1, k2)
         return k1.count > k2.count
      end)
      if #contents > 0 then
         result = result .. " carrying " .. fa_localising.get_item_from_name(contents[1].name, pindex) --***localize
         if #contents > 1 then
            result = result .. ", and " .. fa_localising.get_item_from_name(contents[2].name, pindex)
            if #contents > 2 then result = result .. ", and other item types " end
         end
      else
         --No currently carried items: Report recently carried items by checking the next belt over
         --Those items must be from this belt if this belt is the only input to the next belt and there are no inserters or loaders around it.
         local next_belt = ent.belt_neighbours["outputs"][1]
         local next_contents = {}
         local next_belt_nearby_inserters = nil
         if next_belt ~= nil then
            next_belt_nearby_inserters = next_belt.surface.find_entities_filtered({
               position = next_belt.position,
               radius = 3,
               type = { "inserter", "loader", "loader-1x1" },
            })
         end
         --check contents
         --Ignore multiple input belts, ghosts, circuit connected transport belts, and belts with inserters near them
         if
            next_belt ~= nil
            and next_belt.valid
            and #next_belt.belt_neighbours["inputs"] == 1
            and next_belt.type ~= "entity-ghost"
            and (
               next_belt.type ~= "transport-belt" --Skip this check for non-belts, e.g. underground belts
               or (
                  next_belt.get_circuit_network(defines.wire_type.red) == nil
                  and next_belt.get_circuit_network(defines.wire_type.green) == nil
               )
            )
            and ent.get_circuit_network(defines.wire_type.red) == nil
            and ent.get_circuit_network(defines.wire_type.green) == nil
            and (next_belt_nearby_inserters == nil or #next_belt_nearby_inserters == 0)
         then
            --Check contents of next belt
            local left = next_belt.get_transport_line(1).get_contents()
            local right = next_belt.get_transport_line(2).get_contents()

            for name, count in pairs(right) do
               if left[name] ~= nil then
                  left[name] = left[name] + count
               else
                  left[name] = count
               end
            end
            for name, count in pairs(left) do
               table.insert(next_contents, { name = name, count = count })
            end
            table.sort(next_contents, function(k1, k2)
               return k1.count > k2.count
            end)
         end

         --Check contents of prev belt
         local prev_belts = ent.belt_neighbours["inputs"]
         local prev_contents = {}
         local this_belt_nearby_inserters =
            ent.surface.find_entities_filtered({ position = ent.position, radius = 5, type = { "inserter" } })
         for i, prev_belt in ipairs(prev_belts) do
            --Check contents
            --Ignore ghosts, circuit connected transport belts, and belts with inserters near them
            if
               prev_belt ~= nil
               and prev_belt.valid
               and prev_belt.type ~= "entity-ghost"
               and (
                  prev_belt.type ~= "transport-belt" --Skip this check for non-belts, e.g. underground belts
                  or (
                     prev_belt.get_circuit_network(defines.wire_type.red) == nil
                     and prev_belt.get_circuit_network(defines.wire_type.green) == nil
                  )
               )
               and ent.get_circuit_network(defines.wire_type.red) == nil
               and ent.get_circuit_network(defines.wire_type.green) == nil
               and (this_belt_nearby_inserters == nil or #this_belt_nearby_inserters == 0)
            then
               local left = prev_belt.get_transport_line(1).get_contents()
               local right = prev_belt.get_transport_line(2).get_contents()

               for name, count in pairs(right) do
                  if left[name] ~= nil then
                     left[name] = left[name] + count
                  else
                     left[name] = count
                  end
               end
               for name, count in pairs(left) do
                  table.insert(prev_contents, { name = name, count = count })
               end
               table.sort(prev_contents, function(k1, k2)
                  return k1.count > k2.count
               end)
            end
         end

         --Report assumed carried items based on input/output neighbors
         if #next_contents > 0 then
            result = result .. " carrying " .. fa_localising.get_item_from_name(next_contents[1].name, pindex)
            if #next_contents > 1 then
               result = result .. ", and " .. fa_localising.get_item_from_name(next_contents[2].name, pindex)
               if #next_contents > 2 then result = result .. ", and other item types " end
            end
         elseif #prev_contents > 0 then
            result = result .. " carrying " .. fa_localising.get_item_from_name(prev_contents[1].name, pindex)
            if #prev_contents > 1 then
               result = result .. ", and " .. fa_localising.get_item_from_name(prev_contents[2].name, pindex)
               if #prev_contents > 2 then result = result .. ", and other item types " end
            end
         else
            --No currently or recently carried items
            result = result .. " carrying nothing, "
         end
      end
   end

   --For underground belts, note whether entrance or exit, and report contents
   if ent.type == "underground-belt" then
      if ent.belt_to_ground_type == "input" then
         result = result .. " entrance "
      elseif ent.belt_to_ground_type == "output" then
         result = result .. " exit "
      end
   end

   --Explain the recipe of a machine without pause and before the direction
   pcall(function()
      if ent.get_recipe() ~= nil then
         result = result .. " producing " .. fa_localising.get_recipe_from_name(ent.get_recipe().name, pindex)
      end
   end)
   --State the name of a train stop
   if ent.name == "train-stop" then
      result = result .. " " .. ent.backer_name .. " "
   --State the ID number of a train
   elseif ent.name == "locomotive" or ent.name == "cargo-wagon" or ent.name == "fluid-wagon" then
      result = result .. " of train " .. fa_trains.get_train_name(ent.train)
   --State the signal state of a rail signal
   elseif ent.name == "rail-signal" or ent.name == "rail-chain-signal" then
      if ent.status == defines.entity_status.not_connected_to_rail then
         result = result .. " not connected to rails "
      else
         result = result .. ", " .. fa_rails.get_signal_state_info(ent)
      end
   end
   --Report the entity facing direction
   if
      (ent.prototype.is_building and ent.supports_direction)
      or (ent.name == "entity-ghost" and ent.ghost_prototype.is_building and ent.ghost_prototype.supports_direction)
   then
      result = result .. ", Facing " .. fa_utils.direction_lookup(ent.direction)
      if ent.type == "generator" then
         --For steam engines and steam turbines, north = south and east = west
         result = result .. " and " .. fa_utils.direction_lookup(fa_utils.rotate_180(ent.direction))
      end
   elseif ent.type == "locomotive" or ent.type == "car" then
      result = result .. " facing " .. fa_utils.get_heading_info(ent)
   end
   if ent.name == "rail-signal" or ent.name == "rail-chain-signal" then
      result = result .. ", Heading " .. fa_utils.direction_lookup(fa_utils.rotate_180(ent.direction))
   end
   --Report if marked for deconstruction or upgrading
   if ent.to_be_deconstructed() == true then
      result = result .. " marked for deconstruction, "
   elseif ent.to_be_upgraded() == true then
      result = result .. " marked for upgrading, "
   end
   --Generator power production
   if ent.prototype.type == "generator" then
      result = result .. ", "
      local power1 = ent.energy_generated_last_tick * 60
      local power2 = ent.prototype.max_energy_production * 60
      local power_load_pct = math.ceil(power1 / power2 * 100)
      if power2 ~= nil then
         result = result
            .. " at "
            .. power_load_pct
            .. " percent load, producing "
            .. fa_electrical.get_power_string(power1)
            .. " out of "
            .. fa_electrical.get_power_string(power2)
            .. " capacity, "
      else
         result = result .. " producing " .. fa_electrical.get_power_string(power1) .. " "
      end
   end
   if ent.type == "underground-belt" then
      if ent.neighbours ~= nil then
         result = result
            .. ", Connected to "
            .. fa_utils.direction(ent.position, ent.neighbours.position)
            .. " via "
            .. math.floor(fa_utils.distance(ent.position, ent.neighbours.position)) - 1
            .. " tiles underground, "
      else
         result = result .. ", not connected "
      end
   elseif ent.type == "splitter" then
      --Splitter priority info
      result = result .. fa_belts.splitter_priority_info(ent)
   elseif (ent.name == "pipe") and ent.neighbours ~= nil then
      --List connected neighbors
      result = result .. " connects "
      local con_counter = 0
      for i, nbrs in pairs(ent.neighbours) do
         for j, nbr in pairs(nbrs) do
            local box = nil
            local f_name = nil
            local dir_from_pos = nil
            box, f_name, dir_from_pos =
               fa_building_tools.get_relevant_fluidbox_and_fluid_name(nbr, ent.position, dirs.north)
            --Extra checks for pipes to ground
            if f_name == nil then
               box, f_name, dir_from_pos =
                  fa_building_tools.get_relevant_fluidbox_and_fluid_name(nbr, ent.position, dirs.east)
            end
            if f_name == nil then
               box, f_name, dir_from_pos =
                  fa_building_tools.get_relevant_fluidbox_and_fluid_name(nbr, ent.position, dirs.south)
            end
            if f_name == nil then
               box, f_name, dir_from_pos =
                  fa_building_tools.get_relevant_fluidbox_and_fluid_name(nbr, ent.position, dirs.west)
            end
            if f_name ~= nil then --"empty" is a name too
               result = result .. fa_utils.direction_lookup(dir_from_pos) .. ", "
               --game.print("found " .. f_name .. " at " .. nbr.name ,{volume_modifier=0})
               con_counter = con_counter + 1
            end
         end
      end
      if con_counter == 0 then result = result .. " to nothing" end
   elseif (ent.name == "pipe-to-ground") and ent.neighbours ~= nil then
      result = result .. " connects "
      local connections = ent.fluidbox.get_pipe_connections(1)
      local aboveground_found = false
      local underground_found = false
      for i, con in ipairs(connections) do
         if con.target ~= nil then
            local dist = math.ceil(util.distance(ent.position, con.target.get_pipe_connections(1)[1].position))
            result = result
               .. fa_utils.direction_lookup(fa_utils.get_direction_biased(con.target_position, ent.position))
               .. " "
            if con.connection_type == "underground" then
               result = result .. " via " .. dist - 1 .. " tiles underground, "
               underground_found = true
            else
               result = result .. " directly "
               aboveground_found = true
            end
            result = result .. ", "
         end
      end
      if aboveground_found == false and underground_found == false then
         result = result .. " nothing "
      elseif aboveground_found == true and underground_found == false then
         result = result .. " nothing underground "
      elseif aboveground_found == false and underground_found == true then
         result = result .. " nothing directly "
      end
   elseif next(ent.prototype.fluidbox_prototypes) ~= nil then
      --For a fluidbox inside a building, give info about the connection directions
      local relative_position =
         { x = players[pindex].cursor_pos.x - ent.position.x, y = players[pindex].cursor_pos.y - ent.position.y }
      local direction = ent.direction / 2
      local inputs = 0
      for i, box in pairs(ent.prototype.fluidbox_prototypes) do
         for i1, pipe in pairs(box.pipe_connections) do
            if pipe.type == "input" then inputs = inputs + 1 end
            local adjusted = { position = nil, direction = nil }
            if ent.name == "offshore-pump" then
               adjusted.position = { x = 0, y = 0 }
               if direction == 0 then
                  adjusted.direction = "South"
               elseif direction == 1 then
                  adjusted.direction = "West"
               elseif direction == 2 then
                  adjusted.direction = "North"
               elseif direction == 3 then
                  adjusted.direction = "East"
               end
            else
               adjusted = get_adjacent_source(ent.prototype.selection_box, pipe.positions[direction + 1], direction)
            end
            if adjusted.position.x == relative_position.x and adjusted.position.y == relative_position.y then
               if ent.type == "assembling-machine" and ent.get_recipe() ~= nil then
                  if ent.name == "oil-refinery" and ent.get_recipe().name == "basic-oil-processing" then
                     if i == 2 then
                        result = result
                           .. ", "
                           .. fa_localising.get_fluid_from_name("crude-oil", pindex)
                           .. " Flow "
                           .. pipe.type
                           .. " 1 "
                           .. adjusted.direction
                           .. ", at "
                           .. fa_utils.get_entity_part_at_cursor(pindex)
                     elseif i == 5 then
                        result = result
                           .. ", "
                           .. fa_localising.get_fluid_from_name("petroleum-gas", pindex)
                           .. " Flow "
                           .. pipe.type
                           .. " 1 "
                           .. adjusted.direction
                           .. ", at "
                           .. fa_utils.get_entity_part_at_cursor(pindex)
                     else
                        result = result
                           .. ", "
                           .. "Unused"
                           .. " Flow "
                           .. pipe.type
                           .. " 1 "
                           .. adjusted.direction
                           .. ", at "
                           .. fa_utils.get_entity_part_at_cursor(pindex)
                     end
                  else
                     if pipe.type == "input" then
                        local inputs = ent.get_recipe().ingredients
                        for i2 = #inputs, 1, -1 do
                           if inputs[i2].type ~= "fluid" then table.remove(inputs, i2) end
                        end
                        if #inputs > 0 then
                           local i3 = (i % #inputs)
                           if i3 == 0 then i3 = #inputs end
                           local filter = inputs[i3]
                           result = result
                              .. ", "
                              .. filter.name
                              .. " Flow "
                              .. pipe.type
                              .. " 1 "
                              .. adjusted.direction
                              .. ", at "
                              .. fa_utils.get_entity_part_at_cursor(pindex)
                        else
                           result = result
                              .. ", "
                              .. "Unused"
                              .. " Flow "
                              .. pipe.type
                              .. " 1 "
                              .. adjusted.direction
                              .. ", at "
                              .. fa_utils.get_entity_part_at_cursor(pindex)
                        end
                     else
                        local outputs = ent.get_recipe().products
                        for i2 = #outputs, 1, -1 do
                           if outputs[i2].type ~= "fluid" then table.remove(outputs, i2) end
                        end
                        if #outputs > 0 then
                           local i3 = ((i - inputs) % #outputs)
                           if i3 == 0 then i3 = #outputs end
                           local filter = outputs[i3]
                           result = result
                              .. ", "
                              .. filter.name
                              .. " Flow "
                              .. pipe.type
                              .. " 1 "
                              .. adjusted.direction
                              .. ", at "
                              .. fa_utils.get_entity_part_at_cursor(pindex)
                        else
                           result = result
                              .. ", "
                              .. "Unused"
                              .. " Flow "
                              .. pipe.type
                              .. " 1 "
                              .. adjusted.direction
                              .. ", at "
                              .. fa_utils.get_entity_part_at_cursor(pindex)
                        end
                     end
                  end
               else
                  --Other ent types and assembling machines with no recipes
                  local filter = box.filter or { name = "" }
                  result = result
                     .. ", "
                     .. filter.name
                     .. " Flow "
                     .. pipe.type
                     .. " 1 "
                     .. adjusted.direction
                     .. ", at "
                     .. fa_utils.get_entity_part_at_cursor(pindex)
               end
            end
         end
      end
   end

   if ent.type == "transport-belt" then
      --Check whether items on the belt are stopped or moving (based on whether you can insert at the back of the belt)
      local left = ent.get_transport_line(1)
      local right = ent.get_transport_line(2)

      local left_dir = "left"
      local right_dir = "right"
      if ent.direction == dirs.north then
         left_dir = fa_utils.direction_lookup(dirs.west) or "left"
         right_dir = fa_utils.direction_lookup(dirs.east) or "right"
      elseif ent.direction == dirs.east then
         left_dir = fa_utils.direction_lookup(dirs.north) or "left"
         right_dir = fa_utils.direction_lookup(dirs.south) or "right"
      elseif ent.direction == dirs.south then
         left_dir = fa_utils.direction_lookup(dirs.east) or "left"
         right_dir = fa_utils.direction_lookup(dirs.west) or "right"
      elseif ent.direction == dirs.west then
         left_dir = fa_utils.direction_lookup(dirs.south) or "left"
         right_dir = fa_utils.direction_lookup(dirs.north) or "right"
      end

      local insert_spots_left = 0
      local insert_spots_right = 0
      if not left.can_insert_at_back() and right.can_insert_at_back() then
         result = result .. ", " .. left_dir .. " lane full, "
      elseif left.can_insert_at_back() and not right.can_insert_at_back() then
         result = result .. ", " .. right_dir .. " lane full, "
      elseif not left.can_insert_at_back() and not right.can_insert_at_back() then
         result = result .. ", both lanes full, "
         --game.get_player(pindex).print(", both lanes full, ")
      else
         result = result .. ", both lanes open, "
         --game.get_player(pindex).print(", both lanes open, ")
      end
   elseif ent.name == "cargo-wagon" then
      --Explain contents
      local itemset = ent.get_inventory(defines.inventory.cargo_wagon).get_contents()
      local itemtable = {}
      for name, count in pairs(itemset) do
         table.insert(itemtable, { name = name, count = count })
      end
      table.sort(itemtable, function(k1, k2)
         return k1.count > k2.count
      end)
      if #itemtable == 0 then
         result = result .. " containing nothing "
      else
         result = result .. " containing " .. itemtable[1].name .. " times " .. itemtable[1].count .. ", "
         if #itemtable > 1 then
            result = result .. " and " .. itemtable[2].name .. " times " .. itemtable[2].count .. ", "
         end
         if #itemtable > 2 then result = result .. "and other items " end
      end
   elseif ent.type == "radar" then
      result = result .. ", " .. radar_charting_info(ent)
      --game.print(result)--test
   elseif ent.type == "electric-pole" then
      --List connected wire neighbors
      result = result .. fa_circuits.wire_neighbours_info(ent, false)
      --Count number of entities being supplied within supply area.
      local pos = ent.position
      local sdist = ent.prototype.supply_area_distance
      local supply_area = { { pos.x - sdist, pos.y - sdist }, { pos.x + sdist, pos.y + sdist } }
      local supplied_ents = ent.surface.find_entities_filtered({ area = supply_area })
      local supplied_count = 0
      local producer_count = 0
      for i, ent2 in ipairs(supplied_ents) do
         if
            ent2.prototype.max_energy_usage ~= nil
            and ent2.prototype.max_energy_usage > 0
            and ent2.prototype.is_building
         then
            supplied_count = supplied_count + 1
         elseif
            ent2.prototype.max_energy_production ~= nil
            and ent2.prototype.max_energy_production > 0
            and ent2.prototype.is_building
         then
            producer_count = producer_count + 1
         end
      end
      result = result .. " supplying " .. supplied_count .. " buildings, "
      if producer_count > 0 then result = result .. " drawing from " .. producer_count .. " buildings, " end
      result = result .. "Check status for power flow information. "
   elseif ent.type == "power-switch" then
      if ent.power_switch_state == false then
         result = result .. " off, "
      elseif ent.power_switch_state == true then
         result = result .. " on, "
      end
      if (#ent.neighbours.red + #ent.neighbours.green) > 0 then result = result .. " observes circuit condition, " end
      result = result .. fa_circuits.wire_neighbours_info(ent, true)
   elseif ent.name == "roboport" then
      local cell = ent.logistic_cell
      local network = ent.logistic_cell.logistic_network
      result = result
         .. " of network "
         .. fa_bot_logistics.get_network_name(ent)
         .. ","
         .. fa_bot_logistics.roboport_contents_info(ent)
   elseif ent.type == "spider-vehicle" then
      local label = ent.entity_label
      if label == nil then label = "" end
      result = result .. label
   elseif ent.type == "spider-leg" then
      local spiders =
         ent.surface.find_entities_filtered({ position = ent.position, radius = 5, type = "spider-vehicle" })
      local spider = ent.surface.get_closest(ent.position, spiders)
      local label = spider.entity_label
      if label == nil then label = "" end
      result = result .. label
   end
   --Inserters: Explain held items, pickup and drop positions
   if ent.type == "inserter" then
      --Declare filters
      if ent.filter_slot_count > 0 then
         local filter_result = " Filters for "
         local active_filter_count = 0
         for i = 1, ent.filter_slot_count, 1 do
            local filt = ent.get_filter(i)
            if filt ~= nil then
               active_filter_count = active_filter_count + 1
               if active_filter_count > 1 then filter_result = filter_result .. " and " end
               local local_name = fa_localising.get(game.item_prototypes[filt], pindex)
               if local_name == nil then local_name = filt or " unknown item " end
               filter_result = filter_result .. local_name
            end
         end
         if active_filter_count > 0 then result = result .. filter_result .. ", " end
      end
      --Read held item
      if ent.held_stack ~= nil and ent.held_stack.valid_for_read and ent.held_stack.valid then
         result = result .. ", holding " .. ent.held_stack.name
         if ent.held_stack.count > 1 then result = result .. " times " .. ent.held_stack.count end
      end
      --Take note of long handed inserters
      local pickup_dist_dir = " at 1 " .. fa_utils.direction_lookup(ent.direction)
      local drop_dist_dir = " at 1 " .. fa_utils.direction_lookup(fa_utils.rotate_180(ent.direction))
      if ent.name == "long-handed-inserter" then
         pickup_dist_dir = " at 2 " .. fa_utils.direction_lookup(ent.direction)
         drop_dist_dir = " at 2 " .. fa_utils.direction_lookup(fa_utils.rotate_180(ent.direction))
      end
      --Read the pickup position
      local pickup = ent.pickup_target
      local pickup_name = nil
      if pickup ~= nil and pickup.valid then
         pickup_name = fa_localising.get(pickup, pindex)
      else
         pickup_name = "ground"
         local area_ents = ent.surface.find_entities_filtered({ position = ent.pickup_position })
         for i, area_ent in ipairs(area_ents) do
            if area_ent.type == "straight-rail" or area_ent.type == "curved-rail" then
               pickup_name = fa_localising.get(area_ent, pindex)
            end
         end
      end
      result = result .. " picks up from " .. pickup_name .. pickup_dist_dir
      --Read the drop position
      local drop = ent.drop_target
      local drop_name = nil
      if drop ~= nil and drop.valid then
         drop_name = fa_localising.get(drop, pindex)
      else
         drop_name = "ground"
         local drop_area_ents = ent.surface.find_entities_filtered({ position = ent.drop_position })
         for i, drop_area_ent in ipairs(drop_area_ents) do
            if drop_area_ent.type == "straight-rail" or drop_area_ent.type == "curved-rail" then
               drop_name = fa_localising.get(drop_area_ent, pindex)
            end
         end
      end
      result = result .. ", drops to " .. drop_name .. drop_dist_dir
   end
   if ent.type == "mining-drill" then
      local pos = ent.position
      local radius = ent.prototype.mining_drill_radius
      local area = { { pos.x - radius, pos.y - radius }, { pos.x + radius, pos.y + radius } }
      local resources = ent.surface.find_entities_filtered({ area = area, type = "resource" })
      local dict = {}
      for i, resource in pairs(resources) do
         if dict[resource.name] == nil then
            dict[resource.name] = resource.amount
         else
            dict[resource.name] = dict[resource.name] + resource.amount
         end
      end
      local drop = ent.drop_target
      local drop_name = nil
      if drop ~= nil and drop.valid then
         drop_name = fa_localising.get(drop, pindex)
      else
         drop_name = "ground"
         local drop_area_ents = ent.surface.find_entities_filtered({ position = ent.drop_position })
         for i, drop_area_ent in ipairs(drop_area_ents) do
            if drop_area_ent.type == "straight-rail" or drop_area_ent.type == "curved-rail" then
               drop_name = fa_localising.get(drop_area_ent, pindex)
            end
         end
      end
      if drop ~= nil and drop.valid then result = result .. " outputs to " .. drop_name end
      if ent.status == defines.entity_status.waiting_for_space_in_destination then
         result = result .. " output full "
      end
      if table_size(dict) > 0 then
         result = result .. ", Mining from "
         for i, amount in pairs(dict) do
            if i == "crude-oil" then
               result = result .. " " .. i .. " times " .. math.floor(amount / 3000) / 10 .. " per second "
            else
               result = result .. " " .. i .. " times " .. fa_utils.simplify_large_number(amount)
            end
         end
      end
   end
   --Explain if no fuel
   if ent.prototype.burner_prototype ~= nil then
      if ent.energy == 0 and fa_driving.fuel_inventory_info(ent) == "Contains no fuel." then
         result = result .. ", Out of Fuel "
      end
   end
   --Explain other problematic status messages
   local status = ent.status
   local stat = defines.entity_status
   if status ~= nil and status ~= stat.normal and status ~= stat.working then
      if
         status == stat.no_ingredients
         or status == stat.no_input_fluid
         or status == stat.no_minable_resources
         or status == stat.item_ingredient_shortage
         or status == stat.missing_required_fluid
         or status == stat.no_ammo
      then
         result = result .. ", input missing "
      elseif status == stat.full_output or status == stat.full_burnt_result_output then
         result = result .. " output full "
      end
   end
   --Explain power connected status
   if ent.prototype.electric_energy_source_prototype ~= nil and ent.is_connected_to_electric_network() == false then
      result = result .. " power not Connected"
   elseif ent.prototype.electric_energy_source_prototype ~= nil and ent.energy == 0 and ent.type ~= "solar-panel" then
      result = result .. " out of power "
   end
   if ent.type == "accumulator" then
      local level = math.ceil(ent.energy / 50000) --In percentage
      local charge = math.ceil(ent.energy / 1000) --In kilojoules
      result = result .. ", " .. level .. " percent full, containing " .. charge .. " kilojoules. "
   elseif ent.type == "solar-panel" then
      local s_time = ent.surface.daytime * 24 --We observed 18 = peak solar start, 6 = peak solar end, 11 = night start, 13 = night end
      local solar_status = ""
      if s_time > 13 and s_time <= 18 then
         solar_status = ", increasing production, morning hours. "
      elseif s_time > 18 or s_time < 6 then
         solar_status = ", full production, day time. "
      elseif s_time > 6 and s_time <= 11 then
         solar_status = ", decreasing production, evening hours. "
      elseif s_time > 11 and s_time <= 13 then
         solar_status = ", zero production, night time. "
      end
      result = result .. solar_status
   elseif ent.name == "rocket-silo" then
      if ent.rocket_parts ~= nil and ent.rocket_parts < 100 then
         result = result .. ", " .. ent.rocket_parts .. " finished out of 100. "
      elseif ent.rocket_parts ~= nil then
         result = result .. ", rocket ready, press SPACE to launch. "
      end
   elseif ent.name == "beacon" then
      local modules = ent.get_module_inventory()
      if modules.get_item_count() == 0 then
         result = result .. " with no modules "
      elseif modules.get_item_count() == 1 then
         result = result .. " with " .. modules[1].name
      elseif modules.get_item_count() == 2 then
         result = result .. " with " .. modules[1].name .. " and " .. modules[2].name
      elseif modules.get_item_count() > 2 then
         result = result .. " with " .. modules[1].name .. " and " .. modules[2].name .. " and other modules "
      end
   elseif ent.temperature ~= nil and ent.name ~= "heat-pipe" then --ent.name == "nuclear-reactor" or ent.name == "heat-pipe" or ent.name == "heat-exchanger" then
      result = result .. ", temperature " .. math.floor(ent.temperature) .. " degrees C "
      if ent.name == "nuclear-reactor" then
         if ent.temperature > 900 then result = result .. ", danger " end
         if ent.energy > 0 then result = result .. ", consuming fuel cell " end
         result = result .. ", neighbour bonus " .. ent.neighbour_bonus * 100 .. " percent "
      end
   elseif ent.name == "item-on-ground" then
      result = result .. ", " .. ent.stack.name
   end
   --Explain heat connection neighbors
   if ent.prototype.heat_buffer_prototype ~= nil then
      result = result .. " connects "
      local con_targets = fa_building_tools.get_heat_connection_target_positions(ent.name, ent.position, ent.direction)
      local con_count = 0
      local con_counts = { 0, 0, 0, 0, 0, 0, 0, 0 }
      con_counts[dirs.north + 1] = 0
      con_counts[dirs.south + 1] = 0
      con_counts[dirs.east + 1] = 0
      con_counts[dirs.west + 1] = 0
      if #con_targets > 0 then
         for i, con_target_pos in ipairs(con_targets) do
            --For each heat connection target position
            rendering.draw_circle({
               color = { 1.0, 0.0, 0.5 },
               radius = 0.1,
               width = 2,
               target = con_target_pos,
               surface = ent.surface,
               time_to_live = 30,
            })
            local target_ents = ent.surface.find_entities_filtered({ position = con_target_pos })
            for j, target_ent in ipairs(target_ents) do
               if
                  target_ent.valid
                  and #fa_building_tools.get_heat_connection_positions(
                        target_ent.name,
                        target_ent.position,
                        target_ent.direction
                     )
                     > 0
               then
                  for k, spot in
                     ipairs(
                        fa_building_tools.get_heat_connection_positions(
                           target_ent.name,
                           target_ent.position,
                           target_ent.direction
                        )
                     )
                  do
                     --For each heat connection of the found target entity
                     rendering.draw_circle({
                        color = { 1.0, 1.0, 0.5 },
                        radius = 0.2,
                        width = 2,
                        target = spot,
                        surface = ent.surface,
                        time_to_live = 30,
                     })
                     if util.distance(con_target_pos, spot) < 0.2 then
                        --For each match
                        rendering.draw_circle({
                           color = { 0.5, 1.0, 0.5 },
                           radius = 0.3,
                           width = 2,
                           target = spot,
                           surface = ent.surface,
                           time_to_live = 30,
                        })
                        con_count = con_count + 1
                        local con_dir = fa_utils.get_direction_biased(con_target_pos, ent.position)
                        if con_count > 1 then result = result .. " and " end
                        result = result .. fa_utils.direction_lookup(con_dir)
                     end
                  end
               end
            end
         end
      end
      if con_count == 0 then result = result .. " to nothing " end
      if ent.name == "heat-pipe" then --For this ent in particular, read temp after direction
         result = result .. ", temperature " .. math.floor(ent.temperature) .. " degrees C "
      end
   end
   if ent.type == "constant-combinator" then
      result = result .. fa_circuits.constant_combinator_signals_info(ent, pindex)
   end
   return result
end

--Reports the charting range of a radar and how much of it has been charted so far.
function radar_charting_info(radar)
   local charting_range = radar.prototype.max_distance_of_sector_revealed
   local count = 0
   local total = 0
   local centerx = math.floor(radar.position.x / 32)
   local centery = math.floor(radar.position.y / 32)
   for i = (centerx - charting_range), (centerx + charting_range), 1 do
      for j = (centery - charting_range), (centery + charting_range), 1 do
         if radar.force.is_chunk_charted(radar.surface, { i, j }) then count = count + 1 end
         total = total + 1
      end
   end
   local percent_charted = math.floor(count / total * 100)
   local result = percent_charted .. " percent charted, " .. charting_range * 32 .. " tiles charting range "
   return result
end

--???
function prune_item_groups(array)
   if #groups == 0 then
      local dict = game.item_prototypes
      local a = fa_utils.get_iterable_array(dict)
      for i, v in ipairs(a) do
         local check1 = true
         local check2 = true

         for i1, v1 in ipairs(groups) do
            if v1.name == v.group.name then check1 = false end
            if v1.name == v.subgroup.name then check2 = false end
         end
         if check1 then table.insert(groups, v.group) end
         if check2 then table.insert(groups, v.subgroup) end
      end
   end
   local i = 1
   while i < #array and array ~= nil and array[i] ~= nil do
      local check = true
      for i1, v in ipairs(groups) do
         if v ~= nil and array[i].name == v.name then
            i = i + 1
            check = false
            break
         end
      end
      if check then table.remove(array, i) end
   end
end

function read_item_selector_slot(pindex, start_phrase)
   start_phrase = start_phrase or ""
   printout(start_phrase .. players[pindex].item_cache[players[pindex].item_selector.index].name, pindex)
end

--Ent info: Gives the distance and direction of a fluidbox connection target?
--Todo: update to clarify and include localization
function get_adjacent_source(box, pos, dir)
   local result = { position = pos, direction = "" }
   ebox = table.deepcopy(box)
   if dir == 1 or dir == 3 then
      ebox.left_top.x = box.left_top.y
      ebox.left_top.y = box.left_top.x
      ebox.right_bottom.x = box.right_bottom.y
      ebox.right_bottom.y = box.right_bottom.x
   end
   --   print(ebox.left_top.x .. " " .. ebox.left_top.y)
   ebox.left_top.x = math.ceil(ebox.left_top.x * 2) / 2
   ebox.left_top.y = math.ceil(ebox.left_top.y * 2) / 2
   ebox.right_bottom.x = math.floor(ebox.right_bottom.x * 2) / 2
   ebox.right_bottom.y = math.floor(ebox.right_bottom.y * 2) / 2

   if pos.x < ebox.left_top.x then
      result.position.x = result.position.x + 1
      result.direction = "West"
   elseif pos.x > ebox.right_bottom.x then
      result.position.x = result.position.x - 1
      result.direction = "East"
   elseif pos.y < ebox.left_top.y then
      result.position.y = result.position.y + 1
      result.direction = "North"
   elseif pos.y > ebox.right_bottom.y then
      result.position.y = result.position.y - 1
      result.direction = "South"
   end
   return result
end

--Reads the selected player inventory's selected menu slot. Default is to read the main inventory.
function read_inventory_slot(pindex, start_phrase_in, inv_in)
   local start_phrase = start_phrase_in or ""
   local index = players[pindex].inventory.index
   local inv = inv_in or players[pindex].inventory.lua_inventory
   if index < 1 then
      index = 1
   elseif index > #inv then
      index = #inv
   end
   players[pindex].inventory.index = index
   local stack = inv[index]
   if stack == nil or not stack.valid_for_read then
      printout(start_phrase .. "Empty Slot", pindex)
      return
   end
   if stack.is_blueprint then
      printout(fa_blueprints.get_blueprint_info(stack, false), pindex)
   elseif stack.valid_for_read then
      if stack.health < 1 then start_phrase = start_phrase .. " damaged " end
      printout(
         start_phrase
            .. fa_localising.get(stack, pindex)
            .. " x "
            .. stack.count
            .. " "
            .. stack.prototype.subgroup.name,
         pindex
      )
   end
end

--Reads the item in hand, its facing direction if applicable, its count, and its total count including units in the main inventory.
function read_hand(pindex)
   if players[pindex].skip_read_hand == true then
      players[pindex].skip_read_hand = false
      return
   end
   local cursor_stack = game.get_player(pindex).cursor_stack
   local cursor_ghost = game.get_player(pindex).cursor_ghost
   if cursor_stack and cursor_stack.valid_for_read then
      if cursor_stack.is_blueprint then
         --Blueprint extra info
         printout(fa_blueprints.get_blueprint_info(cursor_stack, true), pindex)
      elseif cursor_stack.name == "spidertron-remote" then
         local remote_info = ""
         if cursor_stack.connected_entity == nil then
            remote_info = " not linked "
         else
            if cursor_stack.connected_entity.entity_label == nil then
               remote_info = " for unlabelled spidertron "
            else
               remote_info = " for spidertron " .. cursor_stack.connected_entity.entity_label
            end
         end
         printout(fa_localising.get(cursor_stack, pindex) .. remote_info, pindex)
      else
         --Any other valid item
         local out = { "access.cursor-description" }
         table.insert(out, cursor_stack.prototype.localised_name)
         local build_entity = cursor_stack.prototype.place_result
         if build_entity and build_entity.supports_direction then
            table.insert(out, 1)
            table.insert(out, { "access.facing-direction", players[pindex].building_direction })
         else
            table.insert(out, 0)
            table.insert(out, "")
         end
         table.insert(out, cursor_stack.count)
         local extra = game.get_player(pindex).get_main_inventory().get_item_count(cursor_stack.name)
         if extra > 0 then
            table.insert(out, cursor_stack.count + extra)
         else
            table.insert(out, 0)
         end
         printout(out, pindex)
      end
   elseif cursor_ghost ~= nil then
      --Any ghost
      local out = { "access.cursor-description" }
      table.insert(out, cursor_ghost.localised_name)
      local build_entity = cursor_ghost.place_result
      if build_entity and build_entity.supports_direction then
         table.insert(out, 1)
         table.insert(out, { "access.facing-direction", players[pindex].building_direction })
      else
         table.insert(out, 0)
         table.insert(out, "")
      end
      table.insert(out, 0)
      local extra = 0
      if extra > 0 then
         table.insert(out, cursor_stack.count + extra)
      else
         table.insert(out, 0)
      end
      printout(out, pindex)
   else
      printout({ "access.empty_cursor" }, pindex)
   end
end

--Clears the item in hand and then locates it from the first found player inventory slot. laterdo can use API:player.hand_location in the future if it has advantages
function locate_hand_in_player_inventory(pindex)
   local p = game.get_player(pindex)
   local inv = p.get_main_inventory()
   local stack = p.cursor_stack

   --Check if stack empty and menu supported
   if stack == nil or not stack.valid_for_read or not stack.valid then
      --Hand is empty
      return
   end
   if players[pindex].in_menu and players[pindex].menu ~= "inventory" then
      --Unsupported menu type, laterdo add support for building menu and closing the menu with a call
      printout("Another menu is open.", pindex)
      return
   end
   if not players[pindex].in_menu then
      --Open the inventory if nothing is open
      players[pindex].in_menu = true
      players[pindex].menu = "inventory"
      p.opened = p
   end
   --Save the hand stack item name
   local item_name = stack.name
   --Empty hand stack (clear cursor stack)
   players[pindex].skip_read_hand = true
   local successful = p.clear_cursor()
   if not successful then
      local message = "Unable to empty hand"
      if inv.count_empty_stacks() == 0 then message = message .. ", inventory full" end
      printout(message, pindex)
      return
   end

   --Iterate the inventory until you find the matching item name's index
   local found = false
   local i = 0
   while not found and i < #inv do
      i = i + 1
      if inv[i] and inv[i].valid_for_read and inv[i].name == item_name then found = true end
   end
   --If found, read it from the inventory
   if not found then
      printout("Error: " .. fa_localising.get(stack, pindex) .. " not found in player inventory", pindex)
      return
   else
      players[pindex].inventory.index = i
      read_inventory_slot(pindex, "inventory ")
   end
end

--Clears the item in hand and then locates it from the first found building output slot
function locate_hand_in_building_output_inventory(pindex)
   local p = game.get_player(pindex)
   local inv = nil
   local stack = p.cursor_stack
   local pb = players[pindex].building

   --Check if stack empty and menu supported
   if stack == nil or not stack.valid_for_read or not stack.valid then
      --Hand is empty
      return
   end
   if
      players[pindex].in_menu
      and (players[pindex].menu == "building" or players[pindex].menu == "vehicle")
      and pb.sectors
      and pb.sectors[pb.sector]
      and pb.sectors[pb.sector].name == "Output"
   then
      inv = p.opened.get_output_inventory()
   else
      --Unsupported menu type
      return
   end

   --Save the hand stack item name
   local item_name = stack.name
   --Empty hand stack (clear cursor stack)
   players[pindex].skip_read_hand = true
   local successful = p.clear_cursor()
   if not successful then
      local message = "Unable to empty hand"
      if inv.count_empty_stacks() == 0 then message = message .. ", inventory full" end
      printout(message, pindex)
      return
   end

   --Iterate the inventory until you find the matching item name's index
   local found = false
   local i = 0
   while not found and i < #inv do
      i = i + 1
      if inv[i] and inv[i].valid_for_read and inv[i].name == item_name then found = true end
   end
   --If found, read it from the inventory
   if not found then
      printout(fa_localising.get(stack, pindex) .. " not found in building output", pindex)
      return
   else
      players[pindex].building.index = i
      fa_sectors.read_sector_slot(pindex, false)
   end
end

--Clears the item in hand and then locates its recipe from the crafting menu. Closes some other menus, does not run in some other menus, uses the menu search function.
function locate_hand_in_crafting_menu(pindex)
   local p = game.get_player(pindex)
   local inv = p.get_main_inventory()
   local stack = p.cursor_stack

   --Check if stack empty and menu supported
   if stack == nil or not stack.valid_for_read or not stack.valid then
      --Hand is empty
      return
   end
   if
      players[pindex].in_menu
      and players[pindex].menu ~= "inventory"
      and players[pindex].menu ~= "building"
      and players[pindex].menu ~= "crafting"
   then
      --Unsupported menu types...
      printout("Another menu is open.", pindex)
      return
   end

   --Open the crafting Menu
   close_menu_resets(pindex)
   players[pindex].in_menu = true
   players[pindex].menu = "crafting"
   p.opened = p

   --Get the name
   local item_name = string.lower(
      fa_utils.get_substring_before_space(
         fa_utils.get_substring_before_dash(fa_localising.get(stack.prototype, pindex))
      )
   )
   players[pindex].menu_search_term = item_name

   --Empty hand stack (clear cursor stack) after getting the name
   players[pindex].skip_read_hand = true
   local successful = p.clear_cursor()
   if not successful then
      local message = "Unable to empty hand"
      if inv.count_empty_stacks() == 0 then message = message .. ", inventory full" end
      printout(message, pindex)
      return
   end

   --Run the search
   fa_menu_search.fetch_next(pindex, item_name, nil)
end

--If there is an entity to select, moves the mouse pointer to it, else moves to the cursor tile.
function target(pindex)
   if players[pindex].vanilla_mode then return end
   local ent = get_selected_ent(pindex)
   if ent then
      fa_mouse.move_mouse_pointer(ent.position, pindex)
   else
      fa_mouse.move_mouse_pointer(players[pindex].cursor_pos, pindex)
   end
end

--Checks the cursor tile for a new entity and reads out ent info. Used when a tile has multiple overlapping entities.
function tile_cycle(pindex)
   local tile = players[pindex].tile
   tile.index = tile.index + 1
   if tile.index > #tile.ents then tile.index = 0 end
   local ent = get_selected_ent(pindex)
   if ent then
      printout(ent_info(pindex, ent, ""), pindex)
   else
      printout(tile.tile, pindex)
   end
end

--Checks if the global players table has been created, and if the table entry for this player exists. Otherwise it is initialized.
function check_for_player(index)
   if not players then
      global.players = global.players or {}
      players = global.players
   end
   if players[index] == nil then
      initialize(game.get_player(index))
      return false
   else
      return true
   end
end

--Prints a string to the Factorio Access Launcher app for the vocalizer to read out.
function printout(str, pindex)
   if pindex ~= nil and pindex > 0 then
      players[pindex].last = str
   else
      return
   end
   if players[pindex].vanilla_mode == nil then players[pindex].vanilla_mode = false end
   if not players[pindex].vanilla_mode then localised_print({ "", "out " .. pindex .. " ", str }) end
end

--Reprints the last sent string to the Factorio Access Launcher app for the vocalizer to read out.
function repeat_last_spoken(pindex)
   printout(players[pindex].last, pindex)
end

--Toggles cursor mode on or off. Appropriately affects other modes such as build lock or remote view.
function toggle_cursor_mode(pindex)
   local p = game.get_player(pindex)
   if p.character == nil then
      players[pindex].cursor = true
      players[pindex].build_lock = false
      return
   end

   if (not players[pindex].cursor) and not players[pindex].hide_cursor then
      --Enable
      players[pindex].cursor = true
      players[pindex].build_lock = false

      --Teleport to the center of the nearest tile to align
      center_player_character(pindex)
      read_tile(pindex, "Cursor mode enabled, ")
   else
      --Disable
      players[pindex].cursor = false
      players[pindex].cursor_pos =
         fa_utils.offset_position(players[pindex].position, players[pindex].player_direction, 1)
      players[pindex].cursor_pos = fa_utils.center_of_tile(players[pindex].cursor_pos)
      fa_mouse.move_mouse_pointer(players[pindex].cursor_pos, pindex)
      fa_graphics.sync_build_cursor_graphics(pindex)
      target(pindex)
      players[pindex].player_direction = p.character.direction
      players[pindex].build_lock = false
      if p.driving and p.vehicle then p.vehicle.active = true end
      read_tile(pindex, "Cursor mode disabled, ")

      --Close Remote view
      toggle_remote_view(pindex, false, true)
      p.close_map()
   end
   if players[pindex].cursor_size < 2 then
      --Update cursor highlight
      local ent = get_selected_ent(pindex)
      if ent and ent.valid then
         fa_graphics.draw_cursor_highlight(pindex, ent, nil)
      else
         fa_graphics.draw_cursor_highlight(pindex, nil, nil)
      end
   else
      local left_top = {
         math.floor(players[pindex].cursor_pos.x) - players[pindex].cursor_size,
         math.floor(players[pindex].cursor_pos.y) - players[pindex].cursor_size,
      }
      local right_bottom = {
         math.floor(players[pindex].cursor_pos.x) + players[pindex].cursor_size + 1,
         math.floor(players[pindex].cursor_pos.y) + players[pindex].cursor_size + 1,
      }
      fa_graphics.draw_large_cursor(left_top, right_bottom, pindex)
   end
end

--Toggles remote view on or off. Appropriately affects build lock or remote view.
function toggle_remote_view(pindex, force_true, force_false)
   if (players[pindex].remote_view ~= true or force_true == true) and force_false ~= true then
      players[pindex].remote_view = true
      players[pindex].cursor = true
      players[pindex].build_lock = false
      center_player_character(pindex)
      printout("Remote view opened", pindex)
   else
      players[pindex].remote_view = false
      players[pindex].cursor = false
      players[pindex].build_lock = false
      printout("Remote view closed", pindex)
      game.get_player(pindex).close_map()
   end

   --Fix zoom
   fa_zoom.fix_zoom(pindex)
end

--Teleports the player character to the nearest tile center position to allow grid aligned cursor movement.
function center_player_character(pindex)
   local p = game.get_player(pindex)
   local can_port = p.surface.can_place_entity({ name = "character", position = fa_utils.center_of_tile(p.position) })
   local ents = p.surface.find_entities_filtered({
      position = fa_utils.center_of_tile(p.position),
      radius = 0.1,
      type = { "character" },
      invert = true,
   })
   if #ents > 0 and ents[1].valid then
      local ent = ents[1]
      --Ignore ents you can walk through, laterdo better collision checks**
      can_port = can_port or all_ents_are_walkable(p.position)
   end
   if can_port then p.teleport(fa_utils.center_of_tile(p.position)) end
   players[pindex].position = p.position
   players[pindex].cursor_pos = fa_utils.center_of_tile(players[pindex].cursor_pos)
   fa_mouse.move_mouse_pointer(players[pindex].cursor_pos, pindex)
end

--Teleports the cursor to the player character
function jump_to_player(pindex)
   local first_player = game.get_player(pindex)
   players[pindex].cursor_pos.x = math.floor(first_player.position.x) + 0.5
   players[pindex].cursor_pos.y = math.floor(first_player.position.y) + 0.5
   read_coords(pindex, "Cursor returned ")
   if players[pindex].cursor_size < 2 then
      fa_graphics.draw_cursor_highlight(pindex, nil, nil)
   else
      local scan_left_top = {
         math.floor(players[pindex].cursor_pos.x) - players[pindex].cursor_size,
         math.floor(players[pindex].cursor_pos.y) - players[pindex].cursor_size,
      }
      local scan_right_bottom = {
         math.floor(players[pindex].cursor_pos.x) + players[pindex].cursor_size + 1,
         math.floor(players[pindex].cursor_pos.y) + players[pindex].cursor_size + 1,
      }
      fa_graphics.draw_large_cursor(scan_left_top, scan_right_bottom, pindex)
   end
end

function return_cursor_to_character(pindex)
   if not check_for_player(pindex) then return end
   local ent = get_selected_ent(pindex)
   if not players[pindex].in_menu then
      if players[pindex].cursor then jump_to_player(pindex) end
   end
end

--Re-checks the cursor tile and indexes the entities on it, returns a boolean on whether it is successful.
function refresh_player_tile(pindex)
   local surf = game.get_player(pindex).surface
   --local search_area = {{x=-0.5,y=-0.5},{x=0.29,y=0.29}}
   --local search_center = players[pindex].cursor_pos
   --search_area[1]=add_position(search_area[1],search_center)
   --search_area[2]=add_position(search_area[2],search_center)
   local c_pos = players[pindex].cursor_pos
   if math.floor(c_pos.x) == math.ceil(c_pos.x) then c_pos.x = c_pos.x - 0.01 end
   if math.floor(c_pos.y) == math.ceil(c_pos.y) then c_pos.y = c_pos.y - 0.01 end
   local search_area = {
      { x = math.floor(c_pos.x) + 0.01, y = math.floor(c_pos.y) + 0.01 },
      { x = math.ceil(c_pos.x) - 0.01, y = math.ceil(c_pos.y) - 0.01 },
   }
   local excluded_names = { "highlight-box", "flying-text" }
   players[pindex].tile.ents = surf.find_entities_filtered({ area = search_area, name = excluded_names, invert = true })
   --rendering.draw_rectangle{left_top = search_area[1], right_bottom = search_area[2], color = {1,0,1}, surface = surf, time_to_live = 100}--
   local wide_area = {
      { x = math.floor(c_pos.x) - 0.01, y = math.floor(c_pos.y) - 0.01 },
      { x = math.ceil(c_pos.x) + 0.01, y = math.ceil(c_pos.y) + 0.01 },
   }
   local remnants = surf.find_entities_filtered({ area = wide_area, type = "corpse" })
   for i, remnant in ipairs(remnants) do
      table.insert(players[pindex].tile.ents, remnant)
   end
   players[pindex].tile.index = #players[pindex].tile.ents == 0 and 0 or 1
   if
      not (
         pcall(function()
            players[pindex].tile.tile = surf.get_tile(players[pindex].cursor_pos.x, players[pindex].cursor_pos.y).name
            players[pindex].tile.tile_object = surf.get_tile(players[pindex].cursor_pos.x, players[pindex].cursor_pos.y)
         end)
      )
   then
      return false
   end
   return true
end

--Reads the cursor tile and reads out the result. If an entity is found, its ent info is read. Otherwise info about the tile itself is read.
function read_tile(pindex, start_text)
   local result = start_text or ""
   if not refresh_player_tile(pindex) then
      printout(result .. "Tile uncharted and out of range", pindex)
      return
   end
   local ent = get_selected_ent(pindex)
   if not (ent and ent.valid) then
      --If there is no ent, read the tile instead
      players[pindex].tile.previous = nil
      local tile = players[pindex].tile.tile
      result = result .. fa_localising.get(players[pindex].tile.tile_object, pindex)
      if
         tile == "water"
         or tile == "deepwater"
         or tile == "water-green"
         or tile == "deepwater-green"
         or tile == "water-shallow"
         or tile == "water-mud"
         or tile == "water-wube"
      then
         --Identify shores and crevices and so on for water tiles
         result = result .. fa_utils.identify_water_shores(pindex)
      end
      fa_graphics.draw_cursor_highlight(pindex, nil, nil)
      game.get_player(pindex).selected = nil
   else --laterdo tackle the issue here where entities such as tree stumps block preview info
      result = result .. ent_info(pindex, ent)
      fa_graphics.draw_cursor_highlight(pindex, ent, nil)
      game.get_player(pindex).selected = ent

      --game.get_player(pindex).print(result)--
      players[pindex].tile.previous = ent
   end
   if not ent or ent.type == "resource" then --possible bug here with the h box being a new tile ent
      local stack = game.get_player(pindex).cursor_stack
      --Run build preview checks
      if stack and stack.valid_for_read and stack.valid and stack.prototype.place_result ~= nil then
         result = result .. fa_building_tools.build_preview_checks_info(stack, pindex)
         --game.get_player(pindex).print(result)--
      end
   end

   --If the player is holding a cut-paste tool, every entity being read gets mined as soon as you read a new tile.
   local stack = game.get_player(pindex).cursor_stack
   if stack and stack.valid_for_read and stack.name == "cut-paste-tool" and not players[pindex].vanilla_mode then
      if ent and ent.valid then --not while loop, because it causes crashes
         local name = ent.name
         game.get_player(pindex).play_sound({ path = "player-mine" })
         if fa_mining_tools.try_to_mine_with_soun(ent, pindex) then result = result .. name .. " mined, " end
         --Second round, in case two entities are there. While loops do not work!
         ent = get_selected_ent(pindex)
         if ent and ent.valid and players[pindex].walk ~= 2 then --not while
            local name = ent.name
            game.get_player(pindex).play_sound({ path = "player-mine" })
            if fa_mining_tools.try_to_mine_with_soun(ent, pindex) then result = result .. name .. " mined, " end
         end
      end
   end

   --Add info on whether the tile is uncharted or blurred or distant
   result = result .. cursor_visibility_info(pindex)
   printout(result, pindex)
   --game.get_player(pindex).print(result)--**
end

--Read the current co-ordinates of the cursor on the map or in a menu. For crafting recipe and technology menus, it reads the ingredients / requirements instead.
--Todo: split this function by menu.
function read_coords(pindex, start_phrase)
   start_phrase = start_phrase or ""
   local result = start_phrase
   local ent = players[pindex].building.ent
   local offset = 0
   if
      (players[pindex].menu == "building" or players[pindex].menu == "vehicle")
      and players[pindex].building.recipe_list ~= nil
   then
      offset = 1
   end
   if not players[pindex].in_menu or players[pindex].menu == "structure-travel" or players[pindex].menu == "travel" then
      if players[pindex].vanilla_mode then players[pindex].cursor_pos = game.get_player(pindex).position end
      if game.get_player(pindex).driving then
         --Give vehicle coords and orientation and speed --laterdo find exact speed coefficient
         local vehicle = game.get_player(pindex).vehicle
         local speed = vehicle.speed * 215
         if vehicle.type ~= "spider-vehicle" then
            if speed > 0 then
               result = result
                  .. " heading "
                  .. fa_utils.get_heading_info(vehicle)
                  .. " at "
                  .. math.floor(speed)
                  .. " kilometers per hour "
            elseif speed < 0 then
               result = result
                  .. " facing "
                  .. fa_utils.get_heading_info(vehicle)
                  .. " while reversing at "
                  .. math.floor(-speed)
                  .. " kilometers per hour "
            else
               result = result .. " parked facing " .. fa_utils.get_heading_info(vehicle)
            end
         else
            result = result .. " moving at " .. math.floor(speed) .. " kilometers per hour "
         end
         result = result .. " in " .. fa_localising.get(vehicle, pindex) .. " at point "
         printout(result .. math.floor(vehicle.position.x) .. ", " .. math.floor(vehicle.position.y), pindex)
      else
         --Simply give coords (floored for the readout, extra precision for the console)
         local location = fa_utils.get_entity_part_at_cursor(pindex)
         if location == nil then location = " " end
         local marked_pos = { x = players[pindex].cursor_pos.x, y = players[pindex].cursor_pos.y }
         result = result .. " " .. location .. " at " .. math.floor(marked_pos.x) .. ", " .. math.floor(marked_pos.y)
         game.get_player(pindex).print(
            result .. "\n (" .. math.floor(marked_pos.x * 10) / 10 .. ", " .. math.floor(marked_pos.y * 10) / 10 .. ")",
            { volume_modifier = 0 }
         )
         rendering.draw_circle({
            color = { 1.0, 0.2, 0.0 },
            radius = 0.1,
            width = 5,
            target = players[pindex].cursor_pos,
            surface = game.get_player(pindex).surface,
            time_to_live = 180,
         })
         --rendering.draw_circle{color = {0.2, 0.8, 0.2},radius = 0.2,width = 5, target = marked_pos,surface = game.get_player(pindex).surface,time_to_live = 180}

         --If there is a build preview, give its dimensions and which way they extend
         local stack = game.get_player(pindex).cursor_stack
         if
            stack
            and stack.valid_for_read
            and stack.valid
            and stack.prototype.place_result ~= nil
            and (stack.prototype.place_result.tile_height > 1 or stack.prototype.place_result.tile_width > 1)
         then
            local dir = players[pindex].building_direction
            turn_to_cursor_direction_cardinal(pindex)
            local p_dir = players[pindex].player_direction
            local preview_str = ", preview is "
            if dir == dirs.north or dir == dirs.south then
               preview_str = preview_str .. stack.prototype.place_result.tile_width .. " tiles wide "
            elseif dir == dirs.east or dir == dirs.west then
               preview_str = preview_str .. stack.prototype.place_result.tile_height .. " tiles wide "
            end
            if players[pindex].cursor or p_dir == dirs.east or p_dir == dirs.south or p_dir == dirs.north then
               preview_str = preview_str .. " to the East "
            elseif not players[pindex].cursor and p_dir == dirs.west then
               preview_str = preview_str .. " to the West "
            end
            if dir == dirs.north or dir == dirs.south then
               preview_str = preview_str .. " and " .. stack.prototype.place_result.tile_height .. " tiles high "
            elseif dir == dirs.east or dir == dirs.west then
               preview_str = preview_str .. " and " .. stack.prototype.place_result.tile_width .. " tiles high "
            end
            if players[pindex].cursor or p_dir == dirs.east or p_dir == dirs.south or p_dir == dirs.west then
               preview_str = preview_str .. " to the South "
            elseif not players[pindex].cursor and p_dir == dirs.north then
               preview_str = preview_str .. " to the North "
            end
            result = result .. preview_str
         elseif
            stack
            and stack.valid_for_read
            and stack.valid
            and stack.is_blueprint
            and stack.is_blueprint_setup()
         then
            --Blueprints have their own data
            local left_top, right_bottom, build_pos = fa_blueprints.get_blueprint_corners(pindex, false)
            local bp_dim_1 = right_bottom.x - left_top.x
            local bp_dim_2 = right_bottom.y - left_top.y
            local preview_str = ", blueprint preview is "
               .. bp_dim_1
               .. " tiles wide to the East and "
               .. bp_dim_2
               .. " tiles high to the South"
            result = result .. preview_str
         elseif stack and stack.valid_for_read and stack.valid and stack.prototype.place_as_tile_result ~= nil then
            --Paving preview size
            local preview_str = ", paving preview "
            local player = players[pindex]
            preview_str = ", paving preview is "
               .. (player.cursor_size * 2 + 1)
               .. " by "
               .. (player.cursor_size * 2 + 1)
               .. " tiles, centered on this tile. "
            if players[pindex].cursor and players[pindex].preferences.tiles_placed_from_northwest_corner then
               preview_str = ", paving preview extends "
                  .. (player.cursor_size * 2 + 1)
                  .. " east and "
                  .. (player.cursor_size * 2 + 1)
                  .. " south, starting from this tile. "
            end
            result = result .. preview_str
         end
         printout(result, pindex)
      end
   elseif
      players[pindex].menu == "inventory"
      or players[pindex].menu == "player_trash"
      or (
         (players[pindex].menu == "building" or players[pindex].menu == "vehicle")
         and players[pindex].building.sector > offset + #players[pindex].building.sectors
      )
   then
      --Give slot coords (player inventory)
      local x = players[pindex].inventory.index % 10
      local y = math.floor(players[pindex].inventory.index / 10) + 1
      if x == 0 then
         x = x + 10
         y = y - 1
      end
      printout(result .. " slot " .. x .. ", on row " .. y, pindex)
   elseif
      (players[pindex].menu == "building" or players[pindex].menu == "vehicle")
      and players[pindex].building.recipe_selection == false
   then
      --Give slot coords (chest/building inventory)
      local x = -1 --Col number
      local y = -1 --Row number
      local row_length = players[pindex].preferences.building_inventory_row_length
      x = players[pindex].building.index % row_length
      y = math.floor(players[pindex].building.index / row_length) + 1
      if x == 0 then
         x = x + row_length
         y = y - 1
      end
      printout(result .. " slot " .. x .. ", on row " .. y, pindex)
   elseif players[pindex].menu == "crafting" then
      --Read recipe ingredients / products (crafting menu)
      local recipe =
         players[pindex].crafting.lua_recipes[players[pindex].crafting.category][players[pindex].crafting.index]
      result = result .. "Ingredients: "
      for i, v in pairs(recipe.ingredients) do
         ---@type LuaItemPrototype | LuaFluidPrototype
         local proto = game.item_prototypes[v.name]
         if proto == nil then proto = game.fluid_prototypes[v.name] end
         local localised_name = fa_localising.get(proto, pindex)
         result = result .. ", " .. localised_name .. " times " .. v.amount
      end
      result = result .. ", Products: "
      for i, v in pairs(recipe.products) do
         ---@type LuaItemPrototype | LuaFluidPrototype
         local proto = game.item_prototypes[v.name]
         if proto == nil then proto = game.fluid_prototypes[v.name] end
         local localised_name = fa_localising.get(proto, pindex)
         result = result .. ", " .. localised_name .. " times " .. v.amount
      end
      result = result .. ", craft time " .. recipe.energy .. " seconds by default."
      printout(result, pindex)
   elseif players[pindex].menu == "technology" then
      --Read research requirements
      local techs = {}
      if players[pindex].technology.category == 1 then
         techs = players[pindex].technology.lua_researchable
      elseif players[pindex].technology.category == 2 then
         techs = players[pindex].technology.lua_locked
      elseif players[pindex].technology.category == 3 then
         techs = players[pindex].technology.lua_unlocked
      end

      if next(techs) ~= nil and players[pindex].technology.index > 0 and players[pindex].technology.index <= #techs then
         result = result .. "Requires prior research "
         local dict = techs[players[pindex].technology.index].prerequisites
         local pre_count = 0
         for a, b in pairs(dict) do
            pre_count = pre_count + 1
         end
         if pre_count == 0 then result = result .. " None " end
         for i, preq in pairs(techs[players[pindex].technology.index].prerequisites) do
            result = result .. fa_localising.get(preq, pindex) .. " , "
         end
         result = result
            .. ", and equipment "
            .. techs[players[pindex].technology.index].research_unit_count
            .. " times "
         for i, ingredient in pairs(techs[players[pindex].technology.index].research_unit_ingredients) do
            result = result .. fa_localising.get_item_from_name(ingredient.name, pindex) .. ", "
         end

         printout(result, pindex)
      end
   end
   if
      (players[pindex].menu == "building" or players[pindex].menu == "vehicle")
      and players[pindex].building.recipe_selection
   then
      --Read recipe ingredients / products (building recipe selection)
      local recipe =
         players[pindex].building.recipe_list[players[pindex].building.category][players[pindex].building.index]
      result = result .. "Ingredients: "
      for i, v in pairs(recipe.ingredients) do
         ---@type LuaItemPrototype | LuaFluidPrototype
         local proto = game.item_prototypes[v.name]
         if proto == nil then proto = game.fluid_prototypes[v.name] end
         local localised_name = fa_localising.get(proto, pindex)
         result = result .. ", " .. localised_name .. " x" .. v.amount .. " per cycle "
      end
      result = result .. ", products: "
      for i, v in pairs(recipe.products) do
         ---@type LuaItemPrototype | LuaFluidPrototype
         local proto = game.item_prototypes[v.name]
         if proto == nil then proto = game.fluid_prototypes[v.name] end
         local localised_name = fa_localising.get(proto, pindex)
         result = result .. ", " .. localised_name .. " x" .. v.amount .. " per cycle "
      end
      result = result .. ", craft time " .. recipe.energy .. " seconds at default speed."
      printout(result, pindex)
   end
end

--Initialize the globally saved data tables for a specific player.
function initialize(player)
   local force = player.force.index
   global.forces[force] = global.forces[force] or {}
   local fa_force = global.forces[force]

   global.players[player.index] = global.players[player.index] or {}
   local faplayer = global.players[player.index]
   faplayer.player = player

   if not fa_force.resources then
      for pi, p in pairs(global.players) do
         if p.player.valid and p.player.force.index == force and p.resources and p.mapped then
            fa_force.resources = p.resources
            fa_force.mapped = p.mapped
            break
         end
      end
      fa_force.resources = fa_force.resources or {}
      fa_force.mapped = fa_force.mapped or {}
   end

   local character = player.cutscene_character or player.character or player
   faplayer.in_menu = faplayer.in_menu or false
   faplayer.in_item_selector = faplayer.in_item_selector or false
   faplayer.menu = faplayer.menu or "none"
   faplayer.entering_search_term = faplayer.entering_search_term or false
   faplayer.menu_search_index = faplayer.menu_search_index or nil
   faplayer.menu_search_index_2 = faplayer.menu_search_index_2 or nil
   faplayer.menu_search_term = faplayer.menu_search_term or nil
   faplayer.menu_search_frame = faplayer.menu_search_frame or nil
   faplayer.menu_search_last_name = faplayer.menu_search_last_name or nil
   faplayer.cursor = faplayer.cursor or false
   faplayer.cursor_size = faplayer.cursor_size or 0
   faplayer.cursor_ent_highlight_box = faplayer.cursor_ent_highlight_box or nil
   faplayer.cursor_tile_highlight_box = faplayer.cursor_tile_highlight_box or nil
   faplayer.num_elements = faplayer.num_elements or 0
   faplayer.player_direction = faplayer.player_direction or character.walking_state.direction
   faplayer.position = faplayer.position or fa_utils.center_of_tile(character.position)
   faplayer.cursor_pos = faplayer.cursor_pos
      or fa_utils.offset_position(faplayer.position, faplayer.player_direction, 1)
   faplayer.walk = faplayer.walk or 0
   faplayer.move_queue = faplayer.move_queue or {}
   faplayer.building_direction = faplayer.building_direction or dirs.north --top
   faplayer.building_footprint = faplayer.building_footprint or nil
   faplayer.building_dir_arrow = faplayer.building_dir_arrow or nil
   faplayer.overhead_sprite = nil
   faplayer.overhead_circle = nil
   faplayer.custom_GUI_frame = nil
   faplayer.custom_GUI_sprite = nil
   faplayer.direction_lag = faplayer.direction_lag or true
   faplayer.previous_hand_item_name = faplayer.previous_hand_item_name or ""
   faplayer.last = faplayer.last or ""
   faplayer.last_indexed_ent = faplayer.last_indexed_ent or nil
   faplayer.item_selection = faplayer.item_selection or false
   faplayer.item_cache = faplayer.item_cache or {}
   faplayer.zoom = faplayer.zoom or 1
   faplayer.build_lock = faplayer.build_lock or false
   faplayer.vanilla_mode = faplayer.vanilla_mode or false
   faplayer.hide_cursor = faplayer.hide_cursor or false
   faplayer.allow_reading_flying_text = faplayer.allow_reading_flying_text or true
   faplayer.resources = fa_force.resources
   faplayer.mapped = fa_force.mapped
   faplayer.destroyed = faplayer.destroyed or {}
   faplayer.last_menu_toggle_tick = faplayer.last_menu_toggle_tick or 1
   faplayer.last_menu_search_tick = faplayer.last_menu_search_tick or 1
   faplayer.last_click_tick = faplayer.last_click_tick or 1
   faplayer.last_damage_alert_tick = faplayer.last_damage_alert_tick or 1
   faplayer.last_damage_alert_pos = faplayer.last_damage_alert_pos or nil
   faplayer.last_pg_key_tick = faplayer.last_pg_key_tick or 1
   faplayer.last_honk_tick = faplayer.last_honk_tick or 1
   faplayer.last_pickup_tick = faplayer.last_pickup_tick or 1
   faplayer.last_item_picked_up = faplayer.last_item_picked_up or nil
   faplayer.skip_read_hand = faplayer.skip_read_hand or false
   faplayer.tutorial = faplayer.tutorial or nil

   faplayer.preferences = faplayer.preferences or {}

   faplayer.preferences.building_inventory_row_length = faplayer.preferences.building_inventory_row_length or 8
   if faplayer.preferences.inventory_wraps_around == nil then faplayer.preferences.inventory_wraps_around = true end
   if faplayer.preferences.tiles_placed_from_northwest_corner == nil then
      faplayer.preferences.tiles_placed_from_northwest_corner = false
   end

   faplayer.nearby = faplayer.nearby
      or {
         index = 0,
         selection = 0,
         count = false,
         category = 1,
         ents = {},
         resources = {},
         containers = {},
         buildings = {},
         vehicles = {},
         players = {},
         enemies = {},
         other = {},
      }
   faplayer.nearby.ents = faplayer.nearby.ents or {}

   faplayer.tile = faplayer.tile or {
      ents = {},
      tile = "",
      index = 1,
      previous = nil,
   }

   faplayer.inventory = faplayer.inventory or {
      lua_inventory = nil,
      max = 0,
      index = 1,
   }

   faplayer.crafting = faplayer.crafting
      or {
         lua_recipes = nil,
         max = 0,
         index = 1,
         category = 1,
      }

   faplayer.crafting_queue = faplayer.crafting_queue or {
      index = 1,
      max = 0,
      lua_queue = nil,
   }

   faplayer.technology = faplayer.technology
      or {
         index = 1,
         category = 1,
         lua_researchable = {},
         lua_unlocked = {},
         lua_locked = {},
      }

   faplayer.building = faplayer.building
      or {
         index = 0,
         ent = nil,
         sectors = nil,
         sector = 0,
         recipe_selection = false,
         item_selection = false,
         category = 0,
         recipe = nil,
         recipe_list = nil,
      }

   faplayer.belt = faplayer.belt
      or {
         index = 1,
         sector = 1,
         ent = nil,
         line1 = nil,
         line2 = nil,
         network = {},
         side = 0,
      }
   faplayer.warnings = faplayer.warnings
      or {
         short = {},
         medium = {},
         long = {},
         sector = 1,
         index = 1,
         category = 1,
      }
   faplayer.pump = faplayer.pump or {
      index = 0,
      positions = {},
   }

   faplayer.item_selector = faplayer.item_selector or {
      index = 0,
      group = 0,
      subgroup = 0,
   }

   faplayer.travel = faplayer.travel
      or {
         index = { x = 1, y = 0 },
         creating = false,
         renaming = false,
      }

   faplayer.structure_travel = faplayer.structure_travel
      or {
         network = {},
         current = nil,
         index = 0,
         direction = "none",
      }

   faplayer.rail_builder = faplayer.rail_builder
      or {
         index = 0,
         index_max = 1,
         rail = nil,
         rail_type = 0,
      }

   faplayer.train_menu = faplayer.train_menu
      or {
         index = 0,
         renaming = false,
         locomotive = nil,
         wait_time = 300,
         index_2 = 0,
         selecting_station = false,
      }

   faplayer.spider_menu = faplayer.spider_menu or {
      index = 0,
      renaming = false,
      spider = nil,
   }

   faplayer.train_stop_menu = faplayer.train_stop_menu
      or {
         index = 0,
         renaming = false,
         stop = nil,
         wait_condition = "time",
         wait_time_seconds = 30,
         safety_wait_enabled = true,
      }

   faplayer.valid_train_stop_list = faplayer.valid_train_stop_list or {}

   faplayer.roboport_menu = faplayer.roboport_menu or {
      port = nil,
      index = 0,
      renaming = false,
   }

   faplayer.blueprint_menu = faplayer.blueprint_menu
      or {
         index = 0,
         edit_label = false,
         edit_description = false,
         edit_export = false,
         edit_import = false,
      }

   faplayer.blueprint_book_menu = faplayer.blueprint_book_menu
      or {
         index = 0,
         menu_length = 0,
         list_mode = true,
         edit_label = false,
         edit_description = false,
         edit_export = false,
         edit_import = false,
      }

   if table_size(faplayer.mapped) == 0 then player.force.rechart() end

   faplayer.localisations = faplayer.localisations or {}
   faplayer.translation_id_lookup = faplayer.translation_id_lookup or {}
   fa_localising.check_player(player.index)

   faplayer.bump = faplayer.bump
      or {
         last_bump_tick = 1, --Updated in bump checker
         last_dir_key_tick = 1, --Updated in key press handlers
         last_dir_key_1st = nil, --Updated in key press handlers
         last_dir_key_2nd = nil, --Updated in key press handlers
         last_pos_1 = nil, --Updated in bump checker
         last_pos_2 = nil, --Updated in bump checker
         last_pos_3 = nil, --Updated in bump checker
         last_pos_4 = nil, --Updated in bump checker
         last_dir_2 = nil, --Updated in bump checker
         last_dir_1 = nil, --Updated in bump checker
      }
end

--Update the position info and cursor info during smooth walking.
script.on_event(defines.events.on_player_changed_position, function(event)
   local pindex = event.player_index
   local p = game.get_player(pindex)
   if not check_for_player(pindex) then return end
   if players[pindex].walk == 2 then
      players[pindex].position = p.position
      local pos = p.position
      if p.walking_state.direction ~= players[pindex].player_direction and players[pindex].cursor == false then
         --Directions mismatch. Turn to new direction --turn (Note, this code handles diagonal turns and other direction changes)
         if p.character ~= nil then
            players[pindex].player_direction = p.character.direction
         else
            players[pindex].player_direction = p.walking_state.direction
            if p.walking_state.direction == nil then players[pindex].player_direction = dirs.north end
         end
         local new_pos = (fa_utils.offset_position(pos, players[pindex].player_direction, 1.0))
         players[pindex].cursor_pos = new_pos

         --Build lock building + rotate belts in hand unless cursor mode
         local stack = p.cursor_stack
         if
            players[pindex].build_lock
            and stack.valid_for_read
            and stack.valid
            and stack.prototype.place_result ~= nil
            and (stack.prototype.place_result.type == "transport-belt" or stack.name == "rail")
         then
            turn_to_cursor_direction_cardinal(pindex)
            players[pindex].building_direction = players[pindex].player_direction
            fa_building_tools.build_item_in_hand(pindex) --build extra belt when turning
         end
      elseif players[pindex].cursor == false then
         --Directions same: Walk straight
         local new_pos = (fa_utils.offset_position(pos, players[pindex].player_direction, 1))
         players[pindex].cursor_pos = new_pos

         --Build lock building + rotate belts in hand unless cursor mode
         if players[pindex].build_lock then
            local stack = p.cursor_stack
            if
               stack
               and stack.valid_for_read
               and stack.valid
               and stack.prototype.place_result ~= nil
               and stack.prototype.place_result.type == "transport-belt"
            then
               turn_to_cursor_direction_cardinal(pindex)
               players[pindex].building_direction = players[pindex].player_direction
            end
            fa_building_tools.build_item_in_hand(pindex)
         end
      end

      --Update cursor graphics
      local stack = p.cursor_stack
      if stack and stack.valid_for_read and stack.valid then fa_graphics.sync_build_cursor_graphics(pindex) end

      --Name a detected entity that you can or cannot walk on, or a tile you cannot walk on, and play a sound to indicate multiple consecutive detections
      refresh_player_tile(pindex)
      local ent = get_selected_ent(pindex)
      if
         not players[pindex].vanilla_mode
         and (
            (ent ~= nil and ent.valid)
            or (p.surface.can_place_entity({ name = "character", position = players[pindex].cursor_pos }) == false)
         )
      then
         fa_graphics.draw_cursor_highlight(pindex, ent, nil)
         if p.driving then return end

         if
            ent ~= nil
            and ent.valid
            and (p.character == nil or (p.character ~= nil and p.character.unit_number ~= ent.unit_number))
         then
            fa_graphics.draw_cursor_highlight(pindex, ent, nil)
            p.selected = ent
            p.play_sound({ path = "Close-Inventory-Sound", volume_modifier = 0.75 })
         else
            fa_graphics.draw_cursor_highlight(pindex, nil, nil)
            p.selected = nil
         end

         read_tile(pindex)
      else
         fa_graphics.draw_cursor_highlight(pindex, nil, nil)
         p.selected = nil
      end
   end
end)

--Calls the appropriate menu movement function for a player and the input direction.
function menu_cursor_move(direction, pindex)
   players[pindex].preferences.inventory_wraps_around = true --laterdo make this a setting to toggle
   if direction == defines.direction.north then
      menu_cursor_up(pindex)
   elseif direction == defines.direction.south then
      menu_cursor_down(pindex)
   elseif direction == defines.direction.east then
      menu_cursor_right(pindex)
   elseif direction == defines.direction.west then
      menu_cursor_left(pindex)
   end
end

--Moves upwards in a menu. Todo: split by menu. "menu_up"
function menu_cursor_up(pindex)
   if players[pindex].item_selection then
      if players[pindex].item_selector.group == 0 then
         printout("Blank", pindex)
      elseif players[pindex].item_selector.subgroup == 0 then
         players[pindex].item_cache = fa_utils.get_iterable_array(game.item_group_prototypes)
         prune_item_groups(players[pindex].item_cache)
         players[pindex].item_selector.index = players[pindex].item_selector.group
         players[pindex].item_selector.group = 0
         read_item_selector_slot(pindex)
      else
         local group = players[pindex].item_cache[players[pindex].item_selector.index].group
         players[pindex].item_cache = fa_utils.get_iterable_array(group.subgroups)
         prune_item_groups(players[pindex].item_cache)

         players[pindex].item_selector.index = players[pindex].item_selector.subgroup
         players[pindex].item_selector.subgroup = 0
         read_item_selector_slot(pindex)
      end
   elseif players[pindex].menu == "inventory" then
      players[pindex].inventory.index = players[pindex].inventory.index - 10
      if players[pindex].inventory.index < 1 then
         if players[pindex].preferences.inventory_wraps_around == true then
            --Wrap around setting: Move to the inventory end and read slot
            players[pindex].inventory.index = players[pindex].inventory.max + players[pindex].inventory.index
            game.get_player(pindex).play_sound({ path = "inventory-wrap-around" })
            read_inventory_slot(pindex)
         else
            --Border setting: Undo change and play "wall" sound
            players[pindex].inventory.index = players[pindex].inventory.index + 10
            game.get_player(pindex).play_sound({ path = "inventory-edge" })
            --printout("Border.", pindex)
         end
      else
         game.get_player(pindex).play_sound({ path = "Inventory-Move" })
         read_inventory_slot(pindex)
      end
   elseif players[pindex].menu == "player_trash" then
      local trash_inv = game.get_player(pindex).get_inventory(defines.inventory.character_trash)
      players[pindex].inventory.index = players[pindex].inventory.index - 10
      if players[pindex].inventory.index < 1 then
         if players[pindex].preferences.inventory_wraps_around == true then
            --Wrap around setting: Move to the inventory end and read slot
            players[pindex].inventory.index = #trash_inv + players[pindex].inventory.index
            game.get_player(pindex).play_sound({ path = "inventory-wrap-around" })
            read_inventory_slot(pindex, "", trash_inv)
         else
            --Border setting: Undo change and play "wall" sound
            players[pindex].inventory.index = players[pindex].inventory.index + 10
            game.get_player(pindex).play_sound({ path = "inventory-edge" })
            --printout("Border.", pindex)
         end
      else
         game.get_player(pindex).play_sound({ path = "Inventory-Move" })
         read_inventory_slot(pindex, "", trash_inv)
      end
   elseif players[pindex].menu == "crafting" then
      game.get_player(pindex).play_sound({ path = "Inventory-Move" })
      players[pindex].crafting.index = 1
      players[pindex].crafting.category = players[pindex].crafting.category - 1

      if players[pindex].crafting.category < 1 then players[pindex].crafting.category = players[pindex].crafting.max end
      fa_crafting.read_crafting_slot(pindex, "", true)
   elseif players[pindex].menu == "crafting_queue" then
      game.get_player(pindex).play_sound({ path = "Inventory-Move" })
      fa_crafting.load_crafting_queue(pindex)
      players[pindex].crafting_queue.index = 1
      fa_crafting.read_crafting_queue(pindex)
   elseif players[pindex].menu == "building" or players[pindex].menu == "vehicle" then
      --Move one row up in a building inventory of some kind
      if players[pindex].building.sector <= #players[pindex].building.sectors then
         --Most building sectors, eg. chest rows
         if
            players[pindex].building.sectors[players[pindex].building.sector].inventory == nil
            or #players[pindex].building.sectors[players[pindex].building.sector].inventory < 1
         then
            printout("blank sector", pindex)
            return
         end
         --Move one row up in building inventory
         local row_length = players[pindex].preferences.building_inventory_row_length
         if #players[pindex].building.sectors[players[pindex].building.sector].inventory > row_length then
            game.get_player(pindex).play_sound({ path = "Inventory-Move" })
            players[pindex].building.index = players[pindex].building.index - row_length
            if players[pindex].building.index < 1 then
               --Wrap around to building inventory last row
               game.get_player(pindex).play_sound({ path = "inventory-wrap-around" })
               players[pindex].building.index = players[pindex].building.index
                  + #players[pindex].building.sectors[players[pindex].building.sector].inventory
            end
         else
            --Inventory size < row length: Wrap over to the same slot
            game.get_player(pindex).play_sound({ path = "inventory-wrap-around" })
            --players[pindex].building.index = 1
         end
         fa_sectors.read_sector_slot(pindex, false)
      elseif players[pindex].building.recipe_list == nil then
         --Move one row up in player inventory
         game.get_player(pindex).play_sound({ path = "Inventory-Move" })
         players[pindex].inventory.index = players[pindex].inventory.index - 10
         if players[pindex].inventory.index < 1 then
            players[pindex].inventory.index = players[pindex].inventory.max + players[pindex].inventory.index
         end
         read_inventory_slot(pindex)
      else
         if players[pindex].building.sector == #players[pindex].building.sectors + 1 then
            --Last building sector. Case = ??? **
            if players[pindex].building.recipe_selection then
               game.get_player(pindex).play_sound({ path = "Inventory-Move" })
               players[pindex].building.category = players[pindex].building.category - 1
               players[pindex].building.index = 1
               if players[pindex].building.category < 1 then
                  players[pindex].building.category = #players[pindex].building.recipe_list
               end
            end
            fa_sectors.read_building_recipe(pindex)
         else
            --Case = ???
            game.get_player(pindex).play_sound({ path = "Inventory-Move" })
            players[pindex].inventory.index = players[pindex].inventory.index - 10
            if players[pindex].inventory.index < 1 then
               players[pindex].inventory.index = players[pindex].inventory.max + players[pindex].inventory.index
            end
            read_inventory_slot(pindex)
         end
      end
   elseif players[pindex].menu == "technology" then
      if players[pindex].technology.category > 1 then
         players[pindex].technology.category = players[pindex].technology.category - 1
         players[pindex].technology.index = 1
      end
      if players[pindex].technology.category == 1 then
         printout("Researchable ttechnologies", pindex)
      elseif players[pindex].technology.category == 2 then
         printout("Locked technologies", pindex)
      elseif players[pindex].technology.category == 3 then
         printout("Past Research", pindex)
      end
   elseif players[pindex].menu == "belt" then
      if players[pindex].belt.sector == 1 then
         if
            (players[pindex].belt.side == 1 and players[pindex].belt.line1.valid and players[pindex].belt.index > 1)
            or (players[pindex].belt.side == 2 and players[pindex].belt.line2.valid and players[pindex].belt.index > 1)
         then
            game.get_player(pindex).play_sound({ path = "Inventory-Move" })
            players[pindex].belt.index = players[pindex].belt.index - 1
         end
      elseif players[pindex].belt.sector == 2 then
         local max = 0
         if players[pindex].belt.side == 1 then
            max = #players[pindex].belt.network.combined.left
         elseif players[pindex].belt.side == 2 then
            max = #players[pindex].belt.network.combined.right
         end
         if players[pindex].belt.index > 1 then
            game.get_player(pindex).play_sound({ path = "Inventory-Move" })
            players[pindex].belt.index = math.min(players[pindex].belt.index - 1, max)
         end
      elseif players[pindex].belt.sector == 3 then
         local max = 0
         if players[pindex].belt.side == 1 then
            max = #players[pindex].belt.network.downstream.left
         elseif players[pindex].belt.side == 2 then
            max = #players[pindex].belt.network.downstream.right
         end
         if players[pindex].belt.index > 1 then
            game.get_player(pindex).play_sound({ path = "Inventory-Move" })
            players[pindex].belt.index = math.min(players[pindex].belt.index - 1, max)
         end
      elseif players[pindex].belt.sector == 4 then
         local max = 0
         if players[pindex].belt.side == 1 then
            max = #players[pindex].belt.network.upstream.left
         elseif players[pindex].belt.side == 2 then
            max = #players[pindex].belt.network.upstream.right
         end
         if players[pindex].belt.index > 1 then
            game.get_player(pindex).play_sound({ path = "Inventory-Move" })
            players[pindex].belt.index = math.min(players[pindex].belt.index - 1, max)
         end
      end
      fa_belts.read_belt_slot(pindex)
   elseif players[pindex].menu == "warnings" then
      if players[pindex].warnings.category > 1 then
         players[pindex].warnings.category = players[pindex].warnings.category - 1
         game.get_player(pindex).play_sound({ path = "Inventory-Move" })
         players[pindex].warnings.index = 1
      end
      fa_warnings.read_warnings_slot(pindex)
   elseif players[pindex].menu == "pump" then
      game.get_player(pindex).play_sound({ path = "Inventory-Move" })
      players[pindex].pump.index = math.max(1, players[pindex].pump.index - 1)
      local dir = ""
      if players[pindex].pump.positions[players[pindex].pump.index].direction == 0 then
         dir = " North"
      elseif players[pindex].pump.positions[players[pindex].pump.index].direction == 4 then
         dir = " South"
      elseif players[pindex].pump.positions[players[pindex].pump.index].direction == 2 then
         dir = " East"
      elseif players[pindex].pump.positions[players[pindex].pump.index].direction == 6 then
         dir = " West"
      end

      printout(
         "Option "
            .. players[pindex].pump.index
            .. ": "
            .. math.floor(
               fa_utils.distance(
                  game.get_player(pindex).position,
                  players[pindex].pump.positions[players[pindex].pump.index].position
               )
            )
            .. " meters "
            .. fa_utils.direction(
               game.get_player(pindex).position,
               players[pindex].pump.positions[players[pindex].pump.index].position
            )
            .. " Facing "
            .. dir,
         pindex
      )
   elseif players[pindex].menu == "travel" then
      fa_travel.fast_travel_menu_up(pindex)
   elseif players[pindex].menu == "structure-travel" then
      fa_travel.move_cursor_structure(pindex, 0)
   elseif players[pindex].menu == "rail_builder" then
      fa_rail_builder.menu_up(pindex)
   elseif players[pindex].menu == "train_stop_menu" then
      fa_train_stops.train_stop_menu_up(pindex)
   elseif players[pindex].menu == "roboport_menu" then
      fa_bot_logistics.roboport_menu_up(pindex)
   elseif players[pindex].menu == "blueprint_menu" then
      fa_blueprints.blueprint_menu_up(pindex)
   elseif players[pindex].menu == "blueprint_book_menu" then
      fa_blueprints.blueprint_book_menu_up(pindex)
   elseif players[pindex].menu == "circuit_network_menu" then
      general_mod_menu_up(pindex, players[pindex].circuit_network_menu, 0)
      fa_circuits.circuit_network_menu_run(pindex, nil, players[pindex].circuit_network_menu.index, false)
   elseif players[pindex].menu == "signal_selector" then
      fa_circuits.signal_selector_group_up(pindex)
      fa_circuits.read_selected_signal_group(pindex, "")
   end
end

--Moves downwards in a menu. Todo: split by menu."menu_down"
function menu_cursor_down(pindex)
   if players[pindex].item_selection then
      if players[pindex].item_selector.group == 0 then
         players[pindex].item_selector.group = players[pindex].item_selector.index
         players[pindex].item_cache =
            fa_utils.get_iterable_array(players[pindex].item_cache[players[pindex].item_selector.group].subgroups)
         prune_item_groups(players[pindex].item_cache)

         players[pindex].item_selector.index = 1
         read_item_selector_slot(pindex)
      elseif players[pindex].item_selector.subgroup == 0 then
         players[pindex].item_selector.subgroup = players[pindex].item_selector.index
         local prototypes = game.get_filtered_item_prototypes({
            { filter = "subgroup", subgroup = players[pindex].item_cache[players[pindex].item_selector.index].name },
         })
         players[pindex].item_cache = fa_utils.get_iterable_array(prototypes)
         players[pindex].item_selector.index = 1
         read_item_selector_slot(pindex)
      else
         printout("Press left bracket to confirm your selection.", pindex)
      end
   elseif players[pindex].menu == "inventory" then
      players[pindex].inventory.index = players[pindex].inventory.index + 10
      if players[pindex].inventory.index > players[pindex].inventory.max then
         if players[pindex].preferences.inventory_wraps_around == true then
            --Wrap around setting: Wrap over to first row
            players[pindex].inventory.index = players[pindex].inventory.index % 10
            if players[pindex].inventory.index == 0 then players[pindex].inventory.index = 10 end
            game.get_player(pindex).play_sound({ path = "inventory-wrap-around" })
            read_inventory_slot(pindex)
         else
            --Border setting: Undo change and play "wall" sound
            players[pindex].inventory.index = players[pindex].inventory.index - 10
            game.get_player(pindex).play_sound({ path = "inventory-edge" })
            --printout("Border.", pindex)
         end
      else
         game.get_player(pindex).play_sound({ path = "Inventory-Move" })
         read_inventory_slot(pindex)
      end
   elseif players[pindex].menu == "player_trash" then
      local trash_inv = game.get_player(pindex).get_inventory(defines.inventory.character_trash)
      players[pindex].inventory.index = players[pindex].inventory.index + 10
      if players[pindex].inventory.index > #trash_inv then
         if players[pindex].preferences.inventory_wraps_around == true then
            --Wrap around setting: Wrap over to first row
            players[pindex].inventory.index = players[pindex].inventory.index % 10
            if players[pindex].inventory.index == 0 then players[pindex].inventory.index = 10 end
            game.get_player(pindex).play_sound({ path = "inventory-wrap-around" })
            read_inventory_slot(pindex, "", trash_inv)
         else
            --Border setting: Undo change and play "wall" sound
            players[pindex].inventory.index = players[pindex].inventory.index - 10
            game.get_player(pindex).play_sound({ path = "inventory-edge" })
            --printout("Border.", pindex)
         end
      else
         game.get_player(pindex).play_sound({ path = "Inventory-Move" })
         read_inventory_slot(pindex, "", trash_inv)
      end
   elseif players[pindex].menu == "crafting" then
      game.get_player(pindex).play_sound({ path = "Inventory-Move" })
      players[pindex].crafting.index = 1
      players[pindex].crafting.category = players[pindex].crafting.category + 1

      if players[pindex].crafting.category > players[pindex].crafting.max then players[pindex].crafting.category = 1 end
      fa_crafting.read_crafting_slot(pindex, "", true)
   elseif players[pindex].menu == "crafting_queue" then
      game.get_player(pindex).play_sound({ path = "Inventory-Move" })
      fa_crafting.load_crafting_queue(pindex)
      players[pindex].crafting_queue.index = players[pindex].crafting_queue.max
      fa_crafting.read_crafting_queue(pindex)
   elseif players[pindex].menu == "building" or players[pindex].menu == "vehicle" then
      --Move one row down in a building inventory of some kind
      if players[pindex].building.sector <= #players[pindex].building.sectors then
         --Most building sectors, eg. chest rows
         if
            players[pindex].building.sectors[players[pindex].building.sector].inventory == nil
            or #players[pindex].building.sectors[players[pindex].building.sector].inventory < 1
         then
            printout("blank sector", pindex)
            return
         end
         game.get_player(pindex).play_sound({ path = "Inventory-Move" })
         local row_length = players[pindex].preferences.building_inventory_row_length
         if #players[pindex].building.sectors[players[pindex].building.sector].inventory > row_length then
            --Move one row down
            players[pindex].building.index = players[pindex].building.index + row_length
            if
               players[pindex].building.index
               > #players[pindex].building.sectors[players[pindex].building.sector].inventory
            then
               --Wrap around to the building inventory first row
               game.get_player(pindex).play_sound({ path = "inventory-wrap-around" })
               players[pindex].building.index = players[pindex].building.index % row_length
               --If the row is shorter than usual, get to its end
               if players[pindex].building.index < 1 then players[pindex].building.index = row_length end
            end
         else
            --Inventory size < row length: Wrap over to the same slot
            game.get_player(pindex).play_sound({ path = "inventory-wrap-around" })
         end
         fa_sectors.read_sector_slot(pindex, false)
      elseif players[pindex].building.recipe_list == nil then
         --Move one row down in player inventory
         game.get_player(pindex).play_sound({ path = "Inventory-Move" })
         players[pindex].inventory.index = players[pindex].inventory.index + 10
         if players[pindex].inventory.index > players[pindex].inventory.max then
            players[pindex].inventory.index = players[pindex].inventory.index % 10
            if players[pindex].inventory.index == 0 then players[pindex].inventory.index = 10 end
         end
         read_inventory_slot(pindex)
      else
         if players[pindex].building.sector == #players[pindex].building.sectors + 1 then
            --Last building sector. Case = ??? **
            if players[pindex].building.recipe_selection then
               game.get_player(pindex).play_sound({ path = "Inventory-Move" })
               players[pindex].building.index = 1
               players[pindex].building.category = players[pindex].building.category + 1
               if players[pindex].building.category > #players[pindex].building.recipe_list then
                  players[pindex].building.category = 1
               end
            end
            fa_sectors.read_building_recipe(pindex)
         else
            --Case = ???
            game.get_player(pindex).play_sound({ path = "Inventory-Move" })
            players[pindex].inventory.index = players[pindex].inventory.index + 10
            if players[pindex].inventory.index > players[pindex].inventory.max then
               players[pindex].inventory.index = players[pindex].inventory.index % 10
               if players[pindex].inventory.index == 0 then players[pindex].inventory.index = 10 end
            end
            read_inventory_slot(pindex)
         end
      end
   elseif players[pindex].menu == "technology" then
      if players[pindex].technology.category < 3 then
         players[pindex].technology.category = players[pindex].technology.category + 1
         players[pindex].technology.index = 1
      end
      if players[pindex].technology.category == 1 then
         printout("Researchable ttechnologies", pindex)
      elseif players[pindex].technology.category == 2 then
         printout("Locked technologies", pindex)
      elseif players[pindex].technology.category == 3 then
         printout("Past Research", pindex)
      end
   elseif players[pindex].menu == "belt" then
      if players[pindex].belt.sector == 1 then
         if
            (players[pindex].belt.side == 1 and players[pindex].belt.line1.valid and players[pindex].belt.index < 4)
            or (players[pindex].belt.side == 2 and players[pindex].belt.line2.valid and players[pindex].belt.index < 4)
         then
            game.get_player(pindex).play_sound({ path = "Inventory-Move" })
            players[pindex].belt.index = players[pindex].belt.index + 1
         end
      elseif players[pindex].belt.sector == 2 then
         local max = 0
         if players[pindex].belt.side == 1 then
            max = #players[pindex].belt.network.combined.left
         elseif players[pindex].belt.side == 2 then
            max = #players[pindex].belt.network.combined.right
         end
         if players[pindex].belt.index < max then
            game.get_player(pindex).play_sound({ path = "Inventory-Move" })
            players[pindex].belt.index = math.min(players[pindex].belt.index + 1, max)
         end
      elseif players[pindex].belt.sector == 3 then
         local max = 0
         if players[pindex].belt.side == 1 then
            max = #players[pindex].belt.network.downstream.left
         elseif players[pindex].belt.side == 2 then
            max = #players[pindex].belt.network.downstream.right
         end
         if players[pindex].belt.index < max then
            game.get_player(pindex).play_sound({ path = "Inventory-Move" })
            players[pindex].belt.index = math.min(players[pindex].belt.index + 1, max)
         end
      elseif players[pindex].belt.sector == 4 then
         local max = 0
         if players[pindex].belt.side == 1 then
            max = #players[pindex].belt.network.upstream.left
         elseif players[pindex].belt.side == 2 then
            max = #players[pindex].belt.network.upstream.right
         end
         if players[pindex].belt.index < max then
            game.get_player(pindex).play_sound({ path = "Inventory-Move" })
            players[pindex].belt.index = math.min(players[pindex].belt.index + 1, max)
         end
      end
      fa_belts.read_belt_slot(pindex)
   elseif players[pindex].menu == "warnings" then
      local warnings = {}
      if players[pindex].warnings.sector == 1 then
         warnings = players[pindex].warnings.short.warnings
      elseif players[pindex].warnings.sector == 2 then
         warnings = players[pindex].warnings.medium.warnings
      elseif players[pindex].warnings.sector == 3 then
         warnings = players[pindex].warnings.long.warnings
      end
      if players[pindex].warnings.category < #warnings then
         players[pindex].warnings.category = players[pindex].warnings.category + 1
         game.get_player(pindex).play_sound({ path = "Inventory-Move" })
         players[pindex].warnings.index = 1
      end
      fa_warnings.read_warnings_slot(pindex)
   elseif players[pindex].menu == "pump" then
      game.get_player(pindex).play_sound({ path = "Inventory-Move" })
      players[pindex].pump.index = math.min(#players[pindex].pump.positions, players[pindex].pump.index + 1)
      local dir = ""
      if players[pindex].pump.positions[players[pindex].pump.index].direction == 0 then
         dir = " North"
      elseif players[pindex].pump.positions[players[pindex].pump.index].direction == 4 then
         dir = " South"
      elseif players[pindex].pump.positions[players[pindex].pump.index].direction == 2 then
         dir = " East"
      elseif players[pindex].pump.positions[players[pindex].pump.index].direction == 6 then
         dir = " West"
      end

      printout(
         "Option "
            .. players[pindex].pump.index
            .. ": "
            .. math.floor(
               fa_utils.distance(
                  game.get_player(pindex).position,
                  players[pindex].pump.positions[players[pindex].pump.index].position
               )
            )
            .. " meters "
            .. fa_utils.direction(
               game.get_player(pindex).position,
               players[pindex].pump.positions[players[pindex].pump.index].position
            )
            .. " Facing "
            .. dir,
         pindex
      )
   elseif players[pindex].menu == "travel" then
      fa_travel.fast_travel_menu_down(pindex)
   elseif players[pindex].menu == "structure-travel" then
      fa_travel.move_cursor_structure(pindex, 4)
   elseif players[pindex].menu == "rail_builder" then
      fa_rail_builder.menu_down(pindex)
   elseif players[pindex].menu == "train_stop_menu" then
      fa_train_stops.train_stop_menu_down(pindex)
   elseif players[pindex].menu == "roboport_menu" then
      fa_bot_logistics.roboport_menu_down(pindex)
   elseif players[pindex].menu == "blueprint_menu" then
      fa_blueprints.blueprint_menu_down(pindex)
   elseif players[pindex].menu == "blueprint_book_menu" then
      fa_blueprints.blueprint_book_menu_down(pindex)
   elseif players[pindex].menu == "circuit_network_menu" then
      general_mod_menu_down(pindex, players[pindex].circuit_network_menu, fa_circuits.CN_MENU_LENGTH)
      fa_circuits.circuit_network_menu_run(pindex, nil, players[pindex].circuit_network_menu.index, false)
   elseif players[pindex].menu == "signal_selector" then
      fa_circuits.signal_selector_group_down(pindex)
      fa_circuits.read_selected_signal_group(pindex, "")
   end
end

--Moves to the left in a menu. Todo: split by menu."menu_left"
function menu_cursor_left(pindex)
   if players[pindex].item_selection then
      players[pindex].item_selector.index = math.max(1, players[pindex].item_selector.index - 1)
      read_item_selector_slot(pindex)
   elseif players[pindex].menu == "inventory" then
      players[pindex].inventory.index = players[pindex].inventory.index - 1
      if players[pindex].inventory.index % 10 == 0 then
         if players[pindex].preferences.inventory_wraps_around == true then
            --Wrap around setting: Move and play move sound and read slot
            players[pindex].inventory.index = players[pindex].inventory.index + 10
            game.get_player(pindex).play_sound({ path = "inventory-wrap-around" })
            read_inventory_slot(pindex)
         else
            --Border setting: Undo change and play "wall" sound
            players[pindex].inventory.index = players[pindex].inventory.index + 1
            game.get_player(pindex).play_sound({ path = "inventory-edge" })
            --printout("Border.", pindex)
         end
      else
         game.get_player(pindex).play_sound({ path = "Inventory-Move" })
         read_inventory_slot(pindex)
      end
   elseif players[pindex].menu == "player_trash" then
      local trash_inv = game.get_player(pindex).get_inventory(defines.inventory.character_trash)
      players[pindex].inventory.index = players[pindex].inventory.index - 1
      if players[pindex].inventory.index % 10 == 0 then
         if players[pindex].preferences.inventory_wraps_around == true then
            --Wrap around setting: Move and play move sound and read slot
            players[pindex].inventory.index = players[pindex].inventory.index + 10
            game.get_player(pindex).play_sound({ path = "inventory-wrap-around" })
            read_inventory_slot(pindex, "", trash_inv)
         else
            --Border setting: Undo change and play "wall" sound
            players[pindex].inventory.index = players[pindex].inventory.index + 1
            game.get_player(pindex).play_sound({ path = "inventory-edge" })
            --printout("Border.", pindex)
         end
      else
         game.get_player(pindex).play_sound({ path = "Inventory-Move" })
         read_inventory_slot(pindex, "", trash_inv)
      end
   elseif players[pindex].menu == "crafting" then
      game.get_player(pindex).play_sound({ path = "Inventory-Move" })
      players[pindex].crafting.index = players[pindex].crafting.index - 1
      if players[pindex].crafting.index < 1 then
         players[pindex].crafting.index = #players[pindex].crafting.lua_recipes[players[pindex].crafting.category]
      end
      fa_crafting.read_crafting_slot(pindex)
   elseif players[pindex].menu == "crafting_queue" then
      game.get_player(pindex).play_sound({ path = "Inventory-Move" })
      fa_crafting.load_crafting_queue(pindex)
      if players[pindex].crafting_queue.index < 2 then
         players[pindex].crafting_queue.index = players[pindex].crafting_queue.max
      else
         players[pindex].crafting_queue.index = players[pindex].crafting_queue.index - 1
      end
      fa_crafting.read_crafting_queue(pindex)
   elseif players[pindex].menu == "building" or players[pindex].menu == "vehicle" then
      --Move along a row in a building inventory
      if players[pindex].building.sector <= #players[pindex].building.sectors then
         --Most building sectors, e.g. chest rows
         if
            players[pindex].building.sectors[players[pindex].building.sector].inventory == nil
            or #players[pindex].building.sectors[players[pindex].building.sector].inventory < 1
         then
            printout("blank sector", pindex)
            return
         end
         game.get_player(pindex).play_sound({ path = "Inventory-Move" })
         local row_length = players[pindex].preferences.building_inventory_row_length
         if #players[pindex].building.sectors[players[pindex].building.sector].inventory > row_length then
            players[pindex].building.index = players[pindex].building.index - 1
            if players[pindex].building.index % row_length < 1 then
               --Wrap around to the end of this row
               game.get_player(pindex).play_sound({ path = "inventory-wrap-around" })
               players[pindex].building.index = players[pindex].building.index + row_length
               if
                  players[pindex].building.index
                  > #players[pindex].building.sectors[players[pindex].building.sector].inventory
               then
                  --If this final row is short, just jump to the end of the inventory
                  players[pindex].building.index =
                     #players[pindex].building.sectors[players[pindex].building.sector].inventory
               end
            end
         else
            players[pindex].building.index = players[pindex].building.index - 1
            if players[pindex].building.index < 1 then
               --Wrap around to the end of this single-row inventory
               game.get_player(pindex).play_sound({ path = "inventory-wrap-around" })
               players[pindex].building.index =
                  #players[pindex].building.sectors[players[pindex].building.sector].inventory
            end
         end
         fa_sectors.read_sector_slot(pindex, false)
      elseif players[pindex].building.recipe_list == nil then
         game.get_player(pindex).play_sound({ path = "Inventory-Move" })
         players[pindex].inventory.index = players[pindex].inventory.index - 1
         if players[pindex].inventory.index % 10 < 1 then
            players[pindex].inventory.index = players[pindex].inventory.index + 10
         end
         read_inventory_slot(pindex)
      else
         if players[pindex].building.sector == #players[pindex].building.sectors + 1 then
            --Recipe selection
            if players[pindex].building.recipe_selection then
               game.get_player(pindex).play_sound({ path = "Inventory-Move" })
               players[pindex].building.index = players[pindex].building.index - 1
               if players[pindex].building.index < 1 then
                  players[pindex].building.index =
                     #players[pindex].building.recipe_list[players[pindex].building.category]
               end
            end
            fa_sectors.read_building_recipe(pindex)
         else
            --Case ???
            game.get_player(pindex).play_sound({ path = "Inventory-Move" })
            players[pindex].inventory.index = players[pindex].inventory.index - 1
            if players[pindex].inventory.index % 10 < 1 then
               players[pindex].inventory.index = players[pindex].inventory.index + 10
            end
            read_inventory_slot(pindex)
         end
      end
   elseif players[pindex].menu == "technology" then
      if players[pindex].technology.index > 1 then
         players[pindex].technology.index = players[pindex].technology.index - 1
         game.get_player(pindex).play_sound({ path = "Inventory-Move" })
      end
      read_technology_slot(pindex)
   elseif players[pindex].menu == "belt" then
      if players[pindex].belt.side == 2 then
         players[pindex].belt.side = 1
         game.get_player(pindex).play_sound({ path = "Inventory-Move" })
         if not pcall(function()
            fa_belts.read_belt_slot(pindex)
         end) then
            printout("Blank", pindex)
         end
      end
   elseif players[pindex].menu == "warnings" then
      if players[pindex].warnings.index > 1 then
         players[pindex].warnings.index = players[pindex].warnings.index - 1
         game.get_player(pindex).play_sound({ path = "Inventory-Move" })
      end
      fa_warnings.read_warnings_slot(pindex)
   elseif players[pindex].menu == "travel" then
      fa_travel.fast_travel_menu_left(pindex)
   elseif players[pindex].menu == "structure-travel" then
      fa_travel.move_cursor_structure(pindex, 6)
   elseif players[pindex].menu == "signal_selector" then
      fa_circuits.signal_selector_signal_prev(pindex)
      fa_circuits.read_selected_signal_slot(pindex, "")
   end
end

----Moves to the right  in a menu. Todo: split by menu. "menu_right"
function menu_cursor_right(pindex)
   if players[pindex].item_selection then
      players[pindex].item_selector.index =
         math.min(#players[pindex].item_cache, players[pindex].item_selector.index + 1)
      read_item_selector_slot(pindex)
   elseif players[pindex].menu == "inventory" then
      players[pindex].inventory.index = players[pindex].inventory.index + 1
      if players[pindex].inventory.index % 10 == 1 then
         if players[pindex].preferences.inventory_wraps_around == true then
            --Wrap around setting: Move and play move sound and read slot
            players[pindex].inventory.index = players[pindex].inventory.index - 10
            game.get_player(pindex).play_sound({ path = "inventory-wrap-around" })
            read_inventory_slot(pindex)
         else
            --Border setting: Undo change and play "wall" sound
            players[pindex].inventory.index = players[pindex].inventory.index - 1
            game.get_player(pindex).play_sound({ path = "inventory-edge" })
            --printout("Border.", pindex)
         end
      else
         game.get_player(pindex).play_sound({ path = "Inventory-Move" })
         read_inventory_slot(pindex)
      end
   elseif players[pindex].menu == "player_trash" then
      local trash_inv = game.get_player(pindex).get_inventory(defines.inventory.character_trash)
      players[pindex].inventory.index = players[pindex].inventory.index + 1
      if players[pindex].inventory.index % 10 == 1 then
         if players[pindex].preferences.inventory_wraps_around == true then
            --Wrap around setting: Move and play move sound and read slot
            players[pindex].inventory.index = players[pindex].inventory.index - 10
            game.get_player(pindex).play_sound({ path = "inventory-wrap-around" })
            read_inventory_slot(pindex, "", trash_inv)
         else
            --Border setting: Undo change and play "wall" sound
            players[pindex].inventory.index = players[pindex].inventory.index - 1
            game.get_player(pindex).play_sound({ path = "inventory-edge" })
            --printout("Border.", pindex)
         end
      else
         game.get_player(pindex).play_sound({ path = "Inventory-Move" })
         read_inventory_slot(pindex, "", trash_inv)
      end
   elseif players[pindex].menu == "crafting" then
      game.get_player(pindex).play_sound({ path = "Inventory-Move" })
      players[pindex].crafting.index = players[pindex].crafting.index + 1
      if players[pindex].crafting.index > #players[pindex].crafting.lua_recipes[players[pindex].crafting.category] then
         players[pindex].crafting.index = 1
      end
      fa_crafting.read_crafting_slot(pindex)
   elseif players[pindex].menu == "crafting_queue" then
      game.get_player(pindex).play_sound({ path = "Inventory-Move" })
      fa_crafting.load_crafting_queue(pindex)
      if players[pindex].crafting_queue.index >= players[pindex].crafting_queue.max then
         players[pindex].crafting_queue.index = 1
      else
         players[pindex].crafting_queue.index = players[pindex].crafting_queue.index + 1
      end
      fa_crafting.read_crafting_queue(pindex)
   elseif players[pindex].menu == "building" or players[pindex].menu == "vehicle" then
      --Move along a row in a building inventory
      if players[pindex].building.sector <= #players[pindex].building.sectors then
         --Most building sectors, e.g. chest inventories
         if
            players[pindex].building.sectors[players[pindex].building.sector].inventory == nil
            or #players[pindex].building.sectors[players[pindex].building.sector].inventory < 1
         then
            printout("blank sector", pindex)
            return
         end
         game.get_player(pindex).play_sound({ path = "Inventory-Move" })
         local row_length = players[pindex].preferences.building_inventory_row_length
         if #players[pindex].building.sectors[players[pindex].building.sector].inventory > row_length then
            players[pindex].building.index = players[pindex].building.index + 1
            if players[pindex].building.index % row_length == 1 then
               --Wrap back around to the start of this row
               game.get_player(pindex).play_sound({ path = "inventory-wrap-around" })
               players[pindex].building.index = players[pindex].building.index - row_length
            end
         else
            players[pindex].building.index = players[pindex].building.index + 1
            if
               players[pindex].building.index
               > #players[pindex].building.sectors[players[pindex].building.sector].inventory
            then
               --Wrap around to the start of the single-row inventory
               game.get_player(pindex).play_sound({ path = "inventory-wrap-around" })
               players[pindex].building.index = 1
            end
         end
         fa_sectors.read_sector_slot(pindex, false)
      elseif players[pindex].building.recipe_list == nil then
         game.get_player(pindex).play_sound({ path = "Inventory-Move" })
         players[pindex].inventory.index = players[pindex].inventory.index + 1
         if players[pindex].inventory.index % 10 == 1 then
            players[pindex].inventory.index = players[pindex].inventory.index - 10
         end
         read_inventory_slot(pindex)
      else
         if players[pindex].building.sector == #players[pindex].building.sectors + 1 then
            --Recipe selection
            if players[pindex].building.recipe_selection then
               game.get_player(pindex).play_sound({ path = "Inventory-Move" })

               players[pindex].building.index = players[pindex].building.index + 1
               if
                  players[pindex].building.index
                  > #players[pindex].building.recipe_list[players[pindex].building.category]
               then
                  players[pindex].building.index = 1
               end
            end
            fa_sectors.read_building_recipe(pindex)
         else
            --Case = ???
            game.get_player(pindex).play_sound({ path = "Inventory-Move" })
            players[pindex].inventory.index = players[pindex].inventory.index + 1
            if players[pindex].inventory.index % 10 == 1 then
               players[pindex].inventory.index = players[pindex].inventory.index - 10
            end
            read_inventory_slot(pindex)
         end
      end
   elseif players[pindex].menu == "technology" then
      local techs = {}
      if players[pindex].technology.category == 1 then
         techs = players[pindex].technology.lua_researchable
      elseif players[pindex].technology.category == 2 then
         techs = players[pindex].technology.lua_locked
      elseif players[pindex].technology.category == 3 then
         techs = players[pindex].technology.lua_unlocked
      end
      if players[pindex].technology.index < #techs then
         game.get_player(pindex).play_sound({ path = "Inventory-Move" })
         players[pindex].technology.index = players[pindex].technology.index + 1
      end
      read_technology_slot(pindex)
   elseif players[pindex].menu == "belt" then
      if players[pindex].belt.side == 1 then
         players[pindex].belt.side = 2
         game.get_player(pindex).play_sound({ path = "Inventory-Move" })
         if not pcall(function()
            fa_belts.read_belt_slot(pindex)
         end) then
            printout("Blank", pindex)
         end
      end
   elseif players[pindex].menu == "warnings" then
      local warnings = {}
      if players[pindex].warnings.sector == 1 then
         warnings = players[pindex].warnings.short.warnings
      elseif players[pindex].warnings.sector == 2 then
         warnings = players[pindex].warnings.medium.warnings
      elseif players[pindex].warnings.sector == 3 then
         warnings = players[pindex].warnings.long.warnings
      end
      if warnings[players[pindex].warnings.category] ~= nil then
         local ents = warnings[players[pindex].warnings.category].ents
         if players[pindex].warnings.index < #ents then
            players[pindex].warnings.index = players[pindex].warnings.index + 1
            game.get_player(pindex).play_sound({ path = "Inventory-Move" })
         end
      end
      fa_warnings.read_warnings_slot(pindex)
   elseif players[pindex].menu == "travel" then
      fa_travel.fast_travel_menu_right(pindex)
   elseif players[pindex].menu == "structure-travel" then
      fa_travel.move_cursor_structure(pindex, 2)
   elseif players[pindex].menu == "signal_selector" then
      fa_circuits.signal_selector_signal_next(pindex)
      fa_circuits.read_selected_signal_slot(pindex, "")
   end
end

--Schedules a function to be called after a certain number of ticks.
function schedule(ticks_in_the_future, func_to_call, data_to_pass_1, data_to_pass_2, data_to_pass_3)
   if type(_G[func_to_call]) ~= "function" then error(func_to_call .. " is not a function") end
   if ticks_in_the_future <= 0 then
      _G[func_to_call](data_to_pass_1, data_to_pass_2, data_to_pass_3)
      return
   end
   local tick = game.tick + ticks_in_the_future
   local schedule = global.scheduled_events
   schedule[tick] = schedule[tick] or {}
   table.insert(schedule[tick], { func_to_call, data_to_pass_1, data_to_pass_2, data_to_pass_3 })
end

--Handles a player joining into a game session.
function on_player_join(pindex)
   players = players or global.players
   schedule(3, "call_to_fix_zoom", pindex)
   schedule(4, "call_to_sync_graphics", pindex)
   fa_localising.check_player(pindex)
   local playerList = {}
   for _, p in pairs(game.connected_players) do
      playerList["_" .. p.index] = p.name
   end
   print("playerList " .. game.table_to_json(playerList))
   if game.players[pindex].name == "Crimso" then
      --Debug stuff
      local player = game.get_player(pindex).cutscene_character or game.get_player(pindex).character
      player.force.research_all_technologies()

      --game.write_file('map.txt', game.table_to_json(game.parse_map_exchange_string(">>>eNpjZGBksGUAgwZ7EOZgSc5PzIHxgNiBKzm/oCC1SDe/KBVZmDO5qDQlVTc/E1Vxal5qbqVuUmIxsmJ7jsyi/Dx0E1iLS/LzUEVKilJTi5E1cpcWJeZlluai62VgnPIl9HFDixwDCP+vZ1D4/x+EgawHQL+AMANjA0glIyNQDAZYk3My09IYGBQcGRgKnFev0rJjZGSsFlnn/rBqij0jRI2eA5TxASpyIAkm4glj+DnglFKBMUyQzDEGg89IDIilJUAroKo4HBAMiGQLSJKREeZ2xl91WXtKJlfYM3qs3zPr0/UqO6A0O0iCCU7MmgkCO2FeYYCZ+cAeKnXTnvHsGRB4Y8/ICtIhAiIcLIDEAW9mBkYBPiBrQQ+QUJBhgDnNDmaMiANjGhh8g/nkMYxx2R7dH8CAsAEZLgciToAIsIVwl0F95tDvwOggD5OVRCgB6jdiQHZDCsKHJ2HWHkayH80hmBGB7A80ERUHLNHABbIwBU68YIa7BhieF9hhPIf5DozMIAZI1RegGIQHkoEZBaEFHMDBzcyAAMC0cepk2C4A0ySfhQ==<<<")))
      player.insert({ name = "pipe", count = 100 })

      for i = 0, 10 do
         for j = 0, 10 do
            player.surface.create_entity({ name = "iron-ore", position = { i + 0.5, j + 0.5 } })
         end
      end
      --   player.force.research_all_technologies()
   end

   --Reset the player building direction to match the vanilla behavior.
   players[pindex].building_direction = dirs.north --
end

script.on_event(defines.events.on_player_joined_game, function(event)
   if game.is_multiplayer() then on_player_join(event.player_index) end
end)

function on_initial_joining_tick(event)
   if not game.is_multiplayer() then on_player_join(game.connected_players[1].index) end
   on_tick(event)
   script.on_event(defines.events.on_tick, on_tick)
end

--Called every tick. Used to call scheduled and repeated functions.
function on_tick(event)
   if global.scheduled_events[event.tick] then
      for _, to_call in pairs(global.scheduled_events[event.tick]) do
         _G[to_call[1]](to_call[2], to_call[3], to_call[4])
      end
      global.scheduled_events[event.tick] = nil
   end
   move_characters(event)

   --The elseifs can schedule up to 16 events.
   if event.tick % 15 == 0 then
      for pindex, player in pairs(players) do
         --Bump checks
         check_and_play_bump_alert_sound(pindex, event.tick)
         check_and_play_stuck_alert_sound(pindex, event.tick)
      end
   elseif event.tick % 15 == 1 then
      --Check and play train track warning sounds at appropriate frequencies
      fa_rails.check_and_play_train_track_alert_sounds(3)
      fa_combat.check_and_play_enemy_alert_sound(3)
      if event.tick % 30 == 1 then
         fa_rails.check_and_play_train_track_alert_sounds(2)
         fa_combat.check_and_play_enemy_alert_sound(2)
         if event.tick % 60 == 1 then
            fa_rails.check_and_play_train_track_alert_sounds(1)
            fa_combat.check_and_play_enemy_alert_sound(1)
         end
      end
   elseif event.tick % 15 == 2 then
      for pindex, player in pairs(players) do
         local check_further = fa_driving.check_and_play_driving_alert_sound(pindex, event.tick, 1)
         if event.tick % 30 == 2 and check_further then
            check_further = fa_driving.check_and_play_driving_alert_sound(pindex, event.tick, 2)
            if event.tick % 60 == 2 and check_further then
               check_further = fa_driving.check_and_play_driving_alert_sound(pindex, event.tick, 3)
               if event.tick % 120 == 2 and check_further then
                  check_further = fa_driving.check_and_play_driving_alert_sound(pindex, event.tick, 4)
               end
            end
         end
      end
   elseif event.tick % 15 == 3 then
      --Adjust camera if in remote view
      for pindex, player in pairs(players) do
         players[pindex].closed_map_count = players[pindex].closed_map_count or 0
         if players[pindex].remote_view == true then
            sync_remote_view(pindex)
            players[pindex].closed_map_count = 0
         elseif players[pindex].vanilla_mode ~= true and players[pindex].closed_map_count < 1 then
            game.get_player(pindex).close_map()
            players[pindex].closed_map_count = players[pindex].closed_map_count + 1
         end
      end
   elseif event.tick % 30 == 6 then
      --Check and play train horns
      for pindex, player in pairs(players) do
         fa_trains.check_and_honk_at_trains_in_same_block(event.tick, pindex)
         fa_trains.check_and_honk_at_closed_signal(event.tick, pindex)
         fa_trains.check_and_play_sound_for_turning_trains(pindex)
      end
   elseif event.tick % 30 == 7 then
      --Update menu visuals
      fa_graphics.update_menu_visuals()
   elseif event.tick % 30 == 8 then
      --Play a sound for any player who is mining
      for pindex, player in pairs(players) do
         if game.get_player(pindex) ~= nil and game.get_player(pindex).mining_state.mining == true then
            fa_mining_tools.play_mining_sound(pindex)
         end
      end
   elseif event.tick % 60 == 11 then
      for pindex, player in pairs(players) do
         --If within 50 tiles of an enemy, try to aim at enemies and play sound to notify of enemies within shooting range
         local p = game.get_player(pindex)
         local enemy = p.surface.find_nearest_enemy({ position = p.position, max_distance = 50, force = p.force })
         if enemy ~= nil and enemy.valid then fa_combat.aim_gun_at_nearest_enemy(pindex, enemy) end

         --If crafting, play a sound
         if p.character and p.crafting_queue ~= nil and #p.crafting_queue > 0 and p.crafting_queue_size > 0 then
            p.play_sound({ path = "player-crafting", volume_modifier = 0.5 })
         end
      end
   elseif event.tick % 90 == 13 then
      for pindex, player in pairs(players) do
         --Fix running speed bug (toggle walk also fixes it)
         fix_walk(pindex)

         --Update the Kruise Kontrol status
         fa_kk.status_update(pindex)
      end
   elseif event.tick % 450 == 14 then
      --Run regular reminders every 7.5 seconds
      for pindex, player in pairs(players) do
         --Tutorial reminder every 10 seconds until you open it
         if players[pindex].started ~= true then
            printout("Press 'TAB' to begin", pindex)
         elseif players[pindex].tutorial == nil then
            printout("Press 'H' to open the tutorial", pindex)
         elseif game.get_player(pindex).ticks_to_respawn ~= nil then
            printout(math.floor(game.get_player(pindex).ticks_to_respawn / 60) .. " seconds until respawn", pindex)
         elseif players[pindex].kruise_kontrolling == true then
            --Report the KK state
            fa_kk.status_read(pindex, false)
         end
      end
   end
end

script.on_event(defines.events.on_tick, on_initial_joining_tick)

--Called for every player on every tick, to manage automatic walking and enforcing mouse pointer position syncs.
--Todo: create a new function for all mouse pointer related updates within this function
function move_characters(event)
   for pindex, player in pairs(players) do
      if player.vanilla_mode == true then
         player.player.game_view_settings.update_entity_selection = true
      elseif player.player.game_view_settings.update_entity_selection == false then
         --Force the mouse pointer to the mod cursor if there is an item in hand
         --(so that the game does not make a mess when you left click while the cursor is actually locked)
         local stack = game.get_player(pindex).cursor_stack
         if players[pindex].in_menu == false and stack and stack.valid_for_read then
            if
               stack.prototype.place_result ~= nil
               or stack.prototype.place_as_tile_result ~= nil
               or stack.is_blueprint
               or stack.is_deconstruction_item
               or stack.is_upgrade_item
            then
               --Force the pointer to the build preview location
               fa_graphics.sync_build_cursor_graphics(pindex)
            else
               --Force the pointer to the cursor location (if on screen)
               if fa_mouse.cursor_position_is_on_screen_with_player_centered(pindex) then
                  fa_mouse.move_mouse_pointer(players[pindex].cursor_pos, pindex)
               else
                  fa_mouse.move_mouse_pointer(players[pindex].position, pindex)
               end
            end
         end
      end

      if player.walk ~= 2 or player.cursor or player.in_menu then
         local walk = false
         while #player.move_queue > 0 do
            local next_move = player.move_queue[1]
            player.player.walking_state = { walking = true, direction = next_move.direction }
            if next_move.direction == defines.direction.north then
               walk = player.player.position.y > next_move.dest.y
            elseif next_move.direction == defines.direction.south then
               walk = player.player.position.y < next_move.dest.y
            elseif next_move.direction == defines.direction.east then
               walk = player.player.position.x < next_move.dest.x
            elseif next_move.direction == defines.direction.west then
               walk = player.player.position.x > next_move.dest.x
            end

            if walk then
               break
            else
               table.remove(player.move_queue, 1)
            end
         end
         if not walk and players[pindex].kruise_kontrolling ~= true then
            player.player.walking_state = { walking = true, direction = player.player_direction }
            player.player.walking_state = { walking = false }
         end
      end
   end
end

--Move player character (and adapt the cursor to smooth walking)
function move(direction, pindex)
   local p = game.get_player(pindex)
   if p.driving then return end
   local first_player = game.get_player(pindex)
   local pos = players[pindex].position
   local new_pos = fa_utils.offset_position(pos, direction, 1)

   --Compare the input direction and facing direction
   if players[pindex].player_direction == direction then
      --Same direction: Move character:
      if players[pindex].walk == 2 then return end
      new_pos = fa_utils.center_of_tile(new_pos)
      can_port = first_player.surface.can_place_entity({ name = "character", position = new_pos })
      if can_port then
         if players[pindex].walk == 1 then
            table.insert(players[pindex].move_queue, { direction = direction, dest = new_pos })
         else
            teleported = first_player.teleport(new_pos)
            if not teleported then printout("Teleport Failed", pindex) end
         end
         players[pindex].position = new_pos
         players[pindex].cursor_pos = fa_utils.offset_position(players[pindex].position, direction, 1)
         --Telestep walking sounds
         if
            players[pindex].tile.previous ~= nil
            and players[pindex].tile.previous.valid
            and players[pindex].tile.previous.type == "transport-belt"
         then
            game.get_player(pindex).play_sound({ path = "utility/metal_walking_sound", volume_modifier = 1 })
         else
            local tile = game.get_player(pindex).surface.get_tile(new_pos.x, new_pos.y)
            local sound_path = "tile-walking/" .. tile.name
            if game.is_valid_sound_path(sound_path) and players[pindex].in_menu == false then
               game.get_player(pindex).play_sound({ path = "tile-walking/" .. tile.name, volume_modifier = 1 })
            elseif players[pindex].in_menu == false then
               game.get_player(pindex).play_sound({ path = "player-walk", volume_modifier = 1 })
            end
         end
         if not game.get_player(pindex).driving then read_tile(pindex) end

         local stack = first_player.cursor_stack
         if stack and stack.valid_for_read and stack.valid and stack.prototype.place_result ~= nil then
            fa_graphics.sync_build_cursor_graphics(pindex)
         end

         if players[pindex].build_lock then fa_building_tools.build_item_in_hand(pindex) end
      else
         printout("Tile Occupied", pindex)
      end
   else
      --New direction: Turn character: --turn
      if players[pindex].walk == 0 then
         new_pos = fa_utils.center_of_tile(new_pos)
         game.get_player(pindex).play_sound({ path = "player-turned" })
      elseif players[pindex].walk == 1 then
         new_pos = fa_utils.center_of_tile(new_pos)
         table.insert(players[pindex].move_queue, { direction = direction, dest = pos })
      end
      players[pindex].player_direction = direction
      players[pindex].cursor_pos = new_pos

      local stack = first_player.cursor_stack
      if stack and stack.valid_for_read and stack.valid and stack.prototype.place_result ~= nil then
         fa_graphics.sync_build_cursor_graphics(pindex)
      end

      if game.get_player(pindex).driving then
         target(pindex)
         return
      end

      if players[pindex].walk ~= 2 then
         read_tile(pindex)
      elseif players[pindex].walk == 2 then
         refresh_player_tile(pindex)
         local ent = get_selected_ent(pindex)
         if
            not players[pindex].vanilla_mode
            and (
               (ent ~= nil and ent.valid)
               or not game
                  .get_player(pindex).surface
                  .can_place_entity({ name = "character", position = players[pindex].cursor_pos })
            )
         then
            target(pindex)
            read_tile(pindex)
         end
      end

      --Rotate belts in hand for build lock Mode
      local stack = game.get_player(pindex).cursor_stack
      if
         players[pindex].build_lock
         and stack.valid_for_read
         and stack.valid
         and stack.prototype.place_result ~= nil
         and stack.prototype.place_result.type == "transport-belt"
      then
         players[pindex].building_direction = players[pindex].player_direction
      end
   end

   --Update cursor highlight
   local ent = get_selected_ent(pindex)
   if ent and ent.valid then
      fa_graphics.draw_cursor_highlight(pindex, ent, nil)
   else
      fa_graphics.draw_cursor_highlight(pindex, nil, nil)
   end

   --Unless the cut-paste tool is in hand, restore the reading of flying text
   local stack = game.get_player(pindex).cursor_stack
   if not (stack and stack.valid_for_read and stack.name == "cut-paste-tool") then
      players[pindex].allow_reading_flying_text = true
   end
end

--Chooses the function to call after a movement keypress, according to the current mode.
function move_key(direction, event, force_single_tile)
   local pindex = event.player_index
   local p = game.get_player(pindex)
   if not check_for_player(pindex) or players[pindex].menu == "prompt" then return end
   --Stop any enabled mouse entity selection
   if players[pindex].vanilla_mode ~= true then
      game.get_player(pindex).game_view_settings.update_entity_selection = false
   end

   --Save the key press event
   local pex = players[event.player_index]
   pex.bump.last_dir_key_2nd = pex.bump.last_dir_key_1st
   pex.bump.last_dir_key_1st = direction
   pex.bump.last_dir_key_tick = event.tick

   if players[pindex].in_menu and players[pindex].menu ~= "prompt" then
      -- Menus: move menu cursor
      menu_cursor_move(direction, pindex)
   elseif players[pindex].cursor then
      -- Cursor mode: Move cursor on map
      cursor_mode_move(direction, pindex, force_single_tile)
   else
      -- General case: Move character
      move(direction, pindex)
   end

   --Play a sound to indicate ongoing selection
   if pex.bp_selecting then game.get_player(pindex).play_sound({ path = "utility/upgrade_selection_started" }) end

   --Play a sound to indicate ongoing ghost rail planner
   if pex.ghost_rail_planning then
      game.get_player(pindex).play_sound({ path = "utility/upgrade_selection_started" })
   end

   --If driving a spidertron in telestep mode, suggest using smooth walking
   if p.vehicle and p.vehicle.type == "spider-vehicle" and players[pindex].walk ~= 2 then
      printout("To walk the spidertron, enable smooth walking mode", pindex)
   end
end

--Moves the cursor, and conducts an area scan for larger cursors. If the player is in a slow moving vehicle, it is stopped.
function cursor_mode_move(direction, pindex, single_only)
   local diff = players[pindex].cursor_size * 2 + 1
   if single_only then diff = 1 end
   local p = game.get_player(pindex)

   if p.driving and p.vehicle and (p.vehicle.type == "car" or p.vehicle.type == "locomotive") then
      if math.abs(p.vehicle.speed * 215) < 25 then
         fa_driving.stop_vehicle(pindex)
         p.vehicle.active = false
      end
   end

   players[pindex].cursor_pos =
      fa_utils.center_of_tile(fa_utils.offset_position(players[pindex].cursor_pos, direction, diff))

   if players[pindex].cursor_size == 0 then
      -- Cursor size 0 ("1 by 1"): Read tile
      read_tile(pindex)

      --Update drawn cursor
      local stack = p.cursor_stack
      if
         stack
         and stack.valid_for_read
         and stack.valid
         and (stack.prototype.place_result ~= nil or stack.is_blueprint)
      then
         fa_graphics.sync_build_cursor_graphics(pindex)
      end

      --Apply build lock if active
      if players[pindex].build_lock then fa_building_tools.build_item_in_hand(pindex) end

      --Update cursor highlight
      local ent = get_selected_ent(pindex)
      if ent and ent.valid then
         fa_graphics.draw_cursor_highlight(pindex, ent, nil)
      else
         fa_graphics.draw_cursor_highlight(pindex, nil, nil)
      end
   else
      -- Larger cursor sizes: scan area
      local scan_left_top = {
         math.floor(players[pindex].cursor_pos.x) - players[pindex].cursor_size,
         math.floor(players[pindex].cursor_pos.y) - players[pindex].cursor_size,
      }
      local scan_right_bottom = {
         math.floor(players[pindex].cursor_pos.x) + players[pindex].cursor_size + 1,
         math.floor(players[pindex].cursor_pos.y) + players[pindex].cursor_size + 1,
      }
      players[pindex].nearby.index = 1
      players[pindex].nearby.ents = fa_scanner.scan_area(
         math.floor(players[pindex].cursor_pos.x) - players[pindex].cursor_size,
         math.floor(players[pindex].cursor_pos.y) - players[pindex].cursor_size,
         players[pindex].cursor_size * 2 + 1,
         players[pindex].cursor_size * 2 + 1,
         pindex
      )
      fa_scanner.populate_list_categories(pindex)
      players[pindex].cursor_scan_center = players[pindex].cursor_pos
      local scan_summary = fa_scanner.area_scan_summary_info(scan_left_top, scan_right_bottom, pindex)
      fa_graphics.draw_large_cursor(scan_left_top, scan_right_bottom, pindex)
      printout(scan_summary, pindex)
   end

   --Update player direction to face the cursor (after the vanilla move event that turns the character too, and only ends when the movement key is released)
   turn_to_cursor_direction_precise(pindex)

   --Play Sound
   if players[pindex].remote_view then
      p.play_sound({ path = "Close-Inventory-Sound", position = players[pindex].cursor_pos, volume_modifier = 0.75 })
   else
      p.play_sound({ path = "Close-Inventory-Sound", position = players[pindex].position, volume_modifier = 0.75 })
   end
end

--Focuses camera on the cursor position.
function sync_remote_view(pindex)
   local p = game.get_player(pindex)
   p.zoom_to_world(players[pindex].cursor_pos)
   fa_graphics.sync_build_cursor_graphics(pindex)
end

--Makes the character face the cursor, choosing the nearest of 4 cardinal directions. Can be overwriten by vanilla move keys.
function turn_to_cursor_direction_cardinal(pindex)
   local p = game.get_player(pindex)
   if p.character == nil then return end
   local pex = players[pindex]
   local dir = fa_utils.get_direction_precise(pex.cursor_pos, p.position)
   if dir == dirs.northwest or dir == dirs.north or dir == dirs.northeast then
      p.character.direction = dirs.north
      pex.player_direction = dirs.north
   elseif dir == dirs.southwest or dir == dirs.south or dir == dirs.southeast then
      p.character.direction = dirs.south
      pex.player_direction = dirs.south
   else
      --p.character.direction = dir
      pex.player_direction = dir
   end
   --game.print("set cardinal pindex_dir: " .. direction_lookup(pex.player_direction))--
   --game.print("set cardinal charct_dir: " .. direction_lookup(p.character.direction))--
end

--Makes the character face the cursor, choosing the nearest of 8 directions. Can be overwriten by vanilla move keys.
function turn_to_cursor_direction_precise(pindex)
   local p = game.get_player(pindex)
   if p.character == nil then return end
   local pex = players[pindex]
   local dir = fa_utils.get_direction_precise(pex.cursor_pos, p.position)
   pex.player_direction = dir
   --game.print("set precise pindex_dir: " .. direction_lookup(pex.player_direction))--
   --game.print("set precise charct_dir: " .. direction_lookup(p.character.direction))--
end

--Called when a player enters or exits a vehicle
script.on_event(defines.events.on_player_driving_changed_state, function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   reset_bump_stats(pindex)
   game.get_player(pindex).clear_cursor()
   players[pindex].last_train_orientation = nil
   if game.get_player(pindex).driving then
      players[pindex].last_vehicle = game.get_player(pindex).vehicle
      printout("Entered " .. game.get_player(pindex).vehicle.name, pindex)
      if players[pindex].last_vehicle.train ~= nil and players[pindex].last_vehicle.train.schedule == nil then
         players[pindex].last_vehicle.train.manual_mode = true
      end
   elseif players[pindex].last_vehicle ~= nil then
      printout("Exited " .. players[pindex].last_vehicle.name, pindex)
      if players[pindex].last_vehicle.train ~= nil and players[pindex].last_vehicle.train.schedule == nil then
         players[pindex].last_vehicle.train.manual_mode = true
      end
      fa_teleport.teleport_to_closest(pindex, players[pindex].last_vehicle.position, true, true)
      if players[pindex].menu == "train_menu" then fa_trains.menu_close(pindex, false) end
      if players[pindex].menu == "spider_menu" then fa_spidertrons.spider_menu_close(pindex, false) end
   else
      printout("Driving state changed.", pindex)
   end
end)

--Pause / resume the game. If a menu GUI is open, ESC makes it close the menu instead
script.on_event("pause-game-fa", function(event)
   local pindex = event.player_index
   game.get_player(pindex).close_map()
   game.get_player(pindex).play_sound({ path = "Close-Inventory-Sound" })
   if players[pindex].remote_view == true then
      toggle_remote_view(pindex, false, true)
      printout("Remote view closed", pindex)
   end
   if game.tick_paused == true then
      for pindex, player in pairs(players) do
         --printout("Game paused", pindex)--does not call because these handlers appear to require ticks running?**
      end
   else
      for pindex, player in pairs(players) do
         if game.get_player(pindex).opened ~= nil then
            printout("Menu closed", pindex)
         else
            --printout("Game resumed", pindex)--This is always incorrect cos this event fires before the pause happens.
         end
      end
   end

   --Close any open screens
   for i, elem in ipairs(fa_utils.get_iterable_array(game.get_player(pindex).gui.children)) do
      if elem.get_mod() == "FactorioAccess" or elem.get_mod() == nil then
         elem.clear()
         close_menu_resets(pindex)
      end
   end
end)

script.on_event("cursor-up", function(event)
   if ui.evt_up(event.player_index) then return end

   move_key(defines.direction.north, event)
end)

script.on_event("cursor-down", function(event)
   if ui.evt_down(event.player_index) then return end

   move_key(defines.direction.south, event)
end)

script.on_event("cursor-left", function(event)
   if ui.evt_left(event.player_index) then return end

   move_key(defines.direction.west, event)
end)

script.on_event("cursor-right", function(event)
   if ui.evt_right(event.player_index) then return end

   move_key(defines.direction.east, event)
end)

--Read coordinates of the cursor. Extra info as well such as entity part if an entity is selected, and heading and speed info for vehicles.
script.on_event("read-cursor-coords", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   read_coords(pindex)
end)

--Get distance and direction of cursor from player.
script.on_event("read-cursor-distance-and-direction", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   if players[pindex].menu == "crafting" then
      --Read recipe ingredients / products (crafting menu)
      local recipe =
         players[pindex].crafting.lua_recipes[players[pindex].crafting.category][players[pindex].crafting.index]
      local result = fa_crafting.recipe_raw_ingredients_info(recipe, pindex)
      --game.get_player(pindex).print(recipe.name)--**
      --game.get_player(pindex).print(result)--**
      printout(result, pindex)
   else
      --Read where the cursor is with respect to the player, e.g. "at 5 west"
      local dir_dist = fa_utils.dir_dist_locale(players[pindex].position, players[pindex].cursor_pos)
      local cursor_location_description = "At"
      local cursor_production = " "
      local cursor_description_of = " "
      local result = { "access.thing-producing-listpos-dirdist", cursor_location_description }
      table.insert(result, cursor_production) --no production
      table.insert(result, cursor_description_of) --listpos
      table.insert(result, dir_dist)
      printout(result, pindex)
      game.get_player(pindex).print(result, { volume_modifier = 0 })
      rendering.draw_circle({
         color = { 1, 0.2, 0 },
         radius = 0.1,
         width = 5,
         target = players[pindex].cursor_pos,
         surface = game.get_player(pindex).surface,
         time_to_live = 180,
      })
   end
end)

--Get distance and direction of cursor from player as a vector with a horizontal component and vertical component.
script.on_event("read-cursor-distance-vector", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   if players[pindex].menu ~= "crafting" then
      local c_pos = players[pindex].cursor_pos
      local p_pos = players[pindex].position
      local diff_x = math.floor(c_pos.x) - math.floor(p_pos.x)
      local diff_y = math.floor(c_pos.y) - math.floor(p_pos.y)
      local dir_x = dirs.east
      if diff_x < 0 then dir_x = dirs.west end
      local dir_y = dirs.south
      if diff_y < 0 then dir_y = dirs.north end
      local result = "At "
         .. math.abs(diff_x)
         .. " "
         .. fa_utils.direction_lookup(dir_x)
         .. " and "
         .. math.abs(diff_y)
         .. " "
         .. fa_utils.direction_lookup(dir_y)
      printout(result, pindex)
      game.get_player(pindex).print(result, { volume_modifier = 0 })
      --Show cursor position
      rendering.draw_circle({
         color = { 1, 0.2, 0 },
         radius = 0.1,
         width = 5,
         target = players[pindex].cursor_pos,
         surface = game.get_player(pindex).surface,
         time_to_live = 180,
      })
   end
end)

script.on_event("read-character-coords", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   local pos = game.get_player(pindex).position
   local result = "Character at " .. math.floor(pos.x) .. ", " .. math.floor(pos.y)
   --Report co-ordinates (floored for the readout, extra precision for the console)
   printout(result, pindex)
   game.get_player(pindex).print(
      result .. "\n (" .. math.floor(pos.x * 10) / 10 .. ", " .. math.floor(pos.y * 10) / 10 .. ")",
      { volume_modifier = 0 }
   )
end)

--Returns the cursor to the player position.
script.on_event("return-cursor-to-player", function(event)
   pindex = event.player_index
   return_cursor_to_character(pindex)
end)

script.on_event("cursor-bookmark-save", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   local pos = players[pindex].cursor_pos
   players[pindex].cursor_bookmark = pos
   printout("Saved cursor bookmark at " .. math.floor(pos.x) .. ", " .. math.floor(pos.y), pindex)
   game.get_player(pindex).play_sound({ path = "Close-Inventory-Sound" })
end)

script.on_event("cursor-bookmark-load", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   local pos = players[pindex].cursor_bookmark
   if pos == nil or pos.x == nil or pos.y == nil then return end
   players[pindex].cursor_pos = pos
   fa_graphics.draw_cursor_highlight(pindex, nil, nil)
   fa_graphics.sync_build_cursor_graphics(pindex)
   printout("Loaded cursor bookmark at " .. math.floor(pos.x) .. ", " .. math.floor(pos.y), pindex)
   game.get_player(pindex).play_sound({ path = "Close-Inventory-Sound" })
end)

script.on_event("type-cursor-target", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   type_cursor_position(pindex)
end)

script.on_event("teleport-to-cursor", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   fa_teleport.teleport_to_cursor(pindex, false, false, false)
end)

script.on_event("teleport-to-cursor-forced", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   fa_teleport.teleport_to_cursor(pindex, false, true, false)
end)

script.on_event("teleport-to-alert-forced", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   local alert_pos = players[pindex].last_damage_alert_pos
   if alert_pos == nil then
      printout("No target", pindex)
      return
   end
   players[pindex].cursor_pos = alert_pos
   fa_teleport.teleport_to_cursor(pindex, false, true, true)
   players[pindex].cursor_pos = game.get_player(pindex).position
   players[pindex].position = game.get_player(pindex).position
   players[pindex].last_damage_alert_pos = game.get_player(pindex).position
   fa_graphics.draw_cursor_highlight(pindex, nil, nil)
   fa_graphics.sync_build_cursor_graphics(pindex)
   refresh_player_tile(pindex)
end)

script.on_event("toggle-cursor", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   if not players[pindex].in_menu then
      players[pindex].move_queue = {}
      toggle_cursor_mode(pindex)
   end
end)

script.on_event("toggle-remote-view", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   if not players[pindex].in_menu then
      players[pindex].move_queue = {}
      toggle_remote_view(pindex)
   end
end)

--We have cursor sizes 1,3,5,11,21,51,101,251
script.on_event("cursor-size-increment", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   if not players[pindex].in_menu then
      if players[pindex].cursor_size == 0 then
         players[pindex].cursor_size = 1
      elseif players[pindex].cursor_size == 1 then
         players[pindex].cursor_size = 2
      elseif players[pindex].cursor_size == 2 then
         players[pindex].cursor_size = 5
      elseif players[pindex].cursor_size == 5 then
         players[pindex].cursor_size = 10
      elseif players[pindex].cursor_size == 10 then
         players[pindex].cursor_size = 25
      elseif players[pindex].cursor_size == 25 then
         players[pindex].cursor_size = 50
      elseif players[pindex].cursor_size == 50 then
         players[pindex].cursor_size = 125
      end

      local say_size = players[pindex].cursor_size * 2 + 1
      printout("Cursor size " .. say_size .. " by " .. say_size, pindex)
      local scan_left_top = {
         math.floor(players[pindex].cursor_pos.x) - players[pindex].cursor_size,
         math.floor(players[pindex].cursor_pos.y) - players[pindex].cursor_size,
      }
      local scan_right_bottom = {
         math.floor(players[pindex].cursor_pos.x) + players[pindex].cursor_size + 1,
         math.floor(players[pindex].cursor_pos.y) + players[pindex].cursor_size + 1,
      }
      fa_graphics.draw_large_cursor(scan_left_top, scan_right_bottom, pindex)
   end

   --Play Sound
   game.get_player(pindex).play_sound({ path = "Close-Inventory-Sound", volume_modifier = 0.75 })
end)

--We have cursor sizes 1,3,5,11,21,51,101,251
script.on_event("cursor-size-decrement", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   if not players[pindex].in_menu then
      if players[pindex].cursor_size == 1 then
         players[pindex].cursor_size = 0
      elseif players[pindex].cursor_size == 2 then
         players[pindex].cursor_size = 1
      elseif players[pindex].cursor_size == 5 then
         players[pindex].cursor_size = 2
      elseif players[pindex].cursor_size == 10 then
         players[pindex].cursor_size = 5
      elseif players[pindex].cursor_size == 25 then
         players[pindex].cursor_size = 10
      elseif players[pindex].cursor_size == 50 then
         players[pindex].cursor_size = 25
      elseif players[pindex].cursor_size == 125 then
         players[pindex].cursor_size = 50
      end

      local say_size = players[pindex].cursor_size * 2 + 1
      printout("Cursor size " .. say_size .. " by " .. say_size, pindex)
      local scan_left_top = {
         math.floor(players[pindex].cursor_pos.x) - players[pindex].cursor_size,
         math.floor(players[pindex].cursor_pos.y) - players[pindex].cursor_size,
      }
      local scan_right_bottom = {
         math.floor(players[pindex].cursor_pos.x) + players[pindex].cursor_size + 1,
         math.floor(players[pindex].cursor_pos.y) + players[pindex].cursor_size + 1,
      }
      fa_graphics.draw_large_cursor(scan_left_top, scan_right_bottom, pindex)
   end

   --Play Sound
   game.get_player(pindex).play_sound({ path = "Close-Inventory-Sound", volume_modifier = 0.75 })
end)

script.on_event("increase-inventory-bar-by-1", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   if players[pindex].in_menu and (players[pindex].menu == "building" or players[pindex].menu == "vehicle") then
      --Chest bar setting: Increase
      local ent = get_selected_ent(pindex)
      local result = fa_sectors.add_to_inventory_bar(ent, 1)
      printout(result, pindex)
   end
end)

script.on_event("increase-inventory-bar-by-5", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   if players[pindex].in_menu and (players[pindex].menu == "building" or players[pindex].menu == "vehicle") then
      --Chest bar setting: Increase
      local ent = get_selected_ent(pindex)
      local result = fa_sectors.add_to_inventory_bar(ent, 5)
      printout(result, pindex)
   end
end)

script.on_event("increase-inventory-bar-by-100", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   if players[pindex].in_menu and (players[pindex].menu == "building" or players[pindex].menu == "vehicle") then
      --Chest bar setting: Increase
      local ent = get_selected_ent(pindex)
      local result = fa_sectors.add_to_inventory_bar(ent, 100)
      printout(result, pindex)
   end
end)

script.on_event("decrease-inventory-bar-by-1", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   if players[pindex].in_menu and (players[pindex].menu == "building" or players[pindex].menu == "vehicle") then
      --Chest bar setting: Decrease
      local ent = get_selected_ent(pindex)
      local result = fa_sectors.add_to_inventory_bar(ent, -1)
      printout(result, pindex)
   end
end)

script.on_event("decrease-inventory-bar-by-5", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   if players[pindex].in_menu and (players[pindex].menu == "building" or players[pindex].menu == "vehicle") then
      --Chest bar setting: Decrease
      local ent = get_selected_ent(pindex)
      local result = fa_sectors.add_to_inventory_bar(ent, -5)
      printout(result, pindex)
   end
end)

script.on_event("decrease-inventory-bar-by-100", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   if players[pindex].in_menu and (players[pindex].menu == "building" or players[pindex].menu == "vehicle") then
      --Chest bar setting: Decrease
      local ent = get_selected_ent(pindex)
      local result = fa_sectors.add_to_inventory_bar(ent, -100)
      printout(result, pindex)
   end
end)

script.on_event("increase-train-wait-times-by-5", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   if players[pindex].in_menu and players[pindex].menu == "train_menu" then
      fa_trains.change_instant_schedule_wait_time(5, pindex)
   elseif players[pindex].in_menu and players[pindex].menu == "train_stop_menu" then
      fa_train_stops.nearby_train_schedule_add_to_wait_time(5, pindex)
   end
end)

script.on_event("increase-train-wait-times-by-60", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   if players[pindex].in_menu and players[pindex].menu == "train_menu" then
      fa_trains.change_instant_schedule_wait_time(60, pindex)
   elseif players[pindex].in_menu and players[pindex].menu == "train_stop_menu" then
      fa_train_stops.nearby_train_schedule_add_to_wait_time(60, pindex)
   end
end)

script.on_event("decrease-train-wait-times-by-5", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   if players[pindex].in_menu and players[pindex].menu == "train_menu" then
      fa_trains.change_instant_schedule_wait_time(-5, pindex)
   elseif players[pindex].in_menu and players[pindex].menu == "train_stop_menu" then
      fa_train_stops.nearby_train_schedule_add_to_wait_time(-5, pindex)
   end
end)

script.on_event("decrease-train-wait-times-by-60", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   if players[pindex].in_menu and players[pindex].menu == "train_menu" then
      fa_trains.change_instant_schedule_wait_time(-60, pindex)
   elseif players[pindex].in_menu and players[pindex].menu == "train_stop_menu" then
      fa_train_stops.nearby_train_schedule_add_to_wait_time(-60, pindex)
   end
end)

script.on_event("inserter-hand-stack-size-up", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   local p = game.get_player(pindex)
   if p.opened and p.opened.type == "inserter" then
      local ent = get_selected_ent(pindex)
      if ent.type == "inserter" then
         local result = fa_sectors.inserter_hand_stack_size_up(ent)
         printout(result, pindex)
      end
   end
end)

script.on_event("inserter-hand-stack-size-down", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   local p = game.get_player(pindex)
   if p.opened and p.opened.type == "inserter" then
      local ent = get_selected_ent(pindex)
      if ent.type == "inserter" then
         local result = fa_sectors.inserter_hand_stack_size_down(ent)
         printout(result, pindex)
      end
   end
end)

script.on_event("read-rail-structure-ahead", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   local ent = get_selected_ent(pindex)
   if game.get_player(pindex).driving and game.get_player(pindex).vehicle.train ~= nil then
      fa_trains.train_read_next_rail_entity_ahead(pindex, false)
   elseif ent ~= nil and ent.valid and (ent.name == "straight-rail" or ent.name == "curved-rail") then
      --Report what is along the rail
      fa_rails.rail_read_next_rail_entity_ahead(pindex, ent, true)
   end
end)

script.on_event("read-driving-structure-ahead", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   local p = game.get_player(pindex)
   if p.driving and (p.vehicle.train ~= nil or p.vehicle.type == "car") then
      local ent = players[pindex].last_driving_alert_ent
      if ent and ent.valid then
         local dir = fa_utils.get_heading_value(p.vehicle)
         local dir_ent = fa_utils.get_direction_biased(ent.position, p.vehicle.position)
         if
            p.vehicle.speed >= 0 and (dir_ent == dir or math.abs(dir_ent - dir) == 1 or math.abs(dir_ent - dir) == 7)
         then
            local dist = math.floor(util.distance(p.vehicle.position, ent.position))
            printout(fa_localising.get(ent, pindex) .. " ahead in " .. dist .. " meters", pindex)
         elseif p.vehicle.speed <= 0 and dir_ent == fa_utils.rotate_180(dir) then
            local dist = math.floor(util.distance(p.vehicle.position, ent.position))
            printout(fa_localising.get(ent, pindex) .. " behind in " .. dist .. " meters", pindex)
         end
      end
   end
end)

script.on_event("read-rail-structure-behind", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   local ent = get_selected_ent(pindex)
   if game.get_player(pindex).driving and game.get_player(pindex).vehicle.train ~= nil then
      fa_trains.train_read_next_rail_entity_ahead(pindex, true)
   elseif ent ~= nil and ent.valid and (ent.name == "straight-rail" or ent.name == "curved-rail") then
      --Report what is along the rail
      fa_rails.rail_read_next_rail_entity_ahead(pindex, ent, false)
   end
end)

script.on_event("rescan", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   if not players[pindex].in_menu then
      fa_scanner.run_scanner_effects(pindex)
      schedule(2, "call_to_run_scan", pindex, nil, false)
   end
end)

script.on_event("scan-facing-direction", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   local p = game.get_player(pindex)
   if p.character == nil then return end
   if not players[pindex].in_menu then
      --Set the filter direction
      local p = game.get_player(pindex)
      local dir = p.character.direction
      fa_scanner.run_scanner_effects(pindex)
      schedule(2, "call_to_run_scan", pindex, dir, false)
   end
end)

script.on_event("a-scan-list-main-up-key", function(event)
   --laterdo: find a more elegant scan list solution here. It depends on hardcoded keybindings and alphabetically named event handling
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   players[pindex].last_pg_key_tick = event.tick
end)

script.on_event("a-scan-list-main-down-key", function(event)
   --laterdo: find a more elegant scan list solution here. It depends on hardcoded keybindings and alphabetically named event handling
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   players[pindex].last_pg_key_tick = event.tick
end)

script.on_event("scan-list-up", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   if not players[pindex].in_menu and not players[pindex].cursor then fa_scanner.list_up(pindex) end
   if
      players[pindex].cursor
      and players[pindex].last_pg_key_tick ~= nil
      and event.tick - players[pindex].last_pg_key_tick < 10
   then
      fa_scanner.list_up(pindex)
   end
end)

script.on_event("scan-list-down", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   if not players[pindex].in_menu and not players[pindex].cursor then fa_scanner.list_down(pindex) end
   if
      players[pindex].cursor
      and players[pindex].last_pg_key_tick ~= nil
      and event.tick - players[pindex].last_pg_key_tick < 10
   then
      fa_scanner.list_down(pindex)
   end
end)

script.on_event("scan-list-middle", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   if not players[pindex].in_menu then fa_scanner.list_current(pindex) end
end)

script.on_event("scan-category-up", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   if not players[pindex].in_menu then fa_scanner.category_up(pindex) end
end)

script.on_event("scan-category-down", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   if not players[pindex].in_menu then fa_scanner.category_down(pindex) end
end)

script.on_event("scan-sort-by-distance", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   if not players[pindex].in_menu then
      local ent = game.get_player(pindex).selected or get_selected_ent(pindex)
      if ent ~= nil and ent.valid == true and (ent.get_control_behavior() ~= nil or ent.type == "electric-pole") then
         --Open the circuit network menu for the selected ent instead.
         return
      end
      players[pindex].nearby.index = 1
      players[pindex].nearby.count = false
      printout("Sorting scan results by distance from character position", pindex)
      fa_scanner.list_sort(pindex)
   end
end)

script.on_event("scan-sort-by-count", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   if not players[pindex].in_menu then
      players[pindex].nearby.index = 1
      players[pindex].nearby.count = true
      printout("Sorting scan results by total count", pindex)
      fa_scanner.list_sort(pindex)
   end
end)

--Move along different inmstances of the same item type
script.on_event("scan-selection-up", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   fa_scanner.selection_up(pindex)
end)

--Move along different inmstances of the same item type
script.on_event("scan-selection-down", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   fa_scanner.selection_down(pindex)
end)

--Repeats the last thing read out. Not just the scanner.
script.on_event("repeat-last-spoken", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   repeat_last_spoken(pindex)
end)

--Calls function to notify if items are being picked up via vanilla F key.
script.on_event("pickup-items-info", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   local p = game.get_player(pindex)
   local bp = p.cursor_stack
   if bp and bp.valid_for_read and bp.is_blueprint then return end
   read_item_pickup_state(pindex)
end)

function read_item_pickup_state(pindex)
   if players[pindex].in_menu then
      printout("Cannot pickup items while in a menu", pindex)
      return
   end
   local p = game.get_player(pindex)
   local result = ""
   local check_last_pickup = false
   local nearby_belts =
      p.surface.find_entities_filtered({ position = p.position, radius = 1.25, type = "transport-belt" })
   local nearby_ground_items =
      p.surface.find_entities_filtered({ position = p.position, radius = 1.25, name = "item-on-ground" })
   rendering.draw_circle({
      color = { 0.3, 1, 0.3 },
      radius = 1.25,
      width = 1,
      target = p.position,
      surface = p.surface,
      time_to_live = 60,
      draw_on_ground = true,
   })
   --Check if there is a belt within n tiles
   if #nearby_belts > 0 then
      result = "Picking up "
      --Check contents being picked up
      local ent = nearby_belts[1]
      if ent == nil or not ent.valid then
         result = result .. " from nearby belts"
         printout(result, pindex)
         return
      end
      local left = ent.get_transport_line(1).get_contents()
      local right = ent.get_transport_line(2).get_contents()

      for name, count in pairs(right) do
         if left[name] ~= nil then
            left[name] = left[name] + count
         else
            left[name] = count
         end
      end
      local contents = {}
      for name, count in pairs(left) do
         table.insert(contents, { name = name, count = count })
      end
      table.sort(contents, function(k1, k2)
         return k1.count > k2.count
      end)
      if #contents > 0 then
         result = result .. contents[1].name
         if #contents > 1 then
            result = result .. ", and " .. contents[2].name
            if #contents > 2 then result = result .. ", and other item types " end
         end
      end
      result = result .. " from nearby belts"
   --Check if there are ground items within n tiles
   elseif #nearby_ground_items > 0 then
      result = "Picking up "
      if nearby_ground_items[1] and nearby_ground_items[1].valid then
         result = result .. nearby_ground_items[1].stack.name
      end
      result = result .. " from ground, and possibly more items "
   else
      result = "No items within range to pick up"
   end
   printout(result, pindex)
end

--Save info about last item pickup and draw radius
script.on_event(defines.events.on_picked_up_item, function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   local p = game.get_player(pindex)
   rendering.draw_circle({
      color = { 0.3, 1, 0.3 },
      radius = 1.25,
      width = 1,
      target = p.position,
      surface = p.surface,
      time_to_live = 10,
      draw_on_ground = true,
   })
   players[pindex].last_pickup_tick = event.tick
   players[pindex].last_item_picked_up = event.item_stack.name
end)

--Reads other entities on the same tile? Note: Possibly unneeded
script.on_event("tile-cycle", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   if not players[pindex].in_menu then tile_cycle(pindex) end
end)

script.on_event("open-inventory", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then
      return
   elseif players[pindex].in_menu or players[pindex].last_menu_toggle_tick == event.tick then
      return
   elseif not players[pindex].in_menu then
      open_player_inventory(event.tick, pindex)
   end
end)

--Sets up mod character menus. Cannot actually open the character GUI.
function open_player_inventory(tick, pindex)
   local p = game.get_player(pindex)
   if p.ticks_to_respawn ~= nil then return end
   p.play_sound({ path = "Open-Inventory-Sound" })
   p.selected = nil
   players[pindex].last_menu_toggle_tick = tick
   players[pindex].in_menu = true
   players[pindex].menu = "inventory"
   players[pindex].inventory.lua_inventory = p.get_main_inventory()
   players[pindex].inventory.max = #players[pindex].inventory.lua_inventory
   players[pindex].inventory.index = 1
   read_inventory_slot(pindex, "Inventory, ")
   players[pindex].crafting.lua_recipes = fa_crafting.get_recipes(pindex, p.character, true)
   players[pindex].crafting.max = #players[pindex].crafting.lua_recipes
   players[pindex].crafting.category = 1
   players[pindex].crafting.index = 1
   players[pindex].technology.category = 1
   players[pindex].technology.lua_researchable = {}
   players[pindex].technology.lua_unlocked = {}
   players[pindex].technology.lua_locked = {}
   -- Create technologies list
   for i, tech in pairs(game.get_player(pindex).force.technologies) do
      if tech.researched then
         table.insert(players[pindex].technology.lua_unlocked, tech)
      else
         local check = true
         for i1, preq in pairs(tech.prerequisites) do
            if not preq.researched then check = false end
         end
         if check then
            table.insert(players[pindex].technology.lua_researchable, tech)
         else
            local check = false
            for i1, preq in pairs(tech.prerequisites) do
               if preq.researched then check = true end
            end
            if check then table.insert(players[pindex].technology.lua_locked, tech) end
         end
      end
   end
end

--Technology menu: Read the selected technology
function read_technology_slot(pindex, start_phrase)
   start_phrase = start_phrase or ""
   local techs = {}
   if players[pindex].technology.category == 1 then
      techs = players[pindex].technology.lua_researchable
   elseif players[pindex].technology.category == 2 then
      techs = players[pindex].technology.lua_locked
   elseif players[pindex].technology.category == 3 then
      techs = players[pindex].technology.lua_unlocked
   end

   if next(techs) ~= nil and players[pindex].technology.index > 0 and players[pindex].technology.index <= #techs then
      local tech = techs[players[pindex].technology.index]
      if tech.valid then
         printout(start_phrase .. fa_localising.get(tech, pindex), pindex)
      else
         printout(start_phrase .. "Error loading technology", pindex)
      end
   else
      printout(start_phrase .. "No technologies in this category", pindex)
   end
end

script.on_event("close-menu-access", function(event) --close_menu, menu closed
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   players[pindex].move_queue = {}
   if not players[pindex].in_menu or players[pindex].last_menu_toggle_tick == event.tick then
      return
   elseif players[pindex].in_menu and players[pindex].menu ~= "prompt" then
      printout("Menu closed.", pindex)
      if
         players[pindex].menu == "inventory"
         or players[pindex].menu == "crafting"
         or players[pindex].menu == "technology"
         or players[pindex].menu == "crafting_queue"
         or players[pindex].menu == "warnings"
      then --**laterdo open close inv sounds in other menus?
         game.get_player(pindex).play_sound({ path = "Close-Inventory-Sound" })
      end
      players[pindex].last_menu_toggle_tick = event.tick
      close_menu_resets(pindex)
   end
end)

function close_menu_resets(pindex)
   local p = game.get_player(pindex)
   if players[pindex].menu == "travel" then
      fa_travel.fast_travel_menu_close(pindex)
   elseif players[pindex].menu == "structure-travel" then
      fa_travel.structure_travel_menu_close(pindex)
   elseif players[pindex].menu == "rail_builer" then
      fa_rail_builder.close_menu(pindex, false)
   elseif players[pindex].menu == "train_menu" then
      fa_trains.menu_close(pindex, false)
   elseif players[pindex].menu == "spider_menu" then
      fa_spidertrons.spider_menu_close(pindex, false)
   elseif players[pindex].menu == "train_stop_menu" then
      fa_train_stops.train_stop_menu_close(pindex, false)
   elseif players[pindex].menu == "roboport_menu" then
      fa_bot_logistics.roboport_menu_close(pindex)
   elseif players[pindex].menu == "blueprint_menu" then
      fa_blueprints.blueprint_menu_close(pindex)
   elseif players[pindex].menu == "blueprint_book_menu" then
      fa_blueprints.blueprint_book_menu_close(pindex)
   elseif players[pindex].menu == "circuit_network_menu" then
      fa_circuits.circuit_network_menu_close(pindex, false)
   end

   if p.gui.screen["cursor-jump"] ~= nil then p.gui.screen["cursor-jump"].destroy() end

   --Stop any enabled mouse entity selection
   if players[pindex].vanilla_mode ~= true then
      game.get_player(pindex).game_view_settings.update_entity_selection = false
   end

   --Reset menu vars
   players[pindex].in_menu = false
   players[pindex].menu = "none"
   players[pindex].entering_search_term = false
   players[pindex].menu_search_index = nil
   players[pindex].menu_search_index_2 = nil
   players[pindex].item_selection = false
   players[pindex].item_cache = {}
   players[pindex].item_selector = { index = 0, group = 0, subgroup = 0 }
   players[pindex].building = {
      index = 0,
      ent = nil,
      sectors = nil,
      sector = 0,
      recipe_selection = false,
      item_selection = false,
      category = 0,
      recipe = nil,
      recipe_list = nil,
   }
end

script.on_event("read-menu-name", function(event) --read_menu_name
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   local menu_name = "menu "
   if players[pindex].in_menu == false then
      menu_name = "no menu"
   elseif players[pindex].menu ~= nil and players[pindex].menu ~= "" then
      menu_name = players[pindex].menu
      if players[pindex].menu == "building" or players[pindex].menu == "vehicle" then
         --Name the building
         local pb = players[pindex].building
         menu_name = menu_name .. " " .. pb.ent.name
         --Name the sector
         if pb.sectors and pb.sectors[pb.sector] and pb.sectors[pb.sector].name ~= nil then
            menu_name = menu_name .. ", " .. pb.sectors[pb.sector].name
         elseif players[pindex].building.recipe_selection == true then
            menu_name = menu_name .. ", recipe selection"
         elseif players[pindex].building.sector_name == "player_inventory" then
            menu_name = menu_name .. ", player inventory"
         else
            menu_name = menu_name .. ", other section"
         end
      end
   else
      menu_name = "unknown menu"
   end
   printout(menu_name, pindex)
end)

--Quickbar event handlers
local quickbar_get_events = {}
local quickbar_set_events = {}
local quickbar_page_events = {}
for i = 1, 10 do
   table.insert(quickbar_get_events, "quickbar-" .. i)
   table.insert(quickbar_set_events, "set-quickbar-" .. i)
   table.insert(quickbar_page_events, "quickbar-page-" .. i)
end

script.on_event(quickbar_get_events, fa_quickbar.quickbar_get_handler)

script.on_event(quickbar_set_events, fa_quickbar.quickbar_set_handler)

script.on_event(quickbar_page_events, fa_quickbar.quickbar_page_handler)

script.on_event("switch-menu-or-gun", function(event)
   if ui.evt_tab_forward(event.player_index) then return end

   pindex = event.player_index
   if not check_for_player(pindex) then return end

   if players[pindex].started ~= true then
      players[pindex].started = true
      return
   end

   --Check if logistics have been researched
   local trash_inv = game.get_player(pindex).get_inventory(defines.inventory.character_trash)
   local logistics_researched = (trash_inv ~= nil and trash_inv.valid and #trash_inv > 0)

   if players[pindex].in_menu and players[pindex].menu ~= "prompt" then
      game.get_player(pindex).play_sound({ path = "Change-Menu-Tab-Sound" })
      if players[pindex].menu == "building" or players[pindex].menu == "vehicle" then
         players[pindex].building.index = 1
         players[pindex].building.category = 1
         players[pindex].building.recipe_selection = false

         players[pindex].building.sector = players[pindex].building.sector + 1 --Change sector
         players[pindex].building.item_selection = false
         players[pindex].item_selection = false
         players[pindex].item_cache = {}
         players[pindex].item_selector = {
            index = 0,
            group = 0,
            subgroup = 0,
         }

         if players[pindex].building.sector <= #players[pindex].building.sectors then
            fa_sectors.read_sector_slot(pindex, true)
            players[pindex].building.sector_name = "other"
         --            if inventory == players[pindex].building.sectors[players[pindex].building.sector+1].inventory then
         --               printout("Big Problem!", pindex)
         --          end
         elseif players[pindex].building.recipe_list == nil then
            if players[pindex].building.sector == (#players[pindex].building.sectors + 1) then
               read_inventory_slot(pindex, "Player Inventory, ")
               players[pindex].building.sector_name = "player_inventory"
            else
               players[pindex].building.sector = 1
               fa_sectors.read_sector_slot(pindex, true)
            end
         else
            if players[pindex].building.sector == #players[pindex].building.sectors + 1 then --Recipe selection sector
               fa_sectors.read_building_recipe(pindex, "Select a Recipe, ")
               players[pindex].building.sector_name = "recipe_selection"
            elseif players[pindex].building.sector == #players[pindex].building.sectors + 2 then --Player inventory sector
               read_inventory_slot(pindex, "Player Inventory, ")
               players[pindex].building.sector_name = "player_inventory"
            else
               players[pindex].building.sector = 1
               fa_sectors.read_sector_slot(pindex, true)
            end
         end
      elseif players[pindex].menu == "inventory" then
         players[pindex].menu = "crafting"
         fa_crafting.read_crafting_slot(pindex, "Crafting, ")
      elseif players[pindex].menu == "crafting" then
         players[pindex].menu = "crafting_queue"
         fa_crafting.load_crafting_queue(pindex)
         fa_crafting.read_crafting_queue(
            pindex,
            "Crafting queue, " .. fa_crafting.get_crafting_que_total(pindex) .. " total, "
         )
      elseif players[pindex].menu == "crafting_queue" then
         players[pindex].menu = "technology"
         read_technology_slot(pindex, "Technology, Researchable Technologies, ")
      elseif players[pindex].menu == "technology" then
         if logistics_researched then
            players[pindex].menu = "player_trash"
            read_inventory_slot(
               pindex,
               "Logistic trash, ",
               game.get_player(pindex).get_inventory(defines.inventory.character_trash)
            )
         else
            players[pindex].menu = "inventory"
            read_inventory_slot(pindex, "Inventory, ")
         end
      elseif players[pindex].menu == "player_trash" then
         players[pindex].menu = "inventory"
         read_inventory_slot(pindex, "Inventory, ")
      elseif players[pindex].menu == "belt" then
         players[pindex].belt.index = 1
         players[pindex].belt.sector = players[pindex].belt.sector + 1
         if players[pindex].belt.sector == 5 then players[pindex].belt.sector = 1 end
         local sector = players[pindex].belt.sector
         if sector == 1 then
            printout("Local Lanes", pindex)
         elseif sector == 2 then
            printout("Total Lanes", pindex)
         elseif sector == 3 then
            printout("Downstream lanes", pindex)
         elseif sector == 4 then
            printout("Upstream Lanes", pindex)
         end
      elseif players[pindex].menu == "warnings" then
         players[pindex].warnings.sector = players[pindex].warnings.sector + 1
         if players[pindex].warnings.sector > 3 then players[pindex].warnings.sector = 1 end
         if players[pindex].warnings.sector == 1 then
            printout("Short Range: " .. players[pindex].warnings.short.summary, pindex)
         elseif players[pindex].warnings.sector == 2 then
            printout("Medium Range: " .. players[pindex].warnings.medium.summary, pindex)
         elseif players[pindex].warnings.sector == 3 then
            printout("Long Range: " .. players[pindex].warnings.long.summary, pindex)
         end
      end
   end

   --Gun related changes (this seems to run before the actual switch happens so even when we write the new index, it will change, so we need to be predictive)
   local p = game.get_player(pindex)
   if p.character == nil then return end
   if p.vehicle ~= nil then
      --laterdo tank weapon naming ***
      return
   end
   local guns_inv = p.get_inventory(defines.inventory.character_guns)
   local ammo_inv = game.get_player(pindex).get_inventory(defines.inventory.character_ammo)
   local result = ""
   local switched_index = -2

   if players[pindex].in_menu then
      --switch_success = swap_weapon_backward(pindex,true)
      switched_index = swap_weapon_backward(pindex, true)
      return
   else
      switched_index = swap_weapon_forward(pindex, false)
   end

   --Declare the selected weapon
   local gun_index = switched_index
   local ammo_stack = nil
   local gun_stack = nil

   if gun_index < 1 then
      result = "No ready weapons"
   else
      local ammo_stack = ammo_inv[gun_index]
      local gun_stack = guns_inv[gun_index]
      --game.print("print " .. gun_index)--
      result = gun_stack.name .. " with " .. ammo_stack.count .. " " .. ammo_stack.name .. "s "
   end

   if not players[pindex].in_menu then
      --p.play_sound{path = "Inventory-Move"}
      printout(result, pindex)
   end
end)

script.on_event("reverse-switch-menu-or-gun", function(event)
   if ui.evt_tab_backward(event.player_index) then return end

   pindex = event.player_index
   if not check_for_player(pindex) then return end

   --Check if logistics have been researched
   local trash_inv = game.get_player(pindex).get_inventory(defines.inventory.character_trash)
   local logistics_researched = (trash_inv ~= nil and trash_inv.valid and #trash_inv > 0)

   if players[pindex].in_menu and players[pindex].menu ~= "prompt" then
      game.get_player(pindex).play_sound({ path = "Change-Menu-Tab-Sound" })
      if players[pindex].menu == "building" or players[pindex].menu == "vehicle" then
         players[pindex].building.category = 1
         players[pindex].building.recipe_selection = false
         players[pindex].building.index = 1

         players[pindex].building.sector = players[pindex].building.sector - 1
         players[pindex].building.item_selection = false
         players[pindex].item_selection = false
         players[pindex].item_cache = {}
         players[pindex].item_selector = {
            index = 0,
            group = 0,
            subgroup = 0,
         }

         if players[pindex].building.sector < 1 then
            if players[pindex].building.recipe_list == nil then
               players[pindex].building.sector = #players[pindex].building.sectors + 1
            else
               players[pindex].building.sector = #players[pindex].building.sectors + 2
            end
            players[pindex].building.sector_name = "player_inventory"
            read_inventory_slot(pindex, "Player Inventory, ")
         elseif players[pindex].building.sector <= #players[pindex].building.sectors then
            fa_sectors.read_sector_slot(pindex, true)
            players[pindex].building.sector_name = "other"
         elseif players[pindex].building.recipe_list == nil then
            if players[pindex].building.sector == (#players[pindex].building.sectors + 1) then
               read_inventory_slot(pindex, "Player Inventory, ")
               players[pindex].building.sector_name = "player_inventory"
            end
         else
            if players[pindex].building.sector == #players[pindex].building.sectors + 1 then
               fa_sectors.read_building_recipe(pindex, "Select a Recipe, ")
               players[pindex].building.sector_name = "recipe_selection"
            elseif players[pindex].building.sector == #players[pindex].building.sectors + 2 then
               read_inventory_slot(pindex, "Player Inventory, ")
               players[pindex].building.sector_name = "player_inventory"
            end
         end
      elseif players[pindex].menu == "inventory" then
         if logistics_researched then
            players[pindex].menu = "player_trash"
            read_inventory_slot(
               pindex,
               "Logistic trash, ",
               game.get_player(pindex).get_inventory(defines.inventory.character_trash)
            )
         else
            players[pindex].menu = "technology"
            read_technology_slot(pindex, "Technology, Researchable Technologies, ")
         end
      elseif players[pindex].menu == "player_trash" then
         players[pindex].menu = "technology"
         read_technology_slot(pindex, "Technology, Researchable Technologies, ")
      elseif players[pindex].menu == "crafting_queue" then
         players[pindex].menu = "crafting"
         fa_crafting.read_crafting_slot(pindex, "Crafting, ")
      elseif players[pindex].menu == "technology" then
         players[pindex].menu = "crafting_queue"
         fa_crafting.load_crafting_queue(pindex)
         fa_crafting.read_crafting_queue(
            pindex,
            "Crafting queue, " .. fa_crafting.get_crafting_que_total(pindex) .. " total, "
         )
      elseif players[pindex].menu == "crafting" then
         players[pindex].menu = "inventory"
         read_inventory_slot(pindex, "Inventory, ")
      elseif players[pindex].menu == "belt" then
         players[pindex].belt.index = 1
         players[pindex].belt.sector = players[pindex].belt.sector - 1
         if players[pindex].belt.sector == 0 then players[pindex].belt.sector = 4 end
         local sector = players[pindex].belt.sector
         if sector == 1 then
            printout("Local Lanes", pindex)
         elseif sector == 2 then
            printout("Total Lanes", pindex)
         elseif sector == 3 then
            printout("Downstream lanes", pindex)
         elseif sector == 4 then
            printout("Upstream Lanes", pindex)
         end
      elseif players[pindex].menu == "warnings" then
         players[pindex].warnings.sector = players[pindex].warnings.sector - 1
         if players[pindex].warnings.sector < 1 then players[pindex].warnings.sector = 3 end
         if players[pindex].warnings.sector == 1 then
            printout("Short Range: " .. players[pindex].warnings.short.summary, pindex)
         elseif players[pindex].warnings.sector == 2 then
            printout("Medium Range: " .. players[pindex].warnings.medium.summary, pindex)
         elseif players[pindex].warnings.sector == 3 then
            printout("Long Range: " .. players[pindex].warnings.long.summary, pindex)
         end
      end
   end

   --Gun related changes (Vanilla Factorio DOES NOT have shift + tab weapon revserse switching, so we add it without prediction needed)
   local p = game.get_player(pindex)
   if p.character == nil then return end
   if p.vehicle ~= nil then
      --laterdo tank weapon naming ***
      return
   end
   local guns_inv = p.get_inventory(defines.inventory.character_guns)
   local ammo_inv = game.get_player(pindex).get_inventory(defines.inventory.character_ammo)
   local result = ""
   local switched_index = -2

   if players[pindex].in_menu then
      --do nothing
      return
   else
      switched_index = swap_weapon_backward(pindex, true)
   end

   --Declare the selected weapon
   local gun_index = switched_index
   local ammo_stack = nil
   local gun_stack = nil

   if gun_index < 1 then
      result = "No ready weapons"
   else
      local ammo_stack = ammo_inv[gun_index]
      local gun_stack = guns_inv[gun_index]
      --game.print("print " .. gun_index)--
      result = gun_stack.name .. " with " .. ammo_stack.count .. " " .. ammo_stack.name .. "s "
   end

   if not players[pindex].in_menu then
      p.play_sound({ path = "Inventory-Move" })
      printout(result, pindex)
   end
end)

function swap_weapon_forward(pindex, write_to_character)
   local p = game.get_player(pindex)
   if p.character == nil then
      return 0 --This is an intentionally selected error code
   end
   local gun_index = p.character.selected_gun_index
   if gun_index == nil then
      return 0 --This is an intentionally selected error code
   end
   local guns_inv = p.get_inventory(defines.inventory.character_guns)
   local ammo_inv = game.get_player(pindex).get_inventory(defines.inventory.character_ammo)

   --Simple index increment (not needed)
   gun_index = gun_index + 1
   if gun_index > 3 then gun_index = 1 end
   --game.print("start " .. gun_index)--

   --Increment again if the new index has no guns or no ammo
   local ammo_stack = ammo_inv[gun_index]
   local gun_stack = guns_inv[gun_index]
   local tries = 0
   while
      tries < 4
      and (
         ammo_stack == nil
         or not ammo_stack.valid_for_read
         or not ammo_stack.valid
         or gun_stack == nil
         or not gun_stack.valid_for_read
         or not gun_stack.valid
      )
   do
      gun_index = gun_index + 1
      if gun_index > 3 then gun_index = 1 end
      ammo_stack = ammo_inv[gun_index]
      gun_stack = guns_inv[gun_index]
      tries = tries + 1
   end

   if tries > 3 then
      --game.print("error " .. gun_index)--
      return -1
   end

   if write_to_character then p.character.selected_gun_index = gun_index end
   --game.print("end " .. gun_index)--
   return gun_index
end

function swap_weapon_backward(pindex, write_to_character)
   local p = game.get_player(pindex)
   if p.character == nil then
      return 0 --This is an intentionally selected error code
   end
   local gun_index = p.character.selected_gun_index
   if gun_index == nil then
      return 0 --This is an intentionally selected error code
   end
   local guns_inv = p.get_inventory(defines.inventory.character_guns)
   local ammo_inv = game.get_player(pindex).get_inventory(defines.inventory.character_ammo)

   --Simple index increment (not needed)
   gun_index = gun_index - 1
   if gun_index < 1 then gun_index = 3 end

   --Increment again if the new index has no guns or no ammo
   local ammo_stack = ammo_inv[gun_index]
   local gun_stack = guns_inv[gun_index]
   local tries = 0
   while
      tries < 4
      and (
         ammo_stack == nil
         or not ammo_stack.valid_for_read
         or not ammo_stack.valid
         or gun_stack == nil
         or not gun_stack.valid_for_read
         or not gun_stack.valid
      )
   do
      gun_index = gun_index - 1
      if gun_index < 1 then gun_index = 3 end
      ammo_stack = ammo_inv[gun_index]
      gun_stack = guns_inv[gun_index]
      tries = tries + 1
   end

   if tries > 3 then return -1 end

   if write_to_character then p.character.selected_gun_index = gun_index end
   return gun_index
end

--Creates sound effects for vanilla mining
script.on_event("mine-access-sounds", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   if not players[pindex].in_menu and not players[pindex].vanilla_mode then
      target(pindex)
      local ent = get_selected_ent(pindex)
      if ent and ent.valid and (ent.prototype.mineable_properties.products ~= nil) and ent.type ~= "resource" then
         game.get_player(pindex).selected = ent
         game.get_player(pindex).play_sound({ path = "player-mine" })
      elseif ent and ent.valid and ent.name == "character-corpse" then
         printout("Collecting items ", pindex)
      end
   end
end)

--Mines tiles such as stone brick or concrete within the cursor area, including enlarged cursors
script.on_event("mine-tiles", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   if not players[pindex].in_menu and not players[pindex].vanilla_mode then
      --Mine tiles around the cursor
      local stack = game.get_player(pindex).cursor_stack
      local surf = game.get_player(pindex).surface
      if stack and stack.valid_for_read and stack.valid and stack.prototype.place_as_tile_result ~= nil then
         players[pindex].allow_reading_flying_text = false
         local c_pos = players[pindex].cursor_pos
         local c_size = players[pindex].cursor_size
         local left_top = { x = math.floor(c_pos.x - c_size), y = math.floor(c_pos.y - c_size) }
         local right_bottom = { x = math.floor(c_pos.x + 1 + c_size), y = math.floor(c_pos.y + 1 + c_size) }
         local tiles = surf.find_tiles_filtered({ area = { left_top, right_bottom } })
         for i, tile in ipairs(tiles) do
            local mined = game.get_player(pindex).mine_tile(tile)
            if mined then game.get_player(pindex).play_sound({ path = "entity-mined/stone-furnace" }) end
         end
      end
   end
end)

--Flush the selected fluid
script.on_event("flush-fluid", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   if players[pindex].menu ~= "building" then return end
   if
      players[pindex].building.ent ~= nil
      and players[pindex].building.ent.valid
      and players[pindex].building.ent.type == "fluid-turret"
      and players[pindex].building.index ~= 1
   then
      --Prevent fluid turret crashes
      players[pindex].building.index = 1
   end
   local building_sector = players[pindex].building.sectors[players[pindex].building.sector]
   local box = building_sector.inventory --= players[pindex].building.fluidbox --
   if building_sector.name ~= "Fluid" then return end
   if box == nil or #box == 0 then
      printout("No fluids to flush", pindex)
      return
   end
   local fluid = box[players[pindex].building.index]
   local len = #box
   local name = "Nothing"
   local amount = 0
   if fluid ~= nil and fluid.name ~= nil then
      amount = fluid.amount
      name = fluid.name --does not localize..?**
   else
      printout("No fluids to flush", pindex)
      return
   end
   --Read the fluid found, including amount if any
   printout(" Flushed away " .. name, pindex)
   box.flush(players[pindex].building.index)
end)

--Mines groups of entities depending on the name or type. Includes trees and rocks, rails.
script.on_event("mine-area", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   if players[pindex].in_menu then return end
   local p = game.get_player(pindex)
   local ent = get_selected_ent(pindex)
   local cleared_count = 0
   local cleared_total = 0
   local comment = ""

   --Check if within reach
   if
      ent ~= nil
         and ent.valid
         and util.distance(game.get_player(pindex).position, ent.position) > game.get_player(pindex).reach_distance
      or util.distance(game.get_player(pindex).position, players[pindex].cursor_pos)
         > game.get_player(pindex).reach_distance
   then
      game.get_player(pindex).play_sound({ path = "utility/cannot_build" })
      printout("This area is out of player reach", pindex)
      return
   end

   --Get initial inventory size
   local init_empty_stacks = game.get_player(pindex).get_main_inventory().count_empty_stacks()

   --Begin clearing
   players[pindex].allow_reading_flying_text = false
   if ent then
      local surf = ent.surface
      local pos = ent.position
      if
         ent.type == "tree"
         or ent.name == "rock-big"
         or ent.name == "rock-huge"
         or ent.name == "sand-rock-big"
         or ent.name == "item-on-ground"
      then
         --Obstacles within 5 tiles: trees and rocks and ground items
         game.get_player(pindex).play_sound({ path = "player-mine" })
         cleared_count, comment = fa_mining_tools.clear_obstacles_in_circle(pos, 5, pindex)
      elseif ent.name == "straight-rail" or ent.name == "curved-rail" then
         --Railway objects within 10 tiles (and their signals)
         local rail_ents = surf.find_entities_filtered({
            position = pos,
            radius = 10,
            name = { "straight-rail", "curved-rail", "rail-signal", "rail-chain-signal", "train-stop" },
         })
         for i, rail_ent in ipairs(rail_ents) do
            p.play_sound({ path = "entity-mined/straight-rail" })
            p.mine_entity(rail_ent, true)
            cleared_count = cleared_count + 1
         end
         rendering.draw_circle({
            color = { 0, 1, 0 },
            radius = 10,
            width = 2,
            target = pos,
            surface = surf,
            time_to_live = 60,
         })
         printout(" Cleared away " .. cleared_count .. " railway objects within 10 tiles. ", pindex)
         return
      elseif ent.name == "entity-ghost" then
         --Ghosts within 10 tiles
         local ghosts = surf.find_entities_filtered({ position = pos, radius = 10, name = { "entity-ghost" } })
         for i, ghost in ipairs(ghosts) do
            game.get_player(pindex).mine_entity(ghost, true)
            cleared_count = cleared_count + 1
         end
         game.get_player(pindex).play_sound({ path = "utility/item_deleted" })
         rendering.draw_circle({
            color = { 0, 1, 0 },
            radius = 10,
            width = 2,
            target = pos,
            surface = surf,
            time_to_live = 60,
         })
         printout(" Cleared away " .. cleared_count .. " entity ghosts within 10 tiles. ", pindex)
         return
      else
         --Check if it is a remnant ent, clear obstacles
         local ent_is_remnant = false
         local remnant_names = ENT_NAMES_CLEARED_AS_OBSTACLES
         for i, name in ipairs(remnant_names) do
            if ent.name == name then ent_is_remnant = true end
         end
         if ent_is_remnant then
            game.get_player(pindex).play_sound({ path = "player-mine" })
            cleared_count, comment = fa_mining_tools.clear_obstacles_in_circle(players[pindex].cursor_pos, 5, pindex)
         end

         --(For other valid ents, do nothing)
      end
   else
      --For empty tiles, clear obstacles
      game.get_player(pindex).play_sound({ path = "player-mine" })
      cleared_count, comment = fa_mining_tools.clear_obstacles_in_circle(players[pindex].cursor_pos, 5, pindex)
   end
   cleared_total = cleared_total + cleared_count

   --If cut-paste tool in hand, mine every non-resource entity in the area that you can.
   local p = game.get_player(pindex)
   local stack = p.cursor_stack
   if stack and stack.valid_for_read and stack.name == "cut-paste-tool" then
      players[pindex].allow_reading_flying_text = false
      local all_ents =
         p.surface.find_entities_filtered({ position = p.position, radius = 5, force = { p.force, "neutral" } })
      for i, ent in ipairs(all_ents) do
         if ent and ent.valid then
            local name = ent.name
            game.get_player(pindex).play_sound({ path = "player-mine" })
            if fa_mining_tools.try_to_mine_with_soun(ent, pindex) then cleared_total = cleared_total + 1 end
         end
      end
   end

   --If the deconstruction planner is in hand, mine every entity marked for deconstruction except for cliffs.
   if stack and stack.valid_for_read and stack.is_deconstruction_item then
      players[pindex].allow_reading_flying_text = false
      local all_ents =
         p.surface.find_entities_filtered({ position = p.position, radius = 5, force = { p.force, "neutral" } })
      for i, ent in ipairs(all_ents) do
         if ent and ent.valid and ent.is_registered_for_deconstruction(p.force) then
            local name = ent.name
            game.get_player(pindex).play_sound({ path = "player-mine" })
            if fa_mining_tools.try_to_mine_with_soun(ent, pindex) then cleared_total = cleared_total + 1 end
         end
      end
   end

   --Calculate collected stack count
   local stacks_collected = init_empty_stacks - game.get_player(pindex).get_main_inventory().count_empty_stacks()

   --Print result
   local result = " Cleared away " .. cleared_total .. " objects "
   if stacks_collected >= 0 then result = result .. " and collected " .. stacks_collected .. " new item stacks." end
   printout(result, pindex)
end)

--Cut-paste-tool. NOTE: This keybind needs to be the same as that for the cut paste tool (default CONTROL + X). laterdo maybe keybind to game control somehow
script.on_event("cut-paste-tool-comment", function(event)
   local pindex = event.player_index
   if not check_for_player(pindex) then return end
   local stack = game.get_player(pindex).cursor_stack
   if stack == nil then
      --(do nothing when the cut paste tool is not enabled)
   elseif stack and stack.valid_for_read and stack.name == "cut-paste-tool" then
      printout("To disable this tool empty the hand, by pressing SHIFT + Q", pindex)
   end
end)

--Right click actions in menus (click_menu)
script.on_event("click-menu-right", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   if players[pindex].last_click_tick == event.tick then return end
   if players[pindex].in_menu then
      players[pindex].last_click_tick = event.tick
      if players[pindex].menu == "inventory" then
         --Player inventory: Take half
         local p = game.get_player(pindex)
         local stack_cur = p.cursor_stack
         local stack_inv = table.deepcopy(players[pindex].inventory.lua_inventory[players[pindex].inventory.index])
         p.play_sound({ path = "utility/inventory_click" })
         if stack_inv and stack_inv.valid_for_read and (stack_inv.is_blueprint or stack_inv.is_blueprint_book) then
            --Do not grab it
            return
         end
         if not (stack_cur and stack_cur.valid_for_read) and (stack_inv and stack_inv.valid_for_read) then
            --Take half (sorted inventory)
            local name = stack_inv.name
            p.cursor_stack.swap_stack(players[pindex].inventory.lua_inventory[players[pindex].inventory.index])
            local bigger_half = math.ceil(p.cursor_stack.count / 2)
            local smaller_half = math.floor(p.cursor_stack.count / 2)
            p.cursor_stack.count = smaller_half
            p.get_main_inventory().insert({ name = name, count = bigger_half })
         end
         players[pindex].inventory.max = #players[pindex].inventory.lua_inventory
      elseif players[pindex].menu == "building" or players[pindex].menu == "vehicle" then
         local sectors_i = players[pindex].building.sectors[players[pindex].building.sector]
         if
            players[pindex].building.sector <= #players[pindex].building.sectors
            and #sectors_i.inventory > 0
            and (sectors_i.name == "Output" or sectors_i.name == "Input" or sectors_i.name == "Fuel")
         then
            --Building invs: Take half**
         elseif players[pindex].building.recipe_list == nil or #players[pindex].building.recipe_list == 0 then
            --Player inventory: Take half
            local p = game.get_player(pindex)
            local stack_cur = p.cursor_stack
            local stack_inv = table.deepcopy(players[pindex].inventory.lua_inventory[players[pindex].inventory.index])
            p.play_sound({ path = "utility/inventory_click" })
            if not (stack_cur and stack_cur.valid_for_read) and (stack_inv and stack_inv.valid_for_read) then
               --Take half (sorted inventory)
               local name = stack_inv.name
               p.cursor_stack.swap_stack(players[pindex].inventory.lua_inventory[players[pindex].inventory.index])
               local bigger_half = math.ceil(p.cursor_stack.count / 2)
               local smaller_half = math.floor(p.cursor_stack.count / 2)
               p.cursor_stack.count = smaller_half
               p.get_main_inventory().insert({ name = name, count = bigger_half })
            end
            players[pindex].inventory.max = #players[pindex].inventory.lua_inventory
         end
      end
   end
end)

script.on_event("leftbracket-key-id", function(event)
   if ui.evt_left_click(event.player_index, { ctrl = false, shift = false, alt = false }) then return end
end)

script.on_event("rightbracket-key-id", function(event)
   if ui.evt_right_click(event.player_index, { ctrl = false, shift = false, alt = false }) then return end
end)

--Left click actions in menus (click_menu)
script.on_event("click-menu", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   if players[pindex].last_click_tick == event.tick then return end
   local p = game.get_player(pindex)
   if players[pindex].in_menu then
      players[pindex].last_click_tick = event.tick
      if players[pindex].menu == "inventory" then
         --Swap stacks
         game.get_player(pindex).play_sound({ path = "utility/inventory_click" })
         local stack = players[pindex].inventory.lua_inventory[players[pindex].inventory.index]
         game.get_player(pindex).cursor_stack.swap_stack(stack)
         players[pindex].inventory.max = #players[pindex].inventory.lua_inventory
      elseif players[pindex].menu == "player_trash" then
         local trash_inv = game.get_player(pindex).get_inventory(defines.inventory.character_trash)
         --Swap stacks
         game.get_player(pindex).play_sound({ path = "utility/inventory_click" })
         local stack = trash_inv[players[pindex].inventory.index]
         game.get_player(pindex).cursor_stack.swap_stack(stack)
      elseif players[pindex].menu == "crafting" then
         --Check recipe category
         local recipe =
            players[pindex].crafting.lua_recipes[players[pindex].crafting.category][players[pindex].crafting.index]
         if p.cheat_mode == false or (p.cheat_mode == true and recipe.subgroup == "fluid-recipes") then
            if recipe.category == "advanced-crafting" then
               printout("An assembling machine is required to craft this", pindex)
               return
            elseif recipe.category == "centrifuging" then
               printout("A centrifuge is required to craft this", pindex)
               return
            elseif recipe.category == "chemistry" then
               printout("A chemical plant is required to craft this", pindex)
               return
            elseif recipe.category == "crafting-with-fluid" then
               printout("An advanced assembling machine is required to craft this", pindex)
               return
            elseif recipe.category == "oil-processing" then
               printout("An oil refinery is required to craft this", pindex)
               return
            elseif recipe.category == "rocket-building" then
               printout("A rocket silo is required to craft this", pindex)
               return
            elseif recipe.category == "smelting" then
               printout("A furnace is required to craft this", pindex)
               return
            elseif p.force.get_hand_crafting_disabled_for_recipe(recipe) == true then
               printout("This recipe cannot be crafted by hand", pindex)
               return
            end
         end
         --Craft 1
         local T = {
            count = 1,
            recipe = players[pindex].crafting.lua_recipes[players[pindex].crafting.category][players[pindex].crafting.index],
            silent = false,
         }
         local count = game.get_player(pindex).begin_crafting(T)
         if count > 0 then
            local total_count = fa_crafting.count_in_crafting_queue(T.recipe.name, pindex)
            printout(
               "Started crafting "
                  .. count
                  .. " "
                  .. fa_localising.get_recipe_from_name(recipe.name, pindex)
                  .. ", "
                  .. total_count
                  .. " total in queue",
               pindex
            )
         else
            local result = fa_crafting.recipe_missing_ingredients_info(pindex)
            printout(result, pindex)
         end
      elseif players[pindex].menu == "crafting_queue" then
         --Cancel 1
         fa_crafting.load_crafting_queue(pindex)
         if players[pindex].crafting_queue.max >= 1 then
            local T = {
               index = players[pindex].crafting_queue.index,
               count = 1,
            }
            game.get_player(pindex).cancel_crafting(T)
            fa_crafting.load_crafting_queue(pindex)
            fa_crafting.read_crafting_queue(pindex, "cancelled 1, ")
         end
      elseif players[pindex].menu == "building" or players[pindex].menu == "vehicle" then
         local sectors_i = players[pindex].building.sectors[players[pindex].building.sector]
         if players[pindex].building.sector <= #players[pindex].building.sectors and #sectors_i.inventory > 0 then
            if sectors_i.name == "Fluid" then
               --Do nothing
               return
            elseif sectors_i.name == "Filters" then
               --Set filters
               if players[pindex].building.index == #sectors_i.inventory then
                  if players[pindex].building.ent == nil or not players[pindex].building.ent.valid then
                     if players[pindex].building.ent == nil then
                        printout("Nil entity", pindex)
                     else
                        printout("Invalid Entity", pindex)
                     end
                     return
                  end
                  if players[pindex].building.ent.inserter_filter_mode == "whitelist" then
                     players[pindex].building.ent.inserter_filter_mode = "blacklist"
                  else
                     players[pindex].building.ent.inserter_filter_mode = "whitelist"
                  end
                  sectors_i.inventory[players[pindex].building.index] =
                     players[pindex].building.ent.inserter_filter_mode
                  fa_sectors.read_sector_slot(pindex, false)
               elseif players[pindex].building.item_selection then
                  if players[pindex].item_selector.group == 0 then
                     players[pindex].item_selector.group = players[pindex].item_selector.index
                     players[pindex].item_cache = fa_utils.get_iterable_array(
                        players[pindex].item_cache[players[pindex].item_selector.group].subgroups
                     )
                     prune_item_groups(players[pindex].item_cache)

                     players[pindex].item_selector.index = 1
                     read_item_selector_slot(pindex)
                  elseif players[pindex].item_selector.subgroup == 0 then
                     players[pindex].item_selector.subgroup = players[pindex].item_selector.index
                     local prototypes = game.get_filtered_item_prototypes({
                        {
                           filter = "subgroup",
                           subgroup = players[pindex].item_cache[players[pindex].item_selector.index].name,
                        },
                     })
                     players[pindex].item_cache = fa_utils.get_iterable_array(prototypes)
                     players[pindex].item_selector.index = 1
                     read_item_selector_slot(pindex)
                  else
                     players[pindex].building.ent.set_filter(
                        players[pindex].building.index,
                        players[pindex].item_cache[players[pindex].item_selector.index].name
                     )
                     sectors_i.inventory[players[pindex].building.index] =
                        players[pindex].building.ent.get_filter(players[pindex].building.index)
                     printout("Filter set.", pindex)
                     players[pindex].building.item_selection = false
                     players[pindex].item_selection = false
                  end
               else
                  players[pindex].item_selector.group = 0
                  players[pindex].item_selector.subgroup = 0
                  players[pindex].item_selector.index = 1
                  players[pindex].item_selection = true
                  players[pindex].building.item_selection = true
                  players[pindex].item_cache = fa_utils.get_iterable_array(game.item_group_prototypes)
                  prune_item_groups(players[pindex].item_cache)
                  read_item_selector_slot(pindex)
               end
               return
            end
            --Otherwise, you are working with item stacks
            local stack = sectors_i.inventory[players[pindex].building.index]
            local cursor_stack = game.get_player(pindex).cursor_stack
            --If both stacks have the same item, do a transfer
            if cursor_stack.valid_for_read and stack.valid_for_read and cursor_stack.name == stack.name then
               stack.transfer_stack(cursor_stack)
               cursor_stack = game.get_player(pindex).cursor_stack
               if sectors_i.name == "Modules" and cursor_stack.is_module then
                  printout(" Only one module can be added per module slot ", pindex)
               elseif cursor_stack.valid_for_read then
                  printout(" Adding to stack of " .. cursor_stack.name, pindex)
               else
                  printout(" Added", pindex)
               end
               return
            end
            --Special case for filling module slots
            if
               sectors_i.name == "Modules"
               and cursor_stack ~= nil
               and cursor_stack.valid_for_read
               and cursor_stack.is_module
            then
               local p_inv = game.get_player(pindex).get_main_inventory()
               local result = ""
               if stack.valid_for_read and stack.count > 0 then
                  if p_inv.count_empty_stacks() < 2 then
                     printout(" Error: At least two empty player inventory slots needed", pindex)
                     return
                  else
                     result = "Collected " .. stack.name .. " and "
                     p_inv.insert(stack)
                     stack.clear()
                  end
               end
               stack = sectors_i.inventory[players[pindex].building.index]
               if (stack == nil or stack.count == 0) and sectors_i.inventory.can_insert(cursor_stack) then
                  local module_name = cursor_stack.name
                  local successful =
                     sectors_i.inventory[players[pindex].building.index].set_stack({ name = module_name, count = 1 })
                  if not successful then
                     printout(" Failed to add module ", pindex)
                     return
                  end
                  cursor_stack.count = cursor_stack.count - 1
                  printout(result .. "added " .. module_name, pindex)
                  return
               else
                  printout(" Failed to add module ", pindex)
                  return
               end
            end
            --Try to swap stacks and report if there is an error
            if cursor_stack.swap_stack(stack) then
               game.get_player(pindex).play_sound({ path = "utility/inventory_click" })
            --             read_building_slot(pindex,false)
            else
               local name = "This item"
               if
                  (stack == nil or not stack.valid_for_read)
                  and (cursor_stack == nil or not cursor_stack.valid_for_read)
               then
                  printout("Empty", pindex)
                  return
               end
               if cursor_stack.valid_for_read then name = cursor_stack.name end
               printout("Cannot insert " .. name .. " in this slot", pindex)
            end
         elseif players[pindex].building.recipe_list == nil then
            --Player inventory: Swap stack
            game.get_player(pindex).play_sound({ path = "utility/inventory_click" })
            local stack = players[pindex].inventory.lua_inventory[players[pindex].inventory.index]
            game.get_player(pindex).cursor_stack.swap_stack(stack)
            players[pindex].inventory.max = #players[pindex].inventory.lua_inventory
         --          read_inventory_slot(pindex)
         else
            if players[pindex].building.sector == #players[pindex].building.sectors + 1 then --Building recipe selection
               if players[pindex].building.recipe_selection then
                  if
                     not (
                        pcall(function()
                           local there_was_a_recipe_before = false
                           players[pindex].building.recipe =
                              players[pindex].building.recipe_list[players[pindex].building.category][players[pindex].building.index]
                           if players[pindex].building.ent.valid then
                              there_was_a_recipe_before = (players[pindex].building.ent.get_recipe() ~= nil)
                              players[pindex].building.ent.set_recipe(players[pindex].building.recipe)
                           end
                           players[pindex].building.recipe_selection = false
                           players[pindex].building.index = 1
                           printout("Selected", pindex)
                           game.get_player(pindex).play_sound({ path = "utility/inventory_click" })
                           --Open GUI if not already
                           local p = game.get_player(pindex)
                           if there_was_a_recipe_before == false and players[pindex].building.ent.valid then
                              --Refresh the GUI --**laterdo figure this out, closing and opening in the same tick does not work.
                              --players[pindex].refreshing_building_gui = true
                              --p.opened = nil
                              --p.opened = players[pindex].building.ent
                              --players[pindex].refreshing_building_gui = false
                           end
                        end)
                     )
                  then
                     printout(
                        "For this building, recipes are selected automatically based on the input item, this menu is for information only.",
                        pindex
                     )
                  end
               elseif #players[pindex].building.recipe_list > 0 then
                  game.get_player(pindex).play_sound({ path = "utility/inventory_click" })
                  players[pindex].building.recipe_selection = true
                  players[pindex].building.category = 1
                  players[pindex].building.index = 1
                  fa_sectors.read_building_recipe(pindex)
               else
                  printout("No recipes unlocked for this building yet.", pindex)
               end
            else
               --Player inventory again: swap stack
               game.get_player(pindex).play_sound({ path = "utility/inventory_click" })
               local stack = players[pindex].inventory.lua_inventory[players[pindex].inventory.index]
               game.get_player(pindex).cursor_stack.swap_stack(stack)

               players[pindex].inventory.max = #players[pindex].inventory.lua_inventory
               ----               read_inventory_slot(pindex)
            end
         end
      elseif players[pindex].menu == "technology" then
         local techs = {}
         if players[pindex].technology.category == 1 then
            techs = players[pindex].technology.lua_researchable
         elseif players[pindex].technology.category == 2 then
            techs = players[pindex].technology.lua_locked
         elseif players[pindex].technology.category == 3 then
            techs = players[pindex].technology.lua_unlocked
         end

         if
            next(techs) ~= nil
            and players[pindex].technology.index > 0
            and players[pindex].technology.index <= #techs
         then
            if game.get_player(pindex).force.add_research(techs[players[pindex].technology.index]) then
               printout("Research started.", pindex)
            else
               printout("Research locked, first complete the prerequisites.", pindex)
            end
         end
      elseif players[pindex].menu == "pump" then
         if players[pindex].pump.index == 0 then
            printout("Move up and down to select a location.", pindex)
            return
         end
         local entry = players[pindex].pump.positions[players[pindex].pump.index]
         game.get_player(pindex).build_from_cursor({ position = entry.position, direction = entry.direction })
         players[pindex].in_menu = false
         players[pindex].menu = "none"
         printout("Pump placed.", pindex)
      elseif players[pindex].menu == "warnings" then
         local warnings = {}
         if players[pindex].warnings.sector == 1 then
            warnings = players[pindex].warnings.short.warnings
         elseif players[pindex].warnings.sector == 2 then
            warnings = players[pindex].warnings.medium.warnings
         elseif players[pindex].warnings.sector == 3 then
            warnings = players[pindex].warnings.long.warnings
         end
         if
            players[pindex].warnings.category <= #warnings
            and players[pindex].warnings.index <= #warnings[players[pindex].warnings.category].ents
         then
            local ent = warnings[players[pindex].warnings.category].ents[players[pindex].warnings.index]
            if ent ~= nil and ent.valid then
               players[pindex].cursor = true
               players[pindex].cursor_pos = fa_utils.center_of_tile(ent.position)
               fa_graphics.draw_cursor_highlight(pindex, ent, nil)
               fa_graphics.sync_build_cursor_graphics(pindex)
               printout({
                  "access.teleported-cursor-to",
                  "" .. math.floor(players[pindex].cursor_pos.x) .. " " .. math.floor(players[pindex].cursor_pos.y),
               }, pindex)
            --               players[pindex].menu = ""
            --               players[pindex].in_menu = false
            else
               printout("Blank", pindex)
            end
         else
            printout(
               "No warnings for this range.  Press tab to pick a larger range, or press E to close this menu.",
               pindex
            )
         end
      elseif players[pindex].menu == "travel" then
         fa_travel.fast_travel_menu_click(pindex)
      elseif players[pindex].menu == "structure-travel" then --Also called "b stride"
         ---@type LuaEntity
         local tar = nil
         local network = players[pindex].structure_travel.network
         local index = players[pindex].structure_travel.index
         local current = players[pindex].structure_travel.current
         if players[pindex].structure_travel.direction == "none" then
            tar = network[current]
         elseif players[pindex].structure_travel.direction == "north" then
            tar = network[network[current].north[index].num]
         elseif players[pindex].structure_travel.direction == "east" then
            tar = network[network[current].east[index].num]
         elseif players[pindex].structure_travel.direction == "south" then
            tar = network[network[current].south[index].num]
         elseif players[pindex].structure_travel.direction == "west" then
            tar = network[network[current].west[index].num]
         end
         local success = fa_teleport.teleport_to_closest(pindex, tar.position, false, false)
         if success and players[pindex].cursor then
            players[pindex].cursor_pos = table.deepcopy(tar.position)
         else
            players[pindex].cursor_pos =
               fa_utils.offset_position(players[pindex].position, players[pindex].player_direction, 1)
         end
         fa_graphics.sync_build_cursor_graphics(pindex)
         game.get_player(pindex).opened = nil

         if not refresh_player_tile(pindex) then
            printout("Tile out of range", pindex)
            return
         end

         --Update cursor highlight
         local ent = get_selected_ent(pindex)
         if ent and ent.valid then
            fa_graphics.draw_cursor_highlight(pindex, ent, nil)
         else
            fa_graphics.draw_cursor_highlight(pindex, nil, nil)
         end
      elseif players[pindex].menu == "rail_builder" then
         fa_rail_builder.run_menu(pindex, true)
         fa_rail_builder.close_menu(pindex, false)
      elseif players[pindex].menu == "train_menu" then
         fa_trains.run_train_menu(players[pindex].train_menu.index, pindex, true)
      elseif players[pindex].menu == "spider_menu" then
         fa_spidertrons.run_spider_menu(
            players[pindex].spider_menu.index,
            pindex,
            game.get_player(pindex).cursor_stack,
            true
         )
      elseif players[pindex].menu == "train_stop_menu" then
         fa_train_stops.run_train_stop_menu(players[pindex].train_stop_menu.index, pindex, true)
      elseif players[pindex].menu == "roboport_menu" then
         fa_bot_logistics.run_roboport_menu(players[pindex].roboport_menu.index, pindex, true)
      elseif players[pindex].menu == "blueprint_menu" then
         fa_blueprints.run_blueprint_menu(players[pindex].blueprint_menu.index, pindex, true)
      elseif players[pindex].menu == "blueprint_book_menu" then
         local bpb_menu = players[pindex].blueprint_book_menu
         fa_blueprints.run_blueprint_book_menu(pindex, bpb_menu.index, bpb_menu.list_mode, true, false)
      elseif players[pindex].menu == "circuit_network_menu" then
         fa_circuits.circuit_network_menu_run(pindex, nil, players[pindex].circuit_network_menu.index, true, false)
      elseif players[pindex].menu == "signal_selector" then
         fa_circuits.apply_selected_signal_to_enabled_condition(
            pindex,
            players[pindex].signal_selector.ent,
            players[pindex].signal_selector.editing_first_slot
         )
      end
   end
end)

--WIP: Different behavior when you click on an inventory slot depending on the item in hand and the item in the slot (WIP)
function player_inventory_click(pindex, left_click)
   --****todo finish this to include all interaction cases, then generalize it to building inventories .
   --Use code from above and then replace above clutter with calls to this.
   --Use stack.transfer_stack(other_stack)
   local click_is_left = left_click or true
   local p = game.get_player(pindex)
   local stack_cur = p.cursor_stack
   local stack_inv = players[pindex].inventory.lua_inventory[players[pindex].inventory.index]

   if stack_cur and stack_cur.valid_for_read then
      --Full hand
      if stack_inv and stack_inv.valid_for_read and stack_inv.name ~= stack_cur.name then
      else
      end
   else
      --Empty hand
   end

   --Play sound and update known inv size
   p.play_sound({ path = "utility/inventory_click" })
   players[pindex].inventory.max = #players[pindex].inventory.lua_inventory
end

--Left click actions with items in hand
script.on_event("click-hand", function(event)
   if ui.evt_left_click(event.player_index, { ctrl = true, alt = true, shift = true }) then return end

   pindex = event.player_index
   if not check_for_player(pindex) then return end
   local p = game.get_player(pindex)
   if players[pindex].last_click_tick == event.tick then return end
   if players[pindex].in_menu then
      return
   else
      --Not in a menu
      local stack = game.get_player(pindex).cursor_stack
      local cursor_ghost = game.get_player(pindex).cursor_ghost
      local ent = get_selected_ent(pindex)

      if stack and stack.valid_for_read and stack.valid then
         players[pindex].last_click_tick = event.tick
      elseif cursor_ghost ~= nil then
         players[pindex].last_click_tick = event.tick
         printout("Cannot build the ghost in hand", pindex)
         return
      else
         return
      end

      --If something is in hand...
      if
         stack.prototype ~= nil
         and (stack.prototype.place_result ~= nil or stack.prototype.place_as_tile_result ~= nil)
         and stack.name ~= "offshore-pump"
      then
         --If holding a preview of a building/tile, try to place it here
         fa_building_tools.build_item_in_hand(pindex)
      elseif stack.name == "offshore-pump" then
         --If holding an offshore pump, open the offshore pump builder
         fa_building_tools.build_offshore_pump_in_hand(pindex)
      elseif stack.name == "spidertron-remote" and stack.connected_entity ~= nil then
         --Set the cursor position as the spidertron autopilot target.
         fa_spidertrons.run_spider_menu(3, pindex, stack.connected_entity, true, nil)
      elseif stack.is_repair_tool then
         --If holding a repair pack, try to use it (will not work on enemies)
         fa_combat.repair_pack_used(ent, pindex)
      elseif stack.is_blueprint and stack.is_blueprint_setup() and players[pindex].blueprint_reselecting ~= true then
         --Paste a ready blueprint
         players[pindex].last_held_blueprint = stack
         fa_blueprints.paste_blueprint(pindex)
      elseif
         stack.is_blueprint and (stack.is_blueprint_setup() == false or players[pindex].blueprint_reselecting == true)
      then
         --Select blueprint
         local pex = players[pindex]
         if pex.bp_selecting ~= true then
            pex.bp_selecting = true
            pex.bp_select_point_1 = pex.cursor_pos
            printout(
               "Started blueprint selection at " .. math.floor(pex.cursor_pos.x) .. "," .. math.floor(pex.cursor_pos.y),
               pindex
            )
         else
            pex.bp_selecting = false
            pex.bp_select_point_2 = pex.cursor_pos
            local bp_data = nil
            if players[pindex].blueprint_reselecting == true then
               bp_data = fa_blueprints.get_bp_data_for_edit(stack)
            end
            fa_blueprints.create_blueprint(pindex, pex.bp_select_point_1, pex.bp_select_point_2, bp_data)
            players[pindex].blueprint_reselecting = false
         end
      elseif stack.is_blueprint_book then
         fa_blueprints.blueprint_book_menu_open(pindex, true)
      elseif stack.is_deconstruction_item then
         --Mark deconstruction
         local pex = players[pindex]
         if pex.bp_selecting ~= true then
            pex.bp_selecting = true
            pex.bp_select_point_1 = pex.cursor_pos
            printout(
               "Started deconstruction selection at "
                  .. math.floor(pex.cursor_pos.x)
                  .. ","
                  .. math.floor(pex.cursor_pos.y),
               pindex
            )
         else
            pex.bp_selecting = false
            pex.bp_select_point_2 = pex.cursor_pos
            --Mark area for deconstruction
            local left_top, right_bottom =
               fa_utils.get_top_left_and_bottom_right(pex.bp_select_point_1, pex.bp_select_point_2)
            p.surface.deconstruct_area({
               area = { left_top, right_bottom },
               force = p.force,
               player = p,
               item = p.cursor_stack,
            })
            local ents = p.surface.find_entities_filtered({ area = { left_top, right_bottom } })
            local decon_counter = 0
            for i, ent in ipairs(ents) do
               if ent.valid and ent.to_be_deconstructed() then decon_counter = decon_counter + 1 end
            end
            printout(decon_counter .. " entities marked to be deconstructed.", pindex)
         end
      elseif stack.is_upgrade_item then
         --Mark upgrade
         local pex = players[pindex]
         if pex.bp_selecting ~= true then
            pex.bp_selecting = true
            pex.bp_select_point_1 = pex.cursor_pos
            printout(
               "Started upgrading selection at " .. math.floor(pex.cursor_pos.x) .. "," .. math.floor(pex.cursor_pos.y),
               pindex
            )
         else
            pex.bp_selecting = false
            pex.bp_select_point_2 = pex.cursor_pos
            --Mark area for upgrading
            local left_top, right_bottom =
               fa_utils.get_top_left_and_bottom_right(pex.bp_select_point_1, pex.bp_select_point_2)
            p.surface.upgrade_area({
               area = { left_top, right_bottom },
               force = p.force,
               player = p,
               item = p.cursor_stack,
            })
            local ents = p.surface.find_entities_filtered({ area = { left_top, right_bottom } })
            local ent_counter = 0
            for i, ent in ipairs(ents) do
               if ent.valid and ent.to_be_upgraded() then ent_counter = ent_counter + 1 end
            end
            printout(ent_counter .. " entities marked to be upgraded.", pindex)
         end
      elseif stack.name == "red-wire" or stack.name == "green-wire" or stack.name == "copper-cable" then
         fa_circuits.drag_wire_and_read(pindex)
      elseif stack.prototype ~= nil and stack.prototype.type == "capsule" then
         --If holding a capsule type, e.g. cliff explosives or robot capsules, or remotes, try to use it at the cursor position (no feedback about successful usage)
         local cursor_dist = util.distance(game.get_player(pindex).position, players[pindex].cursor_pos)
         local range = 20
         if stack.name == "cliff-explosives" then
            range = 10
         elseif stack.name == "grenade" then
            range = 15
         end
         if stack.name == "artillery-targeting-remote" then
            game.get_player(pindex).use_from_cursor(players[pindex].cursor_pos)
            --Play sound **laterdo better sound
            game.get_player(pindex).play_sound({ path = "Close-Inventory-Sound" })
            if cursor_dist < 7 then printout("Warning, you are in the target area!", pindex) end
         elseif cursor_dist < range then
            game.get_player(pindex).use_from_cursor(players[pindex].cursor_pos)
         else
            game.get_player(pindex).play_sound({ path = "utility/cannot_build" })
            printout("Target is out of range", pindex)
         end
      elseif ent ~= nil then
         --If holding an item with no special left click actions, allow entity left click actions.
         clicked_on_entity(ent, pindex)
      else
         printout("No actions for " .. stack.name .. " in hand", pindex)
      end
   end
end)

--Right click actions with items in hand
script.on_event("click-hand-right", function(event)
   if ui.evt_right_click(event.player_index, { ctrl = false, alt = false, shift = false }) then return end

   pindex = event.player_index
   if not check_for_player(pindex) then return end
   local p = game.get_player(pindex)
   if players[pindex].last_click_tick == event.tick then return end
   if players[pindex].in_menu then
      return
   else
      --Not in a menu
      local stack = game.get_player(pindex).cursor_stack
      local ent = get_selected_ent(pindex)

      if stack and stack.valid_for_read and stack.valid then
         players[pindex].last_click_tick = event.tick
      else
         return
      end

      --If something is in hand...
      if
         stack.prototype ~= nil
         and (stack.prototype.place_result ~= nil or stack.prototype.place_as_tile_result ~= nil)
         and stack.name ~= "offshore-pump"
      then
         --Laterdo here: build as ghost
      elseif stack.is_blueprint then
         fa_blueprints.blueprint_menu_open(pindex)
      elseif stack.is_blueprint_book then
         fa_blueprints.blueprint_book_menu_open(pindex, false)
      elseif stack.is_deconstruction_item then
         --Cancel deconstruction
         local pex = players[pindex]
         if pex.bp_selecting ~= true then
            pex.bp_selecting = true
            pex.bp_select_point_1 = pex.cursor_pos
            printout(
               "Started deconstruction selection at "
                  .. math.floor(pex.cursor_pos.x)
                  .. ","
                  .. math.floor(pex.cursor_pos.y),
               pindex
            )
         else
            pex.bp_selecting = false
            pex.bp_select_point_2 = pex.cursor_pos
            --Cancel area for deconstruction
            local left_top, right_bottom =
               fa_utils.get_top_left_and_bottom_right(pex.bp_select_point_1, pex.bp_select_point_2)
            p.surface.cancel_deconstruct_area({
               area = { left_top, right_bottom },
               force = p.force,
               player = p,
               item = p.cursor_stack,
            })
            printout("Canceled deconstruction in selected area", pindex)
         end
      elseif stack.is_upgrade_item then
         local pex = players[pindex]
         if pex.bp_selecting ~= true then
            pex.bp_selecting = true
            pex.bp_select_point_1 = pex.cursor_pos
            printout(
               "Started upgrading selection at " .. math.floor(pex.cursor_pos.x) .. "," .. math.floor(pex.cursor_pos.y),
               pindex
            )
         else
            pex.bp_selecting = false
            pex.bp_select_point_2 = pex.cursor_pos
            --Cancel area for upgrading
            local left_top, right_bottom =
               fa_utils.get_top_left_and_bottom_right(pex.bp_select_point_1, pex.bp_select_point_2)
            p.surface.cancel_upgrade_area({
               area = { left_top, right_bottom },
               force = p.force,
               player = p,
               item = p.cursor_stack,
            })
            printout("Canceled upgrading in selected area", pindex)
         end
      elseif stack.name == "spidertron-remote" then
         --open spidermenu with the remote in hand
         fa_spidertrons.spider_menu_open(pindex, stack)
      end
   end
end)

--Left click actions with no menu and no items in hand
script.on_event("click-entity", function(event)
   if ui.evt_left_click(event.player_index, { ctrl = false, shift = false, alt = false }) then return end

   pindex = event.player_index
   if not check_for_player(pindex) then return end
   if players[pindex].last_click_tick == event.tick then return end
   if players[pindex].vanilla_mode == true then return end
   if players[pindex].in_menu then
      return
   else
      --Not in a menu
      local stack = game.get_player(pindex).cursor_stack
      local ghost = game.get_player(pindex).cursor_ghost
      local ent = get_selected_ent(pindex)

      if ghost or (stack and stack.valid_for_read and stack.valid) then
         return
      else
         players[pindex].last_click_tick = event.tick
      end

      --If the hand is empty...
      clicked_on_entity(ent, pindex)
   end
end)

function clicked_on_entity(ent, pindex)
   local p = game.get_player(pindex)
   if p.vehicle ~= nil and p.vehicle.train ~= nil then
      --If player is on a train, open it
      fa_trains.menu_open(pindex)
      return
   elseif ent == nil then
      --No entity clicked
      p.selected = nil
      return
   elseif not ent.valid then
      --Invalid entity clicked
      p.print("Invalid entity clicked", { volume_modifier = 0 })
      if p.opened ~= nil and p.opened.object_name == "LuaEntity" and p.opened.valid then
         p.print("Opened " .. p.opened.name, { volume_modifier = 0 })
         ent = p.opened
         return
      else
         p.selected = nil
         return
      end
   end
   if p.character and p.character.unit_number == ent.unit_number then
      --Self click
      return
   end

   p.selected = ent
   if ent.name == "locomotive" then
      --For a rail vehicle, open train menu
      fa_trains.menu_open(pindex)
   elseif ent.name == "train-stop" then
      --For a train stop, open train stop menu
      fa_train_stops.train_stop_menu_open(pindex)
   elseif ent.name == "roboport" then
      --For a roboport, open roboport menu
      fa_bot_logistics.roboport_menu_open(pindex)
   elseif ent.type == "power-switch" then
      --Toggle it, if in manual mode
      if (#ent.neighbours.red + #ent.neighbours.green) > 0 then
         printout("observes circuit condition", pindex)
      else
         ent.power_switch_state = not ent.power_switch_state
         if ent.power_switch_state == true then
            printout("Switched on", pindex)
         elseif ent.power_switch_state == false then
            printout("Switched off", pindex)
         end
      end
   elseif ent.type == "constant-combinator" then
      --Toggle it
      ent.get_control_behavior().enabled = not ent.get_control_behavior().enabled
      local enabled = ent.get_control_behavior().enabled
      if enabled == true then
         printout("Switched on", pindex)
      elseif enabled == false then
         printout("Switched off", pindex)
      end
   elseif ent.operable and ent.prototype.is_building then
      --If checking an operable building, open its menu
      fa_sectors.open_operable_building(ent, pindex)
   elseif ent.type == "car" or ent.type == "spider-vehicle" or ent.train ~= nil then
      fa_sectors.open_operable_vehicle(ent, pindex)
   elseif ent.type == "spider-leg" then
      --Find and open the spider
      local spiders =
         ent.surface.find_entities_filtered({ position = ent.position, radius = 5, type = "spider-vehicle" })
      local spider = ent.surface.get_closest(ent.position, spiders)
      if spider and spider.valid then fa_sectors.open_operable_vehicle(spider, pindex) end
   elseif ent.name == "rocket-silo-rocket-shadow" or ent.name == "rocket-silo-rocket" then
      --Find and open the silo
      local silos = ent.surface.find_entities_filtered({ position = ent.position, radius = 5, type = "rocket-silo" })
      local silo = ent.surface.get_closest(ent.position, silos)
      if silo and silo.valid then fa_sectors.open_operable_building(silo, pindex) end
   elseif ent.operable then
      printout("No menu for " .. ent.name, pindex)
   elseif ent.type == "resource" and ent.name ~= "crude-oil" and ent.name ~= "uranium-ore" then
      printout("No menu for " .. ent.name .. " but it can be mined by hand.", pindex)
   else
      printout("No menu for " .. ent.name, pindex)
   end
end

--For a building, opens circuit menu
script.on_event("open-circuit-menu", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   local p = game.get_player(pindex)
   --In a building menu
   if
      players[pindex].menu == "building"
      or players[pindex].menu == "building_no_sectors"
      or players[pindex].menu == "belt"
   then
      local ent = p.opened
      if ent == nil or ent.valid == false then
         printout("Error: Missing building interface", pindex)
         return
      end
      if ent.type == "electric-pole" then
         --Open the menu
         fa_circuits.circuit_network_menu_open(pindex, ent)
         return
      elseif ent.type == "constant-combinator" then
         fa_circuits.circuit_network_menu_open(pindex, ent)
         return
      elseif ent.type == "arithmetic-combinator" or ent.type == "decider-combinator" then
         printout("Error: This combinator is not supported", pindex)
         return
      end
      --Building has control behavior
      local control = ent.get_control_behavior()
      if control == nil then
         printout("No control behavior for this building", pindex)
         return
      end
      --Building has a circuit network
      local nw1 = control.get_circuit_network(defines.wire_type.red)
      local nw2 = control.get_circuit_network(defines.wire_type.green)
      if nw1 == nil and nw2 == nil then
         printout(" not connected to a circuit network", pindex)
         return
      end
      --Open the menu
      fa_circuits.circuit_network_menu_open(pindex, ent)
   elseif players[pindex].in_menu == false then
      local ent = p.selected or get_selected_ent(pindex)
      if ent == nil or ent.valid == false or (ent.get_control_behavior() == nil and ent.type ~= "electric-pole") then
         --Sort scan results instead
         return
      end
      --Building has a circuit network
      p.opened = ent
      if ent.type == "electric-pole" then
         --Open the menu
         fa_circuits.circuit_network_menu_open(pindex, ent)
         return
      elseif ent.type == "constant-combinator" then
         fa_circuits.circuit_network_menu_open(pindex, ent)
         return
      elseif ent.type == "arithmetic-combinator" or ent.type == "decider-combinator" then
         printout("Error: This combinator is not supported", pindex)
         return
      end
      local control = ent.get_control_behavior()
      local nw1 = control.get_circuit_network(defines.wire_type.red)
      local nw2 = control.get_circuit_network(defines.wire_type.green)
      if nw1 == nil and nw2 == nil then
         printout(fa_localising.get(ent, pindex) .. " not connected to a circuit network", pindex)
         return
      end
      --Open the menu
      fa_circuits.circuit_network_menu_open(pindex, ent)
   end
end)

script.on_event("repair-area", function(event)
   if ui.evt_left_click(event.player_index, { ctrl = true, shift = true, alt = false }) then return end

   pindex = event.player_index
   if not check_for_player(pindex) then return end
   if players[pindex].last_click_tick == event.tick then return end
   if players[pindex].in_menu then
      return
   else
      --Not in a menu
      local stack = game.get_player(pindex).cursor_stack
      local ent = get_selected_ent(pindex)

      if stack and stack.valid_for_read and stack.valid then
         players[pindex].last_click_tick = event.tick
      else
         return
      end

      --If something is in hand...
      if stack.is_repair_tool then
         --If holding a repair pack
         fa_combat.repair_area(math.ceil(game.get_player(pindex).reach_distance), pindex)
      end
   end
end)

script.on_event("crafting-all", function(event)
   if ui.evt_left_click(event.player_index, { ctrl = false, shift = true, alt = false }) then return end

   pindex = event.player_index
   if not check_for_player(pindex) then return end
   if players[pindex].in_menu then
      if players[pindex].menu == "crafting" then
         local recipe =
            players[pindex].crafting.lua_recipes[players[pindex].crafting.category][players[pindex].crafting.index]
         local T = {
            count = game.get_player(pindex).get_craftable_count(recipe),
            recipe = players[pindex].crafting.lua_recipes[players[pindex].crafting.category][players[pindex].crafting.index],
            silent = false,
         }
         local count = game.get_player(pindex).begin_crafting(T)
         if count > 0 then
            local total_count = fa_crafting.count_in_crafting_queue(T.recipe.name, pindex)
            printout(
               "Started crafting "
                  .. count
                  .. " "
                  .. fa_localising.get_recipe_from_name(recipe.name, pindex)
                  .. ", "
                  .. total_count
                  .. " total in queue",
               pindex
            )
         else
            printout("Not enough materials", pindex)
         end
      elseif players[pindex].menu == "crafting_queue" then
         fa_crafting.load_crafting_queue(pindex)
         if players[pindex].crafting_queue.max >= 1 then
            local T = {
               index = players[pindex].crafting_queue.index,
               count = players[pindex].crafting_queue.lua_queue[players[pindex].crafting_queue.index].count,
            }
            game.get_player(pindex).cancel_crafting(T)
            fa_crafting.load_crafting_queue(pindex)
            fa_crafting.read_crafting_queue(pindex, "cancelled all, ")
         end
      end
   end
end)

--Transfers a stack from one inventory to another. Preserves BP data.
script.on_event("transfer-one-stack", function(event)
   if ui.evt_left_click(event.player_index, { ctrl = false, shift = true, alt = false }) then return end

   pindex = event.player_index
   if not check_for_player(pindex) then return end
   if players[pindex].in_menu then
      if players[pindex].menu == "building" or players[pindex].menu == "vehicle" then
         if
            players[pindex].building.sector <= #players[pindex].building.sectors
            and #players[pindex].building.sectors[players[pindex].building.sector].inventory > 0
            and players[pindex].building.sectors[players[pindex].building.sector].name ~= "Fluid"
         then
            --Transfer stack from building to player inventory
            local stack =
               players[pindex].building.sectors[players[pindex].building.sector].inventory[players[pindex].building.index]
            if stack and stack.valid and stack.valid_for_read then
               if
                  players[pindex].menu == "vehicle"
                  and game.get_player(pindex).opened.type == "spider-vehicle"
                  and stack.prototype.place_as_equipment_result ~= nil
               then
                  return
               end
               if game.get_player(pindex).can_insert(stack) then
                  game.get_player(pindex).play_sound({ path = "utility/inventory_move" })
                  local result = stack.name
                  local inserted = game.get_player(pindex).insert(stack)
                  players[pindex].building.sectors[players[pindex].building.sector].inventory.remove({
                     name = stack.name,
                     count = inserted,
                  })
                  result = "Moved " .. inserted .. " " .. result .. " to player's inventory." --**laterdo note that ammo gets inserted to ammo slots first
                  printout(result, pindex)
               else
                  local result = "Cannot insert " .. stack.name .. " to player's inventory, "
                  if game.get_player(pindex).get_main_inventory().count_empty_stacks() == 0 then
                     result = result .. "because it is full."
                  end
                  printout(result, pindex)
               end
            end
         else
            local offset = 1
            if players[pindex].building.recipe_list ~= nil then offset = offset + 1 end
            if players[pindex].building.sector == #players[pindex].building.sectors + offset then
               --Transfer stack from player inventory to building
               local stack = players[pindex].inventory.lua_inventory[players[pindex].inventory.index]
               if stack and stack.valid and stack.valid_for_read then
                  if
                     players[pindex].menu == "vehicle"
                     and game.get_player(pindex).opened.type == "spider-vehicle"
                     and stack.prototype.place_as_equipment_result ~= nil
                  then
                     return
                  end
                  if players[pindex].building.ent.can_insert(stack) then
                     game.get_player(pindex).play_sound({ path = "utility/inventory_move" })
                     local result = stack.name
                     local inserted = players[pindex].building.ent.insert(stack)
                     players[pindex].inventory.lua_inventory.remove({ name = stack.name, count = inserted })
                     result = "Moved " .. inserted .. " " .. result .. " to " .. players[pindex].building.ent.name
                     printout(result, pindex)
                  else
                     local result = "Cannot insert " .. stack.name .. " to " .. players[pindex].building.ent.name
                     printout(result, pindex)
                  end
               end
            end
         end
      end
   end
end)

--You can equip armor, armor equipment, guns, ammo. You can equip from the hand, or from the inventory with an empty hand.
script.on_event("equip-item", function(event)
   if ui.evt_left_click(event.player_index, { ctrl = false, shift = true, alt = false }) then return end

   pindex = event.player_index
   if not check_for_player(pindex) then return end
   local stack = game.get_player(pindex).cursor_stack
   local result = ""
   if stack ~= nil and stack.valid_for_read and stack.valid then
      --Equip item grabbed in hand, for selected menus
      if
         not players[pindex].in_menu
         or players[pindex].menu == "inventory"
         or (players[pindex].menu == "vehicle" and game.get_player(pindex).opened.type == "spider-vehicle")
      then
         result = fa_equipment.equip_it(stack, pindex)
      end
   elseif players[pindex].menu == "inventory" then
      --Equip the selected item from its inventory slot directly
      local stack = game.get_player(pindex).get_main_inventory()[players[pindex].inventory.index]
      result = fa_equipment.equip_it(stack, pindex)
   elseif players[pindex].menu == "vehicle" and game.get_player(pindex).opened.type == "spider-vehicle" then
      --Equip the selected item from its inventory slot directly
      local stack
      if players[pindex].building.sector <= #players[pindex].building.sectors then
         local invs = defines.inventory
         stack = game.get_player(pindex).opened.get_inventory(invs.spider_trunk)[players[pindex].building.index]
      else
         stack = players[pindex].inventory.lua_inventory[players[pindex].inventory.index]
      end
      result = fa_equipment.equip_it(stack, pindex)
   elseif players[pindex].menu == "building" or players[pindex].menu == "vehicle" then
      --Something will be smart-inserted so do nothing here
      return
   end

   if result ~= "" then
      --game.get_player(pindex).print(result)--**
      printout(result, pindex)
   end
end)

--Has the same input as the ghost placement function and so it uses that
script.on_event("open-rail-builder", function(event)
   if ui.evt_left_click(event.player_index, { ctrl = false, shift = true, alt = false }) then return end

   pindex = event.player_index
   if not check_for_player(pindex) then return end
   if players[pindex].in_menu then
      if players[pindex].ghost_rail_planning == true then game.get_player(pindex).clear_cursor() end
      return
   elseif players[pindex].ghost_rail_planning == true then
      fa_rails.end_ghost_rail_planning(pindex)
   else
      --Not in a menu
      local ent = get_selected_ent(pindex)
      local stack = game.get_player(pindex).cursor_stack
      if ent then
         if ent.name == "straight-rail" then
            --If holding a rail item and selecting the tip of the end rail, notify about the ghost rail planner activation
            local ghost_rail_case = false
            if stack and stack.valid_for_read and stack.name == "rail" then
               ghost_rail_case = fa_rails.cursor_is_at_straight_end_rail_tip(pindex)
            end
            ghost_rail_case = false --keep this feature off for now
            if ghost_rail_case then
               fa_rails.start_ghost_rail_planning(pindex)
            else
               --Open rail builder
               game.get_player(pindex).clear_cursor()
               fa_rail_builder.open_menu(pindex, ent)
            end
         elseif ent.name == "curved-rail" then
            printout("Rail builder menu cannot use curved rails.", pindex)
         end
      end
   end
end)

script.on_event("quick-build-rail-left-turn", function(event)
   local pindex = event.player_index
   if not check_for_player(pindex) then return end
   local ent = get_selected_ent(pindex)
   if not ent then return end
   --Build left turns on end rails
   if ent.name == "straight-rail" then fa_rail_builder.build_rail_turn_left_45_degrees(ent, pindex) end
end)

script.on_event("quick-build-rail-right-turn", function(event)
   local pindex = event.player_index
   if not check_for_player(pindex) then return end
   local ent = get_selected_ent(pindex)
   if not ent then return end
   --Build left turns on end rails
   if ent.name == "straight-rail" then fa_rail_builder.build_rail_turn_right_45_degrees(ent, pindex) end
end)

--[[Imitates vanilla behavior: 
* Control click an item in an inventory to try smart transfer ALL of it. 
* Control click an empty slot to try to smart transfer ALL items from that inventory.
]]
script.on_event("transfer-all-stacks", function(event)
   if ui.evt_left_click(event.player_index, { ctrl = true, shift = false, alt = false }) then return end

   pindex = event.player_index
   if not check_for_player(pindex) then return end

   if players[pindex].in_menu then
      if players[pindex].menu == "building" or players[pindex].menu == "vehicle" then
         do_multi_stack_transfer(1, pindex)
      end
   end
end)

--Default is control clicking
script.on_event("fa-alternate-build", function(event)
   if ui.evt_left_click(event.player_index, { ctrl = true, shift = false, alt = false }) then return end

   pindex = event.player_index
   if not check_for_player(pindex) then return end

   if players[pindex].in_menu then
      return
   else
      --Not in a menu
      local stack = game.get_player(pindex).cursor_stack
      local ent = get_selected_ent(pindex)
      if stack == nil or stack.valid_for_read == false or stack.valid == false then
         return
      elseif stack.name == "rail" then
         --Straight rail free placement
         fa_building_tools.build_item_in_hand(pindex, true)
      elseif stack.name == "steam-engine" then
         fa_building_tools.snap_place_steam_engine_to_a_boiler(pindex)
      end
   end
end)

--[[Imitates vanilla behavior: 
* Control click an item in an inventory to try smart transfer HALF of it. 
* Control click an empty slot to try to smart transfer HALF of all items from that inventory.
]]
script.on_event("transfer-half-of-all-stacks", function(event)
   if ui.evt_right_click(event.player_index, { ctrl = true, shift = false, alt = false }) then return end

   pindex = event.player_index
   if not check_for_player(pindex) then return end

   if players[pindex].in_menu then
      if players[pindex].menu == "building" or players[pindex].menu == "vehicle" then
         do_multi_stack_transfer(0.5, pindex)
      end
   end
end)

--[[Manages inventory transfers that are bigger than one stack. 
* Has checks and printouts!
]]
function do_multi_stack_transfer(ratio, pindex)
   local result = { "" }
   local sector = players[pindex].building.sectors[players[pindex].building.sector]
   if sector and sector.name ~= "Fluid" and players[pindex].building.sector_name ~= "player_inventory" then
      --This is the section where we move from the building to the player.
      local item_name = ""
      local stack = sector.inventory[players[pindex].building.index]
      if stack and stack.valid and stack.valid_for_read then item_name = stack.name end

      local moved, full =
         transfer_inventory({ from = sector.inventory, to = game.players[pindex], name = item_name, ratio = ratio })
      if full then
         table.insert(result, { "inventory-full-message.main" })
         table.insert(result, ", ")
      end
      if table_size(moved) == 0 then
         table.insert(result, { "access.grabbed-nothing" })
      else
         game.get_player(pindex).play_sound({ path = "utility/inventory_move" })
         local item_list = { "" }
         local other_items = 0
         local listed_count = 0
         for name, amount in pairs(moved) do
            if listed_count <= 5 then
               table.insert(item_list, { "access.item-quantity", game.item_prototypes[name].localised_name, amount })
               table.insert(item_list, ", ")
            else
               other_items = other_items + amount
            end
            listed_count = listed_count + 1
         end
         if other_items > 0 then
            table.insert(item_list, { "access.item-quantity", "other items", other_items }) --***todo localize "other items
            table.insert(item_list, ", ")
         end
         --trim traling comma off
         item_list[#item_list] = nil
         table.insert(result, { "access.grabbed-stuff", item_list })
      end
   elseif sector and sector.name == "fluid" then
      --Do nothing
   else
      local offset = 1
      if players[pindex].building.recipe_list ~= nil then offset = offset + 1 end
      if players[pindex].building.sector_name == "player_inventory" then
         game.print("path 3b")
         --This is the section where we move from the player to the building.
         local item_name = ""
         local stack = players[pindex].inventory.lua_inventory[players[pindex].inventory.index]
         if stack and stack.valid and stack.valid_for_read then item_name = stack.name end

         local moved, full = transfer_inventory({
            from = game.get_player(pindex).get_main_inventory(),
            to = players[pindex].building.ent,
            name = item_name,
            ratio = ratio,
         })

         if full then table.insert(result, "Inventory full or not applicable, ") end
         if table_size(moved) == 0 then
            table.insert(result, { "access.placed-nothing" })
         else
            game.get_player(pindex).play_sound({ path = "utility/inventory_move" })
            local item_list = { "" }
            local other_items = 0
            local listed_count = 0
            for name, amount in pairs(moved) do
               if listed_count <= 5 then
                  table.insert(item_list, { "access.item-quantity", game.item_prototypes[name].localised_name, amount })
                  table.insert(item_list, ", ")
               else
                  other_items = other_items + amount
               end
               listed_count = listed_count + 1
            end
            if other_items > 0 then
               table.insert(item_list, { "access.item-quantity", "other items", other_items }) --***todo localize "other items
               table.insert(item_list, ", ")
            end
            --trim trailing comma off
            item_list[#item_list] = nil
            table.insert(result, { "access.placed-stuff", fa_utils.breakup_string(item_list) })
         end
      end
   end
   printout(result, pindex)
   --game.print(players[pindex].building.sector_name or "(nil)")--**
end

--[[Transfers multiple stacks of a specific item (or all items) to/from the player inventory from/to a building inventory.
* item name / empty string to indicate transfering everything
* ratio (between 0 and 1), the ratio of the total count to transder for each item.
* Has no checks or printouts!
* persistent bug ***: only 1 inv transfer from player inv to chest can work, after that for some reason it always both inserts and takes back
]]
function transfer_inventory(args)
   args.name = args.name or ""
   args.ratio = args.ratio or 1
   local transfer_list = {}
   if args.name ~= "" then
      --Known name: transfer only this
      transfer_list[args.name] = args.from.get_item_count(args.name)
   elseif args.name == "blueprint" or args.name == "blueprint-book" then
      return {}, false
   else
      --No name: Transfer everything
      transfer_list = args.from.get_contents()
   end
   local full = false
   local res = {}
   for name, amount in pairs(transfer_list) do
      if name ~= "blueprint" and name ~= "blueprint-book" then
         amount = math.ceil(amount * args.ratio)
         local actual_amount = args.to.insert({ name = name, count = amount })
         if actual_amount ~= amount then
            print(name, amount, actual_amount)
            amount = actual_amount
            full = true
         end
         if amount > 0 then
            res[name] = amount
            args.from.remove({ name = name, count = amount })
         end
      end
   end
   --game.print("run 1x: " .. args.name)--**
   return res, full
end

script.on_event("crafting-5", function(event)
   if ui.evt_right_click(event.player_index, { ctrl = false, shift = false, alt = false }) then return end

   pindex = event.player_index
   if not check_for_player(pindex) then return end
   local ent = get_selected_ent(pindex)
   local stack = game.get_player(pindex).cursor_stack
   if players[pindex].in_menu then
      if players[pindex].menu == "crafting" then
         local recipe =
            players[pindex].crafting.lua_recipes[players[pindex].crafting.category][players[pindex].crafting.index]
         local T = {
            count = 5,
            recipe = players[pindex].crafting.lua_recipes[players[pindex].crafting.category][players[pindex].crafting.index],
            silent = false,
         }
         local count = game.get_player(pindex).begin_crafting(T)
         if count > 0 then
            local total_count = fa_crafting.count_in_crafting_queue(T.recipe.name, pindex)
            printout(
               "Started crafting "
                  .. count
                  .. " "
                  .. fa_localising.get_recipe_from_name(recipe.name, pindex)
                  .. ", "
                  .. total_count
                  .. " total in queue",
               pindex
            )
         else
            printout("Not enough materials", pindex)
         end
      elseif players[pindex].menu == "crafting_queue" then
         fa_crafting.load_crafting_queue(pindex)
         if players[pindex].crafting_queue.max >= 1 then
            local T = {
               index = players[pindex].crafting_queue.index,
               count = 5,
            }
            game.get_player(pindex).cancel_crafting(T)
            fa_crafting.load_crafting_queue(pindex)
            fa_crafting.read_crafting_queue(pindex, "cancelled 5, ")
         end
      end
   end
end)

script.on_event("menu-clear-filter", function(event)
   if ui.evt_right_click(event.player_index, { ctrl = false, shift = false, alt = false }) then return end

   pindex = event.player_index
   if not check_for_player(pindex) then return end
   local ent = get_selected_ent(pindex)
   local stack = game.get_player(pindex).cursor_stack
   if players[pindex].in_menu then
      if players[pindex].menu == "building" or players[pindex].menu == "vehicle" then
         local stack = game.get_player(pindex).cursor_stack
         if players[pindex].building.sector <= #players[pindex].building.sectors then
            if stack and stack.valid_for_read and stack.valid and stack.count > 0 then
               local iName = players[pindex].building.sectors[players[pindex].building.sector].name
               if
                  iName == "Filters"
                  and players[pindex].item_selection == false
                  and players[pindex].building.index
                     < #players[pindex].building.sectors[players[pindex].building.sector].inventory
               then
                  players[pindex].building.ent.set_filter(players[pindex].building.index, nil)
                  players[pindex].building.sectors[players[pindex].building.sector].inventory[players[pindex].building.index] =
                     "No filter selected."
                  printout("Filter cleared", pindex)
               end
            elseif
               players[pindex].building.sectors[players[pindex].building.sector].name == "Filters"
               and players[pindex].building.item_selection == false
               and players[pindex].building.index
                  < #players[pindex].building.sectors[players[pindex].building.sector].inventory
            then
               players[pindex].building.ent.set_filter(players[pindex].building.index, nil)
               players[pindex].building.sectors[players[pindex].building.sector].inventory[players[pindex].building.index] =
                  "No filter selected."
               printout("Filter cleared.", pindex)
            end
         end
      end
   end
end)

--Reads the entity status but also adds on extra info depending on the entity
script.on_event("read-entity-status", function(event)
   if ui.evt_right_click(event.player_index, { ctrl = false, shift = false, alt = false }) then return end

   pindex = event.player_index
   if not check_for_player(pindex) then return end
   local ent = get_selected_ent(pindex)
   if not ent then return end
   local stack = game.get_player(pindex).cursor_stack
   if players[pindex].in_menu then return end
   --Print out the status of a machine, if it exists.
   local result = { "" }
   local ent_status_id = ent.status
   local ent_status_text = ""
   local status_lookup = fa_utils.into_lookup(defines.entity_status)
   status_lookup[23] = "Full burnt result output" --weird exception
   if ent.name == "cargo-wagon" then
      --Instead of status, read contents
      table.insert(result, fa_trains.cargo_wagon_top_contents_info(ent))
   elseif ent.name == "fluid-wagon" then
      --Instead of status, read contents
      table.insert(result, fa_trains.fluid_contents_info(ent))
   elseif ent_status_id ~= nil then
      --Print status if it exists
      ent_status_text = status_lookup[ent_status_id]
      if ent_status_text == nil then
         print("Weird no entity status lookup" .. ent.name .. "-" .. ent.type .. "-" .. ent.status)
      end
      table.insert(result, { "entity-status." .. ent_status_text:gsub("_", "-") })
   else --There is no status
      --When there is no status, for entities with fuel inventories, read that out instead. This is typical for vehicles.
      if ent.get_fuel_inventory() ~= nil then
         table.insert(result, fa_driving.fuel_inventory_info(ent))
      elseif ent.type == "electric-pole" then
         --For electric poles with no power flow, report the nearest electric pole with a power flow.
         if fa_electrical.get_electricity_satisfaction(ent) > 0 then
            table.insert(
               result,
               fa_electrical.get_electricity_satisfaction(ent)
                  .. " percent network satisfaction, with "
                  .. fa_electrical.get_electricity_flow_info(ent)
            )
         else
            table.insert(result, "No power, " .. fa_electrical.report_nearest_supplied_electric_pole(ent))
         end
      else
         table.insert(result, "No status.")
      end
   end
   --For working or normal entities, give some extra info about specific entities.
   if #result == 1 then table.insert(result, "result error") end

   --For working or normal entities, give some extra info about specific entities in terms of speeds or bonuses.
   local list = defines.entity_status
   if
      ent.status ~= nil
      and ent.status ~= list.no_power
      and ent.status ~= list.no_power
      and ent.status ~= list.no_fuel
   then
      if ent.type == "inserter" then --items per minute based on rotation speed and the STATED hand capacity
         local cap = ent.force.inserter_stack_size_bonus + 1
         if ent.name == "stack-inserter" or ent.name == "stack-filter-inserter" then
            cap = ent.force.stack_inserter_capacity_bonus + 1
         end
         local rate = string.format(" %.1f ", cap * ent.prototype.inserter_rotation_speed * 57.5)
         table.insert(result, ", can move " .. rate .. " items per second, with a hand capacity of " .. cap)
      end
      if ent.prototype ~= nil and ent.prototype.belt_speed ~= nil and ent.prototype.belt_speed > 0 then --items per minute by simple reading
         if ent.type == "splitter" then
            table.insert(
               result,
               ", can process " .. math.floor(ent.prototype.belt_speed * 480 * 2) .. " items per second"
            )
         else
            table.insert(result, ", can move " .. math.floor(ent.prototype.belt_speed * 480) .. " items per second")
         end
      end
      if ent.type == "assembling-machine" or ent.type == "furnace" then --Crafting cycles per minute based on recipe time and the STATED craft speed ; laterdo maybe extend this to all "crafting machine" types?
         local progress = ent.crafting_progress
         local speed = ent.crafting_speed
         local recipe_time = 0
         local cycles = 0 -- crafting cycles completed per minute for this recipe
         if ent.get_recipe() ~= nil and ent.get_recipe().valid then
            recipe_time = ent.get_recipe().energy
            cycles = 60 / recipe_time * speed
         end
         local cycles_string = string.format(" %.2f ", cycles)
         if cycles == math.floor(cycles) then cycles_string = string.format(" %d ", cycles) end
         local speed_string = string.format(" %.2f ", speed)
         if speed == math.floor(speed) then speed_string = string.format(" %d ", cycles) end
         if cycles < 10 then --more than 6 seconds to craft
            table.insert(result, ", recipe progress " .. math.floor(progress * 100) .. " percent ")
         end
         if cycles > 0 then table.insert(result, ", can complete " .. cycles_string .. " recipe cycles per minute ") end
         table.insert(
            result,
            ", with a crafting speed of "
               .. speed_string
               .. ", at "
               .. math.floor(100 * (1 + ent.speed_bonus) + 0.5)
               .. " percent "
         )
         if ent.productivity_bonus ~= 0 then
            table.insert(
               result,
               ", with productivity bonus " .. math.floor(100 * (0 + ent.productivity_bonus) + 0.5) .. " percent "
            )
         end
      elseif ent.type == "mining-drill" then
         table.insert(
            result,
            ", producing "
               .. string.format(" %.2f ", ent.prototype.mining_speed * 60 * (1 + ent.speed_bonus))
               .. " items per minute "
         )
         if ent.speed_bonus ~= 0 then
            table.insert(result, ", with speed " .. math.floor(100 * (1 + ent.speed_bonus) + 0.5) .. " percent ")
         end
         if ent.productivity_bonus ~= 0 then
            table.insert(
               result,
               ", with productivity bonus " .. math.floor(100 * (0 + ent.productivity_bonus) + 0.5) .. " percent "
            )
         end
      elseif ent.name == "lab" then
         if ent.speed_bonus ~= 0 then
            table.insert(
               result,
               ", with speed "
                  .. math.floor(
                     100
                           * (1 + ent.force.laboratory_speed_modifier * (1 + (ent.speed_bonus - ent.force.laboratory_speed_modifier)))
                        + 0.5
                  )
                  .. " percent "
            ) --laterdo fix bug**
            --game.get_player(pindex).print(result)
         end
         if ent.productivity_bonus ~= 0 then
            table.insert(
               result,
               ", with productivity bonus "
                  .. math.floor(100 * (0 + ent.productivity_bonus + ent.force.laboratory_productivity_bonus) + 0.5)
                  .. " percent "
            )
         end
      else --All other entities with the an applicable status
         if ent.speed_bonus ~= 0 then
            table.insert(result, ", with speed " .. math.floor(100 * (1 + ent.speed_bonus) + 0.5) .. " percent ")
         end
         if ent.productivity_bonus ~= 0 then
            table.insert(
               result,
               ", with productivity bonus " .. math.floor(100 * (0 + ent.productivity_bonus) + 0.5) .. " percent "
            )
         end
      end
      --laterdo maybe pump speed?
   end

   --Entity power usage
   local power_rate = (1 + ent.consumption_bonus)
   local drain = ent.electric_drain
   if drain ~= nil then
      drain = drain * 60
   else
      drain = 0
   end
   local uses_energy = false
   if
      drain > 0
      or (ent.prototype ~= nil and ent.prototype.max_energy_usage ~= nil and ent.prototype.max_energy_usage > 0)
   then
      uses_energy = true
   end
   if ent.status ~= nil and uses_energy and ent.status == list.working then
      table.insert(
         result,
         ", consuming " .. fa_electrical.get_power_string(ent.prototype.max_energy_usage * 60 * power_rate + drain)
      )
   elseif ent.status ~= nil and uses_energy and ent.status == list.no_power or ent.status == list.low_power then
      table.insert(
         result,
         ", consuming less than "
            .. fa_electrical.get_power_string(ent.prototype.max_energy_usage * 60 * power_rate + drain)
      )
   elseif
      ent.status ~= nil and uses_energy
      or (ent.prototype ~= nil and ent.prototype.max_energy_usage ~= nil and ent.prototype.max_energy_usage > 0)
   then
      table.insert(result, ", idle and consuming " .. fa_electrical.get_power_string(drain))
   end
   if uses_energy and ent.prototype.burner_prototype ~= nil then table.insert(result, " as burner fuel ") end

   --Entity Health
   if ent.is_entity_with_health and ent.get_health_ratio() == 1 then
      table.insert(result, { "access.full-health" })
   elseif ent.is_entity_with_health then
      table.insert(result, { "access.percent-health", math.floor(ent.get_health_ratio() * 100) })
   end

   -- Report nearest rail intersection position -- laterdo find better keybind
   if ent.name == "straight-rail" then
      local nearest, dist = fa_rails.find_nearest_intersection(ent, pindex)
      if nearest == nil then
         table.insert(result, ", no rail intersections within " .. dist .. " tiles ")
      else
         table.insert(
            result,
            ", nearest rail intersection at "
               .. dist
               .. " "
               .. fa_utils.direction_lookup(fa_utils.get_direction_biased(nearest.position, ent.position))
         )
      end
   end

   --Spawners: Report evolution factor
   if ent.type == "unit-spawner" then
      table.insert(result, ", evolution factor " .. math.floor(1000 * ent.force.evolution_factor) / 1000)
   end

   printout(result, pindex)
   --game.get_player(pindex).print(result)--**
end)

script.on_event("rotate-building", function(event)
   fa_building_tools.rotate_building_info_read(event, true)
end)

script.on_event("reverse-rotate-building", function(event)
   fa_building_tools.rotate_building_info_read(event, false)
end)

script.on_event("flip-blueprint-horizontal-info", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   local p = game.get_player(pindex)
   local bp = p.cursor_stack
   if bp == nil or bp.valid_for_read == false or bp.is_blueprint == false then return end
   printout("Flipping horizontal", pindex)
end)

script.on_event("flip-blueprint-vertical-info", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   local p = game.get_player(pindex)
   local bp = p.cursor_stack
   if bp == nil or bp.valid_for_read == false or bp.is_blueprint == false then return end
   printout("Flipping vertical", pindex)
end)

script.on_event("inventory-read-weapons-data", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   if not players[pindex].in_menu then
      return
   elseif players[pindex].menu == "inventory" then
      --Read Weapon data
      local result = fa_equipment.read_weapons_and_ammo(pindex)
      --game.get_player(pindex).print(result)--
      printout(result, pindex)
   end
end)

script.on_event("inventory-reload-weapons", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   if players[pindex].menu == "inventory" then
      --Reload weapons
      local result = fa_equipment.reload_weapons(pindex)
      --game.get_player(pindex).print(result)
      printout(result, pindex)
   end
end)

script.on_event("inventory-remove-all-weapons-and-ammo", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   if players[pindex].menu == "inventory" then
      local result = fa_equipment.remove_weapons_and_ammo(pindex)
      --game.get_player(pindex).print(result)
      printout(result, pindex)
   end
end)

--Reads the custom info for an item selected. If you are driving, it returns custom vehicle info
script.on_event("item-info", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   if game.get_player(pindex).driving and players[pindex].menu ~= "train_menu" then
      printout(fa_driving.vehicle_info(pindex), pindex)
      return
   end
   local offset = 0
   if
      (players[pindex].menu == "building" or players[pindex].menu == "vehicle")
      and players[pindex].building.recipe_list ~= nil
   then
      offset = 1
   end
   if not players[pindex].in_menu then
      local ent = get_selected_ent(pindex)
      if ent and ent.valid then
         game.get_player(pindex).selected = ent
         local str = ent.localised_description
         if str == nil or str == "" then str = "No description for this entity" end
         printout(str, pindex)
      else
         printout("Nothing selected, use this key to describe an entity or item that you select.", pindex)
      end
   elseif players[pindex].in_menu then
      if
         players[pindex].menu == "inventory"
         or players[pindex].menu == "player_trash"
         or (
            (players[pindex].menu == "building" or players[pindex].menu == "vehicle")
            and players[pindex].building.sector > offset + #players[pindex].building.sectors
         )
      then
         local stack = players[pindex].inventory.lua_inventory[players[pindex].inventory.index]
         if players[pindex].menu == "player_trash" then
            stack =
               game.get_player(pindex).get_inventory(defines.inventory.character_trash)[players[pindex].inventory.index]
         end
         if stack and stack.valid_for_read and stack.valid == true then
            local str = ""
            if stack.prototype.place_result ~= nil then
               str = stack.prototype.place_result.localised_description
            else
               str = stack.prototype.localised_description
            end
            if str == nil or str == "" then str = "No description" end
            printout(str, pindex)
         else
            printout("No description", pindex)
         end
      elseif players[pindex].menu == "technology" then
         local techs = {}
         if players[pindex].technology.category == 1 then
            techs = players[pindex].technology.lua_researchable
         elseif players[pindex].technology.category == 2 then
            techs = players[pindex].technology.lua_locked
         elseif players[pindex].technology.category == 3 then
            techs = players[pindex].technology.lua_unlocked
         end

         if
            next(techs) ~= nil
            and players[pindex].technology.index > 0
            and players[pindex].technology.index <= #techs
         then
            local result = { "" }
            table.insert(result, "Description: ")
            table.insert(result, techs[players[pindex].technology.index].localised_description or "No description")
            table.insert(result, ", Rewards: ")
            local rewards = techs[players[pindex].technology.index].effects
            for i, reward in ipairs(rewards) do
               for i1, v in pairs(reward) do
                  if v then table.insert(result, ", " .. tostring(v)) end
               end
            end
            if techs[players[pindex].technology.index].name == "electronics" then
               table.insert(result, ", later technologies")
            end
            printout(result, pindex)
         end
      elseif players[pindex].menu == "crafting" then
         local recipe =
            players[pindex].crafting.lua_recipes[players[pindex].crafting.category][players[pindex].crafting.index]
         if recipe ~= nil and #recipe.products > 0 then
            local product_name = recipe.products[1].name
            ---@type LuaItemPrototype | LuaFluidPrototype
            local product = game.item_prototypes[product_name]
            local product_is_item = true
            if product == nil then
               product = game.fluid_prototypes[product_name]
               product_is_item = false
            elseif product_name == "empty-barrel" and recipe.products[2] ~= nil then
               product_name = recipe.products[2].name
               product = game.fluid_prototypes[product_name]
               product_is_item = false
            end
            ---@type LocalisedString
            local str = ""
            if product_is_item and product.place_result ~= nil then
               str = product.place_result.localised_description
            else
               str = product.localised_description
            end
            if str == nil or str == "" then str = "No description found for this" end
            printout(str, pindex)
         else
            printout("No description found, menu error", pindex)
         end
      elseif players[pindex].menu == "building" or players[pindex].menu == "vehicle" then
         if players[pindex].building.recipe_selection then
            local recipe =
               players[pindex].building.recipe_list[players[pindex].building.category][players[pindex].building.index]
            if recipe ~= nil and #recipe.products > 0 then
               local product_name = recipe.products[1].name
               local product = game.item_prototypes[product_name] or game.fluid_prototypes[product_name]
               local str = product.localised_description
               if str == nil or str == "" then str = "No description found for this" end
               printout(str, pindex)
            else
               printout("No description found, menu error", pindex)
            end
         elseif players[pindex].building.sector <= #players[pindex].building.sectors then
            local inventory = players[pindex].building.sectors[players[pindex].building.sector].inventory
            if inventory == nil or not inventory.valid then printout("No description found, menu error", pindex) end
            if
               players[pindex].building.sectors[players[pindex].building.sector].name ~= "Fluid"
               and players[pindex].building.sectors[players[pindex].building.sector].name ~= "Filters"
               and inventory.is_empty()
            then
               printout("No description found, menu error", pindex)
               return
            end
            local stack = inventory[players[pindex].building.index]
            if stack and stack.valid_for_read and stack.valid == true then
               local str = ""
               if stack.prototype.place_result ~= nil then
                  str = stack.prototype.place_result.localised_description
               else
                  str = stack.prototype.localised_description
               end
               if str == nil or str == "" then str = "No description found for this item" end
               printout(str, pindex)
            else
               printout("No description found, menu error", pindex)
            end
         end
      else --Another menu
         printout("Descriptions are not supported for this menu.", pindex)
      end
   end
end)

--Reads the custom info for the last indexed scanner item
script.on_event("item-info-last-indexed", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   if players[pindex].in_menu then
      printout("Error: Cannot check scanned item descriptions while in a menu", pindex)
      return
   end
   local ent = players[pindex].last_indexed_ent
   if ent == nil or not ent.valid then
      printout("No description, note that most resources need to be examined from up close", pindex) --laterdo find a workaround for aggregate ents
      return
   end
   local str = ent.localised_description
   if str == nil or str == "" then str = "No description found for this entity" end
   printout(str, pindex)
end)

--Read production statistics info for the selected item, in the hand or else selected in the inventory menu
script.on_event("item-production-info", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   if game.get_player(pindex).driving then return end
   local str = selected_item_production_stats_info(pindex)
   printout(str, pindex)
end)

--Gives in-game time. The night darkness is from 11 to 13, and peak daylight hours are 18 to 6.
--For realism, if we adjust by 12 hours, we get 23 to 1 as midnight and 6 to 18 as peak solar.
script.on_event("read-time-and-research-progress", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   --Get local time
   local surf = game.get_player(pindex).surface
   local hour = math.floor((24 * surf.daytime + 12) % 24)
   local minute = math.floor((24 * surf.daytime - math.floor(24 * surf.daytime)) * 60)
   local time_string = " The local time is " .. hour .. ":" .. string.format("%02d", minute) .. ", "

   --Get total playtime
   local total_hours = math.floor(game.tick / 216000)
   local total_minutes = math.floor((game.tick % 216000) / 3600)
   local total_time_string = " The total mission time is "
      .. total_hours
      .. " hours and "
      .. total_minutes
      .. " minutes "

   --Add research progress info
   local progress_string = " No research in progress, "
   local tech = game.get_player(pindex).force.current_research
   if tech ~= nil then
      local research_progress = math.floor(game.get_player(pindex).force.research_progress * 100)
      progress_string = " Researching " .. tech.name .. ", " .. research_progress .. "%, "
   end

   printout(time_string .. progress_string .. total_time_string, pindex)
   if players[pindex].vanilla_mode then game.get_player(pindex).open_technology_gui() end

   --Temporarily disable research queue, add it as a feature laterdo**
   game.get_player(pindex).force.research_queue_enabled = false
end)

--When the item in hand changes
script.on_event(defines.events.on_player_cursor_stack_changed, function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   local stack = game.get_player(pindex).cursor_stack
   local new_item_name = ""
   if stack and stack.valid_for_read then
      new_item_name = stack.name
      if stack.is_blueprint and players[pindex].blueprint_hand_direction ~= dirs.north then
         --Reset blueprint rotation
         players[pindex].blueprint_hand_direction = dirs.north
         fa_blueprints.refresh_blueprint_in_hand(pindex)
      end
   end
   if players[pindex].menu == "blueprint_menu" or players[pindex].menu == "blueprint_book_menu" then
      close_menu_resets(pindex)
   end
   if players[pindex].previous_hand_item_name ~= new_item_name then
      players[pindex].previous_hand_item_name = new_item_name
      --players[pindex].lag_building_direction = true
      read_hand(pindex)
   end
   fa_building_tools.delete_empty_planners_in_inventory(pindex)
   players[pindex].bp_selecting = false
   players[pindex].blueprint_reselecting = false
   players[pindex].ghost_rail_planning = false
   fa_graphics.sync_build_cursor_graphics(pindex)
end)

script.on_event(defines.events.on_player_mined_item, function(event)
   local pindex = event.player_index
   --Play item pickup sound
   game.get_player(pindex).play_sound({ path = "utility/picked_up_item", volume_modifier = 1 })
   game.get_player(pindex).play_sound({ path = "Close-Inventory-Sound", volume_modifier = 1 })
end)

function ensure_global_structures_are_up_to_date()
   global.forces = global.forces or {}
   global.players = global.players or {}
   players = global.players
   for pindex, player in pairs(game.players) do
      initialize(player)
   end

   global.entity_types = {}
   entity_types = global.entity_types

   local types = {}
   for _, ent in pairs(game.entity_prototypes) do
      if
         types[ent.type] == nil
         and ent.weight == nil
         and (
            ent.burner_prototype ~= nil
            or ent.electric_energy_source_prototype ~= nil
            or ent.automated_ammo_count ~= nil
         )
      then
         types[ent.type] = true
      end
   end

   for i, type in pairs(types) do
      table.insert(entity_types, i)
   end
   table.insert(entity_types, "container")

   global.production_types = {}
   production_types = global.production_types

   local ents = game.entity_prototypes
   local types = {}
   for i, ent in pairs(ents) do
      --      if (ent.get_inventory_size(defines.inventory.fuel) ~= nil or ent.get_inventory_size(defines.inventory.chest) ~= nil or ent.get_inventory_size(defines.inventory.assembling_machine_input) ~= nil) and ent.weight == nil then
      if
         ent.speed == nil
         and ent.consumption == nil
         and (
            ent.burner_prototype ~= nil
            or ent.mining_speed ~= nil
            or ent.crafting_speed ~= nil
            or ent.automated_ammo_count ~= nil
            or ent.construction_radius ~= nil
         )
      then
         types[ent.type] = true
      end
   end
   for i, type in pairs(types) do
      table.insert(production_types, i)
   end
   table.insert(production_types, "transport-belt")
   table.insert(production_types, "container")

   global.building_types = {}
   building_types = global.building_types

   local ents = game.entity_prototypes
   local types = {}
   for i, ent in pairs(ents) do
      if ent.is_building then types[ent.type] = true end
   end
   types["transport-belt"] = nil
   for i, type in pairs(types) do
      table.insert(building_types, i)
   end
   table.insert(building_types, "character")

   global.scheduled_events = global.scheduled_events or {}
end

script.on_load(function()
   players = global.players
   entity_types = global.entity_types
   production_types = global.production_types
   building_types = global.building_types
end)

script.on_configuration_changed(function()
   ensure_global_structures_are_up_to_date()
   ui_internal.reset_global()
end)

script.on_init(function()
   ---@type any
   local skip_intro_message = remote.interfaces["freeplay"]
   skip_intro_message = skip_intro_message and skip_intro_message["set_skip_intro"]
   if skip_intro_message then remote.call("freeplay", "set_skip_intro", true) end
   ensure_global_structures_are_up_to_date()

   ui_internal.reset_global()
end)

script.on_event(defines.events.on_cutscene_cancelled, function(event)
   pindex = event.player_index
   check_for_player(pindex)
   fa_scanner.run_scan(pindex, nil, true)
   schedule(3, "call_to_fix_zoom", pindex)
   schedule(4, "call_to_sync_graphics", pindex)
end)

script.on_event(defines.events.on_cutscene_finished, function(event)
   pindex = event.player_index
   check_for_player(pindex)
   fa_scanner.run_scan(pindex, nil, true)
   schedule(3, "call_to_fix_zoom", pindex)
   schedule(4, "call_to_sync_graphics", pindex)
   --printout("Press TAB to continue",pindex)
end)

script.on_event(defines.events.on_cutscene_started, function(event)
   pindex = event.player_index
   check_for_player(pindex)
   --printout("Press TAB to continue",pindex)
end)

script.on_event(defines.events.on_player_created, function(event)
   initialize(game.players[event.player_index])
   --if not game.is_multiplayer() then printout("Press 'TAB' to continue", pindex) end
end)

script.on_event(defines.events.on_gui_closed, function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end

   --Other resets
   players[pindex].move_queue = {}
   if players[pindex].in_menu == true and players[pindex].menu ~= "prompt" then
      if players[pindex].menu == "inventory" then
         game.get_player(pindex).play_sound({ path = "Close-Inventory-Sound" })
      elseif
         players[pindex].menu == "travel" or players[pindex].menu == "structure-travel" and event.element ~= nil
      then
         event.element.destroy()
      end
      players[pindex].in_menu = false
      players[pindex].menu = "none"
      players[pindex].item_selection = false
      players[pindex].item_cache = {}
      players[pindex].item_selector = {
         index = 0,
         group = 0,
         subgroup = 0,
      }
      players[pindex].building.item_selection = false
      close_menu_resets(pindex)
   end
end)

script.on_event("save-game-manually", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   game.auto_save("manual")
   printout("Saving Game, please wait 3 seconds.", pindex)
end)

--Reads flying text
script.on_nth_tick(10, function(event)
   for pindex, player in pairs(players) do
      if player.allow_reading_flying_text == nil or player.allow_reading_flying_text == true then
         if player.past_flying_texts == nil then player.past_flying_texts = {} end
         local flying_texts = {}
         local search = {
            type = "flying-text",
            position = player.cursor_pos,
            radius = 80,
         }

         for _, ftext in pairs(game.get_player(pindex).surface.find_entities_filtered(search)) do
            local id = ftext.text
            if type(id) == "table" then id = serpent.line(id) end
            flying_texts[id] = (flying_texts[id] or 0) + 1
         end
         for id, count in pairs(flying_texts) do
            if count > (player.past_flying_texts[id] or 0) then
               local ok, local_text = serpent.load(id)
               if ok then printout(local_text, pindex) end
            end
         end
         player.past_flying_texts = flying_texts
      end
   end
end)

walk_type_speech = {
   "Telestep enabled",
   "Step by walk enabled",
   "Walking smoothly enabled",
}

script.on_event("toggle-walk", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   reset_bump_stats(pindex)
   players[pindex].move_queue = {}
   if players[pindex].walk == 0 then --Mode 1 (walk-by-step) is temporarily disabled until it comes back as an in game setting.
      players[pindex].walk = 2
      game.get_player(pindex).character_running_speed_modifier = 0 -- 100% + 0 = 100%
   else --walk == 1 or walk == 2
      players[pindex].walk = 0
      game.get_player(pindex).character_running_speed_modifier = -1 -- 100% - 100% = 0%
   end
   --players[pindex].walk = (players[pindex].walk + 1) % 3
   printout(walk_type_speech[players[pindex].walk + 1], pindex)
end)

function fix_walk(pindex)
   if not check_for_player(pindex) then return end
   if game.get_player(pindex).character == nil or game.get_player(pindex).character.valid == false then return end
   if players[pindex].walk == 0 and players[pindex].kruise_kontrolling ~= true then
      game.get_player(pindex).character_running_speed_modifier = -1 -- 100% - 100% = 0%
   else --walk > 0
      game.get_player(pindex).character_running_speed_modifier = 0 -- 100% + 0 = 100%
   end
   players[pindex].position = game.get_player(pindex).position
end

--Toggle building while walking
script.on_event("toggle-build-lock", function(event)
   local pindex = event.player_index
   if not check_for_player(pindex) then return end
   if not (players[pindex].in_menu == true) then
      if players[pindex].build_lock == true then
         players[pindex].build_lock = false
         printout("Build lock disabled.", pindex)
      else
         players[pindex].build_lock = true
         printout("Build lock enabled", pindex)
      end
   end
end)

script.on_event("toggle-vanilla-mode", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   game.get_player(pindex).play_sound({ path = "utility/confirm" })
   if players[pindex].vanilla_mode == false then
      game.get_player(pindex).print("Vanilla mode : ON")
      players[pindex].cursor = false
      players[pindex].walk = 2
      game.get_player(pindex).character_running_speed_modifier = 0
      players[pindex].hide_cursor = true
      printout("Vanilla mode enabled", pindex)
      players[pindex].vanilla_mode = true
   else
      game.get_player(pindex).print("Vanilla mode : OFF")
      players[pindex].hide_cursor = false
      players[pindex].vanilla_mode = false
      printout("Vanilla mode disabled", pindex)
   end
end)

script.on_event("toggle-cursor-hiding", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   if players[pindex].hide_cursor == nil or players[pindex].hide_cursor == false then
      players[pindex].hide_cursor = true
      printout("Cursor hiding enabled", pindex)
      game.get_player(pindex).print("Cursor hiding : ON")
   else
      players[pindex].hide_cursor = false
      printout("Cursor hiding disabled", pindex)
      game.get_player(pindex).print("Cursor hiding : OFF")
   end
end)

script.on_event("clear-renders", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   game.get_player(pindex).gui.screen.clear()
   players[pindex].cursor_ent_highlight_box = nil
   players[pindex].cursor_tile_highlight_box = nil
   players[pindex].building_footprint = nil
   players[pindex].building_dir_arrow = nil
   players[pindex].overhead_sprite = nil
   players[pindex].overhead_circle = nil
   players[pindex].custom_GUI_frame = nil
   players[pindex].custom_GUI_sprite = nil
   clear_renders()
   printout("Cleared renders", pindex)
end)

function clear_renders()
   rendering.clear("FactorioAccess")
   rendering.clear("")
end

script.on_event("recalibrate-zoom", function(event)
   local pindex = event.player_index
   if not check_for_player(pindex) then return end
   fa_zoom.fix_zoom(pindex)
   fa_graphics.sync_build_cursor_graphics(pindex)
   printout("Recalibrated", pindex)
end)

script.on_event("enable-mouse-update-entity-selection", function(event)
   local pindex = event.player_index
   if not check_for_player(pindex) then return end
   game.get_player(pindex).game_view_settings.update_entity_selection = true
end)

script.on_event("pipette-tool-info", function(event)
   local pindex = event.player_index
   if not check_for_player(pindex) then return end
   local ent = get_selected_ent(pindex)
   local p = game.get_player(pindex)
   if ent and ent.valid then
      p.selected = ent
      if ent.supports_direction then
         players[pindex].building_direction = ent.direction
         players[pindex].cursor_rotation_offset = 0
      end
      if players[pindex].cursor then players[pindex].cursor_pos = fa_utils.get_ent_northwest_corner_position(ent) end
      fa_graphics.sync_build_cursor_graphics(pindex)
      fa_graphics.draw_cursor_highlight(pindex, ent, nil, nil)
   end
end)

script.on_event("copy-entity-settings-info", function(event)
   local pindex = event.player_index
   if not check_for_player(pindex) then return end
   local ent = get_selected_ent(pindex)
   local p = game.get_player(pindex)
   if ent and ent.valid then p.selected = ent end
end)

script.on_event("paste-entity-settings-info", function(event)
   local pindex = event.player_index
   if not check_for_player(pindex) then return end
   local ent = get_selected_ent(pindex)
   local p = game.get_player(pindex)
   if ent and ent.valid then p.selected = ent end
end)

script.on_event("fast-entity-transfer-info", function(event)
   local pindex = event.player_index
   if not check_for_player(pindex) then return end
   local ent = get_selected_ent(pindex)
   local p = game.get_player(pindex)
   if ent and ent.valid then p.selected = ent end
end)

script.on_event("fast-entity-split-info", function(event)
   local pindex = event.player_index
   if not check_for_player(pindex) then return end
   local ent = get_selected_ent(pindex)
   local p = game.get_player(pindex)
   if ent and ent.valid then p.selected = ent end
end)

script.on_event("drop-cursor-info", function(event)
   local pindex = event.player_index
   if not check_for_player(pindex) then return end
   local ent = get_selected_ent(pindex)
   local p = game.get_player(pindex)
   if ent and ent.valid then p.selected = ent end
end)

script.on_event("read-hand", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   read_hand(pindex)
end)

--Empties hand and opens the item from the player/building inventory
script.on_event("locate-hand-in-inventory", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   if players[pindex].in_menu == false then
      locate_hand_in_player_inventory(pindex)
   elseif players[pindex].menu == "inventory" then
      locate_hand_in_player_inventory(pindex)
   elseif players[pindex].menu == "building" or players[pindex].menu == "vehicle" then
      locate_hand_in_building_output_inventory(pindex)
   else
      printout("Cannot locate items in this menu", pindex)
   end
end)

--Empties hand and opens the item from the crafting menu
script.on_event("locate-hand-in-crafting-menu", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   locate_hand_in_crafting_menu(pindex)
end)

--ENTER KEY by default
script.on_event("menu-search-open", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   if players[pindex].in_menu == false then return end
   if players[pindex].menu == "train_menu" then return end
   if game.get_player(pindex).vehicle ~= nil then return end
   if event.tick - players[pindex].last_menu_search_tick < 5 then return end
   fa_menu_search.open_search_box(pindex)
end)

script.on_event("menu-search-get-next", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   if players[pindex].in_menu == false then return end
   local str = players[pindex].menu_search_term
   if str == nil or str == "" then
      printout("Press 'CONTROL + F' to start typing in a search term", pindex)
      return
   end
   fa_menu_search.fetch_next(pindex, str)
end)

script.on_event("menu-search-get-last", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   if players[pindex].in_menu == false then return end
   local str = players[pindex].menu_search_term
   if str == nil or str == "" then
      printout("Press 'CONTROL + F' to start typing in a search term", pindex)
      return
   end
   fa_menu_search.fetch_last(pindex, str)
end)

script.on_event("open-warnings-menu", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) or players[pindex].vanilla_mode then return end
   if players[pindex].in_menu == false or game.get_player(pindex).opened_gui_type == defines.gui_type.production then
      players[pindex].warnings.short = fa_warnings.scan_for_warnings(30, 30, pindex)
      players[pindex].warnings.medium = fa_warnings.scan_for_warnings(100, 100, pindex)
      players[pindex].warnings.long = fa_warnings.scan_for_warnings(500, 500, pindex)
      players[pindex].warnings.index = 1
      players[pindex].warnings.sector = 1
      players[pindex].category = 1
      players[pindex].menu = "warnings"
      players[pindex].in_menu = true
      players[pindex].move_queue = {}
      game.get_player(pindex).selected = nil
      game.get_player(pindex).play_sound({ path = "Open-Inventory-Sound" })
      printout("Warnings, Short Range: " .. players[pindex].warnings.short.summary, pindex)
   else
      printout("Another menu is open. ", pindex)
   end
end)

script.on_event("honk", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   local p = game.get_player(pindex)
   if p.driving == true then
      local vehicle = p.vehicle
      if vehicle == nil or vehicle.valid == false then
         return
      elseif vehicle.type == "locomotive" or vehicle.train ~= nil then
         game.play_sound({ path = "train-honk-low-long", position = vehicle.position })
      elseif vehicle.name == "tank" then
         game.play_sound({ path = "tank-honk", position = vehicle.position })
      else
         game.play_sound({ path = "car-honk", position = vehicle.position })
      end
   end
end)

script.on_event("open-fast-travel-menu", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) or players[pindex].vanilla_mode then return end
   if game.get_player(pindex).driving ~= true then fa_travel.fast_travel_menu_open(pindex) end
end)

--GUI action confirmed, such as by pressing ENTER
script.on_event(defines.events.on_gui_confirmed, function(event)
   local pindex = event.player_index
   local p = game.get_player(pindex)
   if not check_for_player(pindex) then return end
   if players[pindex].cursor_jumping == true then
      --Jump the cursor
      players[pindex].cursor_jumping = false
      local result = event.element.text
      if result ~= nil and result ~= "" then
         local new_x = tonumber(fa_utils.get_substring_before_space(result))
         local new_y = tonumber(fa_utils.get_substring_after_space(result))
         --Check if valid numbers
         local valid_coords = new_x ~= nil and new_y ~= nil
         --Change cursor position or return error
         if valid_coords then
            players[pindex].cursor_pos = { x = new_x, y = new_y }
            printout("Cursor jumped to " .. new_x .. ", " .. new_y, pindex)
            fa_graphics.draw_cursor_highlight(pindex)
            fa_graphics.sync_build_cursor_graphics(pindex)
         else
            printout("Invalid input", pindex)
         end
      else
         printout("Invalid input", pindex)
      end
      event.element.destroy()
      --Set the player menu tracker to none
      players[pindex].menu = "none"
      players[pindex].in_menu = false
      --play sound
      p.play_sound({ path = "Close-Inventory-Sound" })

      --Destroy text fields
      if p.gui.screen["cursor-jump"] ~= nil then p.gui.screen["cursor-jump"].destroy() end
      if p.opened ~= nil then p.opened = nil end
   elseif players[pindex].menu == "circuit_network_menu" then
      --Take the constant number
      local result = event.element.text
      if result ~= nil and result ~= "" then
         local constant = tonumber(result)
         local valid_number = constant ~= nil
         --Apply the valid number
         if valid_number then
            if players[pindex].signal_selector.ent.type == "constant-combinator" then
               --Constant combinators (set last signal value)
               local success = fa_circuits.constant_combinator_set_last_signal_count(
                  constant,
                  players[pindex].signal_selector.ent,
                  pindex
               )
               if success then
                  printout("Set " .. result, pindex)
               else
                  printout("Error: No signals found", pindex)
               end
            else
               --Other devices (set enabled condition)
               local control = players[pindex].signal_selector.ent.get_control_behavior()
               local circuit_condition = control.circuit_condition
               local cond = control.circuit_condition.condition
               cond.second_signal = nil --{name = nil, type = signal_type}
               cond.constant = constant
               circuit_condition.condition = cond
               players[pindex].signal_selector.ent.get_control_behavior().circuit_condition = circuit_condition
               printout(
                  "Set "
                     .. result
                     .. ", condition now checks if "
                     .. fa_circuits.read_circuit_condition(players[pindex].signal_selector.ent, true),
                  pindex
               )
            end
         else
            printout("Invalid input", pindex)
         end
      else
         printout("Invalid input", pindex)
      end
      event.element.destroy()
      players[pindex].signal_selector = nil
      --Set the player menu tracker to none
      players[pindex].menu = "none"
      players[pindex].in_menu = false
      --play sound
      p.play_sound({ path = "Close-Inventory-Sound" })

      --Destroy text fields
      if p.gui.screen["circuit-condition-constant"] ~= nil then p.gui.screen["circuit-condition-constant"].destroy() end
      if p.opened ~= nil then p.opened = nil end
   elseif players[pindex].menu == "travel" then
      --Edit a travel point
      local result = event.element.text
      if result == nil or result == "" then result = "blank" end
      if players[pindex].travel.creating then
         --Create new point
         players[pindex].travel.creating = false
         table.insert(global.players[pindex].travel, {
            name = result,
            position = fa_utils.center_of_tile(players[pindex].position),
            description = "No description",
         })
         table.sort(global.players[pindex].travel, function(k1, k2)
            return k1.name < k2.name
         end)
         printout(
            "Fast travel point "
               .. result
               .. " created at "
               .. math.floor(players[pindex].position.x)
               .. ", "
               .. math.floor(players[pindex].position.y),
            pindex
         )
      elseif players[pindex].travel.renaming then
         --Renaming selected point
         players[pindex].travel.renaming = false
         players[pindex].travel[players[pindex].travel.index.y].name = result
         fa_travel.read_travel_slot(pindex)
      elseif players[pindex].travel.describing then
         --Save the new description
         players[pindex].travel.describing = false
         players[pindex].travel[players[pindex].travel.index.y].description = result
         printout(
            "Description updated for point " .. players[pindex].travel[players[pindex].travel.index.y].name,
            pindex
         )
      end
      players[pindex].travel.index.x = 1
      event.element.destroy()
   elseif players[pindex].train_menu.renaming == true then
      players[pindex].train_menu.renaming = false
      local result = event.element.text
      if result == nil or result == "" then result = "unknown" end
      fa_trains.set_train_name(players[pindex].train_menu.locomotive.train, result)
      printout("Train renamed to " .. result .. ", menu closed.", pindex)
      event.element.destroy()
      fa_trains.menu_close(pindex, false)
   elseif players[pindex].spider_menu.renaming == true then
      players[pindex].spider_menu.renaming = false
      local result = event.element.text
      if result == nil or result == "" then result = "unknown" end
      game.get_player(pindex).cursor_stack.connected_entity.entity_label = result
      printout("spidertron renamed to " .. result .. ", menu closed.", pindex)
      event.element.destroy()
      fa_spidertrons.spider_menu_close(pindex, false)
   elseif players[pindex].train_stop_menu.renaming == true then
      players[pindex].train_stop_menu.renaming = false
      local result = event.element.text
      if result == nil or result == "" then result = "unknown" end
      players[pindex].train_stop_menu.stop.backer_name = result
      printout("Train stop renamed to " .. result .. ", menu closed.", pindex)
      event.element.destroy()
      fa_train_stops.train_stop_menu_close(pindex, false)
   elseif players[pindex].roboport_menu.renaming == true then
      players[pindex].roboport_menu.renaming = false
      local result = event.element.text
      if result == nil or result == "" then result = "unknown" end
      fa_bot_logistics.set_network_name(players[pindex].roboport_menu.port, result)
      printout("Network renamed to " .. result .. ", menu closed.", pindex)
      event.element.destroy()
      fa_bot_logistics.roboport_menu_close(pindex)
   elseif players[pindex].entering_search_term == true then
      local term = string.lower(event.element.text)
      event.element.focus()
      players[pindex].menu_search_term = term
      if term ~= "" then
         printout("Searching for " .. term .. ", go through results with 'SHIFT + ENTER' or 'CONTROL + ENTER' ", pindex)
      end
      event.element.destroy()
      players[pindex].menu_search_frame.destroy()
      players[pindex].menu_search_frame = nil
   elseif players[pindex].blueprint_menu.edit_label == true then
      --Apply the new label
      players[pindex].blueprint_menu.edit_label = false
      local result = event.element.text
      if result == nil or result == "" then result = "unknown" end
      fa_blueprints.set_blueprint_label(p.cursor_stack, result)
      printout("Blueprint label changed to " .. result, pindex)
      event.element.destroy()
      if p.gui.screen["blueprint-edit-label"] ~= nil then p.gui.screen["blueprint-edit-label"].destroy() end
   elseif players[pindex].blueprint_menu.edit_description == true then
      --Apply the new desc
      players[pindex].blueprint_menu.edit_description = false
      local result = event.element.text
      if result == nil or result == "" then result = "unknown" end
      fa_blueprints.set_blueprint_description(p.cursor_stack, result)
      printout("Blueprint description changed.", pindex)
      event.element.destroy()
      if p.gui.screen["blueprint-edit-description"] ~= nil then p.gui.screen["blueprint-edit-description"].destroy() end
   elseif players[pindex].blueprint_menu.edit_import == true then
      --Apply the new import
      players[pindex].blueprint_menu.edit_import = false
      local result = event.element.text
      if result == nil or result == "" then result = "unknown" end
      fa_blueprints.apply_blueprint_import(pindex, result)
      event.element.destroy()
      if p.gui.screen["blueprint-edit-import"] ~= nil then p.gui.screen["blueprint-edit-import"].destroy() end
   elseif players[pindex].blueprint_menu.edit_export == true then
      --Instruct export
      players[pindex].blueprint_menu.edit_export = false
      local result = event.element.text
      if result == nil or result == "" then result = "unknown" end
      printout("Text box closed", pindex)
      event.element.destroy()
      if p.gui.screen["blueprint-edit-export"] ~= nil then p.gui.screen["blueprint-edit-export"].destroy() end
   else
      --Stray text box, so do nothing and destroy it
      if event.element.parent then
         event.element.parent.destroy()
      else
         event.element.destroy()
      end
   end
   players[pindex].last_menu_search_tick = event.tick
end)

script.on_event("open-structure-travel-menu", function(event)
   local pindex = event.player_index
   if not check_for_player(pindex) or players[pindex].vanilla_mode then return end
   if players[pindex].in_menu == false then
      game.get_player(pindex).selected = nil
      players[pindex].menu = "structure-travel"
      players[pindex].in_menu = true
      players[pindex].move_queue = {}
      players[pindex].structure_travel.direction = "none"
      local ent = get_selected_ent(pindex)
      local initial_scan_radius = 50
      if ent ~= nil and ent.valid and ent.unit_number ~= nil and building_types[ent.type] then
         players[pindex].structure_travel.current = ent.unit_number
         players[pindex].structure_travel.network = fa_travel.compile_building_network(ent, initial_scan_radius, pindex)
      else
         ent = game.get_player(pindex).character
         players[pindex].structure_travel.current = ent.unit_number
         players[pindex].structure_travel.network = fa_travel.compile_building_network(ent, initial_scan_radius, pindex)
      end
      local description = ""
      local network = players[pindex].structure_travel.network
      local current = players[pindex].structure_travel.current
      game.get_player(pindex).print("current id = " .. current)
      if network[current].north and #network[current].north > 0 then
         description = description .. ", " .. #network[current].north .. " connections north,"
      end
      if network[current].east and #network[current].east > 0 then
         description = description .. ", " .. #network[current].east .. " connections east,"
      end
      if network[current].south and #network[current].south > 0 then
         description = description .. ", " .. #network[current].south .. " connections south,"
      end
      if network[current].west and #network[current].west > 0 then
         description = description .. ", " .. #network[current].west .. " connections west,"
      end
      if description == "" then description = "No nearby buildings." end
      printout(
         "Structure travel, Now at "
            .. ent.name
            .. " "
            .. fa_scanner.ent_extra_list_info(ent, pindex, true)
            .. " "
            .. description
            .. ", Select a direction, confirm with same direction, and use perpendicular directions to select a target,  press left bracket to teleport to selection",
         pindex
      )
      local screen = game.get_player(pindex).gui.screen
      local frame = screen.add({ type = "frame", name = "structure-travel" })
      frame.bring_to_front()
      frame.force_auto_center()
      frame.focus()
      game.get_player(pindex).opened = frame
   else
      printout("Another menu is open. ", pindex)
   end
end)

script.on_event("cursor-skip-north", function(event)
   local pindex = event.player_index
   if not check_for_player(pindex) or players[pindex].vanilla_mode then return end
   cursor_skip(pindex, defines.direction.north)
end)

script.on_event("cursor-skip-south", function(event)
   local pindex = event.player_index
   if not check_for_player(pindex) or players[pindex].vanilla_mode then return end
   cursor_skip(pindex, defines.direction.south)
end)

script.on_event("cursor-skip-west", function(event)
   local pindex = event.player_index
   if not check_for_player(pindex) or players[pindex].vanilla_mode then return end
   cursor_skip(pindex, defines.direction.west)
end)

script.on_event("cursor-skip-east", function(event)
   local pindex = event.player_index
   if not check_for_player(pindex) or players[pindex].vanilla_mode then return end
   cursor_skip(pindex, defines.direction.east)
end)

--Runs the cursor skip iteration and reads out results
function cursor_skip(pindex, direction, iteration_limit)
   if players[pindex].cursor == false then return end
   local p = game.get_player(pindex)
   local limit = iteration_limit or 100
   local result = ""

   --Run the iteration and play sound
   local moved_count = cursor_skip_iteration(pindex, direction, limit)
   if moved_count < 0 then
      --No change found within the limit
      result = "Skipped " .. limit .. " tiles without a change, "
      --Play Sound
      if players[pindex].remote_view then
         p.play_sound({ path = "inventory-wrap-around", position = players[pindex].cursor_pos, volume_modifier = 1 })
      else
         p.play_sound({ path = "inventory-wrap-around", position = players[pindex].position, volume_modifier = 1 })
      end
   elseif moved_count == 1 then
      --Play Sound
      if players[pindex].remote_view then
         p.play_sound({ path = "Close-Inventory-Sound", position = players[pindex].cursor_pos, volume_modifier = 1 })
      else
         p.play_sound({ path = "Close-Inventory-Sound", position = players[pindex].position, volume_modifier = 1 })
      end
   elseif moved_count > 1 then
      --Change found, with more than 1 tile moved
      result = "Skipped " .. moved_count .. " tiles, "
      --Play Sound
      if players[pindex].remote_view then
         p.play_sound({ path = "inventory-wrap-around", position = players[pindex].cursor_pos, volume_modifier = 1 })
      else
         p.play_sound({ path = "inventory-wrap-around", position = players[pindex].position, volume_modifier = 1 })
      end
   end

   --Read the tile reached
   read_tile(pindex, result)
   fa_graphics.sync_build_cursor_graphics(pindex)
end

--Moves the cursor in the same direction multiple times until the reported entity changes. Change includes: new entity name or new direction for entites with the same name, or changing between nil and ent. Returns move count.
function cursor_skip_iteration(pindex, direction, iteration_limit)
   local p = game.get_player(pindex)
   local start = get_selected_ent(pindex)
   local start_tile_is_water = fa_utils.tile_is_water(p.surface, players[pindex].cursor_pos)
   local current = nil
   local limit = iteration_limit or 100
   local moved = 1
   local comment = ""

   --For pipes to ground, apply a special case where you jump to the underground neighbour
   if start ~= nil and start.valid and start.type == "pipe-to-ground" then
      local connections = start.fluidbox.get_pipe_connections(1)
      for i, con in ipairs(connections) do
         if con.target ~= nil then
            local dist = math.ceil(util.distance(start.position, con.target.get_pipe_connections(1)[1].position))
            local dir_neighbor = fa_utils.get_direction_biased(con.target_position, start.position)
            if con.connection_type == "underground" and dir_neighbor == direction then
               players[pindex].cursor_pos = con.target.get_pipe_connections(1)[1].position
               refresh_player_tile(pindex)
               current = get_selected_ent(pindex)
               return dist
            end
         end
      end
   --For underground belts, apply a special case where you jump to the underground neighbour
   elseif start ~= nil and start.valid and start.type == "underground-belt" then
      local neighbour = start.neighbours
      if neighbour then
         local other_end = neighbour
         local dist = math.ceil(util.distance(start.position, other_end.position))
         local dir_neighbor = fa_utils.get_direction_biased(other_end.position, start.position)
         if dir_neighbor == direction then
            players[pindex].cursor_pos = other_end.position
            refresh_player_tile(pindex)
            current = get_selected_ent(pindex)
            return dist
         end
      end
   --For water start, find the first non-water tile
   elseif start_tile_is_water then
      local selected_tile_is_water = nil
      --Iterate first_tile
      players[pindex].cursor_pos = fa_utils.offset_position(players[pindex].cursor_pos, direction, 1)
      selected_tile_is_water = fa_utils.tile_is_water(p.surface, players[pindex].cursor_pos)

      --Run checks and skip when needed
      while moved < limit do
         if selected_tile_is_water == false then
            --Water tile -> non-water tile found
            return moved
         else
            --Iterate again
            players[pindex].cursor_pos = fa_utils.offset_position(players[pindex].cursor_pos, direction, 1)
            selected_tile_is_water = fa_utils.tile_is_water(p.surface, players[pindex].cursor_pos)
            moved = moved + 1
         end
      end
      --Reached limit
      return -1
   end
   --Iterate first tile
   players[pindex].cursor_pos = fa_utils.offset_position(players[pindex].cursor_pos, direction, 1)
   refresh_player_tile(pindex)
   current = get_selected_ent(pindex)

   --Ignore flying robots (first tile)
   local i = 1
   while
      current ~= nil
      and current.valid
      and (current.type == "logistic-robot" or current.type == "construction-robot" or current.type == "combat-robot")
   do
      i = i + 1
      current = get_selected_ent(pindex, i)
   end

   --Run checks and skip when needed
   while moved < limit do
      if current == nil or current.valid == false then
         if start == nil or start.valid == false then
            --Both are nil: check if water, else skip
            local selected_tile_is_water = fa_utils.tile_is_water(p.surface, players[pindex].cursor_pos)
            if selected_tile_is_water then
               --Non-water tile -> water tile found
               return moved
            else
               --skip
            end
         else
            --Valid start ent -> nil found
            return moved
         end
      else
         if start == nil or start.valid == false then
            --Nil entity start -> valid entity found
            return moved
         else
            --Both are valid
            if start.unit_number == current.unit_number and current.type ~= "resource" then
               --They are the same ent: skip
            else
               --They are differemt ents OR they are resource ents (which can have the same unit number despite being different ents)
               if start.name ~= current.name then
                  --They have different names: return
                  --p.print("RET 1, start: " .. start.name .. ", current: " .. current.name .. ", comment:" .. comment)--
                  return moved
               else
                  --They have the same name
                  if current.supports_direction == false then
                     --They both do not support direction: skip
                  else
                     --They support direction
                     if current.direction ~= start.direction then
                        --They have different directions: return
                        --p.print("RET 2, start: " .. start.name .. ", current: " .. current.name .. ", comment:" .. comment)--
                        return moved
                     else
                        --They have same direction: skip

                        --Exception for transport belts facing the same direction: Return if neighbor counts or shapes are different
                        if start.type == "transport-belt" then
                           local start_input_neighbors = #start.belt_neighbours["inputs"]
                           local start_output_neighbors = #start.belt_neighbours["outputs"]
                           local current_input_neighbors = #current.belt_neighbours["inputs"]
                           local current_output_neighbors = #current.belt_neighbours["outputs"]
                           if
                              start_input_neighbors ~= current_input_neighbors
                              or start_output_neighbors ~= current_output_neighbors
                              or start.belt_shape ~= current.belt_shape
                           then
                              --p.print("RET 3, start: " .. start.name .. ", current: " .. current.name .. ", comment:" .. comment)--
                              return moved
                           end
                        end
                     end
                  end
               end
            end
            --p.print("start: " .. start.name .. ", current: " .. current.name .. ", comment:" .. comment)--
         end
      end
      --Skip case: Move 1 more tile
      players[pindex].cursor_pos = fa_utils.offset_position(players[pindex].cursor_pos, direction, 1)
      refresh_player_tile(pindex)
      current = get_selected_ent(pindex)
      moved = moved + 1
      --Ignore flying robots
      local i = 1
      while
         current ~= nil
         and current.valid
         and (
            current.type == "logistic-robot"
            or current.type == "construction-robot"
            or current.type == "combat-robot"
         )
      do
         i = i + 1
         current = get_selected_ent(pindex, i)
      end
   end
   --Reached limit
   return -1
end

script.on_event("nudge-up", function(event)
   fa_building_tools.nudge_key(defines.direction.north, event)
end)

script.on_event("nudge-down", function(event)
   fa_building_tools.nudge_key(defines.direction.south, event)
end)

script.on_event("nudge-left", function(event)
   fa_building_tools.nudge_key(defines.direction.west, event)
end)

script.on_event("nudge-right", function(event)
   fa_building_tools.nudge_key(defines.direction.east, event)
end)

script.on_event("alternative-menu-up", function(event)
   local pindex = event.player_index
   if not check_for_player(pindex) then return end
   if players[pindex].in_menu and players[pindex].menu == "train_menu" then
      fa_trains.menu_up(pindex)
   elseif players[pindex].in_menu and players[pindex].menu == "spider_menu" then
      fa_spidertrons.spider_menu_up(pindex)
   end
end)

script.on_event("alternative-menu-down", function(event)
   local pindex = event.player_index
   if not check_for_player(pindex) then return end
   if players[pindex].in_menu and players[pindex].menu == "train_menu" then
      fa_trains.menu_down(pindex)
   elseif players[pindex].in_menu and players[pindex].menu == "spider_menu" then
      fa_spidertrons.spider_menu_down(pindex)
   end
end)

script.on_event("alternative-menu-left", function(event)
   local pindex = event.player_index
   if not check_for_player(pindex) then return end
   if players[pindex].in_menu and players[pindex].menu == "train_menu" then fa_trains.menu_left(pindex) end
end)

script.on_event("alternative-menu-right", function(event)
   local pindex = event.player_index
   if not check_for_player(pindex) then return end
   if players[pindex].in_menu and players[pindex].menu == "train_menu" then fa_trains.menu_right(pindex) end
end)

script.on_event("cursor-one-tile-north", function(event)
   local pindex = event.player_index
   if not check_for_player(pindex) then return end
   if players[pindex].cursor then move_key(dirs.north, event, true) end
end)

script.on_event("cursor-one-tile-south", function(event)
   local pindex = event.player_index
   if not check_for_player(pindex) then return end
   if players[pindex].cursor then move_key(dirs.south, event, true) end
end)

script.on_event("cursor-one-tile-east", function(event)
   local pindex = event.player_index
   if not check_for_player(pindex) then return end
   if players[pindex].cursor then move_key(dirs.east, event, true) end
end)

script.on_event("cursor-one-tile-west", function(event)
   local pindex = event.player_index
   if not check_for_player(pindex) then return end
   if players[pindex].cursor then move_key(dirs.west, event, true) end
end)

script.on_event("set-splitter-input-priority-left", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   local ent = get_selected_ent(pindex)
   if not ent then
      return
   elseif ent.valid and ent.type == "splitter" then
      local result = fa_belts.set_splitter_priority(ent, true, true, nil)
      printout(result, pindex)
   end
end)

script.on_event("set-splitter-input-priority-right", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end
   local ent = get_selected_ent(pindex)
   if not ent then
      return
   elseif ent.valid and ent.type == "splitter" then
      local result = fa_belts.set_splitter_priority(ent, true, false, nil)
      printout(result, pindex)
   end
end)

script.on_event("set-splitter-output-priority-left", function(event)
   local pindex = event.player_index
   if not check_for_player(pindex) then return end
   local ent = get_selected_ent(pindex)
   if not ent then return end
   if ent.valid and ent.type == "splitter" then
      local result = fa_belts.set_splitter_priority(ent, false, true, nil)
      printout(result, pindex)
   end
end)

script.on_event("set-splitter-output-priority-right", function(event)
   local pindex = event.player_index
   if not check_for_player(pindex) then return end
   local ent = get_selected_ent(pindex)
   if not ent then return end
   --Build left turns on end rails
   if ent.valid and ent.type == "splitter" then
      local result = fa_belts.set_splitter_priority(ent, false, false, nil)
      printout(result, pindex)
   end
end)

--Sets splitter filter and also contant combinator signals
script.on_event("set-entity-filter-from-hand", function(event)
   pindex = event.player_index
   if not check_for_player(pindex) then return end

   if players[pindex].in_menu then
      return
   else
      --Not in a menu
      local stack = game.get_player(pindex).cursor_stack
      local ent = get_selected_ent(pindex)
      if ent == nil or ent.valid == false then return end
      if stack == nil or not stack.valid_for_read or not stack.valid then
         if ent.type == "splitter" then
            --Clear the filter
            local result = fa_belts.set_splitter_priority(ent, nil, nil, nil, true)
            printout(result, pindex)
         elseif ent.type == "constant-combinator" then
            --Remove the last signal
            fa_circuits.constant_combinator_remove_last_signal(ent, pindex)
         elseif ent.type == "inserter" then
            local result = set_inserter_filter_by_hand(pindex, ent)
            printout(result, pindex)
         end
      else
         if ent.type == "splitter" then
            --Set the filter
            local result = fa_belts.set_splitter_priority(ent, nil, nil, stack)
            printout(result, pindex)
         elseif ent.type == "constant-combinator" then
            --Add a new signal
            fa_circuits.constant_combinator_add_stack_signal(ent, stack, pindex)
         elseif ent.type == "inserter" then
            local result = set_inserter_filter_by_hand(pindex, ent)
            printout(result, pindex)
         end
      end
   end
end)

-- G is used to connect rolling stock
script.on_event("connect-rail-vehicles", function(event)
   local pindex = event.player_index
   local vehicle = nil
   if not check_for_player(pindex) or players[pindex].in_menu then return end
   local ent = get_selected_ent(pindex)
   if game.get_player(pindex).vehicle ~= nil and game.get_player(pindex).vehicle.train ~= nil then
      vehicle = game.get_player(pindex).vehicle
   elseif ent ~= nil and ent.valid and ent.train ~= nil then
      vehicle = ent
   end

   if vehicle ~= nil then
      --Connect rolling stock (or check if the default key bindings make the connection)
      local connected = 0
      if vehicle.connect_rolling_stock(defines.rail_direction.front) then connected = connected + 1 end
      if vehicle.connect_rolling_stock(defines.rail_direction.back) then connected = connected + 1 end
      if connected > 0 then
         printout("Connected this vehicle.", pindex)
      else
         connected = 0
         if vehicle.get_connected_rolling_stock(defines.rail_direction.front) ~= nil then connected = connected + 1 end
         if vehicle.get_connected_rolling_stock(defines.rail_direction.back) ~= nil then connected = connected + 1 end
         if connected > 0 then
            printout("Connected this vehicle.", pindex)
         else
            printout("Nothing was connected.", pindex)
         end
      end
   end
end)

--SHIFT + G is used to disconnect rolling stock
script.on_event("disconnect-rail-vehicles", function(event)
   local pindex = event.player_index
   local vehicle = nil
   if not check_for_player(pindex) or players[pindex].in_menu then return end
   local ent = get_selected_ent(pindex)
   if game.get_player(pindex).vehicle ~= nil and game.get_player(pindex).vehicle.train ~= nil then
      vehicle = game.get_player(pindex).vehicle
   elseif ent ~= nil and ent.train ~= nil then
      vehicle = ent
   end

   if vehicle ~= nil then
      --Disconnect rolling stock
      local disconnected = 0
      if vehicle.disconnect_rolling_stock(defines.rail_direction.front) then disconnected = disconnected + 1 end
      if vehicle.disconnect_rolling_stock(defines.rail_direction.back) then disconnected = disconnected + 1 end
      if disconnected > 0 then
         printout("Disconnected this vehicle.", pindex)
      else
         local connected = 0
         if vehicle.get_connected_rolling_stock(defines.rail_direction.front) ~= nil then connected = connected + 1 end
         if vehicle.get_connected_rolling_stock(defines.rail_direction.back) ~= nil then connected = connected + 1 end
         if connected > 0 then
            printout("Disconnection error.", pindex)
         else
            printout("Disconnected this vehicle.", pindex)
         end
      end
   end
end)

script.on_event("inventory-read-armor-stats", function(event)
   local pindex = event.player_index
   local vehicle = nil
   if not check_for_player(pindex) or not players[pindex].in_menu then return end
   if
      (players[pindex].in_menu and players[pindex].menu == "inventory")
      or (players[pindex].menu == "vehicle" and game.get_player(pindex).opened.type == "spider-vehicle")
   then
      local result = fa_equipment.read_armor_stats(pindex)
      --game.get_player(pindex).print(result)--
      printout(result, pindex)
   end
end)

script.on_event("inventory-read-equipment-list", function(event)
   local pindex = event.player_index
   local vehicle = nil
   if not check_for_player(pindex) or not players[pindex].in_menu then return end
   if
      (players[pindex].in_menu and players[pindex].menu == "inventory")
      or (players[pindex].menu == "vehicle" and game.get_player(pindex).opened.type == "spider-vehicle")
   then
      local result = fa_equipment.read_equipment_list(pindex)
      --game.get_player(pindex).print(result)--
      printout(result, pindex)
   end
end)

script.on_event("inventory-remove-all-equipment-and-armor", function(event)
   local pindex = event.player_index
   local vehicle = nil
   if not check_for_player(pindex) then return end

   if
      (players[pindex].in_menu and players[pindex].menu == "inventory")
      or (players[pindex].menu == "vehicle" and game.get_player(pindex).opened.type == "spider-vehicle")
   then
      local result = fa_equipment.remove_equipment_and_armor(pindex)
      --game.get_player(pindex).print(result)--
      printout(result, pindex)
   end
end)

--Runs before shooting a weapon to check for selected atomic bombs and the target distance
script.on_event("shoot-weapon-fa", function(event)
   local pindex = event.player_index
   if not check_for_player(pindex) then return end
   fa_combat.run_atomic_bomb_checks(pindex)
end)

--Attempt to launch a rocket
script.on_event("launch-rocket", function(event)
   local pindex = event.player_index
   local ent = get_selected_ent(pindex)
   if not check_for_player(pindex) then return end
   --For rocket entities, return the silo instead
   if ent and (ent.name == "rocket-silo-rocket-shadow" or ent.name == "rocket-silo-rocket") then
      local ents = ent.surface.find_entities_filtered({ position = ent.position, radius = 20, name = "rocket-silo" })
      for i, silo in ipairs(ents) do
         ent = silo
      end
   end
   --Try to launch from the silo
   if ent ~= nil and ent.valid and ent.name == "rocket-silo" then
      local try_launch = ent.launch_rocket()
      if try_launch then
         printout("Launch successful!", pindex)
      else
         printout("Not ready to launch!", pindex)
      end
   end
end)

--Help key and tutorial system WIP
script.on_event("help-read", function(event)
   local pindex = event.player_index
   if not check_for_player(pindex) then return end
   fa_tutorial.read_current_step(pindex)
end)

script.on_event("help-next", function(event)
   local pindex = event.player_index
   if not check_for_player(pindex) then return end
   fa_tutorial.next_step(pindex)
end)

script.on_event("help-back", function(event)
   local pindex = event.player_index
   if not check_for_player(pindex) then return end
   fa_tutorial.prev_step(pindex)
end)

script.on_event("help-chapter-next", function(event)
   local pindex = event.player_index
   if not check_for_player(pindex) then return end
   fa_tutorial.next_chapter(pindex)
end)

script.on_event("help-chapter-back", function(event)
   local pindex = event.player_index
   if not check_for_player(pindex) then return end
   fa_tutorial.prev_chapter(pindex)
end)

script.on_event("help-toggle-header-mode", function(event)
   local pindex = event.player_index
   if not check_for_player(pindex) then return end
   fa_tutorial.toggle_header_detail(pindex)
end)

script.on_event("help-get-other", function(event)
   local pindex = event.player_index
   if not check_for_player(pindex) then return end
   fa_tutorial.read_other_once(pindex)
end)

--**Use this key to test stuff (ALT-G)
script.on_event("debug-test-key", function(event)
   local pindex = event.player_index
   if not check_for_player(pindex) then return end
   local p = game.get_player(pindex)
   local pex = players[pindex]
   local ent = get_selected_ent(pindex)
   local stack = game.get_player(pindex).cursor_stack

   game.print(ent.prototype.group.name)
   --get_blueprint_corners(pindex, true)
   --if ent and ent.valid then
   --   game.print("tile width: " .. game.entity_prototypes[ent.name].tile_width)
   --end
   --if ent and ent.type == "programmable-speaker" then
   --ent.play_note(12,1)
   --fa_circuits.play_selected_speaker_note(ent)
   --end
   --show_sprite_demo(pindex)
   --Character:move_to(players[pindex].cursor_pos, util.distance(players[pindex].position,players[pindex].cursor_pos), 100)
end)

script.on_event("logistic-request-read", function(event)
   local pindex = event.player_index
   if not check_for_player(pindex) then return end
   if game.get_player(pindex).driving == false then fa_bot_logistics.logistics_info_key_handler(pindex) end
end)

script.on_event("logistic-request-increment-min", function(event)
   local pindex = event.player_index
   if not check_for_player(pindex) then return end
   fa_bot_logistics.logistics_request_increment_min_handler(pindex)
end)

script.on_event("logistic-request-decrement-min", function(event)
   local pindex = event.player_index
   if not check_for_player(pindex) then return end
   fa_bot_logistics.logistics_request_decrement_min_handler(pindex)
end)

script.on_event("logistic-request-increment-max", function(event)
   local pindex = event.player_index
   if not check_for_player(pindex) then return end
   fa_bot_logistics.logistics_request_increment_max_handler(pindex)
end)

script.on_event("logistic-request-decrement-max", function(event)
   local pindex = event.player_index
   if not check_for_player(pindex) then return end
   fa_bot_logistics.logistics_request_decrement_max_handler(pindex)
end)

script.on_event("logistic-request-clear", function(event)
   local pindex = event.player_index
   if not check_for_player(pindex) then return end
   fa_bot_logistics.logistics_request_clear_handler(pindex)
end)

script.on_event("vanilla-toggle-personal-logistics-info", function(event)
   local pindex = event.player_index
   local p = game.get_player(pindex)
   if p.character_personal_logistic_requests_enabled then
      printout("Resumed personal logistics requests", pindex)
   else
      printout("Paused personal logistics requests", pindex)
   end
end)

script.on_event("logistic-request-toggle-personal-logistics", function(event)
   local pindex = event.player_index
   if not check_for_player(pindex) then return end
   fa_bot_logistics.logistics_request_toggle_handler(pindex)
end)

script.on_event("send-selected-stack-to-logistic-trash", function(event)
   local pindex = event.player_index
   if not check_for_player(pindex) then return end
   fa_bot_logistics.send_selected_stack_to_logistic_trash(pindex)
end)

script.on_event(defines.events.on_gui_opened, function(event)
   local pindex = event.player_index
   if not check_for_player(pindex) then return end
   local p = game.get_player(pindex)
   players[pindex].move_queue = {}

   --Stop any enabled mouse entity selection
   if players[pindex].vanilla_mode ~= true then
      game.get_player(pindex).game_view_settings.update_entity_selection = false
   end

   --Deselect to prevent multiple interactions
   p.selected = nil

   --GUI mismatch checks
   if
      event.gui_type == defines.gui_type.controller
      and players[pindex].menu == "none"
      and event.tick - players[pindex].last_menu_toggle_tick < 5
   then
      --If closing another menu toggles the player GUI screen, we close this screen
      p.opened = nil
      --game.print("Closed an extra controller GUI",{volume_modifier = 0})--**checks GUI shenanigans
   else
      --Assume a GUI has been opened, whether in a menu or not
      players[pindex].in_menu = true
      --game.print("Opened an extra GUI",{volume_modifier = 0})--**checks GUI shenanigans
   end
end)

script.on_event(defines.events.on_chunk_charted, function(event)
   pindex = event.force.players[1].index
   if not check_for_player(pindex) then
   end
   if players[pindex].mapped[fa_utils.pos2str(event.position)] ~= nil then return end
   players[pindex].mapped[fa_utils.pos2str(event.position)] = true
   local islands = fa_scanner.find_islands(game.surfaces[event.surface_index], event.area, pindex)

   if table_size(islands) > 0 then
      for i, v in pairs(islands) do
         if players[pindex].resources[i] == nil then
            players[pindex].resources[i] = {
               patches = {},
               queue = {},
               index = 1,
               positions = {},
            }
         end
         local merged_groups = {}
         local many2many = {}
         if players[pindex].resources[i].queue[fa_utils.pos2str(event.position)] ~= nil then
            for dir, positions in pairs(players[pindex].resources[i].queue[fa_utils.pos2str(event.position)]) do
               --               islands[i].neighbors[dir] = nil
               for i3, pos in pairs(positions) do
                  local dirs = { dir - 1, dir, dir + 1 }
                  if dir == 0 then dirs[1] = 7 end
                  local new_edges = {}
                  for i1, d in ipairs(dirs) do
                     new_edges[fa_utils.pos2str(fa_utils.offset_position(fa_utils.str2pos(pos), d, -1))] = true
                  end
                  local adj = {}
                  for d = 0, 7 do
                     adj[d] = fa_utils.pos2str(fa_utils.offset_position(fa_utils.str2pos(pos), d, 1))
                  end
                  local edge = false
                  for d, p in ipairs(adj) do
                     if new_edges[p] then
                        if islands[i].resources[p] ~= nil then
                           local island_group = islands[i].resources[p].group
                           if merged_groups[island_group] == nil then merged_groups[island_group] = {} end
                           merged_groups[island_group][players[pindex].resources[i].positions[pos]] = true
                        else
                           edge = true
                        end
                     else
                        if players[pindex].resources[i].positions[p] == nil then edge = true end
                     end
                  end
                  if edge == false then
                     local group = players[pindex].resources[i].positions[pos]
                     players[pindex].resources[i].patches[group].edges[pos] = nil
                  end
                  for p, b in pairs(new_edges) do
                     if islands[i].resources[p] ~= nil then
                        local adj = {}
                        for d = 0, 7 do
                           adj[d] = fa_utils.pos2str(fa_utils.offset_position(fa_utils.str2pos(pos), d, 1))
                        end
                        local edge = false
                        for d, p1 in ipairs(adj) do
                           if islands[i].resources[p1] == nil and players[pindex].resources[i].positions[p1] == nil then
                              edge = true
                           end
                        end
                        if edge == false then
                           islands[i].resources[p].edge = false
                           islands[i].edges[p] = nil
                        else
                           islands[i].edges[p] = false
                        end
                     end
                  end
               end
            end
         end
         for island_group, resource_groups in pairs(merged_groups) do
            local matches = {}
            for i1, ref in ipairs(many2many) do
               local match = false
               for i2, v2 in pairs(resource_groups) do
                  if match then break end
                  for i3, v3 in pairs(ref["old"]) do
                     if i2 == i3 then
                        table.insert(matches, i1)
                        match = true
                        break
                     end
                  end
               end
            end
            ---@diagnostic disable-next-line: undefined-global
            local old = table.deepcopy(resource_group) --todo debug: maybe this was meant to be "island_group"? ***
            if old ~= nil then
               local new = {}
               new[island_group] = true
               if table_size(matches) == 0 then
                  local entry = {}
                  entry["old"] = old
                  entry["new"] = new
                  table.insert(many2many, table.deepcopy(entry))
               else
                  table.sort(matches, function(k1, k2)
                     return k1 > k2
                  end)

                  for i1, merge_index in ipairs(matches) do
                     for i2, v2 in pairs(many2many[merge_index]["old"]) do
                        old[i2] = true
                     end
                     for i2, v2 in pairs(many2many[merge_index]["new"]) do
                        new[i2] = true
                     end
                     table.remove(many2many, merge_index)
                  end
                  local entry = {}
                  entry["old"] = old
                  entry["new"] = new

                  table.insert(many2many, table.deepcopy(entry))
               end
            end
         end
         for i1, entry in pairs(many2many) do
            for island_group, v2 in pairs(entry["new"]) do
               for resource_group, v3 in pairs(entry["old"]) do
                  merged_groups[island_group][resource_group] = true
               end
            end
         end

         for island_group, resource_groups in pairs(merged_groups) do
            local new_group = math.huge
            for resource_group, b in pairs(resource_groups) do
               new_group = math.min(new_group, resource_group)
            end
            for resource_group, b in pairs(resource_groups) do
               if
                  new_group < resource_group
                  and players[pindex].resources[i].patches ~= nil
                  and players[pindex].resources[i].patches[resource_group] ~= nil
                  and islands[i] ~= nil
                  and islands[i].resources ~= nil
                  and islands[i].resources[b] ~= nil
               then --**beta changed "p" to "b"
                  for i1, pos in pairs(players[pindex].resources[i].patches[resource_group].positions) do
                     players[pindex].resources[i].positions[pos] = new_group
                     players[pindex].resources[i].count = islands[i].resources[b].count --**beta "p" to "b"
                  end
                  fa_utils.table_concat(
                     players[pindex].resources[i].patches[new_group].positions,
                     players[pindex].resources[i].patches[resource_group].positions
                  )
                  for pos, val in pairs(players[pindex].resources[i].patches[resource_group].edges) do
                     players[pindex].resources[i].patches[new_group].edges[pos] = val
                  end
                  players[pindex].resources[i].patches[resource_group] = nil
               end
            end
            for pos, val in pairs(islands[i].groups[island_group]) do
               players[pindex].resources[i].positions[pos] = new_group
               if "number" == type(players[pindex].resources[i].patches[new_group]) then
                  new_group = players[pindex].resources[i].patches[new_group]
               end
               table.insert(players[pindex].resources[i].patches[new_group].positions, pos)
               if islands[i].edges[pos] ~= nil then
                  players[pindex].resources[i].patches[new_group].edges[pos] = islands[i].edges[pos]
               end
               islands[i].groups[island_group] = nil
            end
         end

         for dir, v1 in pairs(islands[i].neighbors) do
            local chunk_pos = fa_utils.pos2str(fa_utils.offset_position(event.position, dir, 1))
            if players[pindex].resources[i].queue[chunk_pos] == nil then
               players[pindex].resources[i].queue[chunk_pos] = {}
            end
            players[pindex].resources[i].queue[chunk_pos][dir] = {}
         end
         for old_index, group in pairs(v.groups) do
            if true then
               local new_index = players[pindex].resources[i].index
               players[pindex].resources[i].patches[new_index] = {
                  positions = {},
                  edges = {},
               }
               players[pindex].resources[i].index = players[pindex].resources[i].index + 1
               for i2, pos in pairs(group) do
                  players[pindex].resources[i].positions[pos] = new_index
                  table.insert(players[pindex].resources[i].patches[new_index].positions, pos)
                  if islands[i].edges[pos] ~= nil then
                     players[pindex].resources[i].patches[new_index].edges[pos] = islands[i].edges[pos]
                     if islands[i].edges[pos] then
                        local position = fa_utils.str2pos(pos)
                        if fa_utils.area_edge(event.area, 0, position, i) then
                           local chunk_pos = fa_utils.pos2str(fa_utils.offset_position(event.position, 0, 1))
                           if players[pindex].resources[i].queue[chunk_pos][4] == nil then
                              players[pindex].resources[i].queue[chunk_pos][4] = {}
                           end
                           table.insert(players[pindex].resources[i].queue[chunk_pos][4], pos)
                        end
                        if fa_utils.area_edge(event.area, 6, position, i) then
                           local chunk_pos = fa_utils.pos2str(fa_utils.offset_position(event.position, 6, 1))
                           if players[pindex].resources[i].queue[chunk_pos][2] == nil then
                              players[pindex].resources[i].queue[chunk_pos][2] = {}
                           end
                           table.insert(players[pindex].resources[i].queue[chunk_pos][2], pos)
                        end
                        if fa_utils.area_edge(event.area, 4, position, i) then
                           local chunk_pos = fa_utils.pos2str(fa_utils.offset_position(event.position, 4, 1))
                           if players[pindex].resources[i].queue[chunk_pos][0] == nil then
                              players[pindex].resources[i].queue[chunk_pos][0] = {}
                           end
                           table.insert(players[pindex].resources[i].queue[chunk_pos][0], pos)
                        end
                        if fa_utils.area_edge(event.area, 2, position, i) then
                           local chunk_pos = fa_utils.pos2str(fa_utils.offset_position(event.position, 2, 1))
                           if players[pindex].resources[i].queue[chunk_pos][6] == nil then
                              players[pindex].resources[i].queue[chunk_pos][6] = {}
                           end
                           table.insert(players[pindex].resources[i].queue[chunk_pos][6], pos)
                        end
                     end
                  end
               end
            end
         end
      end
      --      print(event.area.left_top.x .. " " .. event.area.left_top.y)
      --      print(event.area.right_bottom.x .. " " .. event.area.right_bottom.y)
      --      for name, obj in pairs(resources) do
      --         print(name .. ": " .. table_size(obj.patches))
      --      end
   end
end)

script.on_event(defines.events.on_entity_destroyed, function(event) --DOES NOT HAVE THE KEY PLAYER_INDEX
   local ent = nil
   for pindex, player in pairs(players) do --If the destroyed entity is destroyed by any player, it will be detected. Laterdo consider logged out players etc?
      if players[pindex] ~= nil then
         local try_ent = players[pindex].destroyed[event.registration_number]
         if try_ent ~= nil and try_ent.valid then ent = try_ent end
      end
   end
   if ent == nil then return end
   local str = fa_utils.pos2str(ent.position)
   if ent.type == "resource" then
      if ent.name ~= "crude-oil" and players[pindex].resources[ent.name].positions[str] ~= nil then --**beta added a check here to not run for nil "group"s...
         local group = players[pindex].resources[ent.name].positions[str]
         players[pindex].resources[ent.name].positions[str] = nil
         --game.get_player(pindex).print("Pos str: " .. str)
         --game.get_player(pindex).print("group: " .. group)
         players[pindex].resources[ent.name].patches[group].edges[str] = nil
         for i = 1, #players[pindex].resources[ent.name].patches[group].positions do
            if players[pindex].resources[ent.name].patches[group].positions[i] == str then
               table.remove(players[pindex].resources[ent.name].patches[group].positions, i)
               i = i - 1
            end
         end
         if #players[pindex].resources[ent.name].patches[group].positions == 0 then
            players[pindex].resources[ent.name].patches[group] = nil
            if table_size(players[pindex].resources[ent.name].patches) == 0 then
               players[pindex].resources[ent.name] = nil
            end
            return
         end
         for d = 0, 7 do
            local adj = fa_utils.pos2str(fa_utils.offset_position(ent.position, d, 1))
            if players[pindex].resources[ent.name].positions[adj] == group then
               players[pindex].resources[ent.name].patches[group].edges[adj] = false
            end
         end
      end
   elseif ent.type == "tree" then
      local adj = {}
      adj[fa_utils.pos2str({ x = math.floor(ent.area.left_top.x / 32), y = math.floor(ent.area.left_top.y / 32) })] =
         true
      adj[fa_utils.pos2str({ x = math.floor(ent.area.right_bottom.x / 32), y = math.floor(ent.area.left_top.y / 32) })] =
         true
      adj[fa_utils.pos2str({ x = math.floor(ent.area.left_top.x / 32), y = math.floor(ent.area.right_bottom.y / 32) })] =
         true
      adj[fa_utils.pos2str({
         x = math.floor(ent.area.right_bottom.x / 32),
         y = math.floor(ent.area.right_bottom.y / 32),
      })] =
         true
      for pos, val in pairs(adj) do
         --players[pindex].tree_chunks[pos].count = players[pindex].tree_chunks[pos].count - 1--**beta Forests need updating but these lines are incorrectly named
      end
   end
   players[pindex].destroyed[event.registration_number] = nil
end)

--Scripts regarding train state changes. NOTE: NO PINDEX
script.on_event(defines.events.on_train_changed_state, function(event)
   if event.train.state == defines.train_state.no_schedule then
      --Trains with no schedule are set back to manual mode
      event.train.manual_mode = true
   elseif event.train.state == defines.train_state.arrive_station then
      --Announce arriving station to players on the train
      for i, player in ipairs(event.train.passengers) do
         local stop = event.train.path_end_stop
         if stop ~= nil then
            local str = " Arriving at station " .. stop.backer_name .. " "
            printout(str, player.index)
         end
      end
   elseif event.train.state == defines.train_state.on_the_path then --laterdo make this announce only when near another trainstop.
      --Announce heading station to players on the train
      for i, player in ipairs(event.train.passengers) do
         local stop = event.train.path_end_stop
         if stop ~= nil then
            local str = " Heading to station " .. stop.backer_name .. " "
            printout(str, player.index)
         end
      end
   elseif event.train.state == defines.train_state.wait_signal then
      --Announce the wait to players on the train
      for i, player in ipairs(event.train.passengers) do
         local stop = event.train.path_end_stop
         if stop ~= nil then
            local str = " Waiting at signal. "
            printout(str, player.index)
         end
      end
   end
   --Check if the train has temporary stops and note this for its passengers
   if fa_trains.schedule_contains_temporary_stops(event.train) == true then
      for i, player in ipairs(event.train.passengers) do
         players[player.index].train_has_temporary_stops = true
      end
   else
      --If not, check if any passangers recently noted that there was a temporary train stop (meaning that you arrived)
      for i, player in ipairs(event.train.passengers) do
         if players[player.index].train_has_temporary_stops == true then
            event.train.manual_mode = true
            local str = "Temporary travel complete, switched to manual control"
            printout(str, player.index)
         end
         players[player.index].train_has_temporary_stops = false
      end
   end
end)

--If a filter inserter is selected, the item in hand is set as its output filter item.
function set_inserter_filter_by_hand(pindex, ent)
   local stack = game.get_player(pindex).cursor_stack
   if ent.filter_slot_count == 0 then return "This inserter has no filters to set" end
   if stack == nil or stack.valid_for_read == false then
      --Delete last filter
      for i = ent.filter_slot_count, 1, -1 do
         local filt = ent.get_filter(i)
         if filt ~= nil then
            ent.set_filter(i, nil)
            return "Last filter cleared"
         end
      end
      return "All filters cleared"
   else
      --Add item in hand as next filter
      for i = 1, ent.filter_slot_count, 1 do
         local filt = ent.get_filter(i)
         if filt == nil then
            ent.set_filter(i, stack.name)
            if ent.get_filter(i) == stack.name then
               return "Added filter"
            else
               return "Filter setting failed"
            end
         end
      end
      return "All filters full"
   end
end

--Feature for typing in coordinates for moving the mod cursor.
function type_cursor_position(pindex)
   printout("Enter new co-ordinates for the cursor, separated by a space", pindex)
   players[pindex].cursor_jumping = true
   local frame = game.get_player(pindex).gui.screen.add({ type = "frame", name = "cursor-jump" })
   frame.bring_to_front()
   frame.force_auto_center()
   frame.focus()
   local input = frame.add({ type = "textfield", name = "input" })
   input.focus()
end

--Alerts a force's players when their structures are destroyed. 300 ticks of cooldown.
script.on_event(defines.events.on_entity_damaged, function(event)
   local ent = event.entity
   local tick = event.tick
   if ent == nil or not ent.valid then
      return
   elseif ent.name == "character" then
      --Check character has any energy shield health remaining
      if ent.player == nil or not ent.player.valid then return end
      local shield_left = nil
      local armor_inv = ent.player.get_inventory(defines.inventory.character_armor)
      if
         armor_inv[1]
         and armor_inv[1].valid_for_read
         and armor_inv[1].valid
         and armor_inv[1].grid
         and armor_inv[1].grid.valid
      then
         local grid = armor_inv[1].grid
         if grid.shield > 0 then
            shield_left = grid.shield
            --game.print(armor_inv[1].grid.shield,{volume_modifier=0})
         end
      end
      --Play shield and/or character damaged sound
      if shield_left ~= nil then ent.player.play_sound({ path = "player-damaged-shield", volume_modifier = 0.8 }) end
      if shield_left == nil or (shield_left < 1.0 and ent.get_health_ratio() < 1.0) then
         ent.player.play_sound({ path = "player-damaged-character", volume_modifier = 0.4 })
      end
      return
   elseif ent.get_health_ratio() == 1.0 then
      --Ignore alerts if an entity has full health despite being damaged
      return
   elseif tick < 3600 and tick > 600 then
      --No alerts for the first 10th to 60th seconds (because of the alert spam from spaceship fire damage)
      return
   end

   local attacker_force = event.force
   local damaged_force = ent.force
   --Alert all players of the damaged force
   for pindex, player in pairs(players) do
      if
         players[pindex] ~= nil
         and game.get_player(pindex).force.name == damaged_force.name
         and (players[pindex].last_damage_alert_tick == nil or (tick - players[pindex].last_damage_alert_tick) > 300)
      then
         players[pindex].last_damage_alert_tick = tick
         players[pindex].last_damage_alert_pos = ent.position
         local dist = math.ceil(util.distance(players[pindex].position, ent.position))
         local dir = fa_utils.direction_lookup(fa_utils.get_direction_biased(ent.position, players[pindex].position))
         local result = ent.name .. " damaged by " .. attacker_force.name .. " forces at " .. dist .. " " .. dir
         printout(result, pindex)
         --game.get_player(pindex).print(result,{volume_modifier=0})--**
         game.get_player(pindex).play_sound({ path = "alert-structure-damaged", volume_modifier = 0.3 })
      end
   end
end)

--Alerts a force's players when their structures are destroyed. No cooldown.
script.on_event(defines.events.on_entity_died, function(event)
   local ent = event.entity
   local causer = event.cause
   if ent == nil then
      return
   elseif ent.name == "character" then
      return
   end
   local attacker_force = event.force
   local damaged_force = ent.force
   --Alert all players of the damaged force
   for pindex, player in pairs(players) do
      if players[pindex] ~= nil and game.get_player(pindex).force.name == damaged_force.name then
         players[pindex].last_damage_alert_tick = event.tick
         players[pindex].last_damage_alert_pos = ent.position
         local dist = math.ceil(util.distance(players[pindex].position, ent.position))
         local dir = fa_utils.direction_lookup(fa_utils.get_direction_biased(ent.position, players[pindex].position))
         local result = ent.name .. " destroyed by " .. attacker_force.name .. " forces at " .. dist .. " " .. dir
         printout(result, pindex)
         --game.get_player(pindex).print(result,{volume_modifier=0})--**
         game.get_player(pindex).play_sound({ path = "utility/alert_destroyed", volume_modifier = 0.5 })
      end
   end
end)

--Notify all players when a player character dies
script.on_event(defines.events.on_player_died, function(event)
   local pindex = event.player_index
   local p = game.get_player(pindex)
   local causer = event.cause
   local bodies = p.surface.find_entities_filtered({ name = "character-corpse" })
   local latest_body = nil
   local latest_death_tick = 0
   local name = p.name
   if name == nil then name = " " end
   --Find the most recent character corpse
   for i, body in ipairs(bodies) do
      if body.character_corpse_player_index == pindex and body.character_corpse_tick_of_death > latest_death_tick then
         latest_body = body
         latest_death_tick = latest_body.character_corpse_tick_of_death
      end
   end
   --Verify the latest death
   if event.tick - latest_death_tick > 120 then latest_body = nil end
   --Generate death message
   local result = "Player " .. name
   if causer == nil or not causer.valid then
      result = result .. " died "
   elseif causer.name == "character" and causer.player ~= nil and causer.player.valid then
      local other_name = causer.player.name
      if other_name == nil then other_name = "" end
      result = result .. " was killed by player " .. other_name
   else
      result = result .. " was killed by " .. causer.name
   end
   if latest_body ~= nil and latest_body.valid then
      result = result
         .. " at "
         .. math.floor(0.5 + latest_body.position.x)
         .. ", "
         .. math.floor(0.5 + latest_body.position.y)
         .. "."
   end
   --Notify all players
   for pindex, player in pairs(players) do
      players[pindex].last_damage_alert_tick = event.tick
      printout(result, pindex)
      game.get_player(pindex).print(result) --**laterdo unique sound, for now use console sound
   end
end)

script.on_event(defines.events.on_player_display_resolution_changed, function(event)
   local pindex = event.player_index
   if not check_for_player(pindex) then return end
   local new_res = game.get_player(pindex).display_resolution
   if players and players[pindex] then players[pindex].display_resolution = new_res end
   game
      .get_player(pindex)
      .print("Display resolution changed: " .. new_res.width .. " x " .. new_res.height, { volume_modifier = 0 })
   schedule(3, "call_to_fix_zoom", pindex)
   schedule(4, "call_to_sync_graphics", pindex)
end)

script.on_event(defines.events.on_player_display_scale_changed, function(event)
   local pindex = event.player_index
   if not check_for_player(pindex) then return end
   local new_sc = game.get_player(pindex).display_scale
   if players and players[pindex] then players[pindex].display_resolution = new_sc end
   game.get_player(pindex).print("Display scale changed: " .. new_sc, { volume_modifier = 0 })
   schedule(3, "call_to_fix_zoom", pindex)
   schedule(4, "call_to_sync_graphics", pindex)
end)

script.on_event(defines.events.on_string_translated, fa_localising.handler)

--If the player has unexpected lateral movement while smooth running in a cardinal direction, like from bumping into an entity or being at the edge of water, play a sound.
function check_and_play_bump_alert_sound(pindex, this_tick)
   if not check_for_player(pindex) or players[pindex].menu == "prompt" then return end
   local p = game.get_player(pindex)
   if p == nil or p.character == nil then return end
   local face_dir = p.character.direction

   --Initialize
   if players[pindex].bump == nil then reset_bump_stats(pindex) end

   --Return and reset if in a menu or a vehicle
   if players[pindex].in_menu or p.vehicle ~= nil then
      players[pindex].bump.last_pos_4 = nil
      players[pindex].bump.last_pos_3 = nil
      players[pindex].bump.last_pos_2 = nil
      players[pindex].bump.last_pos_1 = nil
      players[pindex].bump.last_dir_2 = nil
      players[pindex].bump.last_dir_1 = nil
      return
   end

   --Update Positions and directions since last check
   players[pindex].bump.last_pos_4 = players[pindex].bump.last_pos_3
   players[pindex].bump.last_pos_3 = players[pindex].bump.last_pos_2
   players[pindex].bump.last_pos_2 = players[pindex].bump.last_pos_1
   players[pindex].bump.last_pos_1 = p.position

   players[pindex].bump.last_dir_2 = players[pindex].bump.last_dir_1
   players[pindex].bump.last_dir_1 = face_dir

   --Return if not walking
   if p.walking_state.walking == false then return end

   --Return if not enough positions filled (trying 4 for now)
   if players[pindex].bump.last_pos_4 == nil then
      players[pindex].bump.filled = false
      return
   else
      players[pindex].bump.filled = true
   end

   --Return if bump sounded recently
   if this_tick - players[pindex].bump.last_bump_tick < 15 then return end

   --Return if player changed direction recently
   if
      this_tick - players[pindex].bump.last_dir_key_tick < 30
      and players[pindex].bump.last_dir_key_1st ~= players[pindex].bump.last_dir_key_2nd
   then
      return
   end

   --Return if current running direction is not equal to the last (e.g. letting go of a key)
   if face_dir ~= players[pindex].bump.last_dir_key_1st then return end

   --Return if no last key info filled (rare)
   if players[pindex].bump.last_dir_key_1st == nil then return end

   --Return if no last dir info filled (rare)
   if players[pindex].bump.last_dir_2 == nil then return end

   --Return if not walking in a cardinal direction
   if face_dir ~= dirs.north and face_dir ~= dirs.east and face_dir ~= dirs.south and face_dir ~= dirs.west then
      return
   end

   --Return if last dir is different
   if players[pindex].bump.last_dir_1 ~= players[pindex].bump.last_dir_2 then return end

   --Prepare analysis data
   local TOLERANCE = 0.05
   local was_going_straight = false
   local b = players[pindex].bump

   local diff_x1 = b.last_pos_1.x - b.last_pos_2.x
   local diff_x2 = b.last_pos_2.x - b.last_pos_3.x
   local diff_x3 = b.last_pos_3.x - b.last_pos_4.x

   local diff_y1 = b.last_pos_1.y - b.last_pos_2.y
   local diff_y2 = b.last_pos_2.y - b.last_pos_3.y
   local diff_y3 = b.last_pos_3.y - b.last_pos_4.y

   --Check if earlier movement has been straight
   if players[pindex].bump.last_dir_key_1st == players[pindex].bump.last_dir_key_2nd then
      was_going_straight = true
   else
      if face_dir == dirs.north or face_dir == dirs.south then
         if math.abs(diff_x2) < TOLERANCE and math.abs(diff_x3) < TOLERANCE then was_going_straight = true end
      elseif face_dir == dirs.east or face_dir == dirs.west then
         if math.abs(diff_y2) < TOLERANCE and math.abs(diff_y3) < TOLERANCE then was_going_straight = true end
      end
   end

   --Return if was not going straight earlier (like was running diagonally, as confirmed by last positions)
   if not was_going_straight then return end

   --game.print("checking bump",{volume_modifier=0})--

   --Check if latest movement has been straight
   local is_going_straight = false
   if face_dir == dirs.north or face_dir == dirs.south then
      if math.abs(diff_x1) < TOLERANCE then is_going_straight = true end
   elseif face_dir == dirs.east or face_dir == dirs.west then
      if math.abs(diff_y1) < TOLERANCE then is_going_straight = true end
   end

   --Return if going straight now
   if is_going_straight then return end

   --Now we can confirm that there is a sudden lateral movement
   players[pindex].bump.last_bump_tick = this_tick
   --p.play_sound({ path = "player-bump-alert" }) --Removed the alert beep
   local bump_was_ent = false
   local bump_was_cliff = false
   local bump_was_tile = false

   --Check if there is an ent in front of the player
   local found_ent = get_selected_ent(pindex)
   local ent = nil
   if
      found_ent
      and found_ent.valid
      and found_ent.type ~= "resource"
      and found_ent.type ~= "transport-belt"
      and found_ent.type ~= "item-entity"
      and found_ent.type ~= "entity-ghost"
      and found_ent.type ~= "character"
   then
      ent = found_ent
   end
   if ent == nil or ent.valid == false then
      local ents = p.surface.find_entities_filtered({ position = p.position, radius = 0.75 })
      for i, found_ent in ipairs(ents) do
         --Ignore ents you can walk through, laterdo better collision checks**
         if
            found_ent.type ~= "resource"
            and found_ent.type ~= "transport-belt"
            and found_ent.type ~= "item-entity"
            and found_ent.type ~= "entity-ghost"
            and found_ent.type ~= "character"
         then
            ent = found_ent
         end
      end
   end
   bump_was_ent = (ent ~= nil and ent.valid)

   if bump_was_ent then
      if ent.type == "cliff" then
         p.play_sound({ path = "player-bump-slide" })
      else
         p.play_sound({ path = "player-bump-trip" })
      end
      --game.print("bump: ent:" .. ent.name,{volume_modifier=0})--
      return
   end

   --Check if there is a cliff nearby (the weird size can make it affect the player without being read)
   local ents = p.surface.find_entities_filtered({ position = p.position, radius = 2, type = "cliff" })
   bump_was_cliff = (#ents > 0)
   if bump_was_cliff then
      p.play_sound({ path = "player-bump-slide" })
      --game.print("bump: cliff",{volume_modifier=0})--
      return
   end

   --Check if there is a tile that was bumped into
   local tile = p.surface.get_tile(players[pindex].cursor_pos.x, players[pindex].cursor_pos.y)
   bump_was_tile = (tile ~= nil and tile.valid and tile.collides_with("player-layer"))

   if bump_was_tile then
      p.play_sound({ path = "player-bump-slide" })
      --game.print("bump: tile:" .. tile.name,{volume_modifier=0})--
      return
   end

   --The bump was something else, probably missed it...
   --p.play_sound{path = "player-bump-slide"}
   --game.print("bump: unknown, at " .. p.position.x .. "," .. p.position.y ,{volume_modifier=0})--
   return
end

--If walking but recently position has been unchanged, play alert
function check_and_play_stuck_alert_sound(pindex, this_tick)
   if not check_for_player(pindex) or players[pindex].menu == "prompt" then return end
   local p = game.get_player(pindex)

   --Initialize
   if players[pindex].bump == nil then reset_bump_stats(pindex) end

   --Return if in a menu or a vehicle or in a different walking mode than smooth walking
   if players[pindex].in_menu or p.vehicle ~= nil or players[pindex].walk ~= 2 then return end

   --Return if not walking
   if p.walking_state.walking == false then return end

   --Return if not enough positions filled (trying 3 for now)
   if players[pindex].bump.last_pos_3 == nil then return end

   --Return if no last dir info filled (rare)
   if players[pindex].bump.last_dir_2 == nil then return end

   --Prepare analysis data
   local b = players[pindex].bump

   local diff_x1 = b.last_pos_1.x - b.last_pos_2.x
   local diff_x2 = b.last_pos_2.x - b.last_pos_3.x
   --local diff_x3 = b.last_pos_3.x - b.last_pos_4.x

   local diff_y1 = b.last_pos_1.y - b.last_pos_2.y
   local diff_y2 = b.last_pos_2.y - b.last_pos_3.y
   --local diff_y3 = b.last_pos_3.y - b.last_pos_4.y

   --Check if earlier movement has been straight
   if diff_x1 == 0 and diff_y1 == 0 and diff_x2 == 0 and diff_y2 == 0 then --and diff_x3 == 0 and diff_y3 == 0 then
      p.play_sound({ path = "player-bump-stuck-alert" })
   end
end

function reset_bump_stats(pindex)
   players[pindex].bump = {
      last_bump_tick = 1,
      last_dir_key_tick = 1,
      last_dir_key_1st = nil,
      last_dir_key_2nd = nil,
      last_pos_1 = nil,
      last_pos_2 = nil,
      last_pos_3 = nil,
      last_pos_4 = nil,
      last_dir_2 = nil,
      last_dir_1 = nil,
   }
end

function all_ents_are_walkable(pos)
   local ents = game.surfaces[1].find_entities_filtered({
      position = fa_utils.center_of_tile(pos),
      radius = 0.4,
      invert = true,
      type = ENT_TYPES_YOU_CAN_WALK_OVER,
   })
   for i, ent in ipairs(ents) do
      return false
   end
   return true
end

--WIP. This function can be called via the console: /c __FactorioAccess__ regenerate_all_uncharted_spawners() --laterdo fix bugs?
function regenerate_all_uncharted_spawners(surface_in)
   local surf = surface_in or game.surfaces["nauvis"]

   --Get spawner names
   local spawner_names = {}
   for name, prot in pairs(game.get_filtered_entity_prototypes({ { filter = "type", type = "unit-spawner" } })) do
      table.insert(spawner_names, name)
   end

   for chunk in surf.get_chunks() do
      local is_charted = false
      --Check if the chunk is charted by any players
      for pindex, player in pairs(players) do
         is_charted = is_charted or (player.force and player.force.is_chunk_charted(surf, { x = chunk.x, y = chunk.y }))
      end
      --Regenerate the spawners if NOT charted by any player forces
      if is_charted == false then
         for i, name in ipairs(spawner_names) do
            surf.regenerate_entity(name, chunk)
         end
      end
   end
end

function general_mod_menu_up(pindex, menu, lower_limit_in) --todo*** use
   local lower_limit = lower_limit_in or 0
   menu.index = menu.index - 1
   if menu.index < lower_limit then
      menu.index = lower_limit
      game.get_player(pindex).play_sound({ path = "inventory-edge" })
   else
      --Play sound
      game.get_player(pindex).play_sound({ path = "Inventory-Move" })
   end
end

function general_mod_menu_down(pindex, menu, upper_limit)
   menu.index = menu.index + 1
   if menu.index > upper_limit then
      menu.index = upper_limit
      game.get_player(pindex).play_sound({ path = "inventory-edge" })
   else
      --Play sound
      game.get_player(pindex).play_sound({ path = "Inventory-Move" })
   end
end

--Report total produced in last minute, last hour, last thousand hours for the selected item, either in hand or else selected from player inventory.
function selected_item_production_stats_info(pindex)
   local p = game.get_player(pindex)
   local result = ""
   local stats = p.force.item_production_statistics
   local internal_name = nil
   local item_stack = nil
   local recipe = nil

   --Select the cursor stack
   item_stack = p.cursor_stack
   if item_stack and item_stack.valid_for_read then internal_name = item_stack.prototype.name end

   --Otherwise select the selected inventory stack
   if internal_name == nil and players[pindex].menu == "inventory" then
      item_stack = players[pindex].inventory.lua_inventory[players[pindex].inventory.index]
      if item_stack and item_stack.valid_for_read then internal_name = item_stack.prototype.name end
   end

   --Otherwise select the selected crafting recipe
   if internal_name == nil and players[pindex].menu == "crafting" then
      recipe = players[pindex].crafting.lua_recipes[players[pindex].crafting.category][players[pindex].crafting.index]
      if recipe and recipe.valid and recipe.products and recipe.products[1] then
         local prototype = nil
         if recipe.products[1].type == "item" then
            --Select product item #1
            prototype = game.item_prototypes[recipe.products[1].name]
            if prototype then
               internal_name = prototype.name
               result = fa_localising.get_item_from_name(recipe.products[1].name, pindex) .. " "
            end
         end
         if recipe.products[1].type == "fluid" then
            --Select product fluid #1
            stats = p.force.fluid_production_statistics
            prototype = game.fluid_prototypes[recipe.name]
            if prototype then
               internal_name = prototype.name
               result = fa_localising.get_fluid_from_name(recipe.products[1].name, pindex) .. " "
            end
         end
         if recipe.products[2] and recipe.products[2].type == "fluid" then
            --Select product fluid #2 (instead)
            stats = p.force.fluid_production_statistics
            prototype = game.fluid_prototypes[recipe.products[2].name]
            if prototype then
               internal_name = prototype.name
               result = fa_localising.get_fluid_from_name(recipe.products[2].name, pindex) .. " "
            end
         end
      end
   end

   if internal_name == nil then
      result = "Error: No selected item or fluid"
      return result
   end
   local interval = defines.flow_precision_index
   local last_minute =
      stats.get_flow_count({ name = internal_name, input = true, precision_index = interval.one_minute, count = true })
   local last_10_minutes =
      stats.get_flow_count({ name = internal_name, input = true, precision_index = interval.ten_minutes, count = true })
   local last_hour =
      stats.get_flow_count({ name = internal_name, input = true, precision_index = interval.one_hour, count = true })
   local thousand_hours = stats.get_flow_count({
      name = internal_name,
      input = true,
      precision_index = interval.one_thousand_hours,
      count = true,
   })
   last_minute = fa_utils.simplify_large_number(last_minute)
   last_10_minutes = fa_utils.simplify_large_number(last_10_minutes)
   last_hour = fa_utils.simplify_large_number(last_hour)
   thousand_hours = fa_utils.simplify_large_number(thousand_hours)
   result = result .. " Produced "
   result = result .. last_minute .. " in the last minute, "
   result = result .. last_10_minutes .. " in the last 10 minutes, "
   result = result .. last_hour .. " in the last hour, "
   result = result .. thousand_hours .. " in the last one thousand hours, "
   return result
end

script.on_event("fa-pda-driving-assistant-info", function(event)
   fa_driving.pda_read_assistant_toggled_info(event.player_index)
end)

script.on_event("fa-pda-cruise-control-info", function(event)
   fa_driving.pda_read_cruise_control_toggled_info(event.player_index)
end)

script.on_event("fa-pda-cruise-control-set-speed-info", function(event)
   printout(
      "Type in the new cruise control speed and press 'ENTER' and then 'E' to confirm, or press 'ESC' to exit",
      pindex
   )
end)

--Reports if the cursor tile is uncharted/blurred and also if it is distant (offscreen)
function cursor_visibility_info(pindex)
   local p = game.get_player(pindex)
   local result = ""
   local pos = players[pindex].cursor_pos
   local chunk_pos = { x = math.floor(pos.x / 32), y = math.floor(pos.y / 32) }
   if p.force.is_chunk_charted(p.surface, chunk_pos) == false then
      result = result .. " uncharted "
   elseif p.force.is_chunk_visible(p.surface, chunk_pos) == false then
      result = result .. " blurred "
   end
   if fa_mouse.cursor_position_is_on_screen_with_player_centered(pindex) == false then
      result = result .. " distant "
   end
   return result
end

script.on_event("nearest-damaged-ent-info", function(event)
   local pindex = event.player_index
   if not check_for_player(pindex) then return end
   read_nearest_damaged_ent_info(players[pindex].cursor_pos, pindex)
end)

--Reads out the distance and direction to the nearest damaged entity within 1000 tiles.
function read_nearest_damaged_ent_info(pos, pindex)
   local p = game.get_player(pindex)
   --Scan for ents of your force
   local ents =
      p.surface.find_entities_filtered({ position = players[pindex].cursor_pos, radius = 1000, force = p.force })
   --Check for entities with health
   if ents == nil or #ents == 0 then
      printout("No damaged structures within 1000 tiles.", pindex)
      return
   end
   local at_least_one_has_damage = false
   local damaged_ents = {}
   for i, ent in ipairs(ents) do
      if ent.is_entity_with_health == true and ent.type ~= "character" and ent.get_health_ratio() < 1 then
         at_least_one_has_damage = true
         table.insert(damaged_ents, ent)
      end
   end
   if at_least_one_has_damage == false then
      printout("No damaged structures within 1000 tiles.", pindex)
      return
   end
   --Narrow by distance
   local closest = nil
   local min_dist = 1001
   for i, ent in ipairs(damaged_ents) do
      local dist = util.distance(pos, ent.position)
      if dist < min_dist then
         min_dist = dist
         closest = ent
         if min_dist < 2 then break end
      end
   end
   if closest == nil then
      printout("No damaged structures within 1000 tiles.", pindex)
      return
   else
      --Move cursor to closest
      players[pindex].cursor_pos = closest.position
      fa_graphics.draw_cursor_highlight(pindex, closest, nil, nil)

      --Report the result
      min_dist = math.floor(min_dist)
      local dir = fa_utils.get_direction_biased(closest.position, pos)
      local aligned_note = ""
      if fa_utils.is_direction_aligned(closest.position, pos) then aligned_note = "aligned " end
      local result = fa_localising.get(closest, pindex)
         .. "  damaged at "
         .. min_dist
         .. " "
         .. aligned_note
         .. fa_utils.direction_lookup(dir)
         .. ", cursor moved. "
      printout(result, pindex)
   end
end

script.on_event("cursor-pollution-info", function(event)
   local pindex = event.player_index
   if not check_for_player(pindex) then return end
   read_pollution_level_at_position(players[pindex].cursor_pos, pindex)
end)

--Reads out the relative pollution level at the input position. The categories are based on data like map view shaders, water discoloration rates. For example, in default settings trees are damaged after pollution exceeds 60 and water is discolored after 90, and the deepest shader applies after 150.
function read_pollution_level_at_position(pos, pindex)
   local p = game.get_player(pindex)
   local pol = p.surface.get_pollution(pos)
   local result = " pollution detected"
   if pol <= 0.1 then
      result = "No" .. result
   elseif pol < 10 then
      result = "Minimal" .. result
   elseif pol < 30 then
      result = "Low" .. result
   elseif pol < 60 then
      result = "Medium" .. result
   elseif pol < 100 then
      result = "High" .. result
   elseif pol < 150 then
      result = "Very high" .. result
   elseif pol < 250 then
      result = "Extremely high" .. result
   elseif pol >= 250 then
      result = "Maximal" .. result
   end
   printout(result, pindex)
end

--Enables remote view if not already, and then enables kruise kontrol
script.on_event("klient-alt-move-to", function(event)
   local pindex = event.player_index
   if not check_for_player(pindex) then return end
   fa_kk.activated_kk(pindex, event)
end)

script.on_event("klient-cancel-enter", function(event)
   local pindex = event.player_index
   if not check_for_player(pindex) then return end
   fa_kk.cancelled_kk(pindex)
end)
