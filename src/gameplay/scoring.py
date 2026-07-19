import os
from src.engine import event_bus
from src.content.style_guides import STYLE_GUIDES_DATA

# Base word values for each letter
LETTER_WORDS = {
    'e': 1, 't': 1, 'a': 1, 'o': 1, 'i': 1, 'n': 1, 's': 1,
    'h': 2, 'r': 2, 'd': 2, 'l': 2,
    'c': 3, 'u': 3, 'm': 3, 'w': 3, 'f': 3, 'g': 3, 'y': 3,
    'p': 4, 'b': 4, 'v': 4, 'k': 4,
    'j': 8, 'x': 8, 'q': 10, 'z': 10
}

def check_word(guess, target):
    """
    Wordle comparison algorithm that correctly handles duplicate letters.
    Returns a list of clues: 'green', 'yellow', or 'grey'.
    """
    guess = guess.lower()
    target = target.lower()
    length = len(guess)
    clues = ['grey'] * length
    
    target_matched = [False] * length
    guess_matched = [False] * length
    
    # First pass: find exact matches (green)
    for i in range(length):
        if guess[i] == target[i]:
            clues[i] = 'green'
            target_matched[i] = True
            guess_matched[i] = True
            
    # Second pass: find partial matches (yellow)
    for i in range(length):
        if not guess_matched[i]:
            for j in range(length):
                if not target_matched[j] and guess[i] == target[j]:
                    clues[i] = 'yellow'
                    target_matched[j] = True
                    break
                    
    return clues

def identify_pattern(clues, guess, target):
    """
    Identifies the feedback pattern category of the submission.
    """
    green_count = clues.count('green')
    yellow_count = clues.count('yellow')
    
    combo_map = {
        (0, 0): "The Total Rewrite",
        (0, 1): "The Typo",
        (0, 2): "The Brainstorm",
        (0, 3): "The Outline",
        (0, 4): "The Rough Draft",
        (0, 5): "The Jumble",
        (1, 0): "The Shot in the Dark",
        (1, 1): "The Spark",
        (1, 2): "The Concept",
        (1, 3): "The Framework",
        (1, 4): "The Paradox",
        (2, 0): "The Foundation",
        (2, 1): "The Direction",
        (2, 2): "The Revision",
        (2, 3): "The Anagram",
        (3, 0): "The Solid Lead",
        (3, 1): "The Near Miss",
        (3, 2): "The Spoonerism",
        (4, 0): "The Typographical Error",
        (5, 0): "The Masterpiece"
    }

    return combo_map.get((green_count, yellow_count), "Standard Submission")

class ScoreManager:
    def __init__(self):
        self.words = 0
        self.hype = 0.0
        self.x_hypes = []  # List of multiplicative multipliers (e.g. x1.5, x3.0)

    def add_words(self, amount):
        self.words += amount

    def add_hype(self, amount):
        self.hype += amount

    def add_x_hype(self, multiplier):
        self.x_hypes.append(multiplier)

    def calculate_total(self):
        """Calculates final score: Words * (Hype * Product of x_hypes)"""
        total_hype = self.hype
        for xm in self.x_hypes:
            total_hype *= xm
        # Multiplier cannot fall below 1
        total_hype = max(1.0, total_hype)
        return int(self.words * total_hype)

def calculate_word_score(guess, target, style_guides_levels, keyboard_mods, boss_blind=None):
    """
    Calculates the detailed score for a word.
    
    style_guides_levels: dict of {"PatternName": level_int}
    keyboard_mods: dict of {"letter": {"highlighter": bool, "coffee_ring": bool, "stapler": bool}}
    """
    guess = guess.lower()
    target = target.lower()
    clues = check_word(guess, target)
    
    # Pre-pattern evaluation: Correction Tape forces clues to Grey
    for i, letter in enumerate(guess):
        if keyboard_mods.get(letter, {}).get("correction_tape", False):
            clues[i] = 'grey'
            
    pattern_name = identify_pattern(clues, guess, target)
    
    # Plagiarist Boss Blind Jumble exploit prevention
    if boss_blind == "Plagiarist" and pattern_name == "The Jumble":
        pattern_name = "The Rough Draft" # Downgrade to 4 Yellows for boss logic
        
    score_mgr = ScoreManager()
    
    # 1. Base Score from Style Guide / Pattern Level
    base_info = STYLE_GUIDES_DATA[pattern_name]
    level = style_guides_levels.get(pattern_name, 1)
    
    # Base = Starting Value + (Level - 1) * Level Increment
    base_words = base_info["base_words"] + (level - 1) * base_info["upgrade_words"]
    base_hype = base_info["base_hype"] + (level - 1) * base_info["upgrade_hype"]
    
    score_mgr.add_words(base_words)
    score_mgr.add_hype(base_hype)
    
    # 2. Score Individual Letters
    for i, letter in enumerate(guess):
        clue = clues[i]
        
        # Check keyboard mods for this letter
        mods = keyboard_mods.get(letter, {})
        is_highlighted = mods.get("highlighter", False)
        is_correction_tape = mods.get("correction_tape", False)
        is_stapled = mods.get("stapler", False)
        
        # Stapler causes the letter's scoring to trigger twice
        repeat_count = 2 if is_stapled else 1
        
        for _ in range(repeat_count):
            # Letter base points: equal for all characters, decided only by clue color:
            # green=5, yellow=1, grey=0
            if clue == 'green':
                let_words = 5
            elif clue == 'yellow':
                let_words = 1
            else:
                let_words = 0
                
            # Add mods bonuses
            if is_highlighted:
                score_mgr.add_hype(15.0)
            if is_correction_tape:
                score_mgr.add_words(100)
                
            # Add letter words
            score_mgr.add_words(let_words)
                
        # Fire event for letter-level custom adjustments (e.g. from Tropes)
        event_bus.bus.publish('ON_LETTER_SCORED', letter, i, clue, score_mgr)
        
    # 3. Fire event for overall word-level adjustments (e.g. Plot Twist, Red Pen)
    event_bus.bus.publish('ON_SCORE_CALCULATED', score_mgr, guess, clues, pattern_name)
    
    final_score = score_mgr.calculate_total()
    return {
        "score": final_score,
        "words": score_mgr.words,
        "hype": score_mgr.hype,
        "x_hypes": score_mgr.x_hypes,
        "clues": clues,
        "pattern": pattern_name
    }
