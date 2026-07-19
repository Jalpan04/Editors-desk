local STYLE_GUIDES_DATA = {
    ["The Total Rewrite"] = {display_name = "The Total Rewrite", description = "0 Greens, 0 Yellows, 5 Greys.", base_words = 10, base_hype = 1.0, upgrade_words = 5, upgrade_hype = 1.0, price = 2},
    ["The Typo"] = {display_name = "The Typo", description = "0 Greens, 1 Yellow, 4 Greys.", base_words = 15, base_hype = 1.5, upgrade_words = 5, upgrade_hype = 1.0, price = 2},
    ["The Brainstorm"] = {display_name = "The Brainstorm", description = "0 Greens, 2 Yellows, 3 Greys.", base_words = 20, base_hype = 2.0, upgrade_words = 10, upgrade_hype = 1.0, price = 2},
    ["The Outline"] = {display_name = "The Outline", description = "0 Greens, 3 Yellows, 2 Greys.", base_words = 30, base_hype = 2.5, upgrade_words = 10, upgrade_hype = 1.0, price = 2},
    ["The Rough Draft"] = {display_name = "The Rough Draft", description = "0 Greens, 4 Yellows, 1 Grey.", base_words = 45, base_hype = 3.0, upgrade_words = 15, upgrade_hype = 1.0, price = 2},
    ["The Jumble"] = {display_name = "The Jumble", description = "0 Greens, 5 Yellows, 0 Greys.", base_words = 100, base_hype = 6.0, upgrade_words = 30, upgrade_hype = 1.5, price = 3},
    ["The Shot in the Dark"] = {display_name = "The Shot in the Dark", description = "1 Green, 0 Yellows, 4 Greys.", base_words = 20, base_hype = 2.0, upgrade_words = 10, upgrade_hype = 1.0, price = 2},
    ["The Spark"] = {display_name = "The Spark", description = "1 Green, 1 Yellow, 3 Greys.", base_words = 25, base_hype = 2.5, upgrade_words = 10, upgrade_hype = 1.0, price = 2},
    ["The Concept"] = {display_name = "The Concept", description = "1 Green, 2 Yellows, 2 Greys.", base_words = 35, base_hype = 3.0, upgrade_words = 10, upgrade_hype = 1.0, price = 2},
    ["The Framework"] = {display_name = "The Framework", description = "1 Green, 3 Yellows, 1 Grey.", base_words = 55, base_hype = 3.5, upgrade_words = 15, upgrade_hype = 1.0, price = 2},
    ["The Paradox"] = {display_name = "The Paradox", description = "1 Green, 4 Yellows, 0 Greys.", base_words = 90, base_hype = 5.0, upgrade_words = 25, upgrade_hype = 1.5, price = 3},
    ["The Foundation"] = {display_name = "The Foundation", description = "2 Greens, 0 Yellows, 3 Greys.", base_words = 35, base_hype = 3.0, upgrade_words = 10, upgrade_hype = 1.0, price = 2},
    ["The Direction"] = {display_name = "The Direction", description = "2 Greens, 1 Yellow, 2 Greys.", base_words = 45, base_hype = 3.5, upgrade_words = 15, upgrade_hype = 1.0, price = 2},
    ["The Revision"] = {display_name = "The Revision", description = "2 Greens, 2 Yellows, 1 Grey.", base_words = 65, base_hype = 4.0, upgrade_words = 20, upgrade_hype = 1.0, price = 2},
    ["The Anagram"] = {display_name = "The Anagram", description = "2 Greens, 3 Yellows, 0 Greys.", base_words = 105, base_hype = 5.5, upgrade_words = 30, upgrade_hype = 1.5, price = 3},
    ["The Solid Lead"] = {display_name = "The Solid Lead", description = "3 Greens, 0 Yellows, 2 Greys.", base_words = 60, base_hype = 4.0, upgrade_words = 20, upgrade_hype = 1.0, price = 2},
    ["The Near Miss"] = {display_name = "The Near Miss", description = "3 Greens, 1 Yellow, 1 Grey.", base_words = 85, base_hype = 4.5, upgrade_words = 25, upgrade_hype = 1.5, price = 3},
    ["The Spoonerism"] = {display_name = "The Spoonerism", description = "3 Greens, 2 Yellows, 0 Greys.", base_words = 130, base_hype = 6.0, upgrade_words = 35, upgrade_hype = 2.0, price = 3},
    ["The Typographical Error"] = {display_name = "The Typographical Error", description = "4 Greens, 0 Yellows, 1 Grey.", base_words = 160, base_hype = 7.0, upgrade_words = 40, upgrade_hype = 2.0, price = 3},
    ["The Masterpiece"] = {display_name = "The Masterpiece", description = "5 Greens, 0 Yellows, 0 Greys.", base_words = 250, base_hype = 10.0, upgrade_words = 50, upgrade_hype = 2.0, price = 4}
}

local StyleGuideUpgrade = {}
StyleGuideUpgrade.__index = StyleGuideUpgrade

function StyleGuideUpgrade.new(pattern_name)
    local self = setmetatable({}, StyleGuideUpgrade)
    self.pattern_name = pattern_name
    local data = STYLE_GUIDES_DATA[pattern_name]
    self.name = "Style Guide: " .. data.display_name
    self.description = "Permanently levels up " .. data.display_name .. " (+" .. data.upgrade_words .. " Words, +" .. data.upgrade_hype .. " Hype)."
    self.price = data.price
    return self
end

function StyleGuideUpgrade:use(run_manager)
    if run_manager.style_guides[self.pattern_name] then
        run_manager.style_guides[self.pattern_name] = run_manager.style_guides[self.pattern_name] + 1
        return "Leveled up " .. self.pattern_name .. " to Level " .. run_manager.style_guides[self.pattern_name] .. "!"
    end
    return "Failed to level up!"
end

return {
    STYLE_GUIDES_DATA = STYLE_GUIDES_DATA,
    StyleGuideUpgrade = StyleGuideUpgrade
}
