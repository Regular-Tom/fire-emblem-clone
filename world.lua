require("animation")
require("unit")
require("unit_class")
require("unit_layer")
require("weapon_class")
require("queue")
require("debug")

local sti = require "libs/Simple-Tiled-Implementation/sti"

world = {
    
}

function world.create(animation)
    local self = {}
    setmetatable(self, {__index = world})

    self.animation = animation

    self.map = sti("maps/test_map.lua")

    self.command_queue = {}

    local unit_layer = unit_layer.create(self.map, 200, 200)

    unit_layer:create_unit(unit_class.sword_fighter, 0, 0, { weapon = weapon_class.iron_sword })
    unit_layer:create_unit(unit_class.axe_fighter, 3, 5, { weapon = weapon_class.iron_axe })
    unit_layer:create_unit(unit_class.lance_fighter, 2, 10, { weapon = weapon_class.iron_lance })
    unit_layer:create_unit(unit_class.bow_fighter, 4, 8, { weapon = weapon_class.iron_bow })
    unit_layer:create_unit(unit_class.generic_unit, 8, 2)

    return self
end

function world:receive_command(command)
    table.insert(self.command_queue, command)
end

function world:process_command_queue()
    for k, command in pairs(self.command_queue) do
        local data = command.data
        if command.action == "move_unit" then
            self:move_unit(data.unit, data.tile_x, data.tile_y)
        end
        if command.action == "attack" then
            self:combat(data.unit, data.tile_x, data.tile_y)
        end
    end

    self.command_queue = {}
end

function world:combat(attacker, tile_x, tile_y)
    local attack_power = attacker.strength + attacker.data.weapon.power

    local target_unit = self:get_unit(tile_x, tile_y)

    if target_unit then
        target_unit.data.health = target_unit.data.health - attack_power
    end

    -- Construct animation from combat.
    local animation = { type = "attack" }
    animation.data = { attacker = attacker, tile_x = tile_x, tile_y = tile_y }

    self.animation:receive_animation(animation)
end

function world:update()
    self:process_command_queue()

    self.map:update()
end

function world:draw()
    self.map:draw()
end

function world:get_unit(tile_x, tile_y)
    return self.map.layers.unit_layer:get_unit(tile_x, tile_y)
end

function world:move_unit(unit, tile_x, tile_y)
    self.map.layers.unit_layer:move_unit(unit, tile_x, tile_y)
end

function world:get_adjacent_tiles(tile_x, tile_y)
    return  {
                { x = tile_x, y = tile_y + 1 },
                { x = tile_x, y = tile_y - 1 },
                { x = tile_x + 1, y = tile_y },
                { x = tile_x - 1, y = tile_y }
            }
end

function world:get_tiles_in_distance(arg)
    local function key(x, y) return string.format("(%i, %i)", x, y) end

    local filter = arg.filter or function() return 1 end

    local output = {}
    output[key(arg.tile_x, arg.tile_y)] = { x = arg.tile_x, y = arg.tile_y, distance = 0 }

    -- Initiate the frontier, with a queue for each unit of distance.
    -- The frontier index is one less than the distance since Lua indexs start from 1.
    local frontiers = {}
    for i = 1, arg.distance + 1 do
        frontiers[i] = queue.create()
    end

    -- Start the frontier from the first tile.
    frontiers[1]:push(output[key(arg.tile_x, arg.tile_y)])

    -- Each iteration increases the distance.
    for i = 1, arg.distance do
        -- Expand each frontier in current distance.
        while not frontiers[i]:empty() do
            local current = frontiers[i]:pop()
            for k, tile in pairs(self:get_adjacent_tiles(current.x, current.y)) do
                -- Get the terrain, if the tile is out of bound then the terrain is nil.
                local terrain
                if tile.x >= 0 and tile.y >= 0 then
                    terrain = self.map:getTileProperties("terrain", tile.x + 1, tile.y + 1).terrain
                end

                -- Get the cost to traverse the terrain using the unit filter, e.g. ground units need 2 movement
                -- unit to traverse a forest terrain.
                local cost = filter(terrain)

                -- If tile is not already in output, and is not impassable, and the distance to the tile is not larger than the max distance
                -- add it to output and frontier.
                if output[key(tile.x, tile.y)] == nil and cost ~= "impassable" and i - 1 + cost <= arg.distance then
                    output[key(tile.x, tile.y)] = { x = tile.x, y = tile.y, distance = i - 1 + cost }
                    frontiers[i + cost]:push(output[key(tile.x, tile.y)])
                end
            end
        end
    end

    if arg.min_distance then
        for k, tile in pairs(output) do
            if tile.distance < arg.min_distance then
                output[k] = nil
            end
        end
    end

    return output
end