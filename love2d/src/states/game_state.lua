local config = require("src/config")
local ui = require("src/engine/ui")
local State = require("src/engine/state_machine").State
local Author = require("src/content/authors").Author

local GameState = setmetatable({}, State)
GameState.__index = GameState

function GameState.new(state_machine, run_manager)
    local self = State.new(state_machine, run_manager)
    setmetatable(self, GameState)
    
    self.current_input = ""
    self.buttons = {}
    self.particles = ui.ParticleSystem.new()
    self.shake = ui.ScreenShake.new()
    
    self.typewriter_font = config.get_font("typewriter", 28)
    self.typewriter_lg = config.get_font("typewriter", 40)
    self.ui_font = config.get_font("sans", 20)
    self.ui_bold = config.get_font_bold(22)
    self.score_font = config.get_font("sans", 32)
    self.tooltip_font = config.get_font("sans", 14)
    
    self.kbd_rows = {
        {'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'},
        {'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l'},
        {'z', 'x', 'c', 'v', 'b', 'n', 'm'}
    }
    
    self.key_discoveries = {}
    self.error_message = ""
    self.error_timer = 0.0
    self.hovered_tooltip = nil
    
    self:setup_buttons()
    
    return self
end

function GameState:setup_buttons()
    self.buttons = {}
    table.insert(self.buttons, ui.Button.new(
        880, 140, 160, 45,
        "Draft Word",
        function() self:press_draft() end,
        {230/255, 180/255, 30/255}
    ))
    table.insert(self.buttons, ui.Button.new(
        880, 200, 160, 45,
        "Submit Word",
        function() self:press_submit() end,
        {46/255, 180/255, 110/255}
    ))
end

function GameState:enter(kwargs)
    self.current_input = ""
    self.key_discoveries = self.run_manager.key_discoveries
    self.error_message = ""
    self.error_timer = 0.0
    self.hovered_tooltip = nil
    self:setup_buttons()
end

function GameState:press_draft()
    self:process_guess(true)
end

function GameState:press_submit()
    self:process_guess(false)
end

function GameState:process_guess(is_draft)
    if is_draft and self.run_manager.drafts_left <= 0 then
        self:trigger_error("No Drafts remaining!")
        return
    end
    if not is_draft and self.run_manager.submissions_left <= 0 then
        self:trigger_error("No Submissions remaining!")
        return
    end
    
    local expected_len = (self.run_manager.boss_assignment == "Minimalist") and 4 or 5
    if #self.current_input ~= expected_len then
        self:trigger_error("Must type a " .. expected_len .. "-letter word!")
        return
    end
    
    local result = self.run_manager:submit_word(self.current_input, is_draft)
    
    if result.error then
        self:trigger_error(result.error)
        return
    end
    
    if config.sounds then
        config.sounds:play("carriage")
    end
    
    local clues = result.clues
    for idx = 1, #self.current_input do
        local char = self.current_input:sub(idx, idx)
        local clue = clues[idx]
        if clue ~= "redacted" and char:match("%a") then
            local curr_state = self.key_discoveries[char] or "empty"
            local prio = {green = 3, yellow = 2, grey = 1, empty = 0}
            local clue_prio = prio[clue] or 0
            local curr_prio = prio[curr_state] or 0
            if clue_prio > curr_prio then
                self.key_discoveries[char] = clue
            end
        end
    end
    
    local typed_word = self.current_input
    self.current_input = ""
    
    if not is_draft then
        self.state_machine:change_state("scoring", {result = result, guess = typed_word})
    end
end

function GameState:trigger_error(msg)
    self.error_message = msg
    self.error_timer = 2.0
    if config.sounds then
        config.sounds:play("error")
    end
    self.shake:trigger(8, 0.25)
end

function GameState:keypressed(key, scancode, isrepeat)
    if config.sounds then
        config.sounds:play_clack()
    end
    
    if key == "backspace" then
        if #self.current_input > 0 then
            self.current_input = self.current_input:sub(1, -2)
        end
    elseif key == "return" then
        self:press_submit()
    elseif key == "space" then
        self:press_draft()
    end
