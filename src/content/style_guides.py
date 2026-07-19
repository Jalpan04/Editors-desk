# Style Guides scoring stats and definitions
# Matches Balatro Planet upgrades

STYLE_GUIDES_DATA = {
    "The Total Rewrite": {"display_name": "The Total Rewrite", "description": "0 Greens, 0 Yellows, 5 Greys.", "base_chips": 10, "base_mult": 1.0, "upgrade_chips": 5, "upgrade_mult": 1.0, "price": 2},
    "The Typo": {"display_name": "The Typo", "description": "0 Greens, 1 Yellow, 4 Greys.", "base_chips": 15, "base_mult": 1.5, "upgrade_chips": 5, "upgrade_mult": 1.0, "price": 2},
    "The Brainstorm": {"display_name": "The Brainstorm", "description": "0 Greens, 2 Yellows, 3 Greys.", "base_chips": 20, "base_mult": 2.0, "upgrade_chips": 10, "upgrade_mult": 1.0, "price": 2},
    "The Outline": {"display_name": "The Outline", "description": "0 Greens, 3 Yellows, 2 Greys.", "base_chips": 30, "base_mult": 2.5, "upgrade_chips": 10, "upgrade_mult": 1.0, "price": 2},
    "The Rough Draft": {"display_name": "The Rough Draft", "description": "0 Greens, 4 Yellows, 1 Grey.", "base_chips": 45, "base_mult": 3.0, "upgrade_chips": 15, "upgrade_mult": 1.0, "price": 2},
    "The Jumble": {"display_name": "The Jumble", "description": "0 Greens, 5 Yellows, 0 Greys.", "base_chips": 100, "base_mult": 6.0, "upgrade_chips": 30, "upgrade_mult": 1.5, "price": 3},
    "The Shot in the Dark": {"display_name": "The Shot in the Dark", "description": "1 Green, 0 Yellows, 4 Greys.", "base_chips": 20, "base_mult": 2.0, "upgrade_chips": 10, "upgrade_mult": 1.0, "price": 2},
    "The Spark": {"display_name": "The Spark", "description": "1 Green, 1 Yellow, 3 Greys.", "base_chips": 25, "base_mult": 2.5, "upgrade_chips": 10, "upgrade_mult": 1.0, "price": 2},
    "The Concept": {"display_name": "The Concept", "description": "1 Green, 2 Yellows, 2 Greys.", "base_chips": 35, "base_mult": 3.0, "upgrade_chips": 10, "upgrade_mult": 1.0, "price": 2},
    "The Framework": {"display_name": "The Framework", "description": "1 Green, 3 Yellows, 1 Grey.", "base_chips": 55, "base_mult": 3.5, "upgrade_chips": 15, "upgrade_mult": 1.0, "price": 2},
    "The Paradox": {"display_name": "The Paradox", "description": "1 Green, 4 Yellows, 0 Greys.", "base_chips": 90, "base_mult": 5.0, "upgrade_chips": 25, "upgrade_mult": 1.5, "price": 3},
    "The Foundation": {"display_name": "The Foundation", "description": "2 Greens, 0 Yellows, 3 Greys.", "base_chips": 35, "base_mult": 3.0, "upgrade_chips": 10, "upgrade_mult": 1.0, "price": 2},
    "The Direction": {"display_name": "The Direction", "description": "2 Greens, 1 Yellow, 2 Greys.", "base_chips": 45, "base_mult": 3.5, "upgrade_chips": 15, "upgrade_mult": 1.0, "price": 2},
    "The Revision": {"display_name": "The Revision", "description": "2 Greens, 2 Yellows, 1 Grey.", "base_chips": 65, "base_mult": 4.0, "upgrade_chips": 20, "upgrade_mult": 1.0, "price": 2},
    "The Anagram": {"display_name": "The Anagram", "description": "2 Greens, 3 Yellows, 0 Greys.", "base_chips": 105, "base_mult": 5.5, "upgrade_chips": 30, "upgrade_mult": 1.5, "price": 3},
    "The Solid Lead": {"display_name": "The Solid Lead", "description": "3 Greens, 0 Yellows, 2 Greys.", "base_chips": 60, "base_mult": 4.0, "upgrade_chips": 20, "upgrade_mult": 1.0, "price": 2},
    "The Near Miss": {"display_name": "The Near Miss", "description": "3 Greens, 1 Yellow, 1 Grey.", "base_chips": 85, "base_mult": 4.5, "upgrade_chips": 25, "upgrade_mult": 1.5, "price": 3},
    "The Spoonerism": {"display_name": "The Spoonerism", "description": "3 Greens, 2 Yellows, 0 Greys.", "base_chips": 130, "base_mult": 6.0, "upgrade_chips": 35, "upgrade_mult": 2.0, "price": 3},
    "The Typographical Error": {"display_name": "The Typographical Error", "description": "4 Greens, 0 Yellows, 1 Grey.", "base_chips": 160, "base_mult": 7.0, "upgrade_chips": 40, "upgrade_mult": 2.0, "price": 3},
    "The Masterpiece": {"display_name": "The Masterpiece", "description": "5 Greens, 0 Yellows, 0 Greys.", "base_chips": 250, "base_mult": 10.0, "upgrade_chips": 50, "upgrade_mult": 2.0, "price": 4}
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
