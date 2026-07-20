local config = require("src/config")
local ui = require("src/engine/ui")
local State = require("src/engine/state_machine").State
local Author = require("src/content/authors").Author

local AssignmentSelectState = setmetatable({}, State)
AssignmentSelectState.__index = AssignmentSelectState

function AssignmentSelectState.new(state_machine, run_manager)
    local self = State.new(state_machine, run_manager)
    setmetatable(self, AssignmentSelectState)
    
    self.buttons = {}
    self.title_font = config.get_font("typewriter", 36)
    self.label_font = config.get_font("sans", 20)
    self.desc_font = config.get_font("sans", 16)
    self.stat_font = config.get_font("sans", 24)
    
    return self
end

function AssignmentSelectState:enter(kwargs)
    self.buttons = {}
    local active_idx = self.run_manager.assignment_index
    
    if active_idx == 0 then
        table.insert(self.buttons, ui.Button.new(
            140 + 60, 490, 160, 45,
            "Begin Draft",
            function() self:start_active_assignment() end,
            {46/255, 204/255, 113/255}
        ))
    elseif active_idx == 1 then
        table.insert(self.buttons, ui.Button.new(
            500 + 60, 490, 160, 45,
            "Begin Proof",
            function() self:start_active_assignment() end,
            {46/255, 204/255, 113/255}
        ))
    elseif active_idx == 2 then
        table.insert(self.buttons, ui.Button.new(
            860 + 60, 490, 160, 45,
            "Begin Boss",
            function() self:start_active_assignment() end,
            {231/255, 76/255, 60/255}
        ))
    end
end

function AssignmentSelectState:start_active_assignment()
    self.run_manager:start_round()
    self.state_machine:change_state("game")
end

function AssignmentSelectState:update(dt)
    local mx, my = love.mouse.getPosition()
    mx, my = config.mx or mx, config.my or my
    
    for _, btn in ipairs(self.buttons) do
        btn:check_hover(mx, my)
        btn:update(dt)
    end
end

function AssignmentSelectState:mousepressed(x, y, button, istouch, presses)
    local mx, my = config.mx or x, config.my or y
    for _, btn in ipairs(self.buttons) do
        if btn:handle_event("mousepressed", mx, my, button) then
            break
        end
    end
end

function AssignmentSelectState:get_assignment_target_score(idx)
    local chapter_bases = {0, 500, 1500, 4000, 10000, 25000, 60000, 120000, 250000}
    local base_idx = math.min(self.run_manager.chapter, 8) + 1
    local base = chapter_bases[base_idx] or 250000
    
    local target = 0
    if idx == 0 then
        target = base
    elseif idx == 1 then
        target = math.floor(base * 1.6)
    else
        target = math.floor(base * 2.4)
    end
    
    local has_ghostwriter = false
    for _, t in ipairs(self.run_manager.tropes) do
        if t.name == "The Ghostwriter" and t.is_debuff_active then
            has_ghostwriter = true
            break
        end
    end
    if has_ghostwriter then
        target = math.floor(target * 1.5)
    end
    return target
end

function AssignmentSelectState:draw()
    love.graphics.setColor(config.COLOR_DESK[1], config.COLOR_DESK[2], config.COLOR_DESK[3], 1.0)
    love.graphics.rectangle("fill", 0, 0, config.SCREEN_WIDTH, config.SCREEN_HEIGHT)
    
    love.graphics.setColor(config.COLOR_PANEL[1], config.COLOR_PANEL[2], config.COLOR_PANEL[3], 1.0)
    love.graphics.rectangle("fill", 0, 0, config.SCREEN_WIDTH, 60)
    
    love.graphics.setColor(config.COLOR_TEXT_MUTED[1], config.COLOR_TEXT_MUTED[2], config.COLOR_TEXT_MUTED[3], 1.0)
    love.graphics.setLineWidth(2)
    love.graphics.line(0, 60, config.SCREEN_WIDTH, 60)
    
    love.graphics.setFont(self.stat_font)
    love.graphics.setColor(config.COLOR_ROYALTIES[1], config.COLOR_ROYALTIES[2], config.COLOR_ROYALTIES[3], 1.0)
    love.graphics.print("Royalties: $" .. self.run_manager.royalties, 30, 15)
    
    love.graphics.setColor(config.COLOR_TEXT_LIGHT[1], config.COLOR_TEXT_LIGHT[2], config.COLOR_TEXT_LIGHT[3], 1.0)
    local chap_str = "Chapter: " .. self.run_manager.chapter .. " / 8"
    local chap_w = self.stat_font:getWidth(chap_str)
    love.graphics.print(chap_str, config.SCREEN_WIDTH / 2 - chap_w / 2, 15)
    
    love.graphics.setColor(config.COLOR_TEXT_MUTED[1], config.COLOR_TEXT_MUTED[2], config.COLOR_TEXT_MUTED[3], 1.0)
    local items_str = "Stationery: " .. #self.run_manager.tropes .. "/5 | Snacks: " .. #self.run_manager.edits .. "/2"
    local items_w = self.stat_font:getWidth(items_str)
    love.graphics.print(items_str, config.SCREEN_WIDTH - items_w - 30, 15)
    
    love.graphics.setFont(self.title_font)
    love.graphics.setColor(config.COLOR_TEXT_LIGHT[1], config.COLOR_TEXT_LIGHT[2], config.COLOR_TEXT_LIGHT[3], 1.0)
    local header_str = "Chapter " .. self.run_manager.chapter .. " Assignments"
    local header_w = self.title_font:getWidth(header_str)
    love.graphics.print(header_str, config.SCREEN_WIDTH / 2 - header_w / 2, 85)
    
    local card_w, card_h = 280, 380
    local card_y = 170
    
    self:draw_assignment_card(
        140, card_y, card_w, card_h,
        "Draft Manuscript",
        "Small Assignment",
        self:get_assignment_target_score(0),
        "$3 base + submission bonuses",
        0,
        self.run_manager.assignment_index
    )
    
    self:draw_assignment_card(
        500, card_y, card_w, card_h,
        "Proofread Manuscript",
        "Big Assignment",
        self:get_assignment_target_score(1),
        "$4 base + submission bonuses",
        1,
        self.run_manager.assignment_index
    )
    
    local boss_name = self.run_manager.selected_boss
    local author = Author.new(boss_name)
    self:draw_assignment_card(
        860, card_y, card_w, card_h,
        author.display_name,
        "Bestselling Author",
        self:get_assignment_target_score(2),
        "$5 base + submission bonuses",
        2,
        self.run_manager.assignment_index,
        author.description
    )
    
    for _, btn in ipairs(self.buttons) do
        btn:draw()
    end
