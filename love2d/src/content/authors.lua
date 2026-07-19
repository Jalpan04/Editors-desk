local AUTHORS_DATA = {
    Minimalist = {
        display_name = "The Minimalist",
        description = "Hates clutter. You are only allowed to submit words that are exactly 4 letters long (the 5th slot is disabled).",
        intro_text = "The Minimalist demands brevity. 4-letter target and guesses only."
    },
    Plagiarist = {
        display_name = "The Plagiarist",
        description = "The hidden word is guaranteed to be an anagram of the very first word you submit.",
        intro_text = "The Plagiarist copies your voice. Your first guess sets the letter pool."
    },
    Ghostwriter = {
        display_name = "The Ghostwriter",
        description = "Used disappearing ink. You do not see letter colors until the end of the round; you only see the scoring tally.",
        intro_text = "The Ghostwriter writes in shadows. Letter clues are invisible until completion."
    }
}

local Author = {}
Author.__index = Author

function Author.new(name)
    local self = setmetatable({}, Author)
    self.name = name
    local data = AUTHORS_DATA[name] or {
        display_name = "Unknown Author",
        description = "A mysterious guest.",
        intro_text = "Prepare yourself."
    }
    self.display_name = data.display_name
    self.description = data.description
    self.intro_text = data.intro_text
    return self
end

return {
    AUTHORS_DATA = AUTHORS_DATA,
    Author = Author
}