end

function GameState:textinput(text)
    local expected_len = (self.run_manager.boss_assignment == "Minimalist") and 4 or 5
    local char = text:lower()
    
    local is_ghostwriter_active = false
    for _, t in ipairs(self.run_manager.tropes) do
        if t.name == "The Ghostwriter" then
            is_ghostwriter_active = true
            break
        end
    end
    
    local is_valid_char = char:match("%a") ~= nil
    if is_ghostwriter_active and (char == "*" or char == " " or char == "_") then
        is_valid_char = true
        if char == " " or char == "_" then
            char = "*"
        end
    end
    
    if is_valid_char and #self.current_input < expected_len then
        self.current_input = self.current_input .. char
    end
end

function GameState:mousepressed(x, y, button, istouch, presses)
    local mx, my = config.mx or x, config.my or y
    for _, btn in ipairs(self.buttons) do
        if btn:handle_event("mousepressed", mx, my, button) then
            return
        end
    end
    
    if button == 1 then
        self:click_edit_slot(mx, my)
    end
end

function GameState:click_edit_slot(mx, my)
    local s1_x, s1_y, s1_w, s1_h = 40, 580, 130, 70
    local s2_x, s2_y, s2_w, s2_h = 190, 580, 130, 70
    
    local clicked_idx = -1
    if mx >= s1_x and mx <= s1_x + s1_w and my >= s1_y and my <= s1_y + s1_h then
        clicked_idx = 1
    elseif mx >= s2_x and mx <= s2_x + s2_w and my >= s2_y and my <= s2_y + s2_h then
        clicked_idx = 2
    end
    
    if clicked_idx > 0 and clicked_idx <= #self.run_manager.edits then
        local edit_item = self.run_manager.edits[clicked_idx]
        
        if edit_item.name == "The White-Out" then
            local target_tropes = {}
            for _, t in ipairs(self.run_manager.tropes) do
                if t.is_debuff_active then
                    table.insert(target_tropes, t)
                end
            end
            if #target_tropes > 0 then
                local msg, success = edit_item:use(self.run_manager, {target_trope = target_tropes[1]})
                if success then
                    table.remove(self.run_manager.edits, clicked_idx)
                    self.particles:spawn(100, 615, config.COLOR_HIGHLIGHTER, 15)
                end
                self:trigger_error(msg)
            else
                self:trigger_error("No Tropes have active debuffs!")
            end
        else
            local msg, success = edit_item:use(self.run_manager)
            if success then
                table.remove(self.run_manager.edits, clicked_idx)
                local px = 40 + (clicked_idx - 1) * 150 + 65
                self.particles:spawn(px, 615, config.COLOR_ROYALTIES, 15)
            end
            self:trigger_error(msg)
        end
    end
end

function GameState:check_tooltips(mx, my)
    self.hovered_tooltip = nil
    
    for idx, trope in ipairs(self.run_manager.tropes) do
        local tx = 40 + (idx - 1) * 68
        local ty = 435
        if mx >= tx and mx <= tx + 60 and my >= ty and my <= ty + 60 then
            local debuff_text = trope.is_debuff_active and ("Debuff: " .. trope.debuff_desc) or "Debuff: Cleaned (White-Out)"
            self.hovered_tooltip = {
                title = trope.name,
                desc = trope.description,
                debuff = debuff_text,
                pos = {mx, my}
            }
            return
        end
    end
    
    for idx, edit in ipairs(self.run_manager.edits) do
        local ex = 40 + (idx - 1) * 150
        local ey = 590
        if mx >= ex and mx <= ex + 130 and my >= ey and my <= ey + 70 then
            self.hovered_tooltip = {
                title = edit.name,
                desc = edit.description,
                debuff = "Click to consume immediately.",
                pos = {mx, my}
            }
            return
        end
    end