end

function AssignmentSelectState:draw_assignment_card(x, y, w, h, title, subtitle, target, reward, state, active_idx, description)
    local bg_color, border_color, text_color, status_text
    
    if state < active_idx then
        bg_color = {40/255, 42/255, 50/255}
        border_color = config.COLOR_TEXT_MUTED
        text_color = config.COLOR_TEXT_MUTED
        status_text = "COMPLETED"
    elseif state == active_idx then
        bg_color = config.COLOR_PANEL
        border_color = (state < 2) and config.COLOR_CLUE_GREEN or config.COLOR_ACCENT
        text_color = config.COLOR_TEXT_LIGHT
        status_text = "ASSIGNED"
    else
        bg_color = {24/255, 26/255, 32/255}
        border_color = {50/255, 52/255, 60/255}
        text_color = config.COLOR_TEXT_MUTED
        status_text = "LOCKED"
    end
    
    love.graphics.setColor(bg_color[1], bg_color[2], bg_color[3], 1.0)
    love.graphics.rectangle("fill", x, y, w, h, 10, 10)
    love.graphics.setColor(border_color[1], border_color[2], border_color[3], 1.0)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", x, y, w, h, 10, 10)
    
    love.graphics.setFont(self.desc_font)
    local sub_str = subtitle:upper()
    local sub_w = self.desc_font:getWidth(sub_str)
    love.graphics.print(sub_str, x + (w - sub_w) / 2, y + 20)
    
    love.graphics.setFont(self.label_font)
    local title_w = self.label_font:getWidth(title)
    love.graphics.setColor(text_color[1], text_color[2], text_color[3], 1.0)
    love.graphics.print(title, x + (w - title_w) / 2, y + 55)
    
    love.graphics.setColor(border_color[1], border_color[2], border_color[3], 1.0)
    love.graphics.setLineWidth(1)
    love.graphics.line(x + 30, y + 95, x + w - 30, y + 95)
    
    love.graphics.setFont(self.desc_font)
    love.graphics.setColor(config.COLOR_TEXT_MUTED[1], config.COLOR_TEXT_MUTED[2], config.COLOR_TEXT_MUTED[3], 1.0)
    love.graphics.print("TARGET HYPE SCORE:", x + 30, y + 115)
    
    local target_str = tostring(target)
    local target_formatted = target_str:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    love.graphics.setFont(self.label_font)
    love.graphics.setColor(text_color[1], text_color[2], text_color[3], 1.0)
    love.graphics.print(target_formatted, x + 30, y + 135)
    
    love.graphics.setFont(self.desc_font)
    love.graphics.setColor(config.COLOR_TEXT_MUTED[1], config.COLOR_TEXT_MUTED[2], config.COLOR_TEXT_MUTED[3], 1.0)
    love.graphics.print("ESTIMATED ROYALTIES:", x + 30, y + 175)
    
    love.graphics.setColor(text_color[1], text_color[2], text_color[3], 1.0)
    love.graphics.print(reward, x + 30, y + 195)
    
    if description then
        local desc_y = y + 240
        
        local desc_words = {}
        for word in description:gmatch("%S+") do
            table.insert(desc_words, word)
        end
        local lines = {}
        local curr_line = ""
        for _, word in ipairs(desc_words) do
            if #curr_line + #word + 1 < 26 then
                curr_line = curr_line .. (curr_line == "" and "" or " ") .. word
            else
                table.insert(lines, curr_line)
                curr_line = word
            end
        end
        if curr_line ~= "" then
            table.insert(lines, curr_line)
        end
        
        love.graphics.setFont(self.desc_font)
        for idx, line in ipairs(lines) do
            if idx <= 4 then
                local line_color = (state == active_idx) and config.COLOR_ACCENT or config.COLOR_TEXT_MUTED
                love.graphics.setColor(line_color[1], line_color[2], line_color[3], 1.0)
                love.graphics.print(line, x + 30, desc_y)
                desc_y = desc_y + 18
            end
        end
    end
    
    if state ~= active_idx then
        love.graphics.setFont(self.label_font)
        love.graphics.setColor(border_color[1], border_color[2], border_color[3], 1.0)
        local stat_w = self.label_font:getWidth(status_text)
        love.graphics.print(status_text, x + (w - stat_w) / 2, y + h - 50)
    end
end

return AssignmentSelectState
