local config = require("src/config")
local ui = require("src/engine/ui")
local State = require("src/engine/state_machine").State

local GameOverState = setmetatable({}, State)
GameOverState.__index = GameOverState

function GameOverState.new(state_machine, run_manager)
    local self = State.new(state_machine, run_manager)
    setmetatable(self, GameOverState)
    
    self.buttons = {}
    self.title_font = config.get_font("typewriter", 56)
    self.lbl_font = config.get_font("sans", 24)
    self.desc_font = config.get_font("sans", 18)
    self.stat_font = config.get_font("sans", 22)
    
    self.result = "fired"
    
    return self
end

function GameOverState:enter(kwargs)
    self.result = kwargs.result or "fired"
    self.buttons = {}
    
    table.insert(self.buttons, ui.Button.new(
        config.SCREEN_WIDTH / 2 - 220,
        460,
        200,
        50,
        "Try Again",
        function() self:retry_run() end,
        {46/255, 180/255, 110/255}
    ))
    table.insert(self.buttons, ui.Button.new(
        config.SCREEN_WIDTH / 2 + 20,
        460,
        200,
        50,
        "Main Menu",
        function() self:goto_menu() end,
        {52/255, 152/255, 219/255}
    ))
end

function GameOverState:retry_run()
    local RunManager = require("src/gameplay/run_manager")
    local new_rm = RunManager.new()
    self.state_machine.run_manager = new_rm
    
    for _, s in pairs(self.state_machine.states) do
        s.run_manager = new_rm
    end
    
    self.state_machine:change_state("assignment_select")
end

function GameOverState:goto_menu()
    self.state_machine:change_state("menu")
end

function GameOverState:update(dt)
    local mx, my = love.mouse.getPosition()
    mx, my = config.mx or mx, config.my or my
    
    for _, btn in ipairs(self.buttons) do
        btn:check_hover(mx, my)
        btn:update(dt)
    end
end

function GameOverState:mousepressed(x, y, button, istouch, presses)
    local mx, my = config.mx or x, config.my or y
    for _, btn in ipairs(self.buttons) do
        if btn:handle_event("mousepressed", mx, my, button) then
            break
        end
    end
end

function GameOverState:draw()
    ui.draw_background()
    
    local px, py, pw, ph = config.SCREEN_WIDTH / 2 - 320, 60, 640, 600
    love.graphics.setColor(15/255, 15/255, 20/255, 1.0)
    love.graphics.rectangle("fill", px - 8, py - 8, pw + 16, ph + 16, 8, 8)
    
    if config.images.overlay_paper then
        love.graphics.setColor(1.0, 1.0, 1.0, 1.0)
        love.graphics.draw(config.images.overlay_paper, px, py, 0, pw / config.images.overlay_paper:getWidth(), ph / config.images.overlay_paper:getHeight())
    else
        love.graphics.setColor(config.COLOR_PAPER[1], config.COLOR_PAPER[2], config.COLOR_PAPER[3], 1.0)
        love.graphics.rectangle("fill", px, py, pw, ph, 6, 6)
    end
    
    local title_text, accent_col, desc_text
    if self.result == "published" then
        title_text = "PUBLISHED!"
        accent_col = config.COLOR_CLUE_GREEN
        desc_text = "Congratulations! Your manuscript has become a national bestseller."
    else
        title_text = "YOU ARE FIRED"
        accent_col = config.COLOR_ACCENT
        desc_text = "You ran out of submissions before meeting the Hype requirements."
    end
    
    love.graphics.setFont(self.title_font)
    love.graphics.setColor(accent_col[1], accent_col[2], accent_col[3], 1.0)
    local tw = self.title_font:getWidth(title_text)
    love.graphics.print(title_text, config.SCREEN_WIDTH / 2 - tw / 2, 115)
    
    love.graphics.setFont(self.desc_font)
    love.graphics.setColor(config.COLOR_TEXT_DARK[1], config.COLOR_TEXT_DARK[2], config.COLOR_TEXT_DARK[3], 1.0)
    local dw = self.desc_font:getWidth(desc_text)
    love.graphics.print(desc_text, config.SCREEN_WIDTH / 2 - dw / 2, 200)
    
    love.graphics.setColor(config.COLOR_TEXT_MUTED[1], config.COLOR_TEXT_MUTED[2], config.COLOR_TEXT_MUTED[3], 1.0)
    love.graphics.line(config.SCREEN_WIDTH / 2 - 250, 240, config.SCREEN_WIDTH / 2 + 250, 240)
    
    local stats = {
        "Chapters Completed: " .. (self.run_manager.chapter - 1) .. " / 8",
        "Final Royalties Earned: $" .. self.run_manager.royalties,
        "Active Tropes Equipped: " .. #self.run_manager.tropes,
    }
    
    local y_off = 265
    love.graphics.setFont(self.stat_font)
    love.graphics.setColor(config.COLOR_TEXT_DARK[1], config.COLOR_TEXT_DARK[2], config.COLOR_TEXT_DARK[3], 1.0)
    for _, stat in ipairs(stats) do
        local sw = self.stat_font:getWidth(stat)
        love.graphics.print(stat, config.SCREEN_WIDTH / 2 - sw / 2, y_off)
        y_off = y_off + 30
    end
    
    love.graphics.setFont(self.lbl_font)
    love.graphics.setColor(config.COLOR_TEXT_DARK[1], config.COLOR_TEXT_DARK[2], config.COLOR_TEXT_DARK[3], 1.0)
    love.graphics.print("Your Desk Tropes:", config.SCREEN_WIDTH / 2 - 240, 360)
    
    love.graphics.setFont(self.desc_font)
    if #self.run_manager.tropes == 0 then
        love.graphics.setColor(config.COLOR_TEXT_MUTED[1], config.COLOR_TEXT_MUTED[2], config.COLOR_TEXT_MUTED[3], 1.0)
        love.graphics.print("None (No modifiers equipped)", config.SCREEN_WIDTH / 2 - 240, 395)
    else
        local y_t = 395
        love.graphics.setColor(config.COLOR_TEXT_DARK[1], config.COLOR_TEXT_DARK[2], config.COLOR_TEXT_DARK[3], 1.0)
        for idx = 1, math.min(3, #self.run_manager.tropes) do
            local trope = self.run_manager.tropes[idx]
            local desc_sub = trope.description:sub(1, 55)
            if #trope.description > 55 then
                desc_sub = desc_sub .. "..."
            end
            love.graphics.print("- " .. trope.name .. ": " .. desc_sub, config.SCREEN_WIDTH / 2 - 240, y_t)
            y_t = y_t + 22
        end
    end
    
    for _, btn in ipairs(self.buttons) do
        btn:draw()
    end
end

return GameOverState
