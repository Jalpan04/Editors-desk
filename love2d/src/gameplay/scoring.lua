local event_bus = require("src/engine/event_bus")
local style_guides_data = require("src/content/style_guides").STYLE_GUIDES_DATA

local LETTER_WORDS = {
    e = 1, t = 1, a = 1, o = 1, i = 1, n = 1, s = 1,
    h = 2, r = 2, d = 2, l = 2,
    c = 3, u = 3, m = 3, w = 3, f = 3, g = 3, y = 3,
    p = 4, b = 4, v = 4, k = 4,
    j = 8, x = 8, q = 10, z = 10
}

local function to_chars(s)
    local t = {}
    for i = 1, #s do
        table.insert(t, s:sub(i, i))
    end
    return t
end

local function check_word(guess, target)
    guess = guess:lower()
    target = target:lower()
    local length = #guess
    local clues = {}
    local target_matched = {}
    local guess_matched = {}
    
    for i = 1, length do
        clues[i] = 'grey'
        target_matched[i] = false
        guess_matched[i] = false
    end
    
    local guess_chars = to_chars(guess)
    local target_chars = to_chars(target)
    
    -- First pass: find exact matches (green)
    for i = 1, length do
        if guess_chars[i] == target_chars[i] then
            clues[i] = 'green'
            target_matched[i] = true
            guess_matched[i] = true
        end
    end
    
    -- Second pass: find partial matches (yellow)
    for i = 1, length do
        if not guess_matched[i] then
            for j = 1, length do
                if not target_matched[j] and guess_chars[i] == target_chars[j] then
                    clues[i] = 'yellow'
                    target_matched[j] = true
                    break
                end
            end
        end
    end
    
    return clues
end

local function identify_pattern(clues, guess, target)
    local green_count = 0
    local yellow_count = 0
    for _, clue in ipairs(clues) do
        if clue == 'green' then
            green_count = green_count + 1
        elseif clue == 'yellow' then
            yellow_count = yellow_count + 1
        end
    end
    
    local combo_key = green_count .. "," .. yellow_count
    local combo_map = {
        ["0,0"] = "The Total Rewrite",
        ["0,1"] = "The Typo",
        ["0,2"] = "The Brainstorm",
        ["0,3"] = "The Outline",
        ["0,4"] = "The Rough Draft",
        ["0,5"] = "The Jumble",
        ["1,0"] = "The Shot in the Dark",
        ["1,1"] = "The Spark",
        ["1,2"] = "The Concept",
        ["1,3"] = "The Framework",
        ["1,4"] = "The Paradox",
        ["2,0"] = "The Foundation",
        ["2,1"] = "The Direction",
        ["2,2"] = "The Revision",
        ["2,3"] = "The Anagram",
        ["3,0"] = "The Solid Lead",
        ["3,1"] = "The Near Miss",
        ["3,2"] = "The Spoonerism",
        ["4,0"] = "The Typographical Error",
        ["5,0"] = "The Masterpiece"
    }
    
    return combo_map[combo_key] or "Standard Submission"
end

local ScoreManager = {}
ScoreManager.__index = ScoreManager

function ScoreManager.new()
    local self = setmetatable({}, ScoreManager)
    self.words = 0
    self.hype = 0.0
    self.x_hypes = {}
    return self
end

function ScoreManager:add_words(amount)
    self.words = self.words + amount
end

function ScoreManager:add_hype(amount)
    self.hype = self.hype + amount
end

function ScoreManager:add_x_hype(multiplier)
    table.insert(self.x_hypes, multiplier)
end

function ScoreManager:calculate_total()
    local total_hype = self.hype
    for _, xm in ipairs(self.x_hypes) do
        total_hype = total_hype * xm
    end
    total_hype = math.max(1.0, total_hype)
    return math.floor(self.words * total_hype)
end

local function calculate_word_score(guess, target, style_guides_levels, keyboard_mods, boss_assignment)
    guess = guess:lower()
    target = target:lower()
    local clues = check_word(guess, target)
    
    local guess_chars = to_chars(guess)
    for i = 1, #guess_chars do
        local letter = guess_chars[i]
        if keyboard_mods[letter] and keyboard_mods[letter].correction_tape then
            clues[i] = 'grey'
        end
    end
    
    local pattern_name = identify_pattern(clues, guess, target)
    
    if boss_assignment == "Plagiarist" and pattern_name == "The Jumble" then
        pattern_name = "The Rough Draft"
    end
    
    local score_mgr = ScoreManager.new()
    
    local base_info = style_guides_data[pattern_name]
    local level = style_guides_levels[pattern_name] or 1
    
    local base_words = base_info.base_words + (level - 1) * base_info.upgrade_words
    local base_hype = base_info.base_hype + (level - 1) * base_info.upgrade_hype
    
    score_mgr:add_words(base_words)
    score_mgr:add_hype(base_hype)
    
    for i = 1, #guess_chars do
        local letter = guess_chars[i]
        local clue = clues[i]
        
        local mods = keyboard_mods[letter] or {}
        local is_highlighted = mods.highlighter == true
        local is_correction_tape = mods.correction_tape == true
        local is_stapled = mods.stapler == true
        
        local repeat_count = is_stapled and 2 or 1
        
        for r_idx = 1, repeat_count do
            local let_words = 0
            if clue == 'green' then
                let_words = 5
            elseif clue == 'yellow' then
                let_words = 1
            end
            
            if is_highlighted then
                score_mgr:add_hype(15.0)
            end
            if is_correction_tape then
                score_mgr:add_words(100)
            end
            
            score_mgr:add_words(let_words)
        end
        
        event_bus.bus:publish('ON_LETTER_SCORED', letter, i, clue, score_mgr)
    end
    
    event_bus.bus:publish('ON_SCORE_CALCULATED', score_mgr, guess, clues, pattern_name)
    
    local final_score = score_mgr:calculate_total()
    return {
        score = final_score,
        words = score_mgr.words,
        hype = score_mgr.hype,
        x_hypes = score_mgr.x_hypes,
        clues = clues,
        pattern = pattern_name
    }
end

return {
    LETTER_WORDS = LETTER_WORDS,
    check_word = check_word,
    identify_pattern = identify_pattern,
    ScoreManager = ScoreManager,
    calculate_word_score = calculate_word_score
}
