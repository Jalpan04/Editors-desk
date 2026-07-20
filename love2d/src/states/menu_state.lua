local config = require("src/config")
local ui = require("src/engine/ui")
local State = require("src/engine/state_machine").State

local MenuState = setmetatable({}, State)
MenuState.__index = MenuState

function MenuState.new(state_machine, run_manager)
    local self = State.new(state_machine, run_manager)
    setmetatable(self, MenuState)
    
    self.buttons = {}
    self.title_font = config.get_font("typewriter", 64)
    self.subtitle_font = config.get_font("sans", 24)
    self.desc_font = config.get_font("sans", 18)
    
    self.blinking_timer = 0
    self.show_cursor = true
    
    local start_btn = ui.Button.new(
        config.SCREEN_WIDTH / 2 - 120,
        400,
        240,
        50,
        "Start Assignment",
        function() self:start_game() end,
        {52/255, 152/255, 219/255}
    )
    local exit_btn = ui.Button.new(
        config.SCREEN_WIDTH / 2 - 120,
        480,
        240,
        50,
        "Resign (Exit)",
        function() self:exit_game() end,
        {231/255, 76/255, 60/255}
    )
    table.insert(self.buttons, start_btn)
    table.insert(self.buttons, exit_btn)
    
    return self
end

function MenuState:enter(kwargs) end

function MenuState:start_game()
    self.state_machine:change_state("assignment_select")
end

function MenuState:exit_game()
    love.event.quit()
end

function MenuState:update(dt)
    self.blinking_timer = self.blinking_timer + dt
    if self.blinking_timer >= 0.5 then
        self.show_cursor = not self.show_cursor
        self.blinking_timer = 0.0
    end
    
    local mx, my = love.mouse.getPosition()
    mx, my = config.mx or mx, config.my or my
    
    for _, btn in ipairs(self.buttons) do
        btn:check_hover(mx, my)
        btn:update(dt)
    end
end

function MenuState:mousepressed(x, y, button, istouch, presses)
    local mx, my = config.mx or x, config.my or y
    for _, btn in ipairs(self.buttons) do
        if btn:handle_event("mousepressed", mx, my, button) then
            break
        end
    end
end

function MenuState:draw()
    love.graphics.setColor(config.COLOR_DESK[1], config.COLOR_DESK[2], config.COLOR_DESK[3], 1.0)
    love.graphics.rectangle("fill", 0, 0, config.SCREEN_WIDTH, config.SCREEN_HEIGHT)
    
    local px, py, pw, ph = config.SCREEN_WIDTH / 2 - 350, 50, 700, 620
    love.graphics.setColor(20/255, 20/255, 25/255, 1.0)
    love.graphics.rectangle("fill", px - 4, py - 4, pw + 8, ph + 8, 8, 8)
    
    love.graphics.setColor(config.COLOR_PAPER[1], config.COLOR_PAPER[2], config.COLOR_PAPER[3], 1.0)
    love.graphics.rectangle("fill", px, py, pw, ph, 6, 6)
    
    local title_str = "The Editor's Desk"
    if self.show_cursor then
        title_str = title_str .. "_"
    end
    love.graphics.setFont(self.title_font)
    love.graphics.setColor(config.COLOR_TEXT_DARK[1], config.COLOR_TEXT_DARK[2], config.COLOR_TEXT_DARK[3], 1.0)
    local tw = self.title_font:getWidth(title_str)
    love.graphics.print(title_str, config.SCREEN_WIDTH / 2 - tw / 2, 130)
    
    love.graphics.setFont(self.subtitle_font)
    love.graphics.setColor(config.COLOR_TEXT_MUTED[1], config.COLOR_TEXT_MUTED[2], config.COLOR_TEXT_MUTED[3], 1.0)
    local sub_str = "A Roguelike Word-Building Adventure"
    local sw = self.subtitle_font:getWidth(sub_str)
    love.graphics.print(sub_str, config.SCREEN_WIDTH / 2 - sw / 2, 220)
    
    love.graphics.setFont(self.desc_font)
    love.graphics.setColor(config.COLOR_TEXT_DARK[1], config.COLOR_TEXT_DARK[2], config.COLOR_TEXT_DARK[3], 1.0)
    local desc_lines = {
        "Your desk is cluttered with manuscripts.",
        "Choose your words carefully to beat target Hype scores.",
        "Draft without scoring to find letter placements.",
        "Purchase Style Guides, Stationery items, and keyboard enhancements",
        "to survive 8 Chapters and edit the most chaotic Authors."
    }
    local y_off = 270
    for _, line in ipairs(desc_lines) do
        local lw = self.desc_font:getWidth(line)
        love.graphics.print(line, config.SCREEN_WIDTH / 2 - lw / 2, y_off)
        y_off = y_off + 22
    end
    
    for _, btn in ipairs(self.buttons) do
        btn:draw()
    end
end

return MenuState
