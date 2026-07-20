local config = require("src/config")
local ui = require("src/engine/ui")
local State = require("src/engine/state_machine").State
local scoring = require("src/gameplay/scoring")

local ScoringState = setmetatable({}, State)
ScoringState.__index = ScoringState

function ScoringState.new(state_machine, run_manager)
    local self = State.new(state_machine, run_manager)
    setmetatable(self, ScoringState)
    
    self.buttons = {}
    self.particles = ui.ParticleSystem.new()
    self.shake = ui.ScreenShake.new()
    
    self.typewriter_font = config.get_font("typewriter", 28)
    self.ui_font = config.get_font("sans", 20)
    self.ui_bold = config.get_font_bold(22)
    self.score_font = config.get_font("sans", 32)
    self.math_font = config.get_font("sans", 24)
    self.tooltip_font = config.get_font("sans", 14)
    
    self.kbd_rows = {
        {'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'},
        {'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l'},
        {'z', 'x', 'c', 'v', 'b', 'n', 'm', ';'}
    }
    
    self.anim_stage = "done"
    self.letter_idx = 1
    self.timer = 0.0
    
    self.displayed_words = 0
    self.displayed_hype = 1.0
    self.displayed_x_hypes = {}
    self.target_words = 0
    self.target_hype = 1.0
    self.target_x_hypes = {}
    
    self.floats = {}
    self.score_ticker = 0
    self.auto_continue_timer = 0.0
    
    return self
end

function ScoringState:enter(kwargs)
    self.result = kwargs.result or {}
    self.guess = kwargs.guess or ""
    self.score_ticker = self.run_manager.round_score - (self.result.score or 0)
    self.auto_continue_timer = 0.0
    
    self.buttons = {}
    self.floats = {}
    
    if self.result.pattern == "Plagiarized" then
        self.anim_stage = "done"
        self.letter_idx = #self.guess + 1
        self.timer = 0.0
        self.displayed_words = 0
        self.displayed_hype = 1.0
        self.displayed_x_hypes = {}
        self.target_words = 0
        self.target_hype = 1.0
        self.target_x_hypes = {}
        if config.sounds then
            config.sounds:play("error")
        end
        return
    end
    
    self.anim_stage = "init"
    self.letter_idx = 1
    self.timer = 0.0
    
    self.displayed_words = 0
    self.displayed_hype = 1.0
    self.displayed_x_hypes = {}
    
    local pattern_name = self.result.pattern
    local level = self.run_manager.style_guides[pattern_name] or 1
    local style_guides_data = require("src/content/style_guides").STYLE_GUIDES_DATA
    local base_info = style_guides_data[pattern_name]
    
    self.displayed_words = base_info.base_words + (level - 1) * base_info.upgrade_words
    self.displayed_hype = base_info.base_hype + (level - 1) * base_info.upgrade_hype
    
    self.target_words = self.result.words or 0
    self.target_hype = self.result.hype or 1.0
    self.target_x_hypes = {}
    if self.result.x_hypes then
        for _, xm in ipairs(self.result.x_hypes) do
            table.insert(self.target_x_hypes, xm)
        end
    end
    
    if config.sounds then
        config.sounds:play("stamp")
    end
    self:spawn_float(pattern_name .. "!", config.SCREEN_WIDTH / 2, 120, config.COLOR_CLUE_GREEN)
end

function ScoringState:spawn_float(text, start_x, start_y, color)
    local target_x = config.SCREEN_WIDTH / 2
    local target_y = 370
    local life = 0.5
    table.insert(self.floats, {
        text = text,
        x = start_x,
        y = start_y,
        vx = (target_x - start_x) / life,
        vy = (target_y - start_y) / life,
        color = color,
        life = life
    })
end

function ScoringState:press_continue()
    self.state_machine:change_state("game")
end

function ScoringState:skip_animation()
    self.displayed_words = self.target_words
    self.displayed_hype = self.target_hype
    self.displayed_x_hypes = {}
    for _, xm in ipairs(self.target_x_hypes) do
        table.insert(self.displayed_x_hypes, xm)
    end
    self.anim_stage = "done"
    if config.sounds then
        config.sounds:play("bell")
    end
