local event_bus = require("src/engine/event_bus")

local Trope = {}
Trope.__index = Trope

function Trope.new(name, description, debuff_desc, price)
    local self = setmetatable({}, Trope)
    self.name = name
    self.description = description
    self.debuff_desc = debuff_desc
    self.price = price or 5
    self.is_debuff_active = true
    return self
end

function Trope:on_equip(run_manager) end
function Trope:on_unequip(run_manager) end

local PlotTwistTrope = setmetatable({}, Trope)
PlotTwistTrope.__index = PlotTwistTrope
function PlotTwistTrope.new()
    local self = Trope.new("The Plot Twist", "Guessing exactly 1 Green and 4 Greys gives an x15 Hype multiplier.", "You can no longer play words containing the letter 'E'.", 6)
    return setmetatable(self, PlotTwistTrope)
end
function PlotTwistTrope:on_equip(run_manager)
    self.apply_bonus_cb = function(score_manager, guess, clues, pattern_name)
        if pattern_name == "The Shot in the Dark" then
            score_manager:add_x_hype(15.0)
        end
    end
    event_bus.bus:subscribe('ON_SCORE_CALCULATED', self.apply_bonus_cb)
end
function PlotTwistTrope:on_unequip(run_manager)
    if self.apply_bonus_cb then
        event_bus.bus:unsubscribe('ON_SCORE_CALCULATED', self.apply_bonus_cb)
    end
end

local PurpleProseTrope = setmetatable({}, Trope)
PurpleProseTrope.__index = PurpleProseTrope
function PurpleProseTrope.new()
    local self = Trope.new("Purple Prose", "Rare letters (Z, X, Q, J) trigger their score twice.", "You must use at least two vowels in every guess.", 5)
    return setmetatable(self, PurpleProseTrope)
end
function PurpleProseTrope:on_equip(run_manager)
    self.apply_double_rare_cb = function(letter, index, clue, score_manager)
        local lower = letter:lower()
        if lower == 'z' or lower == 'x' or lower == 'q' or lower == 'j' then
            if clue == 'green' then
                score_manager:add_words(5)
            elseif clue == 'yellow' then
                score_manager:add_words(1)
            end
        end
    end
    event_bus.bus:subscribe('ON_LETTER_SCORED', self.apply_double_rare_cb)
end
function PurpleProseTrope:on_unequip(run_manager)
    if self.apply_double_rare_cb then
        event_bus.bus:unsubscribe('ON_LETTER_SCORED', self.apply_double_rare_cb)
    end
end

local RedPenTrope = setmetatable({}, Trope)
RedPenTrope.__index = RedPenTrope
function RedPenTrope.new()
    local self = Trope.new("The Red Pen", "Grey letters trigger permanent Green letter bonus of +10 words.", "You lose 1 Submission per round; grey letters are removed from keyboard.", 7)
    return setmetatable(self, RedPenTrope)
end
function RedPenTrope:on_equip(run_manager) end
function RedPenTrope:on_unequip(run_manager)
    for char, mod in pairs(run_manager.keyboard_mods) do
        mod.removed = false
    end
end

local GhostwriterTrope = setmetatable({}, Trope)
GhostwriterTrope.__index = GhostwriterTrope
function GhostwriterTrope.new()
    local self = Trope.new("The Ghostwriter", "Blank spaces '*' act as wildcards (matching the correct target letter).", "The Target Score increases by 1.5x.", 6)
    return setmetatable(self, GhostwriterTrope)
end
function GhostwriterTrope:on_equip(run_manager)
    run_manager:update_target_score()
end
function GhostwriterTrope:on_unequip(run_manager)
    run_manager:update_target_score()
end

local InkRibbonTrope = setmetatable({}, Trope)
InkRibbonTrope.__index = InkRibbonTrope
function InkRibbonTrope.new()
    local self = Trope.new("Ink Ribbon", "Each Green letter in your word adds +2 Hype multiplier.", "None.", 4)
    self.is_debuff_active = false
    return setmetatable(self, InkRibbonTrope)
end
function InkRibbonTrope:on_equip(run_manager)
    self.apply_bonus_cb = function(score_manager, guess, clues, pattern_name)
        local green_count = 0
        for _, clue in ipairs(clues) do
            if clue == 'green' then
                green_count = green_count + 1
            end
        end
        if green_count > 0 then
            score_manager:add_hype(green_count * 2.0)
        end
    end
    event_bus.bus:subscribe('ON_SCORE_CALCULATED', self.apply_bonus_cb)
end
function InkRibbonTrope:on_unequip(run_manager)
    if self.apply_bonus_cb then
        event_bus.bus:unsubscribe('ON_SCORE_CALCULATED', self.apply_bonus_cb)
    end
end

local DeadlineTrope = setmetatable({}, Trope)
DeadlineTrope.__index = DeadlineTrope
function DeadlineTrope.new()
    local self = Trope.new("The Deadline", "If this is your final Submission, gain +100 Words and +10 Hype multiplier.", "None.", 4)
    self.is_debuff_active = false
    return setmetatable(self, DeadlineTrope)
end
function DeadlineTrope:on_equip(run_manager)
    self.rm = run_manager
    self.apply_bonus_cb = function(score_manager, guess, clues, pattern_name)
        if self.rm and self.rm.submissions_left <= 0 then
            score_manager:add_words(100)
            score_manager:add_hype(10.0)
        end
    end
    event_bus.bus:subscribe('ON_SCORE_CALCULATED', self.apply_bonus_cb)
end
function DeadlineTrope:on_unequip(run_manager)
    if self.apply_bonus_cb then
        event_bus.bus:unsubscribe('ON_SCORE_CALCULATED', self.apply_bonus_cb)
    end
end

local FirstEditionTrope = setmetatable({}, Trope)
FirstEditionTrope.__index = FirstEditionTrope
function FirstEditionTrope.new()
    local self = Trope.new("First Edition", "The first Submission of every round scores x2.0 Hype multiplier.", "None.", 5)
    self.is_debuff_active = false
    return setmetatable(self, FirstEditionTrope)
end
function FirstEditionTrope:on_equip(run_manager)
    self.rm = run_manager
    self.apply_bonus_cb = function(score_manager, guess, clues, pattern_name)
        if self.rm and #self.rm.round_history == 1 then
            score_manager:add_x_hype(2.0)
        end
    end
    event_bus.bus:subscribe('ON_SCORE_CALCULATED', self.apply_bonus_cb)
end
function FirstEditionTrope:on_unequip(run_manager)
    if self.apply_bonus_cb then
        event_bus.bus:unsubscribe('ON_SCORE_CALCULATED', self.apply_bonus_cb)
    end
end

local function create_all_tropes()
    return {
        PlotTwistTrope.new(),
        PurpleProseTrope.new(),
        RedPenTrope.new(),
        GhostwriterTrope.new(),
        InkRibbonTrope.new(),
        DeadlineTrope.new(),
        FirstEditionTrope.new()
    }
end

return {
    Trope = Trope,
    create_all_tropes = create_all_tropes
}
