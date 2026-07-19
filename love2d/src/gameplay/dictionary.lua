local Dictionary = {}
Dictionary.__index = Dictionary

function Dictionary.new(data_dir)
    local self = setmetatable({}, Dictionary)
    self.target_words = {}
    self.allowed_guesses = {}
    self:load_dictionaries(data_dir or "data")
    return self
end

function Dictionary:load_dictionaries(data_dir)
    local target_path = data_dir .. "/target_words.txt"
    local guess_path = data_dir .. "/allowed_guesses.txt"
    
    if love.filesystem.getInfo(target_path) then
        for line in love.filesystem.lines(target_path) do
            local clean = line:match("^%s*(.-)%s*$"):lower()
            if #clean == 5 then
                table.insert(self.target_words, clean)
            end
        end
    end
    
    if love.filesystem.getInfo(guess_path) then
        for line in love.filesystem.lines(guess_path) do
            local clean = line:match("^%s*(.-)%s*$"):lower()
            if #clean == 5 then
                self.allowed_guesses[clean] = true
            end
        end
    end
    
    for _, word in ipairs(self.target_words) do
        self.allowed_guesses[word] = true
    end
    
    if #self.target_words == 0 then
        self.target_words = {"write", "draft", "story", "novel", "print", "press", "paper", "pages"}
        for _, word in ipairs(self.target_words) do
            self.allowed_guesses[word] = true
        end
    end
end

function Dictionary:is_valid_guess(word)
    if not word then return false end
    local clean = word:match("^%s*(.-)%s*$"):lower()
    return self.allowed_guesses[clean] == true
end

function Dictionary:get_random_target()
    local idx = love.math.random(1, #self.target_words)
    return self.target_words[idx]
end

return Dictionary