end

function ScoringState:keypressed(key, scancode, isrepeat)
    if key == "return" or key == "space" then
        if self.anim_stage ~= "done" then
            self:skip_animation()
        else
            self:press_continue()
        end
    end
end

function ScoringState:mousepressed(x, y, button, istouch, presses)
    if button == 1 then
        if self.anim_stage ~= "done" then
            self:skip_animation()
        else
            self:press_continue()
        end
    end
end

function ScoringState:update(dt)
    self.particles:update(dt)
    self.shake:update(dt)
    
    local active_floats = {}
    for _, f in ipairs(self.floats) do
        f.x = f.x + f.vx * dt
        f.y = f.y + f.vy * dt
        f.life = f.life - dt
        if f.life > 0 then
            table.insert(active_floats, f)
        end
    end
    self.floats = active_floats
    
    if self.anim_stage == "done" then
        local target_score = self.run_manager.round_score
        if self.score_ticker < target_score then
            local diff = target_score - self.score_ticker
            local speed = math.max(1, math.floor(diff * 8.0 * dt))
            self.score_ticker = math.min(target_score, self.score_ticker + speed)
        else
            self.auto_continue_timer = self.auto_continue_timer + dt
            if self.auto_continue_timer >= 1.0 then
                self:press_continue()
            end
        end
    end
    
    self.timer = self.timer + dt
    
    if self.anim_stage == "init" then
        if self.timer >= 0.6 then
            self.anim_stage = "letters"
            self.letter_idx = 1
            self.timer = 0.0
        end
    elseif self.anim_stage == "letters" then
        if self.timer >= 0.4 then
            self.timer = 0.0
            if self.letter_idx <= #self.guess then
                local char = self.guess:sub(self.letter_idx, self.letter_idx)
                local clue = self.result.clues[self.letter_idx]
                
                if config.sounds then
                    config.sounds:play_clack()
                end
                
                local px, py, pw, ph = 400, 80, 440, 360
                local box_w = 40
                local box_gap = 8
                local w_len = #self.guess
                local total_w = w_len * box_w + (w_len - 1) * box_gap
                local start_x = px + (pw - total_w) / 2
                
                local visible_rows = math.min(5, #self.run_manager.round_history)
                local row_y = 100 + (visible_rows - 1) * 50
                
                local letter_center_x = start_x + (self.letter_idx - 1) * (box_w + box_gap) + box_w / 2
                local letter_center_y = row_y + box_w / 2
                
                local p_color = config.COLOR_TEXT_LIGHT
                if clue == "green" then p_color = config.COLOR_CLUE_GREEN
                elseif clue == "yellow" then p_color = config.COLOR_CLUE_YELLOW
                elseif clue == "grey" then p_color = config.COLOR_CLUE_GREY
                elseif clue == "redacted" then p_color = config.COLOR_CLUE_REDACTED
                end
                
                self.particles:spawn(letter_center_x, letter_center_y, p_color, 8)
                
                local mods = self.run_manager.keyboard_mods[char] or {}
                local repeat_cnt = mods.stapler and 2 or 1
                
                for r_idx = 1, repeat_cnt do
                    local added_words = 0
                    local added_hype = 0.0
                    local added_x = 1.0
                    
                    if mods.highlighter then added_hype = added_hype + 15.0 end
                    if mods.coffee_ring then added_words = added_words + 50 end
                    
                    if clue == "green" then
                        added_words = added_words + 5
                    elseif clue == "yellow" then
                        added_words = added_words + 1
                    end
                    
                    self.displayed_words = self.displayed_words + added_words
                    self.displayed_hype = self.displayed_hype + added_hype
                    
                    if added_words > 0 then
                        local float_color = (clue == "yellow") and config.COLOR_CLUE_YELLOW or config.COLOR_CLUE_GREEN
                        self:spawn_float("+" .. added_words .. " Words", letter_center_x, letter_center_y, float_color)
                    end
                    if added_hype > 0 then
                        self:spawn_float("+" .. added_hype .. " Hype", letter_center_x, letter_center_y, config.COLOR_CLUE_YELLOW)
                    end
                end
                
                self.letter_idx = self.letter_idx + 1
            else
                self.anim_stage = "final_calc"
                self.timer = 0.0
            end
        end
    elseif self.anim_stage == "final_calc" then
        if self.timer >= 0.4 then
            self:skip_animation()
            self.shake:trigger(8, 0.3)
            self.particles:spawn(config.SCREEN_WIDTH / 2, 350, config.COLOR_ROYALTIES, 25)
            self:spawn_float("+" .. self.result.score .. " Hype!", config.SCREEN_WIDTH / 2, 320, config.COLOR_ROYALTIES)
            self.anim_stage = "done"
        end
    end
end

function ScoringState:draw()
    love.graphics.setColor(config.COLOR_DESK[1], config.COLOR_DESK[2], config.COLOR_DESK[3], 1.0)
    love.graphics.rectangle("fill", 0, 0, config.SCREEN_WIDTH, config.SCREEN_HEIGHT)
    
    local offset_x, offset_y = self.shake:get_offset()
    
    love.graphics.push()
    love.graphics.translate(offset_x, offset_y)
    self:draw_desk_elements()
    
    if self.result.pattern == "Plagiarized" then
        local px, py, pw, ph = 400, 80, 440, 360
        love.graphics.setFont(self.typewriter_font)
        love.graphics.setColor(231/255, 76/255, 60/255, 1.0)
        
        love.graphics.push()
        love.graphics.translate(px + pw/2, py + ph/2)
        love.graphics.rotate(15 * math.pi / 180)
        
        love.graphics.setLineWidth(4)
        love.graphics.rectangle("line", -120, -25, 240, 50, 6, 6)
        love.graphics.print("PLAGIARIZED", -85, -15)
        love.graphics.pop()
    end
    love.graphics.pop()
    
    love.graphics.setFont(self.ui_bold)
    for _, f in ipairs(self.floats) do
        love.graphics.setColor(f.color[1], f.color[2], f.color[3], 1.0)
        local fw = self.ui_bold:getWidth(f.text)
        love.graphics.print(f.text, f.x - fw / 2, f.y - 12)
    end
    
    self.particles:draw()
end

function ScoringState:draw_desk_elements()
    -- 1. Left Panel - Hype Meter
    love.graphics.setColor(config.COLOR_PANEL[1], config.COLOR_PANEL[2], config.COLOR_PANEL[3], 1.0)
    love.graphics.rectangle("fill", 40, 80, 310, 220, 10, 10)
    love.graphics.setColor(config.COLOR_TEXT_MUTED[1], config.COLOR_TEXT_MUTED[2], config.COLOR_TEXT_MUTED[3], 1.0)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", 40, 80, 310, 220, 10, 10)
    
    love.graphics.setFont(self.ui_font)
    love.graphics.setColor(config.COLOR_TEXT_MUTED[1], config.COLOR_TEXT_MUTED[2], config.COLOR_TEXT_MUTED[3], 1.0)
    love.graphics.print("CURRENT HYPE SCORE", 60, 100)
    
    local display_score = math.floor(self.score_ticker)
    local score_str = tostring(display_score):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    love.graphics.setFont(self.score_font)
    love.graphics.setColor(config.COLOR_TEXT_LIGHT[1], config.COLOR_TEXT_LIGHT[2], config.COLOR_TEXT_LIGHT[3], 1.0)
    love.graphics.print(score_str, 60, 125)
    
    love.graphics.setFont(self.ui_font)
    local target_formatted = tostring(self.run_manager.target_score):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    love.graphics.print("Target: " .. target_formatted, 60, 175)
    
    local pct = math.min(1.0, display_score / math.max(1, self.run_manager.target_score))
    love.graphics.setColor(20/255, 20/255, 25/255, 1.0)
    love.graphics.rectangle("fill", 60, 210, 270, 20, 4, 4)
    if pct > 0 then
        love.graphics.setColor(config.COLOR_CLUE_GREEN[1], config.COLOR_CLUE_GREEN[2], config.COLOR_CLUE_GREEN[3], 1.0)
        love.graphics.rectangle("fill", 60, 210, math.floor(270 * pct), 20, 4, 4)
    end
    
    local stage_name = self.run_manager:get_assignment_name()
    local stage_color = self.run_manager.boss_assignment and config.COLOR_ACCENT or config.COLOR_TEXT_LIGHT
    love.graphics.setFont(self.ui_bold)
    love.graphics.setColor(stage_color[1], stage_color[2], stage_color[3], 1.0)
    love.graphics.print(stage_name, 60, 238)
    
    -- Resources
    love.graphics.setColor(config.COLOR_PANEL[1], config.COLOR_PANEL[2], config.COLOR_PANEL[3], 1.0)
    love.graphics.rectangle("fill", 40, 302, 310, 70, 10, 10)
    love.graphics.setFont(self.ui_font)
    love.graphics.setColor(config.COLOR_TEXT_LIGHT[1], config.COLOR_TEXT_LIGHT[2], config.COLOR_TEXT_LIGHT[3], 1.0)
    love.graphics.print("Submissions: " .. self.run_manager.submissions_left .. "/" .. self.run_manager.submissions_max, 60, 314)
    love.graphics.setColor(config.COLOR_CLUE_YELLOW[1], config.COLOR_CLUE_YELLOW[2], config.COLOR_CLUE_YELLOW[3], 1.0)
    love.graphics.print("Drafts: " .. self.run_manager.drafts_left .. "/" .. self.run_manager.drafts_max, 60, 342)
    
    -- Stationery
    love.graphics.setFont(self.ui_bold)
    love.graphics.setColor(config.COLOR_TEXT_LIGHT[1], config.COLOR_TEXT_LIGHT[2], config.COLOR_TEXT_LIGHT[3], 1.0)
    love.graphics.print("STATIONERY", 40, 388)
    for idx = 1, 5 do
        local tx = 40 + (idx - 1) * 68
        love.graphics.setColor(20/255, 22/255, 30/255, 1.0)
        love.graphics.rectangle("fill", tx, 412, 60, 60, 6, 6)
        love.graphics.setColor(config.COLOR_TEXT_MUTED[1], config.COLOR_TEXT_MUTED[2], config.COLOR_TEXT_MUTED[3], 1.0)
        love.graphics.rectangle("line", tx, 412, 60, 60, 6, 6)
        
        if idx <= #self.run_manager.tropes then
            local trope = self.run_manager.tropes[idx]
            local initials = ""
            for word in trope.name:gmatch("%S+") do
                local c = word:sub(1, 1)
                if c:match("%u") then initials = initials .. c end
            end
            initials = initials:sub(1, 3)
            local txt_color = trope.is_debuff_active and config.COLOR_ACCENT or config.COLOR_CLUE_GREEN
            love.graphics.setFont(self.typewriter_font)
            love.graphics.setColor(txt_color[1], txt_color[2], txt_color[3], 1.0)
            local iw = self.typewriter_font:getWidth(initials)
            local ih = self.typewriter_font:getHeight()
            love.graphics.print(initials, tx + (60 - iw) / 2, 412 + (60 - ih) / 2)
        end
    end
    
    -- 2. Center Panel - Manuscript Paper
    local px, py, pw, ph = 435, 80, 440, 360
    love.graphics.setColor(20/255, 20/255, 25/255, 1.0)
    love.graphics.rectangle("fill", px - 6, py - 6, pw + 12, ph + 12, 8, 8)
    love.graphics.setColor(config.COLOR_PAPER[1], config.COLOR_PAPER[2], config.COLOR_PAPER[3], 1.0)
    love.graphics.rectangle("fill", px, py, pw, ph, 6, 6)
    
    local box_w = 40
    local box_gap = 8
    local w_len = #self.guess
    local total_w = w_len * box_w + (w_len - 1) * box_gap
    local start_x = px + (pw - total_w) / 2
    
    -- Draw historical entries up to index-1
    local row_y = 112
    local hist_len = #self.run_manager.round_history
    local start_hist = math.max(1, hist_len - 3)
    for idx = start_hist, hist_len - 1 do
        local entry = self.run_manager.round_history[idx]
        local word = entry.word
        local clues = entry.clues
        local is_draft = entry.is_draft
        local score = entry.score
        
        for l_idx = 1, #word do
            local char = word:sub(l_idx, l_idx)
            local clue = clues[l_idx]
            local box_x = start_x + (l_idx - 1) * (box_w + box_gap)
            
            local col = config.COLOR_CLUE_EMPTY
            if clue == "green" then col = config.COLOR_CLUE_GREEN
            elseif clue == "yellow" then col = config.COLOR_CLUE_YELLOW
            elseif clue == "grey" then col = config.COLOR_CLUE_GREY
            elseif clue == "redacted" then col = config.COLOR_CLUE_REDACTED
            end
            
            love.graphics.setColor(col[1], col[2], col[3], 1.0)
            love.graphics.rectangle("fill", box_x, row_y, box_w, box_w, 4, 4)
            
            local let_color = (col == config.COLOR_CLUE_EMPTY) and config.COLOR_TEXT_DARK or config.COLOR_TEXT_LIGHT
            love.graphics.setFont(self.typewriter_font)
            love.graphics.setColor(let_color[1], let_color[2], let_color[3], 1.0)
            local char_upper = char:upper()
            local lw = self.typewriter_font:getWidth(char_upper)
            local lh = self.typewriter_font:getHeight()
            love.graphics.print(char_upper, box_x + (box_w - lw) / 2, row_y + (box_w - lh) / 2)
        end
        
        local lbl_color = config.COLOR_ROYALTIES
        local lbl_str = "+" .. score
        if entry.is_plagiarized then
            lbl_color = {231/255, 76/255, 60/255}
            lbl_str = "PLAGIARIZED"
        elseif is_draft then
            lbl_color = config.COLOR_CLUE_YELLOW
            lbl_str = "DRAFT"
        end
        
        love.graphics.setFont(self.ui_font)
        love.graphics.setColor(lbl_color[1], lbl_color[2], lbl_color[3], 1.0)
        love.graphics.print(lbl_str, start_x + total_w + 12, row_y + 10)
        row_y = row_y + 50
    end
    
    -- Draw active scoring row outline & box clues
    local clues = self.result.clues or {}
    love.graphics.setColor(config.COLOR_HIGHLIGHTER[1], config.COLOR_HIGHLIGHTER[2], config.COLOR_HIGHLIGHTER[3], 1.0)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", start_x - 4, row_y - 4, total_w + 8, box_w + 8, 6, 6)
    
    for l_idx = 1, #self.guess do
        local char = self.guess:sub(l_idx, l_idx)
        local box_x = start_x + (l_idx - 1) * (box_w + box_gap)
        
        local clue = clues[l_idx]
        local col = config.COLOR_CLUE_EMPTY
        if clue == "green" then col = config.COLOR_CLUE_GREEN
        elseif clue == "yellow" then col = config.COLOR_CLUE_YELLOW
        elseif clue == "grey" then col = config.COLOR_CLUE_GREY
        elseif clue == "redacted" then col = config.COLOR_CLUE_REDACTED
        end
        
        love.graphics.setColor(col[1], col[2], col[3], 1.0)
        love.graphics.rectangle("fill", box_x, row_y, box_w, box_w, 4, 4)
        
        if l_idx == self.letter_idx and self.anim_stage == "letters" then
            love.graphics.setColor(config.COLOR_HIGHLIGHTER[1], config.COLOR_HIGHLIGHTER[2], config.COLOR_HIGHLIGHTER[3], 1.0)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", box_x, row_y, box_w, box_w, 4, 4)
        end
        
        local let_color = (col == config.COLOR_CLUE_EMPTY) and config.COLOR_TEXT_DARK or config.COLOR_TEXT_LIGHT
        love.graphics.setFont(self.typewriter_font)
        love.graphics.setColor(let_color[1], let_color[2], let_color[3], 1.0)
        local char_upper = char:upper()
        local lw = self.typewriter_font:getWidth(char_upper)
        local lh = self.typewriter_font:getHeight()
        love.graphics.print(char_upper, box_x + (box_w - lw) / 2, row_y + (box_w - lh) / 2)
    end
    
    -- Tally Placard Ticker at bottom
    local placard_x, placard_y, placard_w, placard_h = px + (pw - 380) / 2, 345, 380, 50
    local pattern_str = self.result.pattern or "Standard Submission"
    love.graphics.setFont(self.ui_bold)
    love.graphics.setColor(config.COLOR_CLUE_YELLOW[1], config.COLOR_CLUE_YELLOW[2], config.COLOR_CLUE_YELLOW[3], 1.0)
    local pat_w = self.ui_bold:getWidth(pattern_str:upper())
    love.graphics.print(pattern_str:upper(), px + pw/2 - pat_w/2, placard_y - 32)
    
    love.graphics.setColor(18/255, 19/255, 24/255, 1.0)
    love.graphics.rectangle("fill", placard_x, placard_y, placard_w, placard_h, 8, 8)
    local border_color = (self.anim_stage == "done") and config.COLOR_HIGHLIGHTER or config.COLOR_TEXT_MUTED
    love.graphics.setColor(border_color[1], border_color[2], border_color[3], 1.0)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", placard_x, placard_y, placard_w, placard_h, 8, 8)
    
    -- Draw Words
    love.graphics.setFont(self.math_font)
    love.graphics.setColor(config.COLOR_CLUE_GREEN[1], config.COLOR_CLUE_GREEN[2], config.COLOR_CLUE_GREEN[3], 1.0)
    love.graphics.print(tostring(math.floor(self.displayed_words)), placard_x + 15, placard_y + 10)
    
    -- "x"
    love.graphics.setColor(config.COLOR_TEXT_MUTED[1], config.COLOR_TEXT_MUTED[2], config.COLOR_TEXT_MUTED[3], 1.0)
    love.graphics.print("x", placard_x + 130, placard_y + 10)
    
    -- Hype
    local curr_hype = self.displayed_hype
    for _, xm in ipairs(self.displayed_x_hypes) do
        curr_hype = curr_hype * xm
    end
    love.graphics.setColor(config.COLOR_CLUE_YELLOW[1], config.COLOR_CLUE_YELLOW[2], config.COLOR_CLUE_YELLOW[3], 1.0)
    love.graphics.print(string.format("%.1f", curr_hype), placard_x + 165, placard_y + 10)
    
    -- Equals Tally
    if self.anim_stage == "done" then
        love.graphics.setColor(config.COLOR_ROYALTIES[1], config.COLOR_ROYALTIES[2], config.COLOR_ROYALTIES[3], 1.0)
        love.graphics.print("=", placard_x + 245, placard_y + 10)
        
        local final_score_formatted = tostring(self.result.score):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
        love.graphics.print(final_score_formatted, placard_x + 280, placard_y + 10)
    end
    
    -- 4. Keyboard (static)
    local kbd_x = 423
    local kbd_y = 480
    local key_size = 42
    local key_gap = 5
    for r_idx, row in ipairs(self.kbd_rows) do
        local offset = 0
        if r_idx == 2 then offset = 22
        elseif r_idx == 3 then offset = 52
        end
        for k_idx, char in ipairs(row) do
            local key_x = kbd_x + offset + (k_idx - 1) * (key_size + key_gap)
            local key_y = kbd_y + (r_idx - 1) * (key_size + key_gap)
            
            local mods = self.run_manager.keyboard_mods[char] or {}
            local is_highlighter = mods.highlighter == true
            local is_coffee_ring = mods.coffee_ring == true
            local is_stapler = mods.stapler == true
            local is_removed = mods.removed == true
            
            love.graphics.setColor(config.COLOR_PANEL[1], config.COLOR_PANEL[2], config.COLOR_PANEL[3], 1.0)
            love.graphics.rectangle("fill", key_x, key_y, key_size, key_size, 5, 5)
            
            if is_highlighter and not is_removed then
                love.graphics.setColor(config.COLOR_HIGHLIGHTER[1], config.COLOR_HIGHLIGHTER[2], config.COLOR_HIGHLIGHTER[3], 1.0)
                love.graphics.setLineWidth(2)
                love.graphics.rectangle("line", key_x, key_y, key_size, key_size, 5, 5)
            end
            if is_coffee_ring and not is_removed then
                love.graphics.setColor(config.COLOR_CLUE_REDACTED[1], config.COLOR_CLUE_REDACTED[2], config.COLOR_CLUE_REDACTED[3], 1.0)
                love.graphics.setLineWidth(2)
                love.graphics.circle("line", key_x + key_size / 2, key_y + key_size / 2, 12)
            end
            if is_stapler and not is_removed then
                love.graphics.setColor(180/255, 180/255, 190/255, 1.0)
                love.graphics.setLineWidth(2)
                love.graphics.line(key_x + 8, key_y + 6, key_x + key_size - 8, key_y + 6)
                love.graphics.line(key_x + 8, key_y + key_size - 6, key_x + key_size - 8, key_y + key_size - 6)
            end
            
            love.graphics.setColor(config.COLOR_TEXT_MUTED[1], config.COLOR_TEXT_MUTED[2], config.COLOR_TEXT_MUTED[3], 1.0)
            love.graphics.setLineWidth(1)
            love.graphics.rectangle("line", key_x, key_y, key_size, key_size, 5, 5)
            
            if not is_removed then
                love.graphics.setFont(self.ui_font)
                love.graphics.setColor(config.COLOR_TEXT_LIGHT[1], config.COLOR_TEXT_LIGHT[2], config.COLOR_TEXT_LIGHT[3], 1.0)
                local char_upper = char:upper()
                local lw = self.ui_font:getWidth(char_upper)
                local lh = self.ui_font:getHeight()
                love.graphics.print(char_upper, key_x + (key_size - lw) / 2, key_y + (key_size - lh) / 2)
            else
                love.graphics.setColor(config.COLOR_ACCENT[1], config.COLOR_ACCENT[2], config.COLOR_ACCENT[3], 1.0)
                love.graphics.setLineWidth(2)
                love.graphics.line(key_x + 8, key_y + 8, key_x + key_size - 8, key_y + key_size - 8)
                love.graphics.line(key_x + key_size - 8, key_y + 8, key_x + 8, key_y + key_size - 8)
            end
        end
    end
    
    -- Snacks (Right side - mirrored with Stationery at y = 388)
    love.graphics.setFont(self.ui_bold)
    love.graphics.setColor(config.COLOR_TEXT_LIGHT[1], config.COLOR_TEXT_LIGHT[2], config.COLOR_TEXT_LIGHT[3], 1.0)
    local snk_w = self.ui_bold:getWidth("SNACKS")
    love.graphics.print("SNACKS", 970 + (130 - snk_w) / 2, 388)
    
    for idx = 1, 2 do
        local ex = 970
        local ey = 412 + (idx - 1) * 65
        love.graphics.setColor(20/255, 22/255, 30/255, 1.0)
        love.graphics.rectangle("fill", ex, ey, 130, 55, 6, 6)
        love.graphics.setColor(config.COLOR_TEXT_MUTED[1], config.COLOR_TEXT_MUTED[2], config.COLOR_TEXT_MUTED[3], 1.0)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", ex, ey, 130, 55, 6, 6)
        
        if idx <= #self.run_manager.edits then
            local edit = self.run_manager.edits[idx]
            local name_clean = edit.name:gsub("The ", "")
            love.graphics.setFont(self.ui_font)
            love.graphics.setColor(config.COLOR_TEXT_LIGHT[1], config.COLOR_TEXT_LIGHT[2], config.COLOR_TEXT_LIGHT[3], 1.0)
            local nw = self.ui_font:getWidth(name_clean)
            love.graphics.print(name_clean, ex + (130 - nw) / 2, ey + 8)
            
            love.graphics.setFont(self.tooltip_font)
            love.graphics.setColor(config.COLOR_TEXT_MUTED[1], config.COLOR_TEXT_MUTED[2], config.COLOR_TEXT_MUTED[3], 1.0)
            local uw = self.tooltip_font:getWidth("Locked (scoring)")
            love.graphics.print("Locked (scoring)", ex + (130 - uw) / 2, ey + 32)
        end
    end
end

return ScoringState