end

function GameState:update(dt)
    self.particles:update(dt)
    self.shake:update(dt)
    
    if self.error_timer > 0 then
        self.error_timer = self.error_timer - dt
    end
    
    local mx, my = love.mouse.getPosition()
    mx, my = config.mx or mx, config.my or my
    
    for _, btn in ipairs(self.buttons) do
        btn:check_hover(mx, my)
        btn:update(dt)
    end
    
    self:check_tooltips(mx, my)
    
    local round_status = self.run_manager:check_round_end()
    if round_status == "win" then
        self.run_manager:advance_assignment()
        self.state_machine:change_state("shop")
    elseif round_status == "lose" then
        self.state_machine:change_state("game_over", {result = "fired"})
    end
end

function GameState:draw()
    ui.draw_background()
    
    local offset_x, offset_y = self.shake:get_offset()
    
    love.graphics.push()
    love.graphics.translate(offset_x, offset_y)
    self:draw_gameplay()
    love.graphics.pop()
    
    self.particles:draw()
    
    if self.hovered_tooltip then
        self:draw_tooltip(self.hovered_tooltip)
    end
end

function GameState:draw_gameplay()
    ui.draw_sidebar(25, 70, 340, 615)
    
    -- 1. Left Panel - Hype Meter & Inventory
    love.graphics.setColor(config.COLOR_PANEL[1], config.COLOR_PANEL[2], config.COLOR_PANEL[3], config.images.bg_sidebar and 0.85 or 1.0)
    love.graphics.rectangle("fill", 40, 80, 310, 220, 10, 10)
    love.graphics.setColor(config.COLOR_TEXT_MUTED[1], config.COLOR_TEXT_MUTED[2], config.COLOR_TEXT_MUTED[3], 1.0)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", 40, 80, 310, 220, 10, 10)
    
    love.graphics.setFont(self.ui_font)
    love.graphics.setColor(config.COLOR_TEXT_MUTED[1], config.COLOR_TEXT_MUTED[2], config.COLOR_TEXT_MUTED[3], 1.0)
    love.graphics.print("CURRENT HYPE SCORE", 60, 100)
    
    local score_str = tostring(self.run_manager.round_score):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    love.graphics.setFont(self.score_font)
    love.graphics.setColor(config.COLOR_TEXT_LIGHT[1], config.COLOR_TEXT_LIGHT[2], config.COLOR_TEXT_LIGHT[3], 1.0)
    love.graphics.print(score_str, 60, 125)
    
    love.graphics.setFont(self.ui_font)
    local target_formatted = tostring(self.run_manager.target_score):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    love.graphics.print("Target: " .. target_formatted, 60, 175)
    
    -- Progress Bar
    local pct = math.min(1.0, self.run_manager.round_score / math.max(1, self.run_manager.target_score))
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
    love.graphics.print(stage_name, 60, 250)
    
    -- Resources
    love.graphics.setColor(config.COLOR_PANEL[1], config.COLOR_PANEL[2], config.COLOR_PANEL[3], config.images.bg_sidebar and 0.85 or 1.0)
    love.graphics.rectangle("fill", 40, 315, 310, 80, 10, 10)
    love.graphics.setFont(self.ui_font)
    love.graphics.setColor(config.COLOR_TEXT_LIGHT[1], config.COLOR_TEXT_LIGHT[2], config.COLOR_TEXT_LIGHT[3], 1.0)
    love.graphics.print("Submissions: " .. self.run_manager.submissions_left .. "/" .. self.run_manager.submissions_max, 60, 330)
    love.graphics.setColor(config.COLOR_CLUE_YELLOW[1], config.COLOR_CLUE_YELLOW[2], config.COLOR_CLUE_YELLOW[3], 1.0)
    love.graphics.print("Drafts: " .. self.run_manager.drafts_left .. "/" .. self.run_manager.drafts_max, 60, 360)
    
    -- Tropes
    love.graphics.setFont(self.ui_bold)
    love.graphics.setColor(config.COLOR_TEXT_LIGHT[1], config.COLOR_TEXT_LIGHT[2], config.COLOR_TEXT_LIGHT[3], 1.0)
    love.graphics.print("TROPES (PASSIVES)", 40, 408)
    
    for idx = 1, 5 do
        local tx = 40 + (idx - 1) * 68
        local ty = 435
        love.graphics.setColor(20/255, 22/255, 30/255, 1.0)
        love.graphics.rectangle("fill", tx, ty, 60, 60, 6, 6)
        love.graphics.setColor(config.COLOR_TEXT_MUTED[1], config.COLOR_TEXT_MUTED[2], config.COLOR_TEXT_MUTED[3], 1.0)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", tx, ty, 60, 60, 6, 6)
        
        if idx <= #self.run_manager.tropes then
            local trope = self.run_manager.tropes[idx]
            local initials = ""
            for word in trope.name:gmatch("%S+") do
                local c = word:sub(1, 1)
                if c:match("%u") then
                    initials = initials .. c
                end
            end
            initials = initials:sub(1, 3)
            local txt_color = trope.is_debuff_active and config.COLOR_ACCENT or config.COLOR_CLUE_GREEN
            love.graphics.setFont(self.typewriter_font)
            love.graphics.setColor(txt_color[1], txt_color[2], txt_color[3], 1.0)
            local iw = self.typewriter_font:getWidth(initials)
            local ih = self.typewriter_font:getHeight()
            love.graphics.print(initials, tx + (60 - iw) / 2, ty + (60 - ih) / 2)
        end
    end
    
    -- Edits
    love.graphics.setFont(self.ui_bold)
    love.graphics.setColor(config.COLOR_TEXT_LIGHT[1], config.COLOR_TEXT_LIGHT[2], config.COLOR_TEXT_LIGHT[3], 1.0)
    love.graphics.print("EDITS (CONSUMABLES)", 40, 560)
    
    for idx = 1, 2 do
        local ex = 40 + (idx - 1) * 150
        local ey = 590
        love.graphics.setColor(20/255, 22/255, 30/255, 1.0)
        love.graphics.rectangle("fill", ex, ey, 130, 70, 6, 6)
        love.graphics.setColor(config.COLOR_TEXT_MUTED[1], config.COLOR_TEXT_MUTED[2], config.COLOR_TEXT_MUTED[3], 1.0)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", ex, ey, 130, 70, 6, 6)
        
        if idx <= #self.run_manager.edits then
            local edit = self.run_manager.edits[idx]
            local name_clean = edit.name:gsub("The ", "")
            love.graphics.setFont(self.ui_font)
            love.graphics.setColor(config.COLOR_TEXT_LIGHT[1], config.COLOR_TEXT_LIGHT[2], config.COLOR_TEXT_LIGHT[3], 1.0)
            local nw = self.ui_font:getWidth(name_clean)
            love.graphics.print(name_clean, ex + (130 - nw) / 2, ey + 15)
            
            love.graphics.setFont(self.tooltip_font)
            love.graphics.setColor(config.COLOR_TEXT_MUTED[1], config.COLOR_TEXT_MUTED[2], config.COLOR_TEXT_MUTED[3], 1.0)
            local uw = self.tooltip_font:getWidth("Click to use")
            love.graphics.print("Click to use", ex + (130 - uw) / 2, ey + 40)
        end
    end
    
    -- 2. Center Panel - Manuscript Paper
    local px, py, pw, ph = 400, 80, 440, 360
    love.graphics.setColor(20/255, 20/255, 25/255, 1.0)
    love.graphics.rectangle("fill", px - 6, py - 6, pw + 12, ph + 12, 8, 8)
    
    if config.images.overlay_paper then
        love.graphics.setColor(1.0, 1.0, 1.0, 1.0)
        love.graphics.draw(config.images.overlay_paper, px, py, 0, pw / config.images.overlay_paper:getWidth(), ph / config.images.overlay_paper:getHeight())
    else
        love.graphics.setColor(config.COLOR_PAPER[1], config.COLOR_PAPER[2], config.COLOR_PAPER[3], 1.0)
        love.graphics.rectangle("fill", px, py, pw, ph, 6, 6)
    end
    
    -- Rows history
    local row_y = 100
    local hist_len = #self.run_manager.round_history
    local start_hist = math.max(1, hist_len - 3)
    for idx = start_hist, hist_len do
        local entry = self.run_manager.round_history[idx]
        local word = entry.word
        local clues = entry.clues
        local is_draft = entry.is_draft
        local score = entry.score
        
        local box_w = 40
        local box_gap = 8
        local w_len = #word
        local total_w = w_len * box_w + (w_len - 1) * box_gap
        local start_x = px + (pw - total_w) / 2
        
        for l_idx = 1, w_len do
            local char = word:sub(l_idx, l_idx)
            local clue = clues[l_idx]
            local box_x = start_x + (l_idx - 1) * (box_w + box_gap)
            
            local tile_img = config.images.tile_empty
            if clue == "green" then tile_img = config.images.tile_green
            elseif clue == "yellow" then tile_img = config.images.tile_yellow
            elseif clue == "grey" then tile_img = config.images.tile_grey
            end
            
            if tile_img then
                love.graphics.setColor(1.0, 1.0, 1.0, 1.0)
                love.graphics.draw(tile_img, box_x, row_y, 0, box_w / tile_img:getWidth(), box_w / tile_img:getHeight())
            else
                local col = config.COLOR_CLUE_EMPTY
                if clue == "green" then col = config.COLOR_CLUE_GREEN
                elseif clue == "yellow" then col = config.COLOR_CLUE_YELLOW
                elseif clue == "grey" then col = config.COLOR_CLUE_GREY
                elseif clue == "redacted" then col = config.COLOR_CLUE_REDACTED
                end
                love.graphics.setColor(col[1], col[2], col[3], 1.0)
                love.graphics.rectangle("fill", box_x, row_y, box_w, box_w, 4, 4)
            end
            
            if clue == "redacted" then
                love.graphics.setColor(139/255, 69/255, 19/255, 0.7)
                love.graphics.setLineWidth(3)
                love.graphics.circle("line", box_x + box_w/2, row_y + box_w/2, box_w/2 - 4)
            end
            
            local let_color = (clue == "empty") and config.COLOR_TEXT_DARK or config.COLOR_TEXT_LIGHT
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
    
    -- Active Input Boxes (dynamically aligned on the next line of the manuscript paper)
    local input_len = (self.run_manager.boss_assignment == "Minimalist") and 4 or 5
    local box_w = 40
    local box_gap = 8
    local total_w = input_len * box_w + (input_len - 1) * box_gap
    local start_x = px + (pw - total_w) / 2
    local input_y = row_y
    
    -- Draw active input row outline
    love.graphics.setColor(config.COLOR_HIGHLIGHTER[1], config.COLOR_HIGHLIGHTER[2], config.COLOR_HIGHLIGHTER[3], 1.0)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", start_x - 4, input_y - 4, total_w + 8, box_w + 8, 6, 6)
    
    for l_idx = 1, input_len do
        local box_x = start_x + (l_idx - 1) * (box_w + box_gap)
        
        if l_idx <= #self.current_input then
            -- Typed box: draw a pale yellow post-it note style block
            love.graphics.setColor(253/255, 252/255, 215/255, 1.0)
            love.graphics.rectangle("fill", box_x, input_y, box_w, box_w, 4, 4)
            love.graphics.setColor(config.COLOR_TEXT_DARK[1], config.COLOR_TEXT_DARK[2], config.COLOR_TEXT_DARK[3], 1.0)
            love.graphics.setLineWidth(1)
            love.graphics.rectangle("line", box_x, input_y, box_w, box_w, 4, 4)
            
            local char = self.current_input:sub(l_idx, l_idx)
            local mods = self.run_manager.keyboard_mods[char] or {}
            if mods.coffee_ring then
                love.graphics.setColor(139/255, 69/255, 19/255, 0.7)
                love.graphics.setLineWidth(3)
                love.graphics.circle("line", box_x + box_w/2, input_y + box_w/2, box_w/2 - 4)
            end
            
            love.graphics.setFont(self.typewriter_font)
            love.graphics.setColor(config.COLOR_TEXT_DARK[1], config.COLOR_TEXT_DARK[2], config.COLOR_TEXT_DARK[3], 1.0)
            local char_upper = char:upper()
            local lw = self.typewriter_font:getWidth(char_upper)
            local lh = self.typewriter_font:getHeight()
            love.graphics.print(char_upper, box_x + (box_w - lw) / 2, input_y + (box_w - lh) / 2)
        else
            -- Untyped empty box: draw a semi-transparent dashed/dotted outline, no fill (shows corkboard texture)
            love.graphics.setColor(config.COLOR_TEXT_MUTED[1], config.COLOR_TEXT_MUTED[2], config.COLOR_TEXT_MUTED[3], 0.6)
            love.graphics.setLineWidth(1.5)
            love.graphics.rectangle("line", box_x, input_y, box_w, box_w, 4, 4)
        end
    end
    
    -- 3. Draw Typewriter Keyboard at bottom
    local kbd_x = 400
    local kbd_y = 480
    local key_size = 45
    local key_gap = 8
    
    for r_idx, row in ipairs(self.kbd_rows) do
        local offset = 0
        if r_idx == 2 then
            offset = 20
        elseif r_idx == 3 then
            offset = 40
        end
        
        for k_idx, char in ipairs(row) do
            local key_x = kbd_x + offset + (k_idx - 1) * (key_size + key_gap)
            local key_y = kbd_y + (r_idx - 1) * (key_size + key_gap)
            
            local mods = self.run_manager.keyboard_mods[char] or {}
            local is_highlighter = mods.highlighter == true
            local is_coffee_ring = mods.coffee_ring == true
            local is_stapler = mods.stapler == true
            local is_removed = mods.removed == true
            
            local clue_state = self.key_discoveries[char] or "empty"
            
            local bg_color, border_color
            if is_removed then
                bg_color = {20/255, 20/255, 25/255}
                border_color = {40/255, 42/255, 50/255}
            else
                if clue_state == "green" then
                    bg_color = config.COLOR_CLUE_GREEN
                elseif clue_state == "yellow" then
                    bg_color = config.COLOR_CLUE_YELLOW
                elseif clue_state == "grey" then
                    bg_color = config.COLOR_CLUE_GREY
                else
                    bg_color = config.COLOR_PANEL
                end
                border_color = config.COLOR_TEXT_LIGHT
            end
            
            love.graphics.setColor(bg_color[1], bg_color[2], bg_color[3], 1.0)
            love.graphics.rectangle("fill", key_x, key_y, key_size, key_size, 5, 5)
            
            if is_highlighter and not is_removed then
                love.graphics.setColor(config.COLOR_HIGHLIGHTER[1], config.COLOR_HIGHLIGHTER[2], config.COLOR_HIGHLIGHTER[3], 1.0)
                love.graphics.setLineWidth(3)
                love.graphics.rectangle("line", key_x, key_y, key_size, key_size, 5, 5)
            end
            if is_coffee_ring and not is_removed then
                love.graphics.setColor(config.COLOR_CLUE_REDACTED[1], config.COLOR_CLUE_REDACTED[2], config.COLOR_CLUE_REDACTED[3], 1.0)
                love.graphics.setLineWidth(3)
                love.graphics.circle("line", key_x + key_size / 2, key_y + key_size / 2, 12)
            end
            if is_stapler and not is_removed then
                love.graphics.setColor(180/255, 180/255, 190/255, 1.0)
                love.graphics.setLineWidth(2)
                love.graphics.line(key_x + 8, key_y + 6, key_x + key_size - 8, key_y + 6)
                love.graphics.line(key_x + 8, key_y + key_size - 6, key_x + key_size - 8, key_y + key_size - 6)
            end
            
            love.graphics.setColor(border_color[1], border_color[2], border_color[3], 1.0)
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
    
    -- Error / notice banner
    if self.error_timer > 0 and self.error_message ~= "" then
        local bx, by, bw, bh = 400, 20, 440, 45
        love.graphics.setColor(30/255, 20/255, 20/255, 1.0)
        love.graphics.rectangle("fill", bx, by, bw, bh, 6, 6)
        love.graphics.setColor(config.COLOR_ACCENT[1], config.COLOR_ACCENT[2], config.COLOR_ACCENT[3], 1.0)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", bx, by, bw, bh, 6, 6)
        
        love.graphics.setFont(self.ui_bold)
        love.graphics.setColor(config.COLOR_TEXT_LIGHT[1], config.COLOR_TEXT_LIGHT[2], config.COLOR_TEXT_LIGHT[3], 1.0)
        local ew = self.ui_bold:getWidth(self.error_message)
        local eh = self.ui_bold:getHeight()
        love.graphics.print(self.error_message, bx + (bw - ew) / 2, by + (bh - eh) / 2)
    end
    
    -- Buttons
    for _, btn in ipairs(self.buttons) do
        btn:draw()
    end
