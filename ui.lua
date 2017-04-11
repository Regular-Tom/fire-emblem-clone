require("cursor")
require("action_menu")

ui = {}

function ui.create(world)
    local self = { world = world }
    setmetatable(self, {__index = ui})

    self.state = "cursor"

    self.input_map = { w = "up", r = "down", a = "left", s = "right", z = "select", c = "cancel" }
    self.input_queue = {}

    self.cursor = cursor.create(self, 8, 8)
    self.action_menu = nil

    -- To store temporary movement data (e.g. before attacking to store the unit position).
    self.plan_tile_x = nil
    self.plan_tile_y = nil

    -- Feedback data from cursor or action_menu (e.g. cursor sending selected unit data to create action_menu).
    self.feedback_queue = {}

    return self
end

function ui:process_input(key, pressed)
    local input = self.input_map[key]

    if input and pressed then
        self.input_queue[input] = true
    end
end

function ui:receive_feedback(feedback)
    table.insert(self.feedback_queue, feedback)
end

function ui:process_feedback_queue()
    for k, feedback in pairs(self.feedback_queue) do
        local data = feedback.data
        if feedback.action == "select_position" then
            -- Store original and planned position data.
            self.selected_unit = data.unit
            self.orig_tile_x = data.unit.tile_x
            self.orig_tile_y = data.unit.tile_y
            self.plan_tile_x = data.tile_x
            self.plan_tile_y = data.tile_y

            -- Construct action_menu.
            self.state = "action_menu"
            local x, y = (data.tile_x + 1) * tile_size, data.tile_y * tile_size
            self.action_menu = action_menu.create(self, x, y)
        end
        if feedback.action == "close_action_menu" then
            self.state = "cursor"
            self.selected_unit, self.orig_tile_x, self.orig_tile_y, self.plan_tile_x, self.plan_tile_y = nil
            self.action_menu = nil
        end

        if feedback.action == "attack_prompt" then
            self.state = "cursor"
            self.cursor.state = "attack"
            self.action_menu = nil
        end
        if feedback.action == "wait" then
            self.state = "cursor"
            self.cursor.selected_unit = nil
            self.action_menu = nil

            -- Push command to world to move unit.
            local move_command = { action = "move_unit" }
            move_command.data = { unit = self.selected_unit, tile_x = self.plan_tile_x, tile_y = self.plan_tile_y }
            self.world:receive_command(move_command)
        end

        if feedback.action == "attack" then
            self.state = "cursor"
            self.cursor.state = "move"
            self.cursor.selected_unit = nil

            -- Push command to world to move then attack.
            local move_command = { action = "move_unit" }
            move_command.data = { unit = self.selected_unit, tile_x = self.plan_tile_x, tile_y = self.plan_tile_y }
            self.world:receive_command(move_command)

            local attack_command = { action = "attack" }
            attack_command.data = { attacking_unit = self.selected_unit, target_tile_x = feedback.data.tile_x, target_tile_y = feedback.data.tile_y }
            self.world:receive_command(attack_command)
        end
    end
end

function ui:draw()
    -- Draw unit information.
    local unit = self.cursor:get_unit()
    if unit then
        local info = string.format("%s\nHealth: %i\nStrength: %i\nSpeed: %i", unit.name, unit.health, unit.strength, unit.speed)
        love.graphics.print(info, tile_size, tile_size)
    end

    -- Draw cursor and action_menu at the center of the screen.
    love.graphics.push()

    local cursor_x, cursor_y = self.cursor:get_position()
    love.graphics.translate(love.graphics.getWidth() / zoom / 2 - cursor_x - (tile_size / 2), love.graphics.getHeight() / zoom / 2 - cursor_y - (tile_size / 2))

    self.cursor:draw()

    -- Draw action menu if there's any.
    if self.action_menu then
        self.action_menu:draw()
    end

    love.graphics.pop()
end

function ui:update()
    -- Transfer the control according to the active state.
    if self.state == "cursor" then
        self.cursor:control(self.input_queue)
    elseif self.state == "action_menu" then
        self.action_menu:control(self.input_queue)
    end

    self:process_feedback_queue()

    -- Reset the input queue and feedback queue.
    self.input_queue = {}
    self.feedback_queue = {}
end