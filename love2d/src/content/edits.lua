local Edit = {}
Edit.__index = Edit

function Edit.new(name, description, price)
    local self = setmetatable({}, Edit)
    self.name = name
    self.description = description
    self.price = price or 3
    return self
end

function Edit:use(run_manager, kwargs)
    return "Effect applied"
end

local MagnifyingGlassEdit = setmetatable({}, Edit)
MagnifyingGlassEdit.__index = MagnifyingGlassEdit
function MagnifyingGlassEdit.new()
    local self = Edit.new("The Magnifying Glass", "Reveals the position of one Green letter in the target word.", 3)
    return setmetatable(self, MagnifyingGlassEdit)
end
function MagnifyingGlassEdit:use(run_manager, kwargs)
    local target = run_manager.target_word
    
    local known_indices = {}
    for _, entry in ipairs(run_manager.round_history) do
        if not entry.is_draft then
            local clues = entry.clues
            local word = entry.word
            for i = 1, #clues do
                if clues[i] == "green" and word:sub(i, i) == target:sub(i, i) then
                    known_indices[i] = true
                end
            end
        end
    end
    
    local unknown_indices = {}
    for i = 1, #target do
        if not known_indices[i] then
            table.insert(unknown_indices, i)
        end
    end
    
    local reveal_idx
    if #unknown_indices == 0 then
        reveal_idx = love.math.random(1, #target)
    else
        reveal_idx = unknown_indices[love.math.random(1, #unknown_indices)]
    end
    
    local letter = target:sub(reveal_idx, reveal_idx):upper()
    return "Clue: Index " .. reveal_idx .. " is '" .. letter .. "'!", true
end

local EspressoShotEdit = setmetatable({}, Edit)
EspressoShotEdit.__index = EspressoShotEdit
function EspressoShotEdit.new()
    local self = Edit.new("The Espresso Shot", "Restores 1 Submission for the current round.", 2)
    return setmetatable(self, EspressoShotEdit)
end
function EspressoShotEdit:use(run_manager, kwargs)
    if run_manager.submissions_left >= run_manager.submissions_max then
        return "Submissions already at maximum!", false
    end
    run_manager.submissions_left = run_manager.submissions_left + 1
    return "Gained +1 Submission!", true
end

local ShredderEdit = setmetatable({}, Edit)
ShredderEdit.__index = ShredderEdit
function ShredderEdit.new()
    local self = Edit.new("The Shredder", "Resets round score, clears the grid, picks a new word, and restores submissions/drafts.", 5)
    return setmetatable(self, ShredderEdit)
end
function ShredderEdit:use(run_manager, kwargs)
    run_manager.round_score = 0
    run_manager.round_history = {}
    run_manager.submissions_left = run_manager.submissions_max
    run_manager.drafts_left = run_manager.drafts_max
    
    if run_manager.boss_assignment == "Minimalist" then
        run_manager.target_word = run_manager:get_4_letter_target()
    else
        run_manager.target_word = run_manager.dictionary:get_random_target()
    end
    
    return "Board shredded! New target word loaded and score reset.", true
end

local WhiteOutEdit = setmetatable({}, Edit)
WhiteOutEdit.__index = WhiteOutEdit
function WhiteOutEdit.new()
    local self = Edit.new("The White-Out", "Removes the debuff from one of your active Tropes.", 8)
    return setmetatable(self, WhiteOutEdit)
end
function WhiteOutEdit:use(run_manager, kwargs)
    local target_tropes = {}
    for _, t in ipairs(run_manager.tropes) do
        if t.is_debuff_active then
            table.insert(target_tropes, t)
        end
    end
    if #target_tropes == 0 then
        return "No active Tropes have debuffs to remove!", false
    end
    
    kwargs = kwargs or {}
    local target_trope = kwargs.target_trope
    if not target_trope then
        target_trope = target_tropes[1]
    end
    
    target_trope.is_debuff_active = false
    
    if target_trope.name == "The Ghostwriter" then
        run_manager:update_target_score()
    elseif target_trope.name == "The Red Pen" then
        run_manager.submissions_max = 4
        run_manager.submissions_left = math.min(run_manager.submissions_left + 1, 4)
    end
    
    return "Debuff removed from '" .. target_trope.name .. "'!", true
end

local function create_all_edits()
    return {
        MagnifyingGlassEdit.new(),
        EspressoShotEdit.new(),
        ShredderEdit.new(),
        WhiteOutEdit.new()
    }
end

return {
    Edit = Edit,
    create_all_edits = create_all_edits
}
