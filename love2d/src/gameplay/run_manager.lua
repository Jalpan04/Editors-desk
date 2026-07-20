local event_bus = require("src/engine/event_bus")
local Dictionary = require("src/gameplay/dictionary")
local scoring = require("src/gameplay/scoring")

local RunManager = {}
RunManager.__index = RunManager

function RunManager.new(data_dir)
    local self = setmetatable({}, RunManager)
    self.dictionary = Dictionary.new(data_dir)
    
    -- Persistent Run State
    self.royalties = 4
    self.chapter = 1
    self.assignment_index = 0
    self.assignment_type = "small"
    self.target_score = 500
    
    self.tropes = {}
    self.edits = {}
    
    -- Keyboard modifiers
    self.keyboard_mods = {}
    for c = 97, 122 do
        local char = string.char(c)
        self.keyboard_mods[char] = {
            highlighter = false,
            coffee_ring = false,
            stapler = false,
            removed = false,
            correction_tape = false
        }
    end
    self.stapled_pairs = {}
    
    local style_guides_data = require("src/content/style_guides").STYLE_GUIDES_DATA
    self.style_guides = {
        ["Standard Submission"] = 1
    }
    for pat, _ in pairs(style_guides_data) do
        self.style_guides[pat] = 1
    end
    
    self.key_discoveries = {}
    for c = 97, 122 do
        self.key_discoveries[string.char(c)] = "empty"
    end
    
    -- Current Round State
    self.round_score = 0
    self.submissions_max = 4
    self.submissions_left = 4
    self.drafts_max = 2
    self.drafts_left = 2
    self.target_word = ""
    self.round_history = {}
    
    -- Boss Assignment state
    self.boss_assignment = nil
    self.boss_pool = {"Minimalist", "Plagiarist", "Ghostwriter"}
    self.selected_boss = "Minimalist"
    
    self.red_pen_green_bonus = 0
    
    self:roll_boss_assignment()
    self:update_target_score()
    
    return self
end

