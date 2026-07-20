local config = require("src/config")
local ui = require("src/engine/ui")
local State = require("src/engine/state_machine").State
local StyleGuideUpgrade = require("src/content/style_guides").StyleGuideUpgrade
local style_guides_data = require("src/content/style_guides").STYLE_GUIDES_DATA
local tropes_module = require("src/content/tropes")
local edits_module = require("src/content/edits")

local ShopState = setmetatable({}, State)
ShopState.__index = ShopState

function ShopState.new(state_machine, run_manager)
    local self = State.new(state_machine, run_manager)
    setmetatable(self, ShopState)
    
    self.buttons = {}
    self.particles = ui.ParticleSystem.new()
    
    self.title_font = config.get_font("typewriter", 36)
    self.label_font = config.get_font("sans", 20)
    self.desc_font = config.get_font("sans", 14)
    self.stat_font = config.get_font("sans", 24)
    self.prompt_font = config.get_font("typewriter", 22)
    
    self.shop_items = {}
    self.pending_sticker = "none"
    self.stapler_first_key = nil
    
    self.kbd_rows = {
        {'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'},
        {'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l'},
        {'z', 'x', 'c', 'v', 'b', 'n', 'm'}
    }
    
    return self
end

function ShopState:enter(kwargs)
    self.pending_sticker = "none"
    self.stapler_first_key = nil
    self.buttons = {}
    
    self:roll_shop()
    
    table.insert(self.buttons, ui.Button.new(
        config.SCREEN_WIDTH - 200, 10, 180, 40,
        "Next Assignment",
        function() self:next_assignment() end,
        {46/255, 180/255, 110/255}
    ))
end

function ShopState:next_assignment()
    self.state_machine:change_state("assignment_select")
end

