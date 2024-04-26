require('__stdlib__/stdlib/event/event').set_protected_mode(true)
require('__stdlib__/stdlib/event/player').register_events(true)

local Event = require('__stdlib__/stdlib/event/event')
local Position = require('__stdlib__/stdlib/area/position')
local Direction = require('__stdlib__/stdlib/area/direction')
local Player = require('__stdlib__/stdlib/event/player')

--[[
   "name": "PickerVehicles",
    "version": "1.1.3",
    "factorio_version": "1.1",
    "title": "Picker Vehicles",
    "author": "Nexela",
--]]

local green = { r = 0.0000, g = 1.0000, b = 0.0000, a = 1 }
local ts = {
    wait_station = defines.train_state.wait_station,
    no_path = defines.train_state.no_path,
    no_schedule = defines.train_state.no_schedule,
    manual = defines.train_state.manual_control
}

local available_ts = {
    [defines.train_state.no_schedule] = true,
    [defines.train_state.no_path] = true
}

local consist = {
    ['locomotive'] = true,
    ['cargo-wagon'] = true,
    ['fluid-wagon'] = true,
    ['artillery-wagon'] = true
}

-- Is the train available for automatic to manual control.
local function available_train(train)
    return available_ts[train.state] or (train.state == ts.wait_station and #train.schedule.records == 1)
end
-- When entering a train if it is in automatic and waiting at a station, or has no schedule or path
-- then set to manual mode.
local function on_player_driving_changed_state(event)
    local player = game.players[event.player_index]
    if player.vehicle and player.vehicle.train and player.mod_settings['picker-auto-manual-train'].value then
        local train = player.vehicle.train
        --Set train to manual
        if #train.passengers == 1 and available_train(train) then
            player.vehicle.train.manual_mode = true
            player.create_local_flying_text {
                text = {'vehicles.manual-mode'},
                position = player.vehicle.position,
                color = green
            }
        end
    end
end
Event.register(defines.events.on_player_driving_changed_state, on_player_driving_changed_state)
-- Hotkey for toggling a train between automatic and manual.
local function toggle_train_control(event)
    local player = game.get_player(event.player_index)
    local vehicle = player.vehicle
    local selected = player.selected
    local train = selected and selected.train or vehicle and player.vehicle.train

    if train and not (selected and selected.type == 'train-stop') then
        train.manual_mode = not train.manual_mode
        local text = train.manual_mode and {'vehicles.manual-mode'} or {'vehicles.automatic-mode'}
        player.create_local_flying_text {
            text = text,
            position = vehicle and vehicle.position or selected and selected.position,
            color = green
        }
    end
end
Event.register('picker-toggle-train-control', toggle_train_control)

--[[
	"name": "auto_manual_mode",
	"version": "0.0.9",
	"title": "Auto Manual Mode",
	"author": "Roy Scheerens",
	"description": "When in a train, using the movement controls will automatically set the train in manual mode.",
--]]
local function set_to_manual(event)
    local player = game.get_player(event.player_index)
    local vehicle = player.vehicle

    if vehicle then
        local train = vehicle.train
        if train and not train.manual_mode and player.render_mode == defines.render_mode.game then
            if not player.mod_settings['picker-manual-train-keys'].value then
                return
            end
            train.manual_mode = true
            player.create_local_flying_text {
                text = {'vehicles.manual-mode'},
                position = vehicle.position,
                color = green
            }
        end
    end
end
local keys = {'picker-up-event', 'picker-down-event', 'picker-left-event', 'picker-right-event'}
Event.register(keys, set_to_manual)

--[[
--Restore on exit

script.on_event(
    defines.events.on_player_driving_changed_state,
    function(e)

        local player = game.players[e.player_index];
        local vehicle = e.entity;

        if player and vehicle and vehicle.train and settings.get_player_settings(player)["auto_manual_mode_restore_when_exit"].value and vehicle.train.id == global.auto_manual_mode[e.player_index] then
            vehicle.train.manual_mode = false;
        end

        global.auto_manual_mode[e.player_index] = 0;
    end
);
]]
--[[
    "name": "belt-reverser", 
    "title": "Belt Reverser", 
    "author": "Cogito",
    "homepage": "https://github.com/Cogito/belt-reverser",
    "description": "Reverse entire segments of belt",
    "license": "MIT"

    "name": "PickerBeltTools",
  "version": "1.2.6",
  "factorio_version": "1.1",
  "title": "Picker Belt Tools",
  "author": "Nexela",
--]]

local op_dir = Direction.opposite_direction

local belt_types = {
    ['transport-belt'] = true,
    ['loader'] = true,
    ['underground-belt'] = true
}

-- replace the current line contents with contents
local function replace_line_contents(line, contents)
    line.clear()
    local current = 0

    for _, name in pairs(contents) do
        line.insert_at(current, {name = name, count = 1})
        current = current + (0.03125 * 9)
    end
end

-- Get the reverse order of contents
local function get_contents(line)
    local contents = {}

    for i = #line, 1, -1 do
        contents[#contents + 1] = line[i].name
    end
    return contents
end

local function flip_lines(belt)
    local line_one = belt.get_transport_line(1)
    local line_two = belt.get_transport_line(2)
    --Get the contents before swapping otherwise we will be getting the wrong contents #77
    --Using a custom get_contents to keep ordering.
    local contents_one = get_contents(line_one)
    local contents_two = get_contents(line_two)
    replace_line_contents(line_one, contents_two)
    replace_line_contents(line_two, contents_one)
end

local function getBeltLike(surface, position, type)
    return surface.find_entities_filtered {position = position, type = type}[1]
end

local function isBeltTerminatingDownstream(belt, distance)
    distance = distance or 1
    local pos = Position(belt.position):translate(belt.direction, distance)
    local downstreamBelt = getBeltLike(belt.surface, pos, 'transport-belt')
    local downstreamUGBelt = getBeltLike(belt.surface, pos, 'underground-belt')
    local downstreamLoader = getBeltLike(belt.surface, pos, 'loader')

    if downstreamBelt and downstreamBelt.direction ~= op_dir(belt.direction) then
        return false
    end
    if downstreamUGBelt and downstreamUGBelt.direction == belt.direction and downstreamUGBelt.belt_to_ground_type == 'input' then
        return false
    end
    if downstreamLoader and downstreamLoader.direction == belt.direction and downstreamLoader.loader_type == 'input' then
        return false
    end
    return true
end

local function isBeltSideloadingDownstream(belt, distance)
    distance = distance or 1
    local pos = Position(belt.position):translate(belt.direction, distance)
    local downstreamBelt = getBeltLike(belt.surface, pos, 'transport-belt')
    local downstreamUGBelt = getBeltLike(belt.surface, pos, 'underground-belt')
    local downstreamLoader = getBeltLike(belt.surface, pos, 'loader')
    if downstreamLoader then
        return false
    end
    if downstreamUGBelt and (downstreamUGBelt.direction == belt.direction or downstreamUGBelt.direction == op_dir(belt.direction)) then
        return false
    end
    if downstreamBelt then
        if (downstreamBelt.direction == belt.direction or downstreamBelt.direction == op_dir(belt.direction)) then
            return false
        else
            local up_pos = Position(downstreamBelt.position):translate(op_dir(downstreamBelt.direction))
            local upstreamBelt = getBeltLike(belt.surface, up_pos, 'transport-belt')
            local upstreamUGBelt = getBeltLike(belt.surface, up_pos, 'underground-belt')
            local upstreamLoader = getBeltLike(belt.surface, up_pos, 'loader')

            local opposite_pos = Position(downstreamBelt.position):translate(belt.direction)
            local oppositeBelt = getBeltLike(belt.surface, opposite_pos, 'transport-belt')
            local oppositeUGBelt = getBeltLike(belt.surface, opposite_pos, 'underground-belt')
            local oppositeLoader = getBeltLike(belt.surface, opposite_pos, 'loader')

            local continuingBelt = true
            if not (upstreamBelt or upstreamUGBelt or upstreamLoader) then
                continuingBelt = false
            end
            if upstreamBelt and upstreamBelt.direction ~= downstreamBelt.direction then
                continuingBelt = false
            end
            if upstreamUGBelt and not (upstreamUGBelt.direction == downstreamBelt.direction and upstreamUGBelt.belt_to_ground_type == 'output') then
                continuingBelt = false
            end
            if upstreamLoader and upstreamLoader.direction ~= downstreamBelt.direction then
                continuingBelt = false
            end

            local sandwichBelt = true
            if not (oppositeBelt or oppositeUGBelt or oppositeLoader) then
                sandwichBelt = false
            end

            local opposite_direction = op_dir(belt.direction)
            if oppositeBelt and oppositeBelt.direction ~= opposite_direction then
                sandwichBelt = false
            end
            if oppositeUGBelt and not (oppositeUGBelt.direction == opposite_direction and oppositeUGBelt.belt_to_ground_type == 'output') then
                sandwichBelt = false
            end
            if oppositeLoader and oppositeLoader.direction ~= opposite_direction then
                sandwichBelt = false
            end

            if not continuingBelt and not sandwichBelt then
                return false
            end
        end
    end
    return true
end

local function get_next_downstream_transport_line(belt)
    local distance = 1
    if belt.type == 'underground-belt' and belt.belt_to_ground_type == 'input' then
        if belt.neighbours then
            return belt.neighbours
        else
            return nil
        end
    end
    if belt.type == 'loader' then
        if belt.loader_type == 'output' then
            distance = 1.5
        else
            return nil
        end
    end

    local pos = Position(belt.position):translate(belt.direction, distance)
    local downstreamBelt = getBeltLike(belt.surface, pos, 'transport-belt')
    local downstreamUGBelt = getBeltLike(belt.surface, pos, 'underground-belt')
    local downstreamLoader = getBeltLike(belt.surface, pos, 'loader')

    if isBeltTerminatingDownstream(belt, distance) then
        return nil
    end
    if isBeltSideloadingDownstream(belt, distance) then
        return nil
    end
    local returnBelt = downstreamBelt or downstreamUGBelt or downstreamLoader
    return returnBelt
end

local function getUpstreamBeltInDirection(belt, direction, distance)
    distance = distance or 1
    local pos = Position(belt.position):translate(direction, distance)
    local upstreamBelt = getBeltLike(belt.surface, pos, 'transport-belt')
    local upstreamUGBelt = getBeltLike(belt.surface, pos, 'underground-belt')
    local upstreamLoader = getBeltLike(belt.surface, pos, 'loader')
    local opposite_direction = op_dir(direction)
    if upstreamBelt and upstreamBelt.direction == opposite_direction then
        return upstreamBelt
    end
    if upstreamLoader and upstreamLoader.direction == opposite_direction and upstreamLoader.loader_type == 'output' then
        return upstreamLoader
    end
    if upstreamUGBelt and upstreamUGBelt.direction == opposite_direction and upstreamUGBelt.belt_to_ground_type == 'output' then
        return upstreamUGBelt
    end
    return nil
end

local function get_next_upstream_transport_line(belt)
    if belt.type == 'underground-belt' and belt.belt_to_ground_type == 'output' then
        if belt.neighbours then
            return belt.neighbours
        else
            return nil
        end
    end
    if belt.type == 'loader' then
        if belt.loader_type == 'input' then
            local linearBelt = getUpstreamBeltInDirection(belt, op_dir(belt.direction), 1.5)
            if linearBelt then
                return linearBelt
            end
        end
        return nil
    end
    local linearBelt = getUpstreamBeltInDirection(belt, op_dir(belt.direction))
    local leftTurnBelt = getUpstreamBeltInDirection(belt, Direction.next_direction(belt.direction))
    local rightTurnBelt = getUpstreamBeltInDirection(belt, Direction.next_direction(belt.direction, true))
    if linearBelt then
        return linearBelt
    end
    if leftTurnBelt and not rightTurnBelt then
        return leftTurnBelt
    end
    if rightTurnBelt and not leftTurnBelt then
        return rightTurnBelt
    end
    return nil
end

local function find_start_of_transport_line(current_belt, initial_belt)
    local next_belt = get_next_upstream_transport_line(current_belt)
    if not next_belt then
        return current_belt
    end
    if next_belt == initial_belt then
        if next_belt.type == 'underground-belt' and next_belt.belt_to_ground_type == 'input' then
            return next_belt
        else
            return current_belt
        end
    end
    return find_start_of_transport_line(next_belt, initial_belt)
end

local function reverse_transport_entity(belt, direction)
    if belt.type == 'loader' or (belt.type == 'underground-belt' and belt.belt_to_ground_type == 'input') then
        belt.rotate()
    else
        belt.direction = direction
        flip_lines(belt)
    end
end

local function reverse_downstream_transport_line(current_belt, start_belt)
    local next_belt = get_next_downstream_transport_line(current_belt)
    if not next_belt or next_belt == start_belt then
        return -- we've nothing left to do as at end of belt
    else
        -- set next_belt direction to the opposite of current belt - this should reverse the entire line - but do it after reversing downstream
        reverse_downstream_transport_line(next_belt, start_belt)
        reverse_transport_entity(next_belt, op_dir(current_belt.direction))
    end
end

local function reverse_entire_transport_line(event)
    local player = game.players[event.player_index]
    if player.selected and player.controller_type ~= defines.controllers.ghost and belt_types[player.selected.type] then
        local initial_belt = player.selected
        local start_belt = find_start_of_transport_line(initial_belt, initial_belt)
        local directionToTurnStartBelt = op_dir(start_belt.direction)

        reverse_downstream_transport_line(start_belt, start_belt)

        reverse_transport_entity(start_belt, directionToTurnStartBelt)
    end
end
Event.register('picker-reverse-belts', reverse_entire_transport_line)

--[[
    name": "PickerInventoryTools",
  "version": "1.1.16",
  "factorio_version": "1.1",
  "title": "Picker Inventory Tools",
  "author": "Nexela",
  ]]
--Item Zapper

local trash_types = {
    ['blueprint'] = false,
    ['blueprint-book'] = false,
    ['deconstruction-item'] = true,
    ['selection-tool'] = true,
    ['upgrade-item'] = true
}

-- Zap on keybind
local function zapper(event)
    local player, pdata = Player.get(event.player_index)
    local stack = player.cursor_stack

    if stack and stack.valid_for_read then
        local all = player.mod_settings['picker-item-zapper-all'].value

        if all or trash_types[stack.type] then
            if (pdata.last_dropped or 0) + 30 < game.tick then
                pdata.last_dropped = game.tick
                player.cursor_stack.clear()
                player.surface.create_entity {
                    name = 'drop-planner',
                    position = Position(player.position):translate(math.random(0, 7), math.random())
                }
            end
        end
    end
end
Event.register('picker-zapper', zapper)

-- Zap any planner item on drop
local function on_player_dropped_item(event)
    local stack = event.entity and event.entity.stack
    if stack and trash_types[stack.type] then
        event.entity.surface.create_entity {
            name = 'drop-planner',
            position = event.entity.position
        }
        event.entity.destroy()
    end
end
Event.register(defines.events.on_player_dropped_item, on_player_dropped_item)

local function trash_planners(event)
    local player = game.get_player(event.player_index)
    local settings = player.mod_settings

    local inventory = player.get_inventory(defines.inventory.character_trash)
    if inventory then
        if player.cheat_mode and settings['picker-trash-cheat'].value then
            inventory.clear()
        elseif settings['picker-trash-planners'].value then
            for i = 1, #inventory do
                local slot = inventory[i]
                if slot.valid_for_read and trash_types[slot.type] then
                    slot.clear()
                    return
                end
            end
        end
    end
end
Event.register(defines.events.on_player_trash_inventory_changed, trash_planners)