end

function GameState:draw_tooltip(tooltip)
    local title = tooltip.title
    local desc = tooltip.desc
    local debuff = tooltip.debuff
    local mx, my = tooltip.pos[1], tooltip.pos[2]
    
    local w, h = 300, 110
    local tx = math.min(config.SCREEN_WIDTH - w - 20, math.max(20, mx + 15))
    local ty = math.min(config.SCREEN_HEIGHT - h - 20, math.max(20, my + 15))
    
    love.graphics.setColor(20/255, 22/255, 30/255, 1.0)
    love.graphics.rectangle("fill", tx, ty, w, h, 8, 8)
    love.graphics.setColor(config.COLOR_TEXT_MUTED[1], config.COLOR_TEXT_MUTED[2], config.COLOR_TEXT_MUTED[3], 1.0)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", tx, ty, w, h, 8, 8)
    
    love.graphics.setFont(self.ui_bold)
    love.graphics.setColor(config.COLOR_TEXT_LIGHT[1], config.COLOR_TEXT_LIGHT[2], config.COLOR_TEXT_LIGHT[3], 1.0)
    love.graphics.print(title, tx + 12, ty + 10)
    
    local desc_words = {}
    for word in desc:gmatch("%S+") do
        table.insert(desc_words, word)
    end
    local lines = {}
    local curr_line = ""
    for _, word in ipairs(desc_words) do
        if #curr_line + #word + 1 < 36 then
            curr_line = curr_line .. (curr_line == "" and "" or " ") .. word
        else
            table.insert(lines, curr_line)
            curr_line = word
        end
    end
    if curr_line ~= "" then
        table.insert(lines, curr_line)
    end
    
    love.graphics.setFont(self.tooltip_font)
    love.graphics.setColor(config.COLOR_TEXT_LIGHT[1], config.COLOR_TEXT_LIGHT[2], config.COLOR_TEXT_LIGHT[3], 1.0)
    local y_off = ty + 35
    for idx, line in ipairs(lines) do
        if idx <= 2 then
            love.graphics.print(line, tx + 12, y_off)
            y_off = y_off + 16
        end
    end
    
    love.graphics.setColor(config.COLOR_ACCENT[1], config.COLOR_ACCENT[2], config.COLOR_ACCENT[3], 1.0)
    love.graphics.print(debuff, tx + 12, ty + 85)
end

return GameState