function ShopState:roll_shop()
    self.shop_items = {}
    
    -- 1. Style Guide
    local patterns = {}
    for pat, _ in pairs(style_guides_data) do
        table.insert(patterns, pat)
    end
    local pat = patterns[love.math.random(1, #patterns)]
    table.insert(self.shop_items, {
        type = "style_guide",
        item_obj = StyleGuideUpgrade.new(pat),
        price = style_guides_data[pat].price,
        sold = false
    })
    
    -- 2. Trope
    local tropes = tropes_module.create_all_tropes()
    local owned_names = {}
    for _, t in ipairs(self.run_manager.tropes) do
        owned_names[t.name] = true
    end
    local available_tropes = {}
    for _, t in ipairs(tropes) do
        if not owned_names[t.name] then
            table.insert(available_tropes, t)
        end
    end
    
    local trope
    if #available_tropes > 0 then
        trope = available_tropes[love.math.random(1, #available_tropes)]
    else
        trope = tropes[1]
    end
    table.insert(self.shop_items, {
        type = "trope",
        item_obj = trope,
        price = trope.price,
        sold = false
    })
    
    -- 3. Edit
    local edits = edits_module.create_all_edits()
    local edit = edits[love.math.random(1, #edits)]
    table.insert(self.shop_items, {
        type = "edit",
        item_obj = edit,
        price = edit.price,
        sold = false
    })
    
    -- 4. Sticker
    local stickers = {
        {name = "Yellow Highlighter", desc = "Played key gives permanent +15 Hype.", type = "highlighter", price = 3},
        {name = "Correction Tape", desc = "Played key forces Grey color, but gives massive +100 Words.", type = "correction_tape", price = 3},
        {name = "The Stapler", desc = "Staples two keys. They score twice, but must be played together.", type = "stapler", price = 4}
    }
    local sticker = stickers[love.math.random(1, #stickers)]
    table.insert(self.shop_items, {
        type = "sticker",
        item_obj = sticker,
        price = sticker.price,
        sold = false
    })
end

function ShopState:buy_item(idx)
    if self.pending_sticker ~= "none" then return end
    
    local item_data = self.shop_items[idx]
    if not item_data or item_data.sold then return end
    
    if self.run_manager.royalties < item_data.price then
        if config.sounds then config.sounds:play("error") end
        return
    end
    
    local itype = item_data.type
    local obj = item_data.item_obj
    
    if itype == "style_guide" then
        local msg = obj:use(self.run_manager)
        self.run_manager.royalties = self.run_manager.royalties - item_data.price
        item_data.sold = true
        if config.sounds then config.sounds:play("buy") end
        self.particles:spawn(60 + (idx - 1) * 280 + 130, 240, config.COLOR_ROYALTIES, 15)
        
    elseif itype == "trope" then
        if #self.run_manager.tropes >= 5 then
            if config.sounds then config.sounds:play("error") end
            return
        end
        table.insert(self.run_manager.tropes, obj)
        obj:on_equip(self.run_manager)
        self.run_manager.royalties = self.run_manager.royalties - item_data.price
        item_data.sold = true
        if config.sounds then config.sounds:play("buy") end
        self.particles:spawn(60 + (idx - 1) * 280 + 130, 240, config.COLOR_ACCENT, 15)
        
    elseif itype == "edit" then
        if #self.run_manager.edits >= 2 then
            if config.sounds then config.sounds:play("error") end
            return
        end
        table.insert(self.run_manager.edits, obj)
        self.run_manager.royalties = self.run_manager.royalties - item_data.price
        item_data.sold = true
        if config.sounds then config.sounds:play("buy") end
        self.particles:spawn(60 + (idx - 1) * 280 + 130, 240, config.COLOR_ROYALTIES, 15)
        
    elseif itype == "sticker" then
        self.pending_sticker = obj.type
        self.run_manager.royalties = self.run_manager.royalties - item_data.price
        item_data.sold = true
        if config.sounds then config.sounds:play("buy") end
    end
end

function ShopState:update(dt)
    self.particles:update(dt)
    
    local mx, my = love.mouse.getPosition()
    mx, my = config.mx or mx, config.my or my
    
    for _, btn in ipairs(self.buttons) do
        btn:check_hover(mx, my)
        btn:update(dt)
    end
end

function ShopState:mousepressed(x, y, button, istouch, presses)
    local mx, my = config.mx or x, config.my or y
    
    for _, btn in ipairs(self.buttons) do
        if btn:handle_event("mousepressed", mx, my, button) then
            return
        end
    end
    
    if button == 1 then
        for idx = 1, 4 do
            local card_x = 60 + (idx - 1) * 280
            local card_y = 100
            local bx, by, bw, bh = card_x + 30, card_y + 220, 180, 40
            if mx >= bx and mx <= bx + bw and my >= by and my <= by + bh then
                self:buy_item(idx)
                break
            end
        end
        
        if self.pending_sticker ~= "none" then
            self:click_typewriter_key(mx, my)
        end
    end
end

function ShopState:click_typewriter_key(mx, my)
    local kbd_x = 400
    local kbd_y = 450
    local key_size = 42
    local key_gap = 8
    
    for r_idx, row in ipairs(self.kbd_rows) do
        local offset = 0
        if r_idx == 2 then offset = 18
        elseif r_idx == 3 then offset = 36
        end
        for k_idx, char in ipairs(row) do
            local kx = kbd_x + offset + (k_idx - 1) * (key_size + key_gap)
            local ky = kbd_y + (r_idx - 1) * (key_size + key_gap)
            
            if mx >= kx and mx <= kx + key_size and my >= ky and my <= ky + key_size then
                if config.sounds then config.sounds:play("stamp") end
                
                if self.pending_sticker == "highlighter" then
                    self.run_manager.keyboard_mods[char].highlighter = true
                    self.pending_sticker = "none"
                    self.particles:spawn(kx + key_size/2, ky + key_size/2, config.COLOR_HIGHLIGHTER, 12)
                elseif self.pending_sticker == "correction_tape" then
                    self.run_manager.keyboard_mods[char].correction_tape = true
                    self.pending_sticker = "none"
                    self.particles:spawn(kx + key_size/2, ky + key_size/2, {240/255, 240/255, 240/255}, 12)
                elseif self.pending_sticker == "stapler" then
                    self.stapler_first_key = char
                    self.pending_sticker = "stapler_second"
                elseif self.pending_sticker == "stapler_second" then
                    if char == self.stapler_first_key then
                        if config.sounds then config.sounds:play("error") end
                        return
                    end
                    self.run_manager.keyboard_mods[self.stapler_first_key].stapler = true
                    self.run_manager.keyboard_mods[char].stapler = true
                    table.insert(self.run_manager.stapled_pairs, {self.stapler_first_key, char})
                    
                    self.pending_sticker = "none"
                    self.stapler_first_key = nil
                    self.particles:spawn(kx + key_size/2, ky + key_size/2, {160/255, 160/255, 180/255}, 12)
                end
                break
            end
        end
    end
end

function ShopState:draw()
    love.graphics.setColor(config.COLOR_DESK[1], config.COLOR_DESK[2], config.COLOR_DESK[3], 1.0)
    love.graphics.rectangle("fill", 0, 0, config.SCREEN_WIDTH, config.SCREEN_HEIGHT)
    
    -- 1. Status Bar
    love.graphics.setColor(config.COLOR_PANEL[1], config.COLOR_PANEL[2], config.COLOR_PANEL[3], 1.0)
    love.graphics.rectangle("fill", 0, 0, config.SCREEN_WIDTH, 60)
    love.graphics.setColor(config.COLOR_TEXT_MUTED[1], config.COLOR_TEXT_MUTED[2], config.COLOR_TEXT_MUTED[3], 1.0)
    love.graphics.setLineWidth(2)
    love.graphics.line(0, 60, config.SCREEN_WIDTH, 60)
    
    -- Royalties
    love.graphics.setFont(self.stat_font)
    love.graphics.setColor(config.COLOR_ROYALTIES[1], config.COLOR_ROYALTIES[2], config.COLOR_ROYALTIES[3], 1.0)
    love.graphics.print("Royalties: $" .. self.run_manager.royalties, 30, 15)
    
    -- Header Title
    love.graphics.setFont(self.title_font)
    love.graphics.setColor(config.COLOR_TEXT_LIGHT[1], config.COLOR_TEXT_LIGHT[2], config.COLOR_TEXT_LIGHT[3], 1.0)
    local t_w = self.title_font:getWidth("The Supply Closet")
    love.graphics.print("The Supply Closet", config.SCREEN_WIDTH / 2 - t_w / 2, 12)
    
    for _, btn in ipairs(self.buttons) do
        btn:draw()
    end
    
    -- 2. Draw Cards
    local mx, my = love.mouse.getPosition()
    mx, my = config.mx or mx, config.my or my
    
    for idx, item in ipairs(self.shop_items) do
        local card_x = 60 + (idx - 1) * 280
        local card_y = 100
        local w, h = 260, 280
        
        love.graphics.setColor(config.COLOR_PANEL[1], config.COLOR_PANEL[2], config.COLOR_PANEL[3], 1.0)
        love.graphics.rectangle("fill", card_x, card_y, w, h, 10, 10)
        
        if item.sold then
            love.graphics.setColor(20/255, 20/255, 25/255, 1.0)
            love.graphics.rectangle("fill", card_x, card_y, w, h, 10, 10)
            love.graphics.setColor(config.COLOR_TEXT_MUTED[1], config.COLOR_TEXT_MUTED[2], config.COLOR_TEXT_MUTED[3], 1.0)
            love.graphics.rectangle("line", card_x, card_y, w, h, 10, 10)
            
            love.graphics.setFont(self.title_font)
            local s_w = self.title_font:getWidth("SOLD")
            love.graphics.print("SOLD", card_x + (w - s_w) / 2, card_y + 115)
        else
            local obj = item.item_obj
            local price = item.price
            
            local title_text, type_lbl, desc_text, col_accent
            if item.type == "style_guide" then
                title_text = obj.name:gsub("Style Guide: ", "")
                type_lbl = "STYLE GUIDE"
                desc_text = obj.description:gsub("Permanently levels up ", "Levels up ")
                col_accent = config.COLOR_CLUE_GREEN
            elseif item.type == "trope" then
                title_text = obj.name
                type_lbl = "TROPE (PASSIVE)"
                desc_text = obj.description
                col_accent = config.COLOR_ACCENT
            elseif item.type == "edit" then
                title_text = obj.name:gsub("The ", "")
                type_lbl = "EDIT (CONSUMABLE)"
                desc_text = obj.description
                col_accent = config.COLOR_ROYALTIES
            else
                title_text = obj.name
                type_lbl = "KEYBOARD MOD"
                desc_text = obj.desc
                col_accent = config.COLOR_HIGHLIGHTER
            end
            
            love.graphics.setColor(col_accent[1], col_accent[2], col_accent[3], 1.0)
            love.graphics.rectangle("line", card_x, card_y, w, h, 10, 10)
            
            love.graphics.setFont(self.desc_font)
            love.graphics.print(type_lbl, card_x + 20, card_y + 15)
            
            love.graphics.setFont(self.label_font)
            love.graphics.setColor(config.COLOR_TEXT_LIGHT[1], config.COLOR_TEXT_LIGHT[2], config.COLOR_TEXT_LIGHT[3], 1.0)
            love.graphics.print(title_text, card_x + 20, card_y + 35)
            
            love.graphics.setColor(config.COLOR_TEXT_MUTED[1], config.COLOR_TEXT_MUTED[2], config.COLOR_TEXT_MUTED[3], 1.0)
            love.graphics.line(card_x + 20, card_y + 70, card_x + w - 20, card_y + 70)
            
            local desc_words = {}
            for word in desc_text:gmatch("%S+") do
                table.insert(desc_words, word)
            end
            local lines = {}
            local curr_line = ""
            for _, word in ipairs(desc_words) do
                if #curr_line + #word + 1 < 28 then
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
            love.graphics.setColor(config.COLOR_TEXT_LIGHT[1], config.COLOR_TEXT_LIGHT[2], config.COLOR_TEXT_LIGHT[3], 1.0)
            local y_d = card_y + 90
            for l_idx, line in ipairs(lines) do
                if l_idx <= 5 then
                    love.graphics.print(line, card_x + 20, y_d)
                    y_d = y_d + 18
                end
            end
            
            local bx, by, bw, bh = card_x + 30, card_y + 220, 180, 40
            local is_hover = (mx >= bx and mx <= bx + bw and my >= by and my <= by + bh)
            local btn_col = is_hover and col_accent or {30/255, 32/255, 40/255}
            
            love.graphics.setColor(btn_col[1], btn_col[2], btn_col[3], 1.0)
            love.graphics.rectangle("fill", bx, by, bw, bh, 6, 6)
            love.graphics.setColor(col_accent[1], col_accent[2], col_accent[3], 1.0)
            love.graphics.rectangle("line", bx, by, bw, bh, 6, 6)
            
            local buy_str = "Buy - $" .. price
            local buy_w = self.label_font:getWidth(buy_str)
            local buy_h = self.label_font:getHeight()
            local cx = bx + bw / 2
            local cy = by + bh / 2
            
            love.graphics.setFont(self.label_font)
            love.graphics.setColor(config.COLOR_TEXT_LIGHT[1], config.COLOR_TEXT_LIGHT[2], config.COLOR_TEXT_LIGHT[3], 1.0)
            love.graphics.print(buy_str, cx, cy - 1, 0, 1, 1, buy_w / 2, buy_h / 2)
        end
    end
    
    -- 3. Keyboard at bottom
    local kbd_x = 400
    local kbd_y = 450
    local key_size = 42
    local key_gap = 8
    
    if self.pending_sticker ~= "none" then
        local prompt_str = "Click a key on the keyboard below to apply the sticker!"
        if self.pending_sticker == "stapler_second" then
            prompt_str = "Click second key to staple to '" .. self.stapler_first_key:upper() .. "'!"
        end
        love.graphics.setFont(self.prompt_font)
        love.graphics.setColor(config.COLOR_HIGHLIGHTER[1], config.COLOR_HIGHLIGHTER[2], config.COLOR_HIGHLIGHTER[3], 1.0)
        local pr_w = self.prompt_font:getWidth(prompt_str)
        love.graphics.print(prompt_str, config.SCREEN_WIDTH / 2 - pr_w / 2, 405)
        
        for r_idx, row in ipairs(self.kbd_rows) do
            local offset = 0
            if r_idx == 2 then offset = 18
            elseif r_idx == 3 then offset = 36
            end
            for k_idx, char in ipairs(row) do
                local kx = kbd_x + offset + (k_idx - 1) * (key_size + key_gap)
                local ky = kbd_y + (r_idx - 1) * (key_size + key_gap)
                
                local mods = self.run_manager.keyboard_mods[char] or {}
                local is_highlighter = mods.highlighter == true
                local is_correction_tape = mods.correction_tape == true
                local is_stapler = mods.stapler == true
                local is_removed = mods.removed == true
                
                local bg_color = config.COLOR_PANEL
                local border_color = config.COLOR_TEXT_MUTED
                
                love.graphics.setColor(bg_color[1], bg_color[2], bg_color[3], 1.0)
                love.graphics.rectangle("fill", kx, ky, key_size, key_size, 4, 4)
                
                if mx >= kx and mx <= kx + key_size and my >= ky and my <= ky + key_size then
                    border_color = config.COLOR_HIGHLIGHTER
                end
                
                if is_highlighter and not is_removed then
                    love.graphics.setColor(config.COLOR_HIGHLIGHTER[1], config.COLOR_HIGHLIGHTER[2], config.COLOR_HIGHLIGHTER[3], 1.0)
                    love.graphics.setLineWidth(2)
                    love.graphics.rectangle("line", kx, ky, key_size, key_size, 4, 4)
                end
                if is_correction_tape and not is_removed then
                    love.graphics.setColor(230/255, 230/255, 240/255, 1.0)
                    love.graphics.rectangle("fill", kx + 4, ky + key_size - 12, key_size - 8, 8)
                end
                if is_stapler and not is_removed then
                    love.graphics.setColor(180/255, 180/255, 190/255, 1.0)
                    love.graphics.setLineWidth(2)
                    love.graphics.line(kx + 6, ky + 4, kx + key_size - 6, ky + 4)
                    love.graphics.line(kx + 6, ky + key_size - 4, kx + key_size - 6, ky + key_size - 4)
                end
                
                love.graphics.setColor(border_color[1], border_color[2], border_color[3], 1.0)
                love.graphics.setLineWidth(1)
                love.graphics.rectangle("line", kx, ky, key_size, key_size, 4, 4)
                
                if not is_removed then
                    love.graphics.setFont(self.desc_font)
                    love.graphics.setColor(config.COLOR_TEXT_LIGHT[1], config.COLOR_TEXT_LIGHT[2], config.COLOR_TEXT_LIGHT[3], 1.0)
                    local char_upper = char:upper()
                    local kw = self.desc_font:getWidth(char_upper)
                    local kh = self.desc_font:getHeight()
                    love.graphics.print(char_upper, kx + (key_size - kw) / 2, ky + (key_size - kh) / 2)
                else
                    love.graphics.setColor(config.COLOR_ACCENT[1], config.COLOR_ACCENT[2], config.COLOR_ACCENT[3], 1.0)
                    love.graphics.setLineWidth(2)
                    love.graphics.line(kx + 6, ky + 6, kx + key_size - 6, ky + key_size - 6)
                    love.graphics.line(kx + key_size - 6, ky + 6, kx + 6, ky + key_size - 6)
                end
            end
        end
    end
    
    self.particles:draw()
end

return ShopState