function RunManager:roll_boss_assignment()
    local idx = love.math.random(1, #self.boss_pool)
    self.selected_boss = self.boss_pool[idx]
end

function RunManager:get_assignment_name()
    if self.assignment_index == 0 then
        return "Small Assignment"
    elseif self.assignment_index == 1 then
        return "Big Assignment"
    else
        return "Boss: " .. self.selected_boss
    end
end

function RunManager:update_target_score()
    local chapter_bases = {0, 500, 1500, 4000, 10000, 25000, 60000, 120000, 250000}
    local base_idx = math.min(self.chapter, 8) + 1 -- chapter 1 maps to chapter_bases[2]
    local base = chapter_bases[base_idx] or 250000
    
    if self.assignment_index == 0 then
        self.target_score = base
        self.assignment_type = "small"
        self.boss_assignment = nil
    elseif self.assignment_index == 1 then
        self.target_score = math.floor(base * 1.6)
        self.assignment_type = "big"
        self.boss_assignment = nil
    else
        self.target_score = math.floor(base * 2.4)
        self.assignment_type = "boss"
        self.boss_assignment = self.selected_boss
    end
    
    -- Ghostwriter trope target modifier
    local has_ghostwriter = false
    for _, t in ipairs(self.tropes) do
        if t.name == "The Ghostwriter" and t.is_debuff_active then
            has_ghostwriter = true
            break
        end
    end
    if has_ghostwriter then
        self.target_score = math.floor(self.target_score * 1.5)
    end
end

function RunManager:start_round()
    self.round_score = 0
    self.round_history = {}
    for c = 97, 122 do
        self.key_discoveries[string.char(c)] = "empty"
    end
    
    self.submissions_max = 4
    local has_red_pen = false
    for _, t in ipairs(self.tropes) do
        if t.name == "The Red Pen" and t.is_debuff_active then
            has_red_pen = true
            break
        end
    end
    if has_red_pen then
        self.submissions_max = 3
    end
    
    self.submissions_left = self.submissions_max
    self.drafts_left = self.drafts_max
    
    if self.boss_assignment == "Minimalist" then
        self.target_word = self:get_4_letter_target()
    else
        self.target_word = self.dictionary:get_random_target()
    end
    
    event_bus.bus:publish('ON_ROUND_START')
end

function RunManager:get_4_letter_target()
    local words_4 = {"book", "page", "edit", "plot", "word", "desk", "read", "type", "inks", "bind"}
    local idx = love.math.random(1, #words_4)
    return words_4[idx]:sub(1, 4):lower()
end

local function sort_string(s)
    local chars = {}
    for i = 1, #s do
        table.insert(chars, s:sub(i, i))
    end
    table.sort(chars)
    return table.concat(chars)
end

function RunManager:get_plagiarist_anagram(first_guess)
    local sorted_guess = sort_string(first_guess)
    local candidates = {}
    
    for _, w in ipairs(self.dictionary.target_words) do
        if sort_string(w) == sorted_guess and w ~= first_guess then
            table.insert(candidates, w)
        end
    end
    
    if #candidates == 0 then
        for w, _ in pairs(self.dictionary.allowed_guesses) do
            if sort_string(w) == sorted_guess and w ~= first_guess then
                table.insert(candidates, w)
            end
        end
    end
    
    if #candidates > 0 then
        return candidates[love.math.random(1, #candidates)]
    else
        local chars = {}
        for i = 1, #first_guess do
            table.insert(chars, first_guess:sub(i, i))
        end
        -- Shuffle chars
        for i = #chars, 2, -1 do
            local j = love.math.random(1, i)
            chars[i], chars[j] = chars[j], chars[i]
        end
        return table.concat(chars)
    end
end

function RunManager:submit_word(guess, is_draft)
    guess = guess:lower():match("^%s*(.-)%s*$")
    is_draft = is_draft or false
    
    if self.boss_assignment == "Minimalist" then
        if #guess ~= 4 then
            return {error = "Must submit a 4-letter word!"}
        end
    else
        if #guess ~= 5 then
            return {error = "Must submit a 5-letter word!"}
        end
    end
    
    -- Plagiarism check
    local previous_submissions = {}
    for _, entry in ipairs(self.round_history) do
        if not entry.is_draft then
            previous_submissions[entry.word] = true
        end
    end
    if not is_draft and previous_submissions[guess] then
        self.submissions_left = self.submissions_left - 1
        local clues = scoring.check_word(guess, self.target_word)
        local result = {
            score = 0,
            words = 0,
            hype = 1.0,
            x_hypes = {},
            clues = clues,
            pattern = "Plagiarized"
        }
        table.insert(self.round_history, {
            word = guess,
            clues = clues,
            is_draft = false,
            score = 0,
            is_plagiarized = true
        })
        return result
    end
    
    local is_ghostwriter_active = false
    for _, t in ipairs(self.tropes) do
        if t.name == "The Ghostwriter" then
            is_ghostwriter_active = true
            break
        end
    end
    
    if is_ghostwriter_active then
        local _, wildcards = guess:gsub("%*", "")
        if wildcards > 2 then
            return {error = "Ghostwriter exploit! Max 2 wildcards allowed per submission."}
        end
    end
    
    if not is_ghostwriter_active or not guess:find("%*") then
        if self.boss_assignment == "Minimalist" then
            -- Accept all 4 letter words
        elseif not self.dictionary:is_valid_guess(guess) then
            return {error = "Not in word list!"}
        end
    end
    
    for _, pair in ipairs(self.stapled_pairs) do
        local letter1, letter2 = pair[1], pair[2]
        local has1 = guess:find(letter1, 1, true) ~= nil
        local has2 = guess:find(letter2, 1, true) ~= nil
        if (has1 and not has2) or (has2 and not has1) then
            return {error = "Stapled keys! Must play '" .. letter1:upper() .. "' and '" .. letter2:upper() .. "' together."}
        end
    end
    
    local has_plot_twist_debuff = false
    for _, t in ipairs(self.tropes) do
        if t.name == "The Plot Twist" and t.is_debuff_active then
            has_plot_twist_debuff = true
            break
        end
    end
    if has_plot_twist_debuff and guess:find("e", 1, true) then
        return {error = "Plot Twist debuff! Cannot play words containing 'E'."}
    end
    
    local has_purple_prose_debuff = false
    for _, t in ipairs(self.tropes) do
        if t.name == "Purple Prose" and t.is_debuff_active then
            has_purple_prose_debuff = true
            break
        end
    end
    if has_purple_prose_debuff then
        local vowels = 0
        for i = 1, #guess do
            local char = guess:sub(i, i)
            if char:find("[aeiou]") then
                vowels = vowels + 1
            end
        end
        if vowels < 2 then
            return {error = "Purple Prose debuff! Must use at least 2 vowels."}
        end
    end
    
    local has_red_pen_debuff = false
    for _, t in ipairs(self.tropes) do
        if t.name == "The Red Pen" and t.is_debuff_active then
            has_red_pen_debuff = true
            break
        end
    end
    if has_red_pen_debuff then
        for i = 1, #guess do
            local char = guess:sub(i, i)
            if self.keyboard_mods[char] and self.keyboard_mods[char].removed then
                return {error = "Red Pen debuff! Letter '" .. char:upper() .. "' has been removed."}
            end
        end
    end
    
    if self.boss_assignment == "Plagiarist" and #self.round_history == 0 and not is_draft then
        self.target_word = self:get_plagiarist_anagram(guess)
    end
    
    local eval_guess_chars = {}
    for i = 1, #guess do
        local c = guess:sub(i, i)
        if is_ghostwriter_active and c == "*" and i <= #self.target_word then
            table.insert(eval_guess_chars, self.target_word:sub(i, i))
        else
            table.insert(eval_guess_chars, c)
        end
    end
    local eval_guess_str = table.concat(eval_guess_chars)
    
    local clues = scoring.check_word(eval_guess_str, self.target_word)
    
    local has_red_pen = false
    for _, t in ipairs(self.tropes) do
        if t.name == "The Red Pen" then
            has_red_pen = true
            break
        end
    end
    if has_red_pen and not is_draft then
        for idx = 1, #clues do
            local clue = clues[idx]
            local char = guess:sub(idx, idx)
            if clue == 'grey' and char:match("%a") then
                if self.keyboard_mods[char] and not self.keyboard_mods[char].removed then
                    self.keyboard_mods[char].removed = true
                    self.red_pen_green_bonus = self.red_pen_green_bonus + 10
                end
            end
        end
    end
    
    local result
    if is_draft then
        self.drafts_left = self.drafts_left - 1
        result = {
            score = 0,
            words = 0,
            hype = 1.0,
            x_hypes = {},
            clues = clues,
            pattern = "Drafted"
        }
    else
        self.submissions_left = self.submissions_left - 1
        
        result = scoring.calculate_word_score(eval_guess_str, self.target_word, self.style_guides, self.keyboard_mods, self.boss_assignment)
        
        if self.red_pen_green_bonus > 0 then
            for idx = 1, #clues do
                if clues[idx] == 'green' then
                    result.words = result.words + self.red_pen_green_bonus
                    local total_hype = result.hype
                    for _, xm in ipairs(result.x_hypes) do
                        total_hype = total_hype * xm
                    end
                    result.score = math.floor(result.words * total_hype)
                end
            end
        end
        
        self.round_score = self.round_score + result.score
    end
    
    local final_clues = {}
    for idx = 1, #guess do
        local char = guess:sub(idx, idx)
        if self.keyboard_mods[char] and self.keyboard_mods[char].coffee_ring then
            final_clues[idx] = "redacted"
        else
            final_clues[idx] = clues[idx]
        end
    end
    
    local history_entry = {
        word = guess,
        clues = final_clues,
        score = result.score,
        is_draft = is_draft
    }
    table.insert(self.round_history, history_entry)
    
    if is_draft then
        event_bus.bus:publish('ON_WORD_DRAFTED', guess, final_clues)
    else
        event_bus.bus:publish('ON_WORD_SUBMITTED', guess, final_clues, result.score)
    end
    
    return result
end

function RunManager:check_round_end()
    if self.round_score >= self.target_score then
        local reward = 3 + self.submissions_left
        self.royalties = self.royalties + reward
        event_bus.bus:publish('ON_STAGE_WON', reward)
        return "win"
    elseif self.submissions_left <= 0 then
        event_bus.bus:publish('ON_STAGE_LOST')
        return "lose"
    end
    return "continue"
end

function RunManager:advance_assignment()
    self.assignment_index = self.assignment_index + 1
    if self.assignment_index > 2 then
        self.chapter = self.chapter + 1
        self.assignment_index = 0
        for _, mod in pairs(self.keyboard_mods) do
            mod.removed = false
        end
        self:roll_boss_assignment()
    end
    self:update_target_score()
end

return RunManager
