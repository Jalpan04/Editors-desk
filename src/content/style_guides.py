# Style Guides scoring stats and definitions
# Matches Balatro Planet upgrades

STYLE_GUIDES_DATA = {
    "Masterpiece": {
        "display_name": "The Masterpiece",
        "description": "5 Green letters. Guess the exact word.",
        "base_chips": 250,
        "base_mult": 8.0,
        "upgrade_chips": 80,
        "upgrade_mult": 6.0,
        "price": 3
    },
    "Jumble": {
        "display_name": "The Jumble",
        "description": "5 Yellow letters. An exact anagram of the target word.",
        "base_chips": 100,
        "base_mult": 4.0,
        "upgrade_chips": 40,
        "upgrade_mult": 4.0,
        "price": 3
    },
    "Shot in the Dark": {
        "display_name": "The Shot in the Dark",
        "description": "1 Green, 4 Grey letters. Pinpointing just one letter.",
        "base_chips": 20,
        "base_mult": 2.0,
        "upgrade_chips": 15,
        "upgrade_mult": 2.0,
        "price": 2
    },
    "Total Rewrite": {
        "display_name": "The Total Rewrite",
        "description": "5 Grey letters. Guess a word with zero correct letters.",
        "base_chips": 5,
        "base_mult": 1.0,
        "upgrade_chips": 5,
        "upgrade_mult": 1.0,
        "price": 2
    },
    "Standard Submission": {
        "display_name": "Standard Submission",
        "description": "Any other letter combination.",
        "base_chips": 10,
        "base_mult": 1.0,
        "upgrade_chips": 10,
        "upgrade_mult": 1.0,
        "price": 2
    }
}

class StyleGuideUpgrade:
    def __init__(self, pattern_name):
        self.pattern_name = pattern_name
        data = STYLE_GUIDES_DATA[pattern_name]
        self.name = f"Style Guide: {data['display_name']}"
        self.description = f"Permanently levels up {data['display_name']} (+{data['upgrade_chips']} Chips, +{data['upgrade_mult']} Mult)."
        self.price = data["price"]

    def use(self, run_manager):
        """Levels up the style guide for the target pattern."""
        if self.pattern_name in run_manager.style_guides:
            run_manager.style_guides[self.pattern_name] += 1
            return f"Leveled up {self.pattern_name} to Level {run_manager.style_guides[self.pattern_name]}!"
        return "Failed to level up!"
